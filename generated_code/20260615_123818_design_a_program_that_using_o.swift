import Foundation
import AVFoundation
import Vision
import CoreImage

// MARK: - Terminal Helpers
struct ANSI {
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> String {
        "\u{001B}[38;2;\(r);\(g);\(b)m"
    }
    static let reset = "\u{001B}[0m"
}
let block = "█"   // full block character

// MARK: - Audio Spectrum Analyzer
class AudioAnalyzer {
    private let engine = AVAudioEngine()
    private var bufferSize: AVAudioFrameCount = 1024
    private var fftSetup: FFTSetup?
    private var log2n: vDSP_Length = 10   // 2^10 = 1024
    
    init() {
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }
        try? engine.start()
    }
    
    var lastMagnitudes: [Float] = Array(repeating: 0, count: 512)
    private func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        var window = [Float](repeating: 0, count: frameCount)
        vDSP_hann_window(&window, vDSP_Length(frameCount), Int32(vDSP_HANN_N))
        var windowed = [Float](repeating:0, count: frameCount)
        vDSP_vmul(channelData, 1, window, 1, &windowed, 1, vDSP_Length(frameCount))
        
        var real = [Float](repeating:0, count: 512)
        var imag = [Float](repeating:0, count: 512)
        real.withUnsafeMutableBufferPointer { rPtr in
            imag.withUnsafeMutableBufferPointer { iPtr in
                var splitComplex = DSPSplitComplex(realp: rPtr.baseAddress!, imagp: iPtr.baseAddress!)
                windowed.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                    ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: frameCount) { typeConvertedTransferBuffer in
                        vDSP_ctoz(typeConvertedTransferBuffer, 2, &splitComplex, 1, vDSP_Length(512))
                    }
                }
                vDSP_fft_zrip(fftSetup!, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                var magnitudes = [Float](repeating:0, count:512)
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(512))
                var normalized = [Float](repeating:0, count:512)
                vDSP_vsmul(sqrt(magnitudes), 1, [2.0/Float(frameCount)], &normalized, 1, vDSP_Length(512))
                self.lastMagnitudes = normalized
            }
        }
    }
}

// MARK: - Video & Eye‑Tracking
class EyeTracker {
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "eyeTrackerQueue")
    var gazeX: CGFloat = 0.5   // normalized [0,1]
    
    init() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .front) else { return }
        let input = try? AVCaptureDeviceInput(device: device)
        captureSession.beginConfiguration()
        if let input = input, captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: queue)
        }
        captureSession.commitConfiguration()
        captureSession.startRunning()
    }
}
extension EyeTracker: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        let request = VNDetectFaceLandmarksRequest { [weak self] req, err in
            guard let results = req.results as? [VNFaceObservation],
                  let face = results.first,
                  let landmarks = face.landmarks,
                  let leftPupil = landmarks.leftPupil?.normalizedPoints.first,
                  let rightPupil = landmarks.rightPupil?.normalizedPoints.first else { return }
            // average pupils -> gaze direction (very rough)
            let avg = CGPoint(x: (leftPupil.x + rightPupil.x)/2,
                              y: (leftPupil.y + rightPupil.y)/2)
            self?.gazeX = CGFloat(avg.x)  // 0..1 left‑to‑right
        }
        try? handler.perform([request])
    }
}

// MARK: - Mandala Renderer
class Mandala {
    let rows = 24
    let cols = 48
    var rules: [(Float) -> (Int, Int, Int)] = []
    
    init() {
        // initial rule: map magnitude to hue, radius, intensity
        rules.append { mag in
            let hue = Int((mag * 360).truncatingRemainder(dividingBy: 360))
            let radius = Int(mag * 12) % 12
            let bright = Int(mag * 255)
            return (hue, radius, bright)
        }
    }
    
    func evolve(gaze: CGFloat) {
        // simple self‑modification: shift rule parameters based on gaze
        if gaze > 0.6 {
            // add a new mapping that swaps hue and brightness
            rules.append { mag in
                let bright = Int((mag * 360).truncatingRemainder(dividingBy: 360))
                let hue = Int(mag * 255)
                let radius = Int(mag * 12) % 12
                return (hue, radius, bright)
            }
        } else if gaze < 0.4, !rules.isEmpty {
            // occasionally drop the last rule
            _ = rules.popLast()
        }
    }
    
    func render(spectrum: [Float]) -> String {
        var output = ""
        let centerX = cols / 2
        let centerY = rows / 2
        
        for y in 0..<rows {
            for x in 0..<cols {
                let dx = x - centerX
                let dy = y - centerY
                let dist = sqrt(Double(dx*dx + dy*dy))
                // pick a magnitude based on distance bucket
                let idx = min(Int(dist) * 4, spectrum.count - 1)
                let mag = spectrum[idx]
                // apply first rule (could be more complex)
                let (hue, radius, bright) = rules.first?(mag) ?? (0,0,0)
                if Int(dist) % (radius + 1) == 0 {
                    let color = ANSI.rgb(hue % 256, bright % 256, 128)
                    output += color + block + ANSI.reset
                } else {
                    output += " "
                }
            }
            output += "\n"
        }
        return output
    }
}

// MARK: - Main Loop
let audio = AudioAnalyzer()
let eye = EyeTracker()
let mandala = Mandala()

// Render at ~15 FPS
let timer = DispatchSource.makeTimerSource(queue: .global())
timer.schedule(deadline: .now(), repeating: .milliseconds(66))
timer.setEventHandler {
    mandala.evolve(gaze: eye.gazeX)
    let frame = mandala.render(spectrum: audio.lastMagnitudes)
    // Clear screen
    print("\u{001B}[2J\u{001B}[H", terminator: "")
    print(frame)
}
timer.resume()

// Keep script alive
RunLoop.main.run()