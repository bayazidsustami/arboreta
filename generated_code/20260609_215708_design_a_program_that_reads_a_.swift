import SwiftUI
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import AudioKit
import AudioKitEX
import SoundpipeAudioKit
import MetalKit

// MARK: - Color ↔︎ MIDI mapping
struct ColorNoteMapper {
    // simple 12‑note scale starting at C
    private let notes: [MIDINoteNumber] = [60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79]
    
    func note(for color: UIColor) -> MIDINoteNumber {
        // Convert hue (0…1) to index in notes array
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alp: CGFloat = 0
        color.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alp)
        let idx = Int((hue * CGFloat(notes.count)).truncatingRemainder(dividingBy: CGFloat(notes.count)))
        return notes[idx]
    }
}

// MARK: - Camera & dominant color extraction
final class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var dominantColor: UIColor = .black
    
    private let session = AVCaptureSession()
    private let context = CIContext()
    private let mapper = ColorNoteMapper()
    private let midi = MIDISampler()
    
    override init() {
        super.init()
        setupSession()
        try? midi.loadInstrument(.piano)
    }
    
    private func setupSession() {
        session.beginConfiguration()
        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: cam) else { return }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera"))
        session.addOutput(output)
        session.commitConfiguration()
        session.startRunning()
    }
    
    // called for each video frame
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ci = CIImage(cvPixelBuffer: pixel)
        // downscale to 1×1 pixel to get average color (approx dominant)
        let scale = CGAffineTransform(scaleX: 0.01, y: 0.01)
        let tiny = ci.transformed(by: scale)
        guard let bitmap = context.createCGImage(tiny, from: tiny.extent) else { return }
        let data = CFDataCreateMutable(nil, 0)!
        let destination = CGImageDestinationCreateWithData(data, kUTTypePNG, 1, nil)!
        CGImageDestinationAddImage(destination, bitmap, nil)
        CGImageDestinationFinalize(destination)
        guard let img = UIImage(data: data as Data) else { return }
        let color = img.averageColor ?? .black
        
        DispatchQueue.main.async {
            self.dominantColor = color
            self.playChord(for: color)
        }
    }
    
    private func playChord(for color: UIColor) {
        // generate triad based on hue
        let root = mapper.note(for: color)
        let third = root + 4   // major third
        let fifth = root + 7   // perfect fifth
        try? midi.play(noteNumber: root, velocity: 100, channel: 0)
        try? midi.play(noteNumber: third, velocity: 100, channel: 0)
        try? midi.play(noteNumber: fifth, velocity: 100, channel: 0)
    }
}

// MARK: - Fractal renderer (simple kaleidoscopic shader)
struct FractalView: NSViewRepresentable {
    class Coordinator: NSObject, MTKViewDelegate {
        var device: MTLDevice!
        var commandQueue: MTLCommandQueue!
        var pipeline: MTLRenderPipelineState!
        var time: Float = 0
        var color: SIMD4<Float> = .zero
        
        init(mtkView: MTKView) {
            device = MTLCreateSystemDefaultDevice()
            mtkView.device = device
            commandQueue = device.makeCommandQueue()
            let lib = device.makeDefaultLibrary()!
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = lib.makeFunction(name: "vert")
            desc.fragmentFunction = lib.makeFunction(name: "frag")
            desc.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
            pipeline = try! device.makeRenderPipelineState(descriptor: desc)
            mtkView.delegate = self
        }
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor else { return }
            time += 1/60
            let cmd = commandQueue.makeCommandBuffer()!
            let enc = cmd.makeRenderCommandEncoder(descriptor: descriptor)!
            enc.setRenderPipelineState(pipeline)
            enc.setFragmentBytes(&time, length: MemoryLayout<Float>.size, index: 0)
            enc.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.size, index: 1)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            enc.endEncoding()
            cmd.present(drawable)
            cmd.commit()
        }
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    }
    
    @Binding var uiColor: UIColor
    
    func makeCoordinator() -> Coordinator {
        let mtk = MTKView()
        return Coordinator(mtkView: mtk)
    }
    
    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = 60
        context.coordinator.device = MTLCreateSystemDefaultDevice()
        view.device = context.coordinator.device
        view.delegate = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        context.coordinator.color = SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
    }
}

// MARK: - SwiftUI App
@main
struct KaleidoMusicApp: App {
    @StateObject private var cam = CameraManager()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                FractalView(uiColor: $cam.dominantColor)
                    .ignoresSafeArea()
                VStack {
                    Circle()
                        .fill(Color(cam.dominantColor))
                        .frame(width: 120, height: 120)
                        .overlay(Text("🎹").font(.largeTitle))
                        .padding()
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Helper extensions
extension UIImage {
    var averageColor: UIColor? {
        guard let input = CIImage(image: self) else { return nil }
        let extent = input.extent
        let filter = CIFilter.areaAverage()
        filter.inputImage = input
        filter.extent = extent
        guard let output = filter.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        let ctx = CIContext()
        ctx.render(output,
                   toBitmap: &bitmap,
                   rowBytes: 4,
                   bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                   format: .RGBA8,
                   colorSpace: CGColorSpaceCreateDeviceRGB())
        return UIColor(red: CGFloat(bitmap[0]) / 255,
                       green: CGFloat(bitmap[1]) / 255,
                       blue: CGFloat(bitmap[2]) / 255,
                       alpha: CGFloat(bitmap[3]) / 255)
    }
}

// MARK: - Metal Shaders (embedded as strings)
let metalShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
};

vertex VertexOut vert(uint vid [[vertex_id]]) {
    float4 pos[3] = { float4(-1,-1,0,1), float4(3,-1,0,1), float4(-1,3,0,1) };
    VertexOut out;
    out.position = pos[vid];
    return out;
}

fragment float4 frag(VertexOut in [[stage_in]],
                     constant float &time [[buffer(0)]],
                     constant float4 &color [[buffer(1)]]) {
    float2 uv = in.position.xy * 0.5 + 0.5;
    float2 p = uv - 0.5;
    float r = length(p);
    float a = atan2(p.y, p.x) + time;
    float v = sin(r*10.0 - time*5.0);
    float4 col = mix(color, float4(v, v*0.5, 1.0 - v, 1.0), 0.5);
    return col;
}
"""

// Compile the shader at runtime (required for playgrounds / scripts)
class ShaderLoader {
    static let shared = ShaderLoader()
    var library: MTLLibrary?
    private init() {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        library = try? device.makeLibrary(source: metalShaderSource, options: nil)
    }
}
 
// Patch MTKView to use our runtime compiled library
extension MTKView {
    open override func draw(_ rect: NSRect) {
        // force redraw – real work is done in coordinator
    }
}