import AVFoundation
import Accelerate
import Foundation

// -------- Configuration ----------
let sampleRate: Double = 44100
let fftSize: Int = 1024               // power of two
let binCount = fftSize / 2
let glyphs: [Character] = ["⣀","⣤","⣶","⣾","⣿","⣾","⣶","⣤","⣀"]
let rows = 12                         // height of the glyph matrix
let cols = 40                         // width of the glyph matrix
let caRule: UInt8 = 30                // Wolfram code for 1‑dim cellular automaton
let scrollInterval = 0.05             // seconds between frames
// ----------------------------------

// Prepare audio engine
let engine = AVAudioEngine()
let input = engine.inputNode
let format = input.inputFormat(forBus: 0)

// Circular buffer for raw samples (for reversible encoding)
var rawSamples = [Int16]()
let rawLock = NSLock()

// FFT setup
let log2n = vDSP_Length(log2(Float(fftSize)))
let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!

// Buffers
var window = [Float](repeating: 0, count: fftSize)
vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

var inputBuffer = [Float](repeating: 0, count: fftSize)
var magnitude = [Float](repeating: 0, count: binCount)

// Cellular Automaton state (1‑dim, will be tiled into 2‑dim)
var caState = [UInt8](repeating: 0, count: cols)
for i in 0..<cols { caState[i] = UInt8(arc4random_uniform(2)) }

// Glyph matrix
var matrix = Array(repeating: Array(repeating: Character(" "), count: cols), count: rows)

// Helper: map magnitude to glyph index
func glyphIndex(for magnitude: Float) -> Int {
    let norm = min(max(magnitude / 50.0, 0.0), 1.0) // crude scaling
    return Int(norm * Float(glyphs.count - 1))
}

// Helper: evolve CA using Wolfram rule
func evolveCA(_ state: inout [UInt8]) {
    var newState = state
    for i in 0..<state.count {
        let left  = state[(i - 1 + state.count) % state.count]
        let center = state[i]
        let right = state[(i + 1) % state.count]
        let pattern = (left << 2) | (center << 1) | right
        let newBit = (caRule >> pattern) & 1
        newState[i] = newBit
    }
    state = newState
}

// Helper: render matrix to terminal
func renderMatrix(_ mat: [[Character]]) {
    // Clear screen
    print("\u{001B}[2J\u{001B}[H", terminator: "")
    for row in mat {
        for ch in row {
            print(ch, terminator: "")
        }
        print()
    }
}

// Audio tap
let bufferSize = AVAudioFrameCount(fftSize)
input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { (buffer, when) in
    guard let channelData = buffer.floatChannelData?[0] else { return }
    let frameLength = Int(buffer.frameLength)
    
    // Copy to circular rawSamples (16‑bit PCM)
    rawLock.lock()
    for i in 0..<frameLength {
        let sample = Int16(max(min(channelData[i] * 32767.0, 32767.0), -32768.0))
        rawSamples.append(sample)
    }
    rawLock.unlock()
    
    // Fill inputBuffer with windowed data (simple FIFO)
    if frameLength >= fftSize {
        for i in 0..<fftSize {
            inputBuffer[i] = channelData[i] * window[i]
        }
    } else {
        // shift older data
        inputBuffer.removeFirst(frameLength)
        inputBuffer.append(contentsOf: channelData[0..<frameLength].map { $0 * window[0] })
        return
    }
    
    // Perform FFT
    var realp = [Float](repeating: 0, count: binCount)
    var imagp = [Float](repeating: 0, count: binCount)
    realp.withUnsafeMutableBufferPointer { realPtr in
        imagp.withUnsafeMutableBufferPointer { imagPtr in
            var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
            inputBuffer.withUnsafeBytes { ptr in
                let casted = ptr.bindMemory(to: DSPComplex.self)
                vDSP_ctoz(casted.baseAddress!, 2, &splitComplex, 1, vDSP_Length(binCount))
            }
            vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
            var mag = [Float](repeating: 0, count: binCount)
            vDSP_zvmags(&splitComplex, 1, &mag, 1, vDSP_Length(binCount))
            vDSP_vsqrt(mag, 1, &mag, 1, vDSP_Length(binCount))
            magnitude = mag
        }
    }
    
    // Build new column based on magnitudes and CA
    var column = [Character](repeating: " ", count: rows)
    for r in 0..<rows {
        // Choose a bin proportionally
        let bin = min(r * binCount / rows, binCount - 1)
        let idx = glyphIndex(for: magnitude[bin])
        let baseGlyph = glyphs[idx]
        // Modify shape via CA bit: flip to a different glyph if needed
        let caBit = caState[r % cols]
        column[r] = caBit == 1 ? Character(String(baseGlyph).uppercased()) : baseGlyph
    }
    
    // Scroll matrix left and insert new column
    for r in 0..<rows {
        matrix[r].removeFirst()
        matrix[r].append(column[r])
    }
    
    // Evolve CA for next frame
    evolveCA(&caState)
}

// Start engine
do {
    try engine.start()
} catch {
    fatalError("Audio engine failed: \(error)")
}

// Rendering loop
while true {
    renderMatrix(matrix)
    
    // Append encoded waveform fragment as a line (hex of last 128 samples)
    rawLock.lock()
    let recent = rawSamples.suffix(128)
    let hexString = recent.map { String(format: "%04x", $0) }.joined()
    rawLock.unlock()
    print(hexString)
    
    Thread.sleep(forTimeInterval: scrollInterval)
}

// Cleanup (unreachable in this infinite demo)
//engine.stop()
//vDSP_destroy_fftsetup(fftSetup)