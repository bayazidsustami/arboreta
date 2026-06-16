import SwiftUI
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import AudioKit
import AudioKitEX
import SoundpipeAudioKit
import SpriteKit

// MARK: - Helper Extensions

extension CGColor {
    // Convert to SwiftUI Color
    var swiftUI: Color { Color(self) }
}

extension CIImage {
    // Simple k‑means like dominant color extraction (2 clusters)
    func dominantColors(count: Int = 2) -> [CIColor] {
        guard let bitmap = CIContext().createCGImage(self, from: extent) else { return [] }
        let width = bitmap.width, height = bitmap.height
        let bytesPerPixel = 4, bytesPerRow = bytesPerPixel * width
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: &rawData,
                            width: width,
                            height: height,
                            bitsPerComponent: 8,
                            bytesPerRow: bytesPerRow,
                            space: colorSpace,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(bitmap, in: CGRect(x: 0, y: 0, width: width, height: height))

        var clusters = Array(repeating: SIMD3<Double>(0,0,0), count: count)
        var counts = Array(repeating: 0, count: count)

        // Initialize clusters with random pixels
        for i in 0..<count {
            let idx = Int.random(in: 0..<(width*height))
            let offset = idx * bytesPerPixel
            let r = Double(rawData[offset])
            let g = Double(rawData[offset+1])
            let b = Double(rawData[offset+2])
            clusters[i] = SIMD3(r,g,b)
        }

        // Iterate
        for _ in 0..<5 {
            counts = Array(repeating: 0, count: count)
            var sums = Array(repeating: SIMD3<Double>(0,0,0), count: count)

            for y in 0..<height {
                for x in 0..<width {
                    let offset = (y*width + x) * bytesPerPixel
                    let r = Double(rawData[offset])
                    let g = Double(rawData[offset+1])
                    let b = Double(rawData[offset+2])
                    let pixel = SIMD3(r,g,b)

                    // nearest cluster
                    var bestIdx = 0
                    var bestDist = Double.greatestFiniteMagnitude
                    for i in 0..<count {
                        let d = simd_distance(pixel, clusters[i])
                        if d < bestDist {
                            bestDist = d
                            bestIdx = i
                        }
                    }
                    sums[bestIdx] += pixel
                    counts[bestIdx] += 1
                }
            }

            for i in 0..<count where counts[i] > 0 {
                clusters[i] = sums[i] / Double(counts[i])
            }
        }

        // Convert to CIColor
        return clusters.map {
            CIColor(red: CGFloat($0.x/255.0),
                    green: CGFloat($0.y/255.0),
                    blue: CGFloat($0.z/255.0),
                    alpha: 1.0)
        }
    }
}

// MARK: - Audio (Chord Mapping)

struct Chord {
    // Simple triad based on root hue (0..360)
    let rootFreq: AUValue
    let freqs: [AUValue]

    init(rootHue: Double) {
        // Map hue to a root note between C2 (65.41 Hz) and C7 (2093 Hz)
        let minFreq: AUValue = 65.41
        let maxFreq: AUValue = 2093
        rootFreq = AUValue(minFreq + (maxFreq - minFreq) * (rootHue / 360.0))

        // Major triad intervals
        let majorThird = rootFreq * pow(2.0, 4.0/12.0)
        let perfectFifth = rootFreq * pow(2.0, 7.0/12.0)
        freqs = [rootFreq, majorThird, perfectFifth]
    }
}

// Simple polyphonic synth node
class ChordSynth {
    private let engine = AudioEngine()
    private var oscillators: [Oscillator] = []

    init() {
        for _ in 0..<3 {
            let osc = Oscillator(waveform: Table(.sine))
            osc.amplitude = 0.2
            engine.output = Mixer(osc)
            oscillators.append(osc)
        }
        try? engine.start()
    }

    func play(chord: Chord) {
        for (i,osc) in oscillators.enumerated() {
            osc.frequency = chord.freqs[i]
            osc.start()
        }
        // short envelope
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.oscillators.forEach { $0.stop() }
        }
    }
}

// MARK: - SpriteKit Visualisation

class KaleidoScene: SKScene {
    private var particles: [SKShapeNode] = []
    private var lastUpdate: TimeInterval = 0

    func spawnParticle(at pos: CGPoint, color: Color, velocity: CGVector) {
        let node = SKShapeNode(circleOfRadius: 8)
        node.fillColor = color
        node.position = pos
        node.physicsBody = SKPhysicsBody(circleOfRadius: 8)
        node.physicsBody?.velocity = velocity
        node.physicsBody?.linearDamping = 0.5
        addChild(node)
        particles.append(node)
        // limit count
        if particles.count > 200 { particles.removeFirst().removeFromParent() }
    }

    override func update(_ currentTime: TimeInterval) {
        // Simple kaleidoscopic mirroring
        let angle = CGFloat(currentTime).truncatingRemainder(dividingBy: .pi * 2)
        self.camera?.run(SKAction.rotate(toAngle: angle, duration: 0.1))
    }
}

// MARK: - Main App

@main
struct AudioVisualPoemApp: App {
    @StateObject private var camera = CameraManager()
    @StateObject private var synth = ChordSynth()
    private let scene = KaleidoScene(size: CGSize(width: 640, height: 480))

    var body: some Scene {
        WindowGroup {
            ZStack {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
                Text(" 🎞️ ").font(.largeTitle).opacity(0) // placeholder to keep SwiftUI alive
            }
            .onAppear {
                camera.startCapture { ciImage in
                    // 1. Extract dominant colors
                    let colors = ciImage.dominantColors(count: 2)

                    // 2. Map first color hue to chord
                    if let first = colors.first {
                        let hue = first.hueComponent * 360.0
                        let chord = Chord(rootHue: hue)
                        synth.play(chord: chord)

                        // 3. Spawn particles based on colors
                        let uiColor = UIColor(ciColor: first)
                        let swiftColor = Color(uiColor)
                        let velocity = CGVector(dx: Double.random(in: -150...150),
                                                dy: Double.random(in: -150...150))
                        DispatchQueue.main.async {
                            scene.spawnParticle(at: CGPoint(x: scene.size.width/2,
                                                            y: scene.size.height/2),
                                                color: swiftColor,
                                                velocity: velocity)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Camera Manager

class CameraManager: NSObject, ObservableObject {
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "camera.queue")
    private var handler: ((CIImage) -> Void)?

    func startCapture(frameHandler: @escaping (CIImage) -> Void) {
        handler = frameHandler
        session.beginConfiguration()
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.addInput(input)

        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:
                                kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        session.addOutput(output)
        session.commitConfiguration()
        session.startRunning()
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let handler = handler,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        handler(ciImage)
    }
}