import Foundation

// MARK: - AST & Dissonance Modeling

enum ASTNodeType {
    case keyword, identifier, literal, operatorSymbol, structure, error
}

struct MusicNote {
    let frequency: Double
    let duration: Double
}

struct CodeAnalyzer {
    // Basic AST parser that categorizes code tokens and flags potential syntax imbalances/errors
    static func parseAndMapToNotes(sourceCode: String) -> [MusicNote] {
        let lines = sourceCode.components(separatedBy: .newlines)
        var notes: [MusicNote] = []
        var parenBalance = 0
        var braceBalance = 0
        
        // Pentatonic base frequencies (C4, D4, E4, G4, A4, C5)
        let scale = [261.63, 293.66, 329.63, 392.00, 440.00, 523.25]
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            for char in trimmed {
                if char == "(" { parenBalance += 1 }
                else if char == ")" { parenBalance -= 1 }
                else if char == "{" { braceBalance += 1 }
                else if char == "}" { braceBalance -= 1 }
            }
            
            let isError = parenBalance < 0 || braceBalance < 0
            let tokenCount = trimmed.components(separatedBy: .whitespaces).count
            
            // Map AST structure to scale pitch, and syntax errors/imbalance to dissonance
            let baseFreq = scale[abs(trimmed.hashValue) % scale.count]
            let frequency = isError ? baseFreq * 1.05946 : baseFreq // Unresolved semitone shift for dissonance
            let duration = max(0.1, Double(tokenCount) * 0.05)
            
            notes.append(MusicNote(frequency: frequency, duration: duration))
        }
        
        // Final structural error check
        if parenBalance != 0 || braceBalance != 0 {
            notes.append(MusicNote(frequency: 110.0, duration: 0.5)) // Harsh low bass dissonance
        }
        
        return notes
    }
}

// MARK: - Audio Waveform Generator

class AudioDSP {
    static let sampleRate = 44100.0
    
    static func renderWAV(notes: [MusicNote]) -> (Data, [Float]) {
        var rawSamples: [Float] = []
        
        for note in notes {
            let totalSamples = Int(AudioDSP.sampleRate * note.duration)
            for i in 0..<totalSamples {
                let time = Double(i) / AudioDSP.sampleRate
                // Sine wave synthesis with soft envelope to avoid clipping clicks
                let envelope = sin(Double.pi * (Double(i) / Double(totalSamples)))
                let sample = Float(sin(2.0 * Double.pi * note.frequency * time) * envelope)
                rawSamples.append(sample)
            }
        }
        
        let wavData = createWAVHeaderAndBuffer(samples: rawSamples)
        return (wavData, rawSamples)
    }
    
    private static func createWAVHeaderAndBuffer(samples: [Float]) -> Data {
        var data = Data()
        let numSamples = Int32(samples.count)
        let subchunk2Size = numSamples * 2 // 16-bit PCM
        let chunkSize = 36 + subchunk2Size
        
        // RIFF Header
        data.append(contentsOf: [UInt8]("RIFF".utf8))
        data.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian) { Array($0) })
        data.append(contentsOf: [UInt8]("WAVE".utf8))
        
        // fmt Subchunk
        data.append(contentsOf: [UInt8]("fmt ".utf8))
        data.append(contentsOf: withUnsafeBytes(of: Int32(16).littleEndian) { Array($0) }) // Subchunk1Size
        data.append(contentsOf: withUnsafeBytes(of: Int16(1).littleEndian) { Array($0) })  // AudioFormat (PCM)
        data.append(contentsOf: withUnsafeBytes(of: Int16(1).littleEndian) { Array($0) })  // NumChannels (Mono)
        data.append(contentsOf: withUnsafeBytes(of: Int32(44100).littleEndian) { Array($0) }) // SampleRate
        data.append(contentsOf: withUnsafeBytes(of: Int32(88200).littleEndian) { Array($0) }) // ByteRate
        data.append(contentsOf: withUnsafeBytes(of: Int16(2).littleEndian) { Array($0) })  // BlockAlign
        data.append(contentsOf: withUnsafeBytes(of: Int16(16).littleEndian) { Array($0) }) // BitsPerSample
        
        // data Subchunk
        data.append(contentsOf: [UInt8]("data".utf8))
        data.append(contentsOf: withUnsafeBytes(of: subchunk2Size.littleEndian) { Array($0) })
        
        for sample in samples {
            let pcmValue = Int16(max(-1.0, min(1.0, sample)) * 32767.0)
            data.append(contentsOf: withUnsafeBytes(of: pcmValue.littleEndian) { Array($0) })
        }
        
        return data
    }
}

// MARK: - ASCII Visualizer

struct Visualizer {
    static func generateASCIIWaveform(samples: [Float], columns: Int = 60, rows: Int = 12) -> String {
        guard !samples.isEmpty else { return "" }
        let chunkSize = max(1, samples.count / columns)
        var displayPeaks: [Float] = []
        
        for col in 0..<columns {
            let start = col * chunkSize
            let end = min(start + chunkSize, samples.count)
            if start < end {
                let maxPeak = samples[start..<end].map { abs($0) }.max() ?? 0.0
                displayPeaks.append(maxPeak)
            }
        }
        
        var grid = Array(repeating: Array(repeating: " ", count: displayPeaks.count), count: rows)
        let midRow = rows / 2
        
        for (col, peak) in displayPeaks.enumerated() {
            let height = Int(peak * Float(midRow))
            for r in (midRow - height)...(midRow + height) {
                if r >= 0 && r < rows {
                    grid[r][col] = (r == midRow) ? "─" : "█"
                }
            }
        }
        
        return grid.map { $0.joined() }.joined(separator: "\n")
    }
}

// MARK: - Main Execution

let arguments = CommandLine.arguments
let inputPath = arguments.count > 1 ? arguments[1] : #file
let outputPath = "generative_composition.wav"

do {
    let sourceCode = try String(contentsOfFile: inputPath, encoding: .utf8)
    let musicNotes = CodeAnalyzer.parseAndMapToNotes(sourceCode: sourceCode)
    let (audioData, samples) = AudioDSP.renderWAV(notes: musicNotes)
    
    let destinationURL = URL(fileURLWithPath: outputPath)
    try audioData.write(to: destinationURL)
    
    print("Synthesized AST Audio saved to: \(outputPath)")
    print("\nVisual Waveform (ASCII Art):")
    print(Visualizer.generateASCIIWaveform(samples: samples))
} catch {
    print("Error processing source code file: \(error.localizedDescription)")
}