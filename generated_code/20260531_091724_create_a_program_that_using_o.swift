import Foundation
import AVFoundation
import Accelerate

// MARK: - Simple 1‑D cellular automaton (Rule 30)
struct Automaton {
    var cells: [UInt8]          // 0 or 1
    let rule: UInt8 = 0b00011110 // Rule 30 table (bits for 111..000)

    init(size: Int) {
        cells = Array(repeating: 0, count: size)
        cells[size/2] = 1         // seed single live cell
    }

    // Apply one generation
    mutating func step() {
        var next = cells
        for i in 0..<cells.count {
            let left  = cells[(i-1+cells.count)%cells.count]
            let center= cells[i]
            let right = cells[(i+1)%cells.count]
            let idx = (left<<2) | (center<<1) | right
            next[i] = (rule >> idx) & 1
        }
        cells = next
    }

    // Return binary string of current generation
    func binaryString() -> String {
        cells.map { $0 == 1 ? "1" : "0" }.joined()
    }
}

// MARK: - Audio analyser (FFT → magnitude array)
final class Analyzer {
    private let engine = AVAudioEngine()
    private let fftSize: vDSP_Length = 1024
    private var window: [Float] = []
    private var spectrum: [Float] = []

    init() {
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        let bufferSize = AVAudioFrameCount(fftSize)

        // Hann window
        window = (0..<Int(fftSize)).map { i in
            0.5 * (1 - cos(2 * .pi * Float(i) / Float(fftSize - 1)))
        }

        input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] (buf, _) in
            self?.process(buf: buf)
        }

        try? engine.start()
    }

    private func process(buf: AVAudioPCMBuffer) {
        guard let channelData = buf.floatChannelData?.pointee else { return }
        var windowed = [Float](repeating: 0, count: Int(fftSize))
        vDSP_vmul(channelData, 1, window, 1, &windowed, 1, fftSize)

        var real = [Float](repeating: 0, count: Int(fftSize/2))
        var imag = [Float](repeating: 0, count: Int(fftSize/2))
        var splitComplex = DSPSplitComplex(realp: &real, imagp: &imag)

        windowed.withUnsafeMutableBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: Int(fftSize)) { typeConvertedTransferBuffer in
                let log2n = vDSP_Length(log2(Float(fftSize)))
                let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_destroy_fftsetup(fftSetup)
            }
        }

        var magnitudes = [Float](repeating: 0, count: Int(fftSize/2))
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, fftSize/2)
        vDSP_vsmul(sqrt(magnitudes), 1, [2.0/Float(fftSize)], &magnitudes, 1, fftSize/2)
        spectrum = magnitudes
    }

    // Return a normalized snapshot of the current spectrum (0…1)
    func currentSpectrum(bands: Int) -> [Float] {
        guard spectrum.count > 0 else { return Array(repeating: 0, count: bands) }
        let step = max(1, spectrum.count / bands)
        var result: [Float] = []
        for i in stride(from: 0, to: spectrum.count, by: step) {
            let avg = spectrum[i..<min(i+step, spectrum.count)].reduce(0, +) / Float(step)
            result.append(min(1, avg * 10)) // crude scaling
        }
        if result.count > bands { result = Array(result[0..<bands]) }
        while result.count < bands { result.append(0) }
        return result
    }
}

// MARK: - Visual and poetic rendering
struct Renderer {
    let width = 40
    let height = 12
    let automatonSize = 64
    var automaton = Automaton(size: 64)

    // Unicode blocks for intensity
    let shades: [Character] = [" ", "░", "▒", "▓", "█"]

    mutating func render(spectrum: [Float]) {
        automaton.step()
        let bin = automaton.binaryString()
        let ones = bin.filter { $0 == "1" }.count

        // Build mandala rows using spectrum amplitudes
        var rows: [String] = []
        for y in 0..<height {
            var line = ""
            for x in 0..<width {
                let idx = (x * spectrum.count) / width
                let amp = spectrum[idx]
                let level = min(shades.count - 1, Int(amp * Float(shades.count)))
                line.append(shades[level])
            }
            rows.append(line)
        }

        // Clear terminal
        print("\u{001B}[2J\u{001B}[H", terminator: "")

        // Print mandala
        for row in rows { print(row) }

        // Generate a short poem line based on automaton state
        let syllables = max(1, ones % 8) // 1‑8 syllables
        let words = ["silence","storm","echo","whisper","pulse","drift","glow","tide","flare","mist"]
        var line = ""
        for _ in 0..<syllables {
            line += words.randomElement()! + " "
        }
        print("\n\(line.capitalized.trimmingCharacters(in: .whitespaces)).")
    }
}

// MARK: - Main loop
let analyser = Analyzer()
var renderer = Renderer()

let timer = DispatchSource.makeTimerSource(queue: .global())
timer.schedule(deadline: .now(), repeating: .milliseconds(200))
timer.setEventHandler {
    let spec = analyser.currentSpectrum(bands: renderer.width)
    renderer.render(spectrum: spec)
}
timer.resume()

// Keep the script running
RunLoop.main.run()