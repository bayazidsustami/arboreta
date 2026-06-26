import Foundation
import AVFoundation
import CoreImage
import CoreGraphics
import AppKit   // needed for NSBitmapImageRep, NSImage
import AudioKit   // Swift Package Manager dependency
import simd

// MARK: - Helper Extensions

extension CIImage {
    /// Returns an array of the most dominant colors using a simple k‑means clustering.
    func dominantColors(count: Int = 5) -> [NSColor] {
        guard let cgImage = CIContext().createCGImage(self, from: extent) else { return [] }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return [] }
        let pixelData = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> [SIMD3<Float>] in
            let bytes = ptr.bindMemory(to: UInt8.self)
            var result: [SIMD3<Float>] = []
            for i in stride(from: 0, to: bytes.count, by: 4) {
                let r = Float(bytes[i]) / 255.0
                let g = Float(bytes[i+1]) / 255.0
                let b = Float(bytes[i+2]) / 255.0
                result.append(SIMD3(r,g,b))
            }
            return result
        }
        // Very naive k‑means (max 10 iterations)
        var centroids = (0..<count).map { _ in pixelData.randomElement()! }
        for _ in 0..<10 {
            var clusters = Array(repeating: [SIMD3<Float>](), count: count)
            for p in pixelData {
                let distances = centroids.map { simd_distance($0, p) }
                let idx = distances.firstIndex(of: distances.min()!)!
                clusters[idx].append(p)
            }
            for i in 0..<count where !clusters[i].isEmpty {
                centroids[i] = clusters[i].reduce(SIMD3<Float>(repeating: 0), +) / Float(clusters[i].count)
            }
        }
        return centroids.map {
            NSColor(red: CGFloat($0.x), green: CGFloat($0.y), blue: CGFloat($0.z), alpha: 1.0)
        }
    }
}

// Simple 12‑tone scale derived from golden ratio
let goldenRatio = 1.61803398875
let baseFreq: Double = 440.0   // A4
let scaleFrequencies: [Double] = (0..<12).map {
    baseFreq * pow(goldenRatio, Double($0) - 6.0)   // shift to centre around A4
}

// MARK: - Audio Engine (AudioKit)

class ToneSynth {
    private let engine = AudioEngine()
    private var osc = Oscillator()
    private var mixer = Mixer()
    
    init() {
        mixer.addInput(osc)
        engine.output = mixer
        try? engine.start()
    }
    
    func play(frequency: Double, amplitude: Double, duration: Double) {
        osc.frequency = frequency
        osc.amplitude = amplitude
        osc.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.osc.stop()
        }
    }
}

// MARK: - Voronoi Renderer

class VoronoiRenderer {
    private let width: Int
    private let height: Int
    private var points: [CGPoint] = []
    private var time: Double = 0.0
    
    init(width: Int, height: Int, pointCount: Int = 30) {
        self.width = width
        self.height = height
        for _ in 0..<pointCount {
            points.append(randomPoint())
        }
    }
    
    private func randomPoint() -> CGPoint {
        CGPoint(x: CGFloat.random(in: 0...width), y: CGFloat.random(in: 0...height))
    }
    
    /// Update point positions based on an amplitude value (0‑1)
    func update(amplitude: Double) {
        time += 0.02
        for i in 0..<points.count {
            let angle = Double(i) / Double(points.count) * Double.pi * 2 + time
            let radius = amplitude * 30.0
            let dx = cos(angle) * radius
            let dy = sin(angle) * radius
            var p = points[i]
            p.x = max(0, min(CGFloat(width), p.x + CGFloat(dx)))
            p.y = max(0, min(CGFloat(height), p.y + CGFloat(dy)))
            points[i] = p
        }
    }
    
    /// Render a bitmap of the Voronoi diagram.
    func render() -> CGImage? {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        // Very naive cell coloring: nearest point determines cell colour
        for y in 0..<height {
            for x in 0..<width {
                let pt = CGPoint(x: x, y: y)
                var minDist = Double.greatestFiniteMagnitude
                var idx = 0
                for (i, p) in points.enumerated() {
                    let d = hypot(Double(p.x - pt.x), Double(p.y - pt.y))
                    if d < minDist {
                        minDist = d
                        idx = i
                    }
                }
                // colour based on point index
                let hue = CGFloat(idx) / CGFloat(points.count)
                ctx.setFillColor(NSColor(hue: hue, saturation: 0.6, brightness: 0.9, alpha: 1.0).cgColor)
                ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.cgImage
    }
}

// MARK: - Video & Audio Recording

class AVRecorder {
    private let writer: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let audioInput: AVAssetWriterInput
    private let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    private var frameCount: Int64 = 0
    private let fps: Int32 = 30
    
    init(outputURL: URL, width: Int, height: Int) throws {
        writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput,
                                                                 sourcePixelBufferAttributes: nil)
        writer.add(videoInput)
        
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false
        ]
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = true
        writer.add(audioInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
    }
    
    func append(frame: CGImage, at time: CMTime) {
        guard videoInput.isReadyForMoreMediaData,
              let buffer = pixelBuffer(from: frame) else { return }
        pixelBufferAdaptor.append(buffer, withPresentationTime: time)
    }
    
    func append(audioBuffer: AVAudioPCMBuffer, at time: CMTime) {
        guard audioInput.isReadyForMoreMediaData else { return }
        let sampleBuffer = audioBuffer.sampleBuffer(withPresentationTime: time)
        audioInput.append(sampleBuffer)
    }
    
    func finish(completion: @escaping () -> Void) {
        videoInput.markAsFinished()
        audioInput.markAsFinished()
        writer.finishWriting {
            completion()
        }
    }
    
    private func pixelBuffer(from image: CGImage) -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        let options: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         image.width,
                                         image.height,
                                         kCVPixelFormatType_32ARGB,
                                         options as CFDictionary,
                                         &pb)
        guard status == kCVReturnSuccess, let buffer = pb else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                            width: image.width,
                            height: image.height,
                            bitsPerComponent: 8,
                            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        ctx?.draw(image, in: CGRect(x: 0, y: 0,
                                    width: image.width,
                                    height: image.height))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
}

// MARK: - Main Pipeline

let captureSession = AVCaptureSession()
captureSession.sessionPreset = .high

guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                for: .video,
                                                position: .front),
      let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
    fatalError("Cannot access camera")
}
captureSession.addInput(videoInput)

let videoOutput = AVCaptureVideoDataOutput()
videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:
                                kCVPixelFormatType_32BGRA]
let outputQueue = DispatchQueue(label: "videoQueue")
videoOutput.setSampleBufferDelegate(nil, queue: outputQueue) // will set later
captureSession.addOutput(videoOutput)

let synth = ToneSynth()
let renderer = VoronoiRenderer(width: 640, height: 480)

let outputURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kaleido.mov")
let recorder = try! AVRecorder(outputURL: outputURL, width: 640, height: 480)

var startTime = CFAbsoluteTimeGetCurrent()

videoOutput.setSampleBufferDelegate(
    NSObject(),
    queue: outputQueue
)

// Custom delegate class to avoid NSObject subclass in-line
class FrameHandler: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let synth: ToneSynth
    let renderer: VoronoiRenderer
    let recorder: AVRecorder
    let start: CFAbsoluteTime
    init(synth: ToneSynth, renderer: VoronoiRenderer, recorder: AVRecorder, start: CFAbsoluteTime) {
        self.synth = synth
        self.renderer = renderer
        self.recorder = recorder
        self.start = start
    }
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        // 1. extract dominant colors
        let colors = ciImage.dominantColors(count: 3)
        // 2. map first color to nearest frequency
        if let first = colors.first {
            let rgb = first.usingColorSpace(.deviceRGB)!
            let lum = 0.2126*rgb.redComponent + 0.7152*rgb.greenComponent + 0.0722*rgb.blueComponent
            let idx = Int(lum * Double(scaleFrequencies.count-1))
            let freq = scaleFrequencies[idx]
            // 3. play short note, amplitude from brightness
            synth.play(frequency: freq, amplitude: Double(lum), duration: 0.1)
            // 4. use amplitude to drive Voronoi geometry
            renderer.update(amplitude: lum)
        }
        // 5. render Voronoi image
        guard let img = renderer.render() else { return }
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        let pts = CMTime(value: CMTimeValue(elapsed*30.0), timescale: 30)
        recorder.append(frame: img, at: pts)
    }
}

let handler = FrameHandler(synth: synth, renderer: renderer, recorder: recorder, start: startTime)
videoOutput.setSampleBufferDelegate(handler, queue: outputQueue)

captureSession.startRunning()

// Run for a fixed duration (e.g., 10 seconds) then clean up
DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
    captureSession.stopRunning()
    recorder.finish {
        print("Finished → \(outputURL.path)")
        exit(0)
    }
}

// Keep the runloop alive
RunLoop.main.run()