import Foundation
import CoreGraphics

// MARK: - Color & Vector Primitives

struct Pixel {
    var r: UInt8
    var g: UInt8
    var b: UInt8

    var hsb: (hue: Double, saturation: Double, brightness: Double) {
        let rf = Double(r) / 255.0
        let gf = Double(g) / 255.0
        let bf = Double(b) / 255.0

        let maxVal = max(rf, max(gf, bf))
        let minVal = min(rf, min(gf, bf))
        let delta = maxVal - minVal

        let brightness = maxVal
        let saturation = maxVal == 0 ? 0 : delta / maxVal

        var hue: Double = 0
        if delta != 0 {
            if maxVal == rf {
                hue = (gf - bf) / delta + (gf < bf ? 6 : 0)
            } else if maxVal == gf {
                hue = (bf - rf) / delta + 2
            } else {
                hue = (rf - gf) / delta + 4
            }
            hue /= 6.0
        }
        return (hue, saturation, brightness)
    }
}

struct Point {
    var x: Int
    var y: Int
}

enum Direction: CaseIterable {
    case right, down, left, up

    var dx: Int {
        switch self {
        case .right: return 1
        case .down: return 0
        case .left: return -1
        case .up: return 0
        }
    }

    var dy: Int {
        switch self {
        case .right: return 0
        case .down: return 1
        case .left: return 0
        case .up: return -1
        }
    }

    func rotateClockwise() -> Direction {
        switch self {
        case .right: return .down
        case .down: return .left
        case .left: return .up
        case .up: return .right
        }
    }
}

// MARK: - Photo Canvas (Visual Code Source)

class ImageCanvas {
    let width: Int
    let height: Int
    var pixels: [Pixel]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.pixels = Array(repeating: Pixel(r: 0, g: 0, b: 0), count: width * height)
    }

    func getPixel(x: Int, y: Int) -> Pixel {
        guard x >= 0 && x < width && y >= 0 && y < height else {
            return Pixel(r: 0, g: 0, b: 0)
        }
        return pixels[y * width + x]
    }

    func setPixel(x: Int, y: Int, pixel: Pixel) {
        guard x >= 0 && x < width && y >= 0 && y < height else { return }
        pixels[y * width + x] = pixel
    }

    /// Synthesizes a high-resolution mathematical "photograph" filled with light gradients.
    func synthesizeGenerativeCode() {
        for y in 0..<height {
            for x in 0..<width {
                let u = Double(x) / Double(width)
                let v = Double(y) / Double(height)

                // Complex wave interference pattern generating dynamic hue gradients & lighting
                let wave1 = sin(u * .pi * 8.0 + v * .pi * 4.0)
                let wave2 = cos(sqrt(u * u + v * v) * .pi * 12.0)
                let wave3 = sin(Double(x ^ y) * 0.05)

                let hue = (atan2(v - 0.5, u - 0.5) / (2.0 * .pi) + 1.0).truncatingRemainder(dividingBy: 1.0)
                let sat = 0.6 + 0.4 * wave1
                let bri = 0.3 + 0.7 * abs(wave2 * wave3)

                self.setPixel(x: x, y: y, pixel: Pixel.fromHSB(h: hue, s: sat, b: bri))
            }
        }
    }
}

extension Pixel {
    static func fromHSB(h: Double, s: Double, b: Double) -> Pixel {
        let c = b * s
        let x = c * (1.0 - abs((h * 6.0).truncatingRemainder(dividingBy: 2.0) - 1.0))
        let m = b - c

        var (r1, g1, b1) = (0.0, 0.0, 0.0)
        let sector = Int(h * 6.0) % 6
        switch sector {
        case 0: (r1, g1, b1) = (c, x, 0)
        case 1: (r1, g1, b1) = (x, c, 0)
        case 2: (r1, g1, b1) = (0, c, x)
        case 3: (r1, g1, b1) = (0, x, c)
        case 4: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }

        return Pixel(
            r: UInt8((r1 + m) * 255.0),
            g: UInt8((g1 + m) * 255.0),
            b: UInt8((b1 + m) * 255.0)
        )
    }
}

// MARK: - Esoteric Interpreter & Generative Weaver

class ChromaticInterpreter {
    private let sourceCodeImage: ImageCanvas
    private var tapestry: ImageCanvas
    
    private var pos = Point(x: 0, y: 0)
    private var dir = Direction.right
    private var memory = Array(repeating: Double(0.0), count: 256)
    private var stack: [Double] = []
    
    init(source: ImageCanvas, outputResolution: Int) {
        self.sourceCodeImage = source
        self.tapestry = ImageCanvas(width: outputResolution, height: outputResolution)
    }

    func execute(maxSteps: Int = 100_000) {
        var steps = 0

        while steps < maxSteps {
            let pixel = sourceCodeImage.getPixel(x: pos.x, y: pos.y)
            let (hue, sat, brightness) = pixel.hsb

            // Canvas Lighting maps directly to memory addresses [0...255]
            let memAddress = Int(brightness * 255.0) % memory.count

            // Hue determines instruction class & control flow steering
            let hueDegrees = hue * 360.0
            
            switch hueDegrees {
            case 0..<60: // Red: Push brightness/saturation payload to stack
                stack.append(brightness * sat * 100.0)

            case 60..<120: // Yellow: Arithmetic operation driven by memory state
                if stack.count >= 2 {
                    let b = stack.removeLast()
                    let a = stack.removeLast()
                    stack.append((a + b).truncatingRemainder(dividingBy: 255.0))
                }

            case 120..<180: // Green: Store value to lighting memory address
                let val = stack.popLast() ?? (sat * 255.0)
                memory[memAddress] = val

            case 180..<240: // Cyan: Conditional direction pivot based on memory light level
                if memory[memAddress] > 128.0 {
                    dir = dir.rotateClockwise()
                }

            case 240..<300: // Blue: Weave pixel into the tapestry
                let tapX = Int((Double(pos.x) / Double(sourceCodeImage.width)) * Double(tapestry.width))
                let tapY = Int((Double(pos.y) / Double(sourceCodeImage.height)) * Double(tapestry.height))
                
                let wovenColor = Pixel(
                    r: UInt8((memory[memAddress] + Double(pixel.r)) / 2.0),
                    g: UInt8(pixel.g),
                    b: UInt8((Double(stack.last ?? 0) + Double(pixel.b)) / 2.0)
                )
                tapestry.setPixel(x: tapX, y: tapY, pixel: wovenColor)

            default: // Magenta: Teleport instruction Pointer to new memory-derived coordinate
                let newX = Int(memory[memAddress]) % sourceCodeImage.width
                let newY = Int((stack.last ?? 0)) % sourceCodeImage.height
                pos = Point(x: abs(newX), y: abs(newY))
            }

            // Advance instruction pointer along current vector
            pos.x += dir.dx
            pos.y += dir.dy

            // Wrap around edges of the photograph
            if pos.x < 0 { pos.x = sourceCodeImage.width - 1 }
            if pos.x >= sourceCodeImage.width { pos.x = 0 }
            if pos.y < 0 { pos.y = sourceCodeImage.height - 1 }
            if pos.y >= sourceCodeImage.height { pos.y = 0 }

            steps += 1
        }
    }

    /// Renders the generated tapestry as a Netpbm PPM file
    func saveTapestryPPM(to filePath: String) {
        var ppmText = "P3\n\(tapestry.width) \(tapestry.height)\n255\n"
        for y in 0..<tapestry.height {
            for x in 0..<tapestry.width {
                let px = tapestry.getPixel(x: x, y: y)
                ppmText += "\(px.r) \(px.g) \(px.b) "
            }
            ppmText += "\n"
        }
        try? ppmText.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    /// Displays an ASCII visual tapestry directly to terminal output
    func printAsciiTapestry() {
        let asciiChars = [" ", ".", ":", "-", "=", "+", "*", "#", "%", "@"]
        print("=== GENERATED DIGITAL TAPESTRY PREVIEW ===")
        for y in stride(from: 0, to: tapestry.height, by: 2) {
            var line = ""
            for x in stride(from: 0, to: tapestry.width, by: 1) {
                let px = tapestry.getPixel(x: x, y: y)
                let lum = (Double(px.r) * 0.299 + Double(px.g) * 0.587 + Double(px.b) * 0.114) / 255.0
                let index = Int(lum * Double(asciiChars.count - 1))
                line += asciiChars[max(0, min(asciiChars.count - 1, index))]
            }
            print(line)
        }
    }
}

// MARK: - Program Execution

let photoWidth = 128
let photoHeight = 128
let sourcePhoto = ImageCanvas(width: photoWidth, height: photoHeight)

print("Synthesizing source photograph (executable code canvas)...")
sourcePhoto.synthesizeGenerativeCode()

print("Executing Esoteric Chromatic Interpreter...")
let interpreter = ChromaticInterpreter(source: sourcePhoto, outputResolution: 64)
interpreter.execute(maxSteps: 50_000)

print("Interpreter execution complete.")
interpreter.printAsciiTapestry()

let outputPath = "tapestry.ppm"
interpreter.saveTapestryPPM(to: outputPath)
print("Digital Tapestry saved to '\(outputPath)'.")