import Cocoa
import AVFoundation
import Vision
import SpriteKit
import Accelerate

// MARK: - Global Helpers

/// Simple structure to hold a color and its associated chord frequencies.
struct PaletteChord {
    let color: NSColor
    let frequencies: [Float]          // in Hz
}

// MARK: - Audio Engine (generates simple chords)

class AudioGenerator {
    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private var playerNodes: [AVAudioPlayerNode] = []
    private var buffers: [AVAudioPCMBuffer] = []
    
    init() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
        try? engine.start()
    }
    
    /// Create a chord from frequencies, schedule it to loop.
    func playChord(_ freqs: [Float]) {
        stopAll()
        for f in freqs {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: mixer, format: nil)
            let buf = makeSineWaveBuffer(frequency: f, duration: 2.0)
            player.scheduleBuffer(buf, at: nil, options: .loops, completionHandler: nil)
            player.play()
            playerNodes.append(player)
            buffers.append(buf)
        }
    }
    
    func stopAll() {
        for p in playerNodes { p.stop() }
        playerNodes.removeAll()
        buffers.removeAll()
    }
    
    private func makeSineWaveBuffer(frequency: Float, duration: Float) -> AVAudioPCMBuffer {
        let sampleRate: Float = 44100
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let ptr = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            ptr[i] = sin(2.0 * .pi * frequency * t) * 0.2
        }
        return buffer
    }
}

// MARK: - Video Capture & Palette Extraction

class CameraProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    var onPaletteReady: ((PaletteChord) -> Void)?
    private let audioGen = AudioGenerator()
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        session.sessionPreset = .low
        guard let dev = AVCaptureDevice.default(for: .video),
              let inp = try? AVCaptureDeviceInput(device: dev) else { return }
        session.addInput(inp)
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camQueue"))
        session.addOutput(output)
        session.startRunning()
    }
    
    // Simple dominant color extraction (average + 4‑color k‑means placeholder)
    private func extractPalette(from image: CIImage) -> PaletteChord {
        let ctx = CIContext()
        guard let bitmap = ctx.createCGImage(image, from: image.extent) else {
            return PaletteChord(color: .black, frequencies: [220])
        }
        let uiImg = NSImage(cgImage: bitmap, size: .zero)
        guard let tiff = uiImg.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiff) else {
            return PaletteChord(color: .black, frequencies: [220])
        }
        var rSum: Double = 0, gSum: Double = 0, bSum: Double = 0
        let w = bitmapRep.pixelsWide, h = bitmapRep.pixelsHigh
        for x in 0..<w {
            for y in 0..<h {
                let col = bitmapRep.colorAt(x: x, y: y) ?? .black
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                col.getRed(&r, green: &g, blue: &b, alpha: &a)
                rSum += Double(r)
                gSum += Double(g)
                bSum += Double(b)
            }
        }
        let cnt = Double(w * h)
        let avg = NSColor(calibratedRed: CGFloat(rSum/cnt),
                          green: CGFloat(gSum/cnt),
                          blue: CGFloat(bSum/cnt),
                          alpha: 1.0)
        // Map hue to a major triad (root, major third, fifth)
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alp: CGFloat = 0
        avg.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alp)
        let baseFreq = 220.0 * pow(2.0, Float(hue) * 2.0)   // 220‑880 Hz range
        let freqs: [Float] = [Float(baseFreq),
                              Float(baseFreq * pow(2.0, 4.0/12.0)),
                              Float(baseFreq * pow(2.0, 7.0/12.0))]
        return PaletteChord(color: avg, frequencies: freqs)
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pix = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ci = CIImage(cvPixelBuffer: pix)
        let palette = extractPalette(from: ci)
        audioGen.playChord(palette.frequencies)
        onPaletteReady?(palette)
    }
}

// MARK: - SpriteKit Scene (visual reacts to audio spectrum)

class AudioReactiveScene: SKScene {
    private var shapes: [SKShapeNode] = []
    private var lastUpdate: TimeInterval = 0
    
    override func didMove(to view: SKView) {
        backgroundColor = .black
    }
    
    func updatePalette(_ pc: PaletteChord) {
        // create a new shape with the palette colour
        let size: CGFloat = CGFloat.random(in: 30...100)
        let shape = SKShapeNode(circleOfRadius: size/2)
        shape.fillColor = pc.color
        shape.strokeColor = .clear
        shape.position = CGPoint(x: CGFloat.random(in: 0...size.width),
                                 y: CGFloat.random(in: 0...size.height))
        shape.alpha = 0.0
        addChild(shape)
        shapes.append(shape)
    }
    
    override func update(_ currentTime: TimeInterval) {
        let dt = currentTime - lastUpdate
        lastUpdate = currentTime
        for shape in shapes {
            // Drift and fade
            shape.position.x += CGFloat.random(in: -30...30) * CGFloat(dt)
            shape.position.y += CGFloat.random(in: -30...30) * CGFloat(dt)
            shape.alpha = min(1.0, shape.alpha + CGFloat(dt) * 0.5)
            shape.zRotation += CGFloat(dt)
            // Remove if out of bounds
            if !frame.contains(shape.position) {
                shape.removeFromParent()
                if let idx = shapes.firstIndex(of: shape) { shapes.remove(at: idx) }
            }
        }
    }
}

// MARK: - Application Bootstrap

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var skView: SKView!
    var scene: AudioReactiveScene!
    var camProcessor: CameraProcessor!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Window
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Audiovisual Poem"
        window.makeKeyAndOrderFront(nil)
        
        // SpriteKit view
        skView = SKView(frame: window.contentView!.bounds)
        skView.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(skView)
        scene = AudioReactiveScene(size: skView.bounds.size)
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)
        
        // Camera + audio
        camProcessor = CameraProcessor()
        camProcessor.onPaletteReady = { [weak self] pc in
            DispatchQueue.main.async {
                self?.scene.updatePalette(pc)
            }
        }
    }
}

// Run
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)