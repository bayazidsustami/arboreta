import Foundation
import AVFoundation
import CoreImage
import CoreGraphics
import AppKit
import AudioKit
import AudioKitEX
import SoundpipeAudioKit
import Accelerate
import MetalKit

// MARK: - Video Capture and Color Extraction

class VideoProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let ciContext = CIContext()
    var onColorsExtracted: (([NSColor]) -> Void)?

    override init() {
        super.init()
        session.sessionPreset = .high
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        session.addOutput(output)
        session.startRunning()
    }

    // Simple dominant‑color extraction using k‑means (k=5)
    private func dominantColors(from image: CIImage) -> [NSColor] {
        guard let bitmap = ciContext.createCGImage(image, from: image.extent) else { return [] }
        let width = bitmap.width, height = bitmap.height
        guard let data = bitmap.dataProvider?.data else { return [] }
        let ptr = CFDataGetBytePtr(data)!
        var pixels: [[Float]] = []
        for y in stride(from: 0, to: height, by: 4) {
            for x in stride(from: 0, to: width, by: 4) {
                let i = ((width * y) + x) * 4
                let r = Float(ptr[i]) / 255.0
                let g = Float(ptr[i+1]) / 255.0
                let b = Float(ptr[i+2]) / 255.0
                pixels.append([r,g,b])
            }
        }
        // k‑means (5 iterations, 5 clusters)
        var centroids = (0..<5).map { _ in pixels.randomElement()! }
        for _ in 0..<5 {
            var clusters = Array(repeating: [[Float]](), count: 5)
            for p in pixels {
                let dists = centroids.map { zip($0, p).map(-).map { $0*$0 }.reduce(0,+) }
                let idx = dists.firstIndex(of: dists.min()!)!
                clusters[idx].append(p)
            }
            for i in 0..<5 {
                if clusters[i].isEmpty { continue }
                let sum = clusters[i].reduce([0.0,0.0,0.0]) { zip($0,$1).map(+)}
                centroids[i] = sum.map { $0/Float(clusters[i].count) }
            }
        }
        return centroids.map {
            let color = NSColor(calibratedRed: CGFloat($0[0]),
                               green: CGFloat($0[1]),
                               blue: CGFloat($0[2]),
                               alpha: 1.0)
            return color
        }
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let colors = dominantColors(from: ciImage)
        DispatchQueue.main.async { self.onColorsExtracted?(colors) }
    }
}

// MARK: - Audio Synthesis from Colors

class ColorSynthesizer {
    private let engine = AudioEngine()
    private let oscillator = Oscillator()
    private var timer: Timer?

    init() {
        oscillator.amplitude = 0.0
        engine.output = Mixer(oscillator)
        try? engine.start()
    }

    // Map hue→pitch, saturation→volume, brightness→density (affects tremolo rate)
    func play(colors: [NSColor]) {
        timer?.invalidate()
        var idx = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            guard !colors.isEmpty else { return }
            let c = colors[idx % colors.count]
            let hsba = c.usingColorSpace(.deviceRGB)!.hsbaComponents
            let pitch = 220.0 * pow(2.0, Double(hsba.hue) * 2.0)   // two octaves
            let volume = Double(hsba.saturation) * 0.5 + 0.1
            let tremRate = Double(hsba.brightness) * 8.0 + 2.0

            self.oscillator.frequency = AUValue(pitch)
            self.oscillator.amplitude = AUValue(volume)

            // simple tremolo for rhythmic density
            self.oscillator.$amplitude.ramp(to: 0.0, duration: 0.05)
            self.oscillator.$amplitude.ramp(to: AUValue(volume), duration: 0.05, delay: AUValue(1.0 / tremRate))

            idx += 1
        }
    }
}

// MARK: - Visual Kaleidoscope Driven by Audio FFT

class KaleidoscopeView: MTKView {
    private var pipelineState: MTLRenderPipelineState!
    private var commandQueue: MTLCommandQueue!
    private var vertexBuffer: MTLBuffer!
    private var audioFFT: FFTTap!
    private var spectrum: [Float] = Array(repeating: 0, count: 64)

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override init(frame frameRect: NSRect, device: MTLDevice?) {
        let dev = MTLCreateSystemDefaultDevice()!
        super.init(frame: frameRect, device: dev)
        self.commandQueue = dev.makeCommandQueue()
        self.colorPixelFormat = .bgra8Unorm
        buildPipeline()
        buildGeometry()
        setupAudioTap()
    }

    private func buildPipeline() {
        let lib = device!.makeDefaultLibrary()!
        let vert = lib.makeFunction(name: "vertex_main")!
        let frag = lib.makeFunction(name: "fragment_main")!
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vert
        desc.fragmentFunction = frag
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineState = try! device!.makeRenderPipelineState(descriptor: desc)
    }

    private func buildGeometry() {
        // simple full‑screen quad
        let verts: [Float] = [-1, -1, 0, 1,
                               1, -1, 1, 1,
                              -1,  1, 0, 0,
                               1,  1, 1, 0]
        vertexBuffer = device!.makeBuffer(bytes: verts, length: verts.count*4, options: [])
    }

    private func setupAudioTap() {
        let tracker = FFTTracker()
        audioFFT = FFTTap(tracker.input) { [weak self] fftData in
            guard let self = self else { return }
            self.spectrum = fftData
        }
        audioFFT.start()
    }

    override func draw(_ rect: NSRect) {
        guard let drawable = currentDrawable,
              let cmd = commandQueue.makeCommandBuffer(),
              let encoder = cmd.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor!) else { return }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

        // Pass FFT magnitude as a texture‑like uniform
        var fft = spectrum
        encoder.setFragmentBytes(&fft, length: MemoryLayout<Float>.size * fft.count, index: 0)

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        cmd.present(drawable)
        cmd.commit()
    }
}

// MARK: - Shader Code (embedded as strings)

let metalShader = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut vertex_main(const device float4 *verts [[buffer(0)]],
                             uint id [[vertex_id]]) {
    VertexOut out;
    out.position = verts[id];
    out.uv = verts[id].zw;
    return out;
}

fragment half4 fragment_main(VertexOut in [[stage_in]],
                             constant float *fft [[buffer(0)]]) {
    float angle = in.uv.x * 6.2831 + fft[uint(in.uv.y*63)] * 5.0;
    float2 p = float2(cos(angle), sin(angle));
    float brightness = smoothstep(0.4,0.5,length(p));
    return half4(brightness, brightness*0.5, brightness*0.8, 1.0);
}
"""

// Compile shaders at runtime
func compileShaders(for view: MTKView) {
    let device = view.device!
    let library = try! device.makeLibrary(source: metalShader, options: nil)
    // The KaleidoscopeView will rebuild its pipeline using this library
}

// MARK: - Application Setup

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var videoProcessor: VideoProcessor!
    var synth: ColorSynthesizer!
    var kaleidoView: KaleidoscopeView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Window
        window = NSWindow(contentRect: NSMakeRect(0,0,800,600),
                          styleMask:[.titled,.closable,.resizable],
                          backing:.buffered,
                          defer:false)
        window.title = "Synesthetic Live"
        window.makeKeyAndOrderFront(nil)

        // Visual view
        kaleidoView = KaleidoscopeView(frame: window.contentView!.bounds)
        kaleidoView.autoresizingMask = [.width,.height]
        window.contentView?.addSubview(kaleidoView)

        // Audio & Video
        synth = ColorSynthesizer()
        videoProcessor = VideoProcessor()
        videoProcessor.onColorsExtracted = { [weak self] colors in
            self?.synth.play(colors: colors)
        }

        compileShaders(for: kaleidoView)
    }
}

// MARK: - Run

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()