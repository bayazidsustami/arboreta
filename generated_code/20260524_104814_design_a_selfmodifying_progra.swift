import Foundation
import AVFoundation

// MARK: - Simple Byte‑to‑Note Mapper
struct NoteMapper {
    static let baseFreq: Double = 440.0           // A4
    static let notesPerOctave = 12
    static let scale = [0, 2, 4, 5, 7, 9, 11]    // Major pentatonic subset
    
    // Convert a byte (0‑255) to a frequency in the audible range.
    static func freq(for byte: UInt8) -> Double {
        let octave = Int(byte) % 4 + 2               // 2‑5 octaves above middle C
        let step   = scale[Int(byte) % scale.count]
        let semitones = octave * notesPerOctave + step
        return baseFreq * pow(2.0, Double(semitones - 9) / 12.0)
    }
}

// MARK: - Tiny Synthesizer (sine wave)
class Synthesizer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    
    init(sampleRate: Double = 44100.0) {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(player)
        let main = engine.mainMixerNode
        engine.connect(player, to: main, format: format)
        try! engine.start()
    }
    
    // Generate a buffer for a single note.
    private func buffer(for freq: Double, duration: Double) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let thetaInc = 2.0 * Double.pi * freq / format.sampleRate
        var theta = 0.0
        let ptr = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            ptr[i] = Float(sin(theta) * 0.2)   // low amplitude to avoid clipping
            theta += thetaInc
        }
        return buffer
    }
    
    // Play a sequence of bytes as notes.
    func play(bytes: [UInt8]) {
        var buffers: [AVAudioPCMBuffer] = []
        for b in bytes {
            let freq = NoteMapper.freq(for: b)
            buffers.append(buffer(for: freq, duration: 0.12))
        }
        player.scheduleBuffer(buffers[0], completionHandler: nil)
        for i in 1..<buffers.count {
            player.scheduleBuffer(buffers[i], after: nil, completionHandler: nil)
        }
        player.play()
        // Wait until finished
        Thread.sleep(forTimeInterval: Double(buffers.count) * 0.13)
    }
}

// MARK: - Self‑Modifying Loop
class SelfModifying {
    private let synth = Synthesizer()
    
    // Read own source file.
    private func sourceBytes() -> [UInt8] {
        let path = CommandLine.arguments[0]               // path of the compiled binary
        // Find the original .swift file (assume same name with .swift)
        let srcPath = URL(fileURLWithPath: path).deletingPathExtension().appendingPathExtension("swift").path
        if let data = try? Data(contentsOf: URL(fileURLWithPath: srcPath)) {
            return [UInt8](data)
        }
        return []
    }
    
    // Dummy "compiler": just returns the same bytes (could be transformed).
    private func compile(_ bytes: [UInt8]) -> [UInt8] {
        // In a real scenario we could transform the bytecode.
        // Here we simply reverse every 8‑byte block to create change.
        var result = bytes
        for i in stride(from: 0, to: bytes.count, by: 8) {
            let end = min(i + 8, bytes.count)
            result[i..<end] = result[i..<end].reversed()
        }
        return result
    }
    
    func run() {
        var iteration = 0
        var current = sourceBytes()
        while true {
            iteration += 1
            print("Iteration \(iteration), bytes: \(current.count)")
            synth.play(bytes: current)
            let next = compile(current)
            // Break condition to avoid infinite CPU hog in this demo
            if iteration >= 10 { break }
            current = next
        }
    }
}

// Entry point
SelfModifying().run()