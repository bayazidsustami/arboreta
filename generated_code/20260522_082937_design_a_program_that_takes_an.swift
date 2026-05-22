#!/usr/bin/swift
import Foundation
import AVFoundation
import Accelerate

// ---------- Configuration ----------
let tapeLength = 32                         // Number of LED cells
let updateInterval: TimeInterval = 0.05    // 20 Hz visual update
let audioFilePath = CommandLine.arguments.dropFirst().first ?? "sample.mp3"

// ---------- Helper Types ----------
struct Color {
    var r: Float, g: Float, b: Float
    static func random() -> Color {
        return Color(r: Float.random(in: 0...1),
                     g: Float.random(in: 0...1),
                     b: Float.random(in: 0...1))
    }
    func toString() -> String {
        return String(format:"(%.0f,%.0f,%.0f)",
                      r*255,g*255,b*255)
    }
}

struct TapeCell {
    var color: Color
    var intensity: Float   // 0…1
}

// ---------- Grammar‑Based Poetic Logger ----------
class PoeticLogger {
    let adjectives = ["luminous", "pulsing", "glimmering", "synchronised", "vivid"]
    let nouns = ["wave", "cascade", "spectrum", "heartbeat", "cascade"]
    let verbs = ["dances", "shifts", "flutters", "rises", "fades"]
    func line(for cellIndex: Int, color: Color, intensity: Float) -> String {
        let adj = adjectives.randomElement()!
        let noun = nouns.randomElement()!
        let verb = verbs.randomElement()!
        return "Cell \(cellIndex) \(verb) like a \(adj) \(noun) of color \(color.toString()) at intensity \(String(format:"%.2f", intensity))."
    }
}

// ---------- Audio Analyzer ----------
class AudioAnalyzer {
    private let engine = AVAudioEngine()
    private var fftSetup: FFTSetup!
    private var log2n: vDSP_Length
    private var bufferSize: UInt32
    private var window: [Float]
    private var tape: [TapeCell]
    private let logger = PoeticLogger()
    private var lastLogTime = Date()
    
    init(tapeLength: Int, bufferSize: UInt32 = 1024) {
        self.bufferSize = bufferSize
        self.log2n = vDSP_Length(log2(Float(bufferSize)))
        self.fftSetup = vDSP_create_fftsetup(self.log2n, FFTRadix(kFFTRadix2))
        self.window = [Float](repeating: 0, count: Int(bufferSize))
        vDSP_hann_window(&window, vDSP_Length(bufferSize), Int32(vDSP_HANN_NORM))
        self.tape = Array(repeating: TapeCell(color: .random(), intensity: 0), count: tapeLength)
    }
    
    func start() throws {
        let fileURL = URL(fileURLWithPath: audioFilePath)
        let audioFile = try AVAudioFile(forReading: fileURL)
        let format = audioFile.processingFormat
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try engine.start()
        player.scheduleFile(audioFile, at: nil, completionHandler: nil)
        player.play()
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize)!
        let queue = DispatchQueue(label: "analysis")
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] (buf, _) in
            queue.async {
                self?.process(buffer: buf)
            }
        }
        // Keep the script alive while audio plays
        RunLoop.current.run()
    }
    
    private func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?.pointee else { return }
        var windowed = [Float](repeating:0, count:Int(bufferSize))
        vDSP_vmul(channelData, 1, window, 1, &windowed, 1, vDSP_Length(bufferSize))
        var realp = [Float](repeating:0, count:Int(bufferSize/2))
        var imagp = [Float](repeating:0, count:Int(bufferSize/2))
        realp.withUnsafeMutableBufferPointer { realPtr in
            imagp.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                windowed.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                    ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: Int(bufferSize)) { typeConvertedTransferBuffer in
                        vDSP_ctoz(typeConvertedTransferBuffer, 2, &splitComplex, 1, vDSP_Length(bufferSize/2))
                    }
                }
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                var magnitudes = [Float](repeating:0, count:Int(bufferSize/2))
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(bufferSize/2))
                var normalized = [Float](repeating:0, count:Int(bufferSize/2))
                var scale: Float = 1.0 / Float(bufferSize)
                vDSP_vsmul(sqrt(magnitudes), 1, &scale, &normalized, 1, vDSP_Length(bufferSize/2))
                updateTape(with: normalized)
            }
        }
    }
    
    private func updateTape(with spectrum: [Float]) {
        // Map low frequencies to first cells, high to later cells
        for i in 0..<tape.count {
            let band = spectrum[min(i * spectrum.count / tape.count, spectrum.count-1)]
            let intensity = min(max(band * 10, 0), 1) // amplify & clamp
            tape[i].intensity = intensity
            if intensity > 0.7 { tape[i].color = .random() }
        }
        render()
        maybeLog()
    }
    
    private func render() {
        // Simple console visualisation
        var line = ""
        for cell in tape {
            let char = cell.intensity > 0.5 ? "█" : cell.intensity > 0.1 ? "▓" : "░"
            line.append(char)
        }
        print("\r\(line)", terminator:"")
        fflush(stdout)
    }
    
    private func maybeLog() {
        let now = Date()
        if now.timeIntervalSince(lastLogTime) > 2.0 {
            for (idx, cell) in tape.enumerated() where cell.intensity > 0.3 {
                print("\n" + logger.line(for: idx, color: cell.color, intensity: cell.intensity))
            }
            lastLogTime = now
        }
    }
}

// ---------- Main ----------
do {
    let analyzer = AudioAnalyzer(tapeLength: tapeLength)
    try analyzer.start()
} catch {
    print("Error: \(error.localizedDescription)")
}