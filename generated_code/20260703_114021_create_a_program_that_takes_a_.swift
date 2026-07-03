import Foundation
import AVFoundation
import Vision
import AppKit

// MARK: - Global Settings
let frameInterval: TimeInterval = 0.2               // seconds between processed frames
let asciiWidth = 80                                 // width of ASCII output
let asciiHeight = 24                                // height of ASCII output
let moodGradients: [(String, String)] = [           // (terrain, weather) per mood
    ("🌲🌲🌲🌲🌲🌲🌲🌲🌲🌲", "☀️"),   // very happy
    ("🌳🌳🌳🌳🌳🌳🌳🌳", "🌤️"),   // happy
    ("🌾🌾🌾🌾", "🌥️"),          // neutral
    ("🍂🍂🍂", "🌧️"),          // sad
    ("🪦🪦🪦", "⛈️")           // very sad
]

// MARK: - Audio Engine (simple sine tone)
class MoodAudio {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffer: AVAudioPCMBuffer!
    private var timer: Timer?
    
    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let frameCount = AVAudioFrameCount(format.sampleRate * 2) // 2 seconds tone
        buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let freq: Float = 440.0
        let theta = 2.0 * Float.pi * freq / Float(format.sampleRate)
        for n in 0..<Int(frameCount) {
            let sample = sin(theta * Float(n))
            buffer.floatChannelData!.pointee[n] = sample * 0.2
        }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        player.play()
    }
    
    func update(mood: Float) {
        // mood -1..1 maps to pitch 220..880 Hz and tempo 0.5..1.5
        let pitch = 220.0 + Double((mood + 1.0) / 2.0) * 660.0
        let rate = 0.5 + Double((mood + 1.0) / 2.0) * 1.0
        player.rate = Float(rate)
        player.play()
        // Change frequency by recreating buffer
        let format = buffer.format
        let theta = 2.0 * Float.pi * Float(pitch) / Float(format.sampleRate)
        for n in 0..<Int(buffer.frameLength) {
            let sample = sin(theta * Float(n))
            buffer.floatChannelData!.pointee[n] = sample * 0.2
        }
    }
}

// MARK: - ASCII Landscape Generator
func generateLandscape(mood: Float) -> String {
    // Map mood to index 0...4
    let idx = max(0, min(moodGradients.count - 1,
                         Int(((mood + 1) / 2.0) * Float(moodGradients.count))))
    let (terrain, weather) = moodGradients[idx]
    var lines: [String] = []
    for _ in 0..<asciiHeight {
        let padding = String(repeating: " ", count: Int.random(in: 0..<asciiWidth/2))
        let line = padding + terrain
        lines.append(line)
    }
    let header = String(repeating: "=", count: asciiWidth) + "\n" + weather + "\n"
    return header + lines.joined(separator: "\n")
}

// MARK: - Sentiment from Face (simple smile metric)
func sentimentFrom(image: CGImage) -> Float {
    let request = VNDetectFaceLandmarksRequest()
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try? handler.perform([request])
    guard let results = request.results as? [VNFaceObservation],
          let face = results.first,
          let landmarks = face.landmarks,
          let mouth = landmarks.innerLips ?? landmarks.outerLips else { return 0.0 }
    // Use mouth width vs height as proxy for smile
    let points = mouth.normalizedPoints
    guard points.count >= 2 else { return 0.0 }
    let left = points.first!
    let right = points.last!
    let width = hypot(right.x - left.x, right.y - left.y)
    let height = points.map { $0.y }.max()! - points.map { $0.y }.min()!
    let ratio = width / (height + 0.001)
    // Map ratio (0.5..1.5) to mood -1..1
    let mood = min(1.0, max(-1.0, (ratio - 1.0) * 2.0))
    return Float(mood)
}

// MARK: - Video Capture
class CameraProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private var lastProcess = Date()
    private var audio = MoodAudio()
    
    override init() {
        super.init()
        session.sessionPreset = .low
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.addInput(input)
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.queue"))
        session.addOutput(output)
        session.startRunning()
        clearConsole()
    }
    
    func clearConsole() {
        print("\u{001B}[2J") // clear screen
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastProcess) >= frameInterval else { return }
        lastProcess = now
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let mood = sentimentFrom(image: cgImage)
        audio.update(mood: mood)
        let landscape = generateLandscape(mood: mood)
        DispatchQueue.main.async {
            self.clearConsole()
            print(landscape)
        }
    }
}

// MARK: - Run
let _ = CameraProcessor()
RunLoop.main.run()