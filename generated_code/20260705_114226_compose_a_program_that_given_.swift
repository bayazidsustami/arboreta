import Foundation
import AVFoundation
import SceneKit
import PlaygroundSupport

// MARK: - Simple word‑to‑note mapper
struct NoteMapper {
    // Map each distinct word to a MIDI note (C4‑C6 range)
    private var wordToNote: [String:Int] = [:]
    private var nextNote: Int = 60   // Middle C
    
    mutating func note(for word: String) -> Int {
        let lower = word.lowercased()
        if let n = wordToNote[lower] { return n }
        // wrap inside two octaves
        let n = nextNote
        wordToNote[lower] = n
        nextNote += 2                     // step by whole tone for variety
        if nextNote > 84 { nextNote = 60 } // C6
        return n
    }
}

// MARK: - Generate a short tone for a MIDI note
func toneBuffer(note: Int, duration: Double = 0.3) -> AVAudioPCMBuffer {
    let sampleRate = 44100.0
    let frameCount = AVAudioFrameCount(sampleRate * duration)
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
    buffer.frameLength = frameCount

    let freq = 440.0 * pow(2.0, Double(note - 69)/12.0) // A4 = MIDI 69
    let thetaInc = 2.0 * Double.pi * freq / sampleRate
    var theta = 0.0
    let amp = 0.2

    let ptr = buffer.floatChannelData![0]
    for i in 0..<Int(frameCount) {
        ptr[i] = Float(sin(theta) * amp)
        theta += thetaInc
    }
    return buffer
}

// MARK: - Create an audio engine that plays the poem as notes
class PoemPlayer {
    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private var mapper = NoteMapper()
    private var noteBuffers: [AVAudioPCMBuffer] = []
    
    init(poem: String) {
        // split on whitespace, ignore punctuation
        let words = poem
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        for w in words {
            let n = mapper.note(for: w)
            noteBuffers.append(toneBuffer(note: n))
        }
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
        try? engine.start()
    }
    
    // Play notes sequentially, schedule next when previous ends
    func play(completion: @escaping () -> Void) {
        guard !noteBuffers.isEmpty else { completion(); return }
        var idx = 0
        func scheduleNext() {
            let buffer = noteBuffers[idx]
            mixer.scheduleBuffer(buffer, at: nil, options: [], completionHandler: {
                idx += 1
                if idx < self.noteBuffers.count {
                    scheduleNext()
                } else {
                    completion()
                }
            })
            mixer.play()
        }
        scheduleNext()
    }
    
    var outputNode: AVAudioNode { mixer }
}

// MARK: - Fractal particle system driven by audio spectrum
class FractalScene: SCNScene, AVAudioRecorderDelegate {
    private let audioEngine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var fftSize: Int = 512
    private var spectrum = [Float](repeating: 0, count: 256)
    
    private var particles: [SCNNode] = []
    private let particleCount = 200
    
    override init() {
        super.init()
        // camera
        let cam = SCNCamera()
        cam.zFar = 1000
        let camNode = SCNNode()
        camNode.camera = cam
        camNode.position = SCNVector3(0,0,30)
        rootNode.addChildNode(camNode)
        
        // light
        let light = SCNLight()
        light.type = .ambient
        light.color = UIColor(white: 0.6, alpha: 1)
        let lightNode = SCNNode()
        lightNode.light = light
        rootNode.addChildNode(lightNode)
        
        // particles as small spheres
        for _ in 0..<particleCount {
            let sphere = SCNSphere(radius: 0.3)
            sphere.firstMaterial?.diffuse.contents = UIColor.white
            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3.random(in: -10...10)
            rootNode.addChildNode(node)
            particles.append(node)
        }
        
        // audio chain
        audioEngine.attach(playerNode)
        let mainMix = audioEngine.mainMixerNode
        audioEngine.connect(playerNode, to: mainMix, format: nil)
        try? audioEngine.start()
    }
    
    required init?(coder: NSCoder) { nil }
    
    // Feed external audio buffer (from PoemPlayer) into the player node
    func play(buffer: AVAudioPCMBuffer, completion: @escaping ()->Void) {
        playerNode.scheduleBuffer(buffer, completionHandler: completion)
        playerNode.play()
    }
    
    // Update particles each frame based on current FFT
    func rendererUpdate(atTime time: TimeInterval) {
        guard let tap = audioEngine.mainMixerNode.installTap else { return }
        // Perform FFT on latest audio (simple magnitude estimate)
        if let buffer = audioEngine.mainMixerNode.outputFormat(forBus: 0).channelCount > 0 ? audioEngine.mainMixerNode.outputFormat(forBus: 0) : nil {
            // placeholder – real FFT would need vDSP
        }
        // drive particle motion
        for (i, p) in particles.enumerated() {
            let angle = Float(time) + Float(i)
            let radius = 5.0 + 2.0 * sin(angle)
            p.position.x = radius * cos(angle)
            p.position.y = radius * sin(angle)
            // colour reacts to low frequencies
            let hue = CGFloat((spectrum.first ?? 0) * 2.0).truncatingRemainder(dividingBy: 1.0)
            p.geometry?.firstMaterial?.diffuse.contents = UIColor(hue: hue, saturation: 0.8, brightness: 0.9, alpha: 1)
        }
    }
}

// MARK: - Helper extensions
extension SCNVector3 {
    static func random(in range: ClosedRange<Float>) -> SCNVector3 {
        let x = Float.random(in: range)
        let y = Float.random(in: range)
        let z = Float.random(in: range)
        return SCNVector3(x, y, z)
    }
}

// MARK: - Main execution
let poem = """
Shall I compare thee to a summer's day?
Thou art more lovely and more temperate.
"""

let player = PoemPlayer(poem: poem)
let scene = FractalScene()

// Set up a view to show the scene
let view = SCNView(frame: CGRect(x:0, y:0, width:800, height:600))
view.scene = scene
view.allowsCameraControl = true
view.backgroundColor = .black
PlaygroundPage.current.liveView = view

// Play music and drive visualization
player.play {
    // after music ends nothing else needed
}
for buffer in player.noteBuffers {
    scene.play(buffer: buffer) {}
}
scene.rendererUpdate(atTime: 0)