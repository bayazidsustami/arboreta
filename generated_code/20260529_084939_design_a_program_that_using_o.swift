import Foundation

// ---------- Simple real‑time audio “FFT” ----------
let sampleRate = 8000                     // Hz (dummy)
let bufferSize = 64                       // samples per frame
var audioBuffer = [Int16](repeating: 0, count: bufferSize)

// read raw PCM from stdin (16‑bit little‑endian)
func fillBuffer() -> Bool {
    let bytes = FileHandle.standardInput.readData(ofLength: bufferSize * 2)
    guard bytes.count == bufferSize * 2 else { return false }
    bytes.withUnsafeBytes { ptr in
        let p = ptr.bindMemory(to: Int16.self)
        for i in 0..<bufferSize { audioBuffer[i] = p[i] }
    }
    return true
}

// naive DFT → magnitude spectrum (only first half)
func magnitudeSpectrum() -> [Double] {
    var mags = [Double](repeating: 0.0, count: bufferSize/2)
    for k in 0..<bufferSize/2 {
        var re = 0.0, im = 0.0
        for n in 0..<bufferSize {
            let angle = -2.0 * Double.pi * Double(k) * Double(n) / Double(bufferSize)
            re += Double(audioBuffer[n]) * cos(angle)
            im += Double(audioBuffer[n]) * sin(angle)
        }
        mags[k] = sqrt(re*re + im*im)
    }
    return mags
}

// ---------- ASCII colour mapping ----------
let asciiRamp = Array(" .:-=+*#%@")        // low → high intensity

func mapToChar(_ magnitude: Double, maxMag: Double) -> Character {
    let idx = Int((magnitude / maxMag) * Double(asciiRamp.count-1))
    return asciiRamp[max(0, min(idx, asciiRamp.count-1))]
}

// ---------- Mandala canvas ----------
let width = 80
let height = 24
var canvas = Array(repeating: Array(repeating: " ", count: width), count: height)

// scroll upward one line
func scrollCanvas() {
    canvas.removeFirst()
    canvas.append(Array(repeating: " ", count: width))
}

// draw a single “brushstroke” encoded as a Lisp‑style S‑expression
func renderStroke(_ expr: String) {
    // expression format: (draw x y c next)
    let tokens = expr
        .replacingOccurrences(of: "(", with: "")
        .replacingOccurrences(of: ")", with: "")
        .split(separator: " ")
    guard tokens.count >= 5 else { return }
    guard let x = Int(tokens[1]), let y = Int(tokens[2]), let c = tokens[3].first else { return }
    if y >= 0 && y < height && x >= 0 && x < width {
        canvas[y][x] = String(c)
    }
}

// generate next‑rule expression (random walk)
func nextExpression(from x: Int, y: Int, char: Character) -> String {
    let dx = Int.random(in: -1...1)
    let dy = Int.random(in: -1...1)
    let nx = (x + dx + width) % width
    let ny = (y + dy + height) % height
    let nc = asciiRamp.randomElement()!
    return "(draw \(nx) \(ny) \(nc) (draw \(nx) \(ny) \(nc) ...))"
}

// ---------- Main loop ----------
var frame = 0
while fillBuffer() {
    let mags = magnitudeSpectrum()
    let maxMag = mags.max() ?? 1.0

    // map a subset of bins to radial positions
    for (i, mag) in mags.enumerated() {
        let angle = Double(i) / Double(mags.count) * 2.0 * Double.pi
        let radius = Int((mag / maxMag) * Double(min(width, height))/2.0)
        let cx = width/2 + Int(Double(radius) * cos(angle))
        let cy = height/2 + Int(Double(radius) * sin(angle))
        let ch = mapToChar(mag, maxMag: maxMag)
        let expr = "(draw \(cx) \(cy) \(ch) (draw \(cx) \(cy) \(ch) ...))"
        renderStroke(expr)
    }

    // scroll and display
    scrollCanvas()
    for line in canvas {
        print(String(line))
    }

    // tiny pause to keep terminal readable
    usleep(30_000)
    frame += 1
    if frame > 500 { break }               // safety stop
}