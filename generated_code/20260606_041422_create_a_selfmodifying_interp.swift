import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: - Helpers

func loadPNG(at path: String) -> (image: CGImage, data: Data)? {
    guard let url = URL(string: "file://\(URL(fileURLWithPath: path).path)") else { return nil }
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil),
          let data = try? Data(contentsOf: url) else { return nil }
    return (img, data)
}

func savePNG(image: CGImage, metadata: [CFString: Any], to path: String) -> Bool {
    guard let url = URL(string: "file://\(URL(fileURLWithPath: path).path)") else { return false }
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
    let pngProps: [CFString: Any] = [kCGImagePropertyPNGDictionary: metadata]
    CGImageDestinationAddImage(dest, image, pngProps as CFDictionary)
    return CGImageDestinationFinalize(dest)
}

// Simple brain‑fuck interpreter
func runBF(_ code: String, input: String = "") -> String {
    var tape = [UInt8](repeating: 0, count: 30_000)
    var ptr = 0
    var ip = 0
    var out = ""
    var inputIdx = input.startIndex
    // Pre‑compute bracket map
    var stack = [Int]()
    var jump = [Int:Int]()
    for (i,ch) in code.enumerated() {
        if ch == "[" { stack.append(i) }
        else if ch == "]" {
            let j = stack.removeLast()
            jump[i] = j
            jump[j] = i
        }
    }
    while ip < code.count {
        let ch = code[code.index(code.startIndex, offsetBy: ip)]
        switch ch {
        case ">": ptr = (ptr + 1) % tape.count
        case "<": ptr = (ptr - 1 + tape.count) % tape.count
        case "+": tape[ptr] = tape[ptr] &+ 1
        case "-": tape[ptr] = tape[ptr] &- 1
        case ".": out.append(Character(UnicodeScalar(tape[ptr])))
        case ",": 
            if inputIdx < input.endIndex {
                tape[ptr] = UInt8(input[inputIdx].unicodeScalars.first!.value)
                inputIdx = input.index(after: inputIdx)
            } else { tape[ptr] = 0 }
        case "[":
            if tape[ptr] == 0 { ip = jump[ip]! }
        case "]":
            if tape[ptr] != 0 { ip = jump[ip]! }
        default: break
        }
        ip += 1
    }
    return out
}

// Generate a simple SVG fractal (recursive squares)
func generateSVGFractal(size: Int = 256, depth: Int = 4) -> String {
    func square(x: Int, y: Int, s: Int, d: Int) -> String {
        guard d > 0 else { return "" }
        let rect = "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(s)\" height=\"\(s)\" fill=\"none\" stroke=\"hsl(\(d*45),80%,50%)\"/>"
        let child = square(x: x + s/4, y: y + s/4, s: s/2, d: d-1)
        return rect + child
    }
    let header = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    let svgOpen = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(size)\" height=\"\(size)\">"
    let content = square(x: 0, y: 0, s: size, d: depth)
    let svgClose = "</svg>"
    return header + svgOpen + content + svgClose
}

// Map pixel colors to BF commands
let colorMap: [UInt32: Character] = [
    0x000000FF: ">",   // black
    0xFFFFFFFF: "<",   // white
    0xFF0000FF: "+",   // red
    0x00FF00FF: "-",   // green
    0x0000FFFF: ".",   // blue
    0x00FFFFFF: ",",   // cyan
    0xFF00FFFF: "[",   // magenta
    0xFFFF00FF: "]"    // yellow
]

// Extract BF code from image pixels
func bfCode(from cgImg: CGImage) -> String {
    guard let data = cgImg.dataProvider?.data,
          let ptr = CFDataGetBytePtr(data) else { return "" }
    let width = cgImg.width
    let height = cgImg.height
    let bytesPerPixel = cgImg.bitsPerPixel / 8
    var code = ""
    for y in 0..<height {
        for x in 0..<width {
            let offset = (y * cgImg.bytesPerRow) + (x * bytesPerPixel)
            let b = UInt32(ptr[offset])
            let g = UInt32(ptr[offset+1])
            let r = UInt32(ptr[offset+2])
            let a = UInt32(ptr[offset+3])
            let rgba = (r << 24) | (g << 16) | (b << 8) | a
            if let cmd = colorMap[rgba] {
                code.append(cmd)
            }
        }
    }
    return code
}

// Main
guard CommandLine.arguments.count == 3 else {
    print("Usage: \(CommandLine.arguments[0]) input.png output.png")
    exit(1)
}
let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]

guard let (img, _) = loadPNG(at: inputPath) else {
    print("Failed to load input PNG.")
    exit(1)
}

// Decode BF program from pixels
let program = bfCode(from: img)

// Execute program (ignore input, take output as SVG)
let rawOutput = runBF(program)
let svg = rawOutput.isEmpty ? generateSVGFractal() : rawOutput

// Attach SVG as tEXt metadata
let metadata: [CFString: Any] = [
    kCGImagePropertyPNGKeyword: "fractal",
    kCGImagePropertyPNGComment: svg
]

// Write new PNG with embedded SVG
let success = savePNG(image: img, metadata: metadata, to: outputPath)
print(success ? "Success" : "Failed")