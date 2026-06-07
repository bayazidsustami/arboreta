#!/usr/bin/env swift

import Foundation

// MARK: - Utility Extensions

extension String {
    // Frequency of each character (case‑insensitive, alphanum only)
    var charFrequencies: [Character: Int] {
        var dict = [Character: Int]()
        for ch in lowercased() where ch.isLetter || ch.isNumber {
            dict[ch, default: 0] += 1
        }
        return dict
    }
    // Simple bigram entropy (shannon)
    var bigramEntropy: Double {
        var pairs = [String: Int]()
        let letters = lowercased().filter { $0.isLetter }
        guard letters.count > 1 else { return 0.0 }
        for i in 0..<(letters.count - 1) {
            let pair = String(letters[i...i+1])
            pairs[pair, default: 0] += 1
        }
        let total = Double(pairs.values.reduce(0, +))
        return -pairs.values.reduce(0.0) { $0 + Double($1)/total * log2(Double($1)/total) }
    }
    // Very naive sentiment: +1 for happy words, -1 for sad words
    var sentimentScore: Int {
        let happy = ["joy","happy","love","peace","smile","glad"]
        let sad   = ["sad","pain","sorrow","dark","lonely","hate"]
        let lower = lowercased()
        var score = 0
        for w in happy where lower.contains(w) { score += 1 }
        for w in sad   where lower.contains(w) { score -= 1 }
        return score
    }
}

// MARK: - Mandala Generation

struct MandalaLayer {
    let radius: Int
    let char: Character
    let speed: Double          // radians per frame
    let hueOffset: Double      // for color gradient
}

// Map text stats to visual parameters
func buildLayers(from text: String) -> [MandalaLayer] {
    let freq = text.charFrequencies
    let entropy = text.bigramEntropy
    let sentiment = text.sentimentScore
    
    // Sort characters by frequency descending
    let sorted = freq.sorted { $0.value > $1.value }
    var layers = [MandalaLayer]()
    var baseRadius = 4
    
    for (idx, (ch, count)) in sorted.enumerated() {
        // radius grows with order
        let radius = baseRadius + idx * 2
        // speed derived from count & entropy
        let speed = (Double(count) + entropy) / 20.0
        // hue offset shifts with sentiment
        let hue = Double((sentiment + idx) % 360) / 360.0
        layers.append(MandalaLayer(radius: radius, char: ch, speed: speed, hueOffset: hue))
    }
    return layers
}

// Simple HSV to ANSI 256 colour conversion
func ansiColor(from hue: Double, brightness: Double = 1.0) -> Int {
    // hue in [0,1), map to 0‑5 cube
    let h = Int(hue * 6.0) % 6
    let v = Int(brightness * 5.0)
    return 16 + 36 * h + 6 * v + v
}

// Render a frame
func render(layers: [MandalaLayer], time: Double) -> String {
    let size = (layers.map { $0.radius }.max() ?? 0) * 2 + 4
    var grid = Array(repeating: Array(repeating: " ", count: size), count: size)
    let center = size / 2
    
    for layer in layers {
        let angle = time * layer.speed
        for deg in stride(from: 0.0, to: 2.0 * Double.pi, by: Double.pi / Double(layer.radius * 4)) {
            let a = deg + angle
            let r = Double(layer.radius)
            let x = Int(round(r * cos(a))) + center
            let y = Int(round(r * sin(a))) + center
            guard x >= 0 && x < size && y >= 0 && y < size else { continue }
            let hue = fmod(layer.hueOffset + a / (2.0 * Double.pi), 1.0)
            let color = ansiColor(from: hue)
            grid[y][x] = "\u{001B}[38;5;\(color)m\(layer.char)\u{001B}[0m"
        }
    }
    return grid.map { $0.joined() }.joined(separator: "\n")
}

// MARK: - Hidden Poem Embedding

let hiddenPoem = """
When the code breathes, the mandala sings,
Layers of thought in looping rings.
Seek the flag, the secret key,
And verses bloom for eyes that see.
"""

func embedPoem(in executablePath: String) {
    // Append poem after a marker line; simple binary append works for script.
    let marker = "\n---POEM-START---\n"
    let data = (marker + hiddenPoem).data(using: .utf8)!
    FileHandle.standardOutput.write(data)
}

// MARK: - Main

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("Usage: \(args[0]) \"your text\" [--poem]")
    exit(1)
}
let inputText = args[1]

// Secret flag to extract poem
if args.contains("--poem") {
    // Locate own source file (available via $0 when compiled as script)
    if let sourcePath = ProcessInfo.processInfo.arguments.first {
        if let src = try? String(contentsOfFile: sourcePath),
           let range = src.range(of: "---POEM-START---") {
            let poem = src[range.upperBound...]
            print(poem.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            print(hiddenPoem) // fallback
        }
    }
    exit(0)
}

// Build mandala layers from text
let layers = buildLayers(from: inputText)

// Animation loop (30 FPS, 10 seconds)
let fps = 30.0
let duration = 10.0
let frames = Int(fps * duration)
for i in 0..<frames {
    let t = Double(i) / fps
    // Clear screen
    print("\u{001B}[2J\u{001B}[H", terminator: "")
    print(render(layers: layers, time: t))
    // Simple frame pacing
    usleep(useconds_t(1_000_000 / UInt32(fps)))
}

// Append hidden poem so future runs can retrieve it
embedPoem(in: args[0])