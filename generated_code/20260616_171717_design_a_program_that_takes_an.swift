import Foundation
import AVFoundation
import SpriteKit
import AppKit

// ---------- Helper Types ----------
struct WordMapping: Codable {
    let word: String
    let frequency: Float
    let duration: Float
    let color: NSColor
}

// ---------- Text → Sound/Visual Mapping ----------
func mapWord(_ word: String) -> WordMapping {
    // Simple semantic proxy: word length influences pitch & duration
    let baseFreq: Float = 220.0                      // A3
    let freq = baseFreq * powf(2.0, Float(word.count % 12) / 12.0)
    let dur = max(0.2, Float(word.count) * 0.05)     // seconds
    // Color derived from hash of word
    var hash = UInt64(0)
    for c in word.unicodeScalars { hash = hash &* 31 &+ UInt64(c.value) }
    let hue = CGFloat((hash % 360)) / 360.0
    let color = NSColor(hue: hue, saturation: 0.6, brightness: 0.9, alpha: 1.0)
    return WordMapping(word: word, frequency: freq, duration: dur, color: color)
}

// ---------- Audio Engine ----------
class AudioGenerator {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private var bufferQueue: [AVAudioPCMBuffer] = []
    
    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }
    
    func schedule(mapping: WordMapping) {
        let sampleCount = AVAudioFrameCount(mapping.duration * Float(format.sampleRate))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: sampleCount) else { return }
        buffer.frameLength = sampleCount
        let theta_increment = 2.0 * Double.pi * Double(mapping.frequency) / Double(format.sampleRate)
        var theta = 0.0
        let amp: Float = 0.2
        for i in 0..<Int(sampleCount) {
            let sample = sin(theta) * Double(amp)
            buffer.floatChannelData!.pointee[i] = Float(sample)
            theta += theta_increment
        }
        bufferQueue.append(buffer)
    }
    
    func playAll(completion: @escaping () -> Void) {
        guard !bufferQueue.isEmpty else { completion(); return }
        let first = bufferQueue.removeFirst()
        player.scheduleBuffer(first) { [weak self] in
            self?.playAll(completion: completion)
        }
        player.play()
    }
    
    func export(to url: URL) {
        // Simple export: render all buffers into a single file using AVAudioFile
        guard let file = try? AVAudioFile(forWriting: url, settings: format.settings) else { return }
        for buffer in bufferQueue {
            try? file.write(from: buffer)
        }
    }
}

// ---------- Visual Scene ----------
class MandalaScene: SKScene {
    private var mappings: [WordMapping] = []
    private var currentIndex = 0
    private var lastUpdateTime: TimeInterval = 0
    
    init(size: CGSize, mappings: [WordMapping]) {
        self.mappings = mappings
        super.init(size: size)
        backgroundColor = .black
    }
    
    required init(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func update(_ currentTime: TimeInterval) {
        guard currentIndex < mappings.count else { return }
        if currentTime - lastUpdateTime > Double(mappings[currentIndex].duration) {
            spawnNode(for: mappings[currentIndex])
            currentIndex += 1
            lastUpdateTime = currentTime
        }
    }
    
    private func spawnNode(for mapping: WordMapping) {
        let radius = CGFloat(20 + mapping.word.count * 3)
        let node = SKShapeNode(circleOfRadius: radius)
        node.fillColor = SKColor(mapping.color)
        node.position = CGPoint(x: size.width/2, y: size.height/2)
        addChild(node)
        let rotate = SKAction.rotate(byAngle: CGFloat.pi * 2, duration: 4.0)
        let fade = SKAction.fadeOut(withDuration: Double(mapping.duration))
        let remove = SKAction.removeFromParent()
        node.run(SKAction.sequence([rotate, fade, remove]))
    }
}

// ---------- Main ----------
let inputText = """
Swift is a powerful and intuitive programming language for iOS, macOS, watchOS, and tvOS.
"""

let words = inputText
    .components(separatedBy: CharacterSet.alphanumerics.inverted)
    .filter { !$0.isEmpty }

let mappings = words.map { mapWord($0) }

let audio = AudioGenerator()
for m in mappings { audio.schedule(mapping: m) }

let viewSize = CGSize(width: 800, height: 800)
let scene = MandalaScene(size: viewSize, mappings: mappings)

// Set up a window to host the SpriteKit view
let window = NSWindow(contentRect: NSRect(origin: .zero, size: viewSize),
                      styleMask: [.titled, .closable, .resizable],
                      backing: .buffered, defer: false)
window.title = "Kaleidoscopic Mandala"
let skView = SKView(frame: NSRect(origin: .zero, size: viewSize))
skView.presentScene(scene)
window.contentView = skView
window.makeKeyAndOrderFront(nil)

// Play audio and start visuals
audio.playAll {
    // Export JSON mapping
    let jsonURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("mapping.json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    if let data = try? encoder.encode(mappings) {
        try? data.write(to: jsonURL)
    }
    // Export audio (raw PCM, placeholder)
    let audioURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("output.wav")
    audio.export(to: audioURL)
    // Terminate after short delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        NSApplication.shared.terminate(nil)
    }
}

// Run the app loop
let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()