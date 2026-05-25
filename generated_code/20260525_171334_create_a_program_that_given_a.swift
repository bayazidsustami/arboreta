import Foundation
import AVFoundation
import Accelerate

// MARK: - Audio capture & FFT --------------------------------------------------

class AudioAnalyzer {
    private let engine = AVAudioEngine()
    private var fftSetup: FFTSetup?
    private let fftSize = 1024
    private var window: [Float] = []
    
    init() {
        fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(fftSize))), FFTRadix(kFFTRadix2))
        window = vDSP.window(.hanningDenormalized, length: fftSize, isHalfWindow: false).map { $0 }
    }
    
    func captureAndAnalyze(duration: TimeInterval, completion: @escaping ([Float]) -> Void) {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        var samples = [Float]()
        let bufferSize = AVAudioFrameCount(fftSize)
        
        input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { buffer, _ in
            let channelData = buffer.floatChannelData![0]
            let frameLength = Int(buffer.frameLength)
            samples.append(contentsOf: UnsafeBufferPointer(start: channelData, count: frameLength))
        }
        
        try? engine.start()
        DispatchQueue.global().asyncAfter(deadline: .now() + duration) {
            self.engine.stop()
            self.inputNode.removeTap(onBus: 0)
            let magnitudes = self.performFFT(on: samples)
            completion(magnitudes)
        }
    }
    
    private func performFFT(on signal: [Float]) -> [Float] {
        guard let fftSetup = fftSetup else { return [] }
        var real = [Float](repeating: 0, count: fftSize/2)
        var imag = [Float](repeating: 0, count: fftSize/2)
        var windowed = zip(signal, window).map(*)
        windowed += [Float](repeating: 0, count: max(0, fftSize - windowed.count))
        windowed.withUnsafeMutableBytes { ptr in
            let complexPtr = ptr.baseAddress!.assumingMemoryBound(to: DSPComplex.self)
            vDSP_ctoz(complexPtr, 2, &DSPSplitComplex(realp: &real, imagp: &imag), 1, vDSP_Length(fftSize/2))
        }
        vDSP_fft_zrip(fftSetup, &DSPSplitComplex(realp: &real, imagp: &imag), 1, vDSP_Length(log2(Float(fftSize))), FFTDirection(FFT_FORWARD))
        var mags = [Float](repeating: 0, count: fftSize/2)
        vDSP_zvmags(&DSPSplitComplex(realp: &real, imagp: &imag), 1, &mags, 1, vDSP_Length(fftSize/2))
        var normalized = [Float](repeating: 0, count: mags.count)
        vDSP_vsmul(&mags, 1, [2.0/Float(fftSize)], &normalized, 1, vDSP_Length(mags.count))
        return normalized
    }
}

// MARK: - L‑System --------------------------------------------------------------

struct LSystem {
    var axiom: String
    var rules: [Character: String]
    var angle: Double
    var step: Double
    
    func generate(iterations: Int) -> String {
        var current = axiom
        for _ in 0..<iterations {
            var next = ""
            for ch in current {
                if let repl = rules[ch] {
                    next.append(contentsOf: repl)
                } else {
                    next.append(ch)
                }
            }
            current = next
        }
        return current
    }
}

// MARK: - Turtle graphics → SVG -------------------------------------------------

struct Turtle {
    var x: Double = 0, y: Double = 0
    var heading: Double = 0
    var path = "M0 0"
    var minX = 0.0, maxX = 0.0, minY = 0.0, maxY = 0.0
    
    mutating func forward(_ dist: Double) {
        let rad = heading * .pi / 180
        x += cos(rad) * dist
        y += sin(rad) * dist
        path += " L\(x) \(y)"
        minX = min(minX, x); maxX = max(maxX, x)
        minY = min(minY, y); maxY = max(maxY, y)
    }
    mutating func turn(_ angle: Double) {
        heading += angle
    }
}

// MARK: - Main -------------------------------------------------------------------

let analyzer = AudioAnalyzer()
let captureDuration: TimeInterval = 2.0

let semaphore = DispatchSemaphore(value: 0)
var lastMagnitudes: [Float] = []

analyzer.captureAndAnalyze(duration: captureDuration) { mags in
    lastMagnitudes = mags
    semaphore.signal()
}
semaphore.wait()

// Map low, mid, high energy to rule tweaks
let lowEnergy = lastMagnitudes.prefix(10).reduce(0,+)
let midEnergy = lastMagnitudes[10..<30].reduce(0,+)
let highEnergy = lastMagnitudes[30..<lastMagnitudes.count].reduce(0,+)

var rules: [Character: String] = [
    "F": "F[+F]F[-F]F"
]

// Dynamic alteration: if high energy spikes, add extra branch
if highEnergy > 0.5 {
    rules["F"] = "F[+F]F[-F]F[+F]"
}
if lowEnergy > 0.3 {
    rules["F"] = "F[-F]F[+F]F"
}

// Create L‑system
let lsys = LSystem(axiom: "F", rules: rules, angle: 25.0, step: 10.0)
let generated = lsys.generate(iterations: 4)

// Turtle walk
var turtle = Turtle()
for ch in generated {
    switch ch {
    case "F":
        turtle.forward(lsys.step)
    case "+":
        turtle.turn(lsys.angle)
    case "-":
        turtle.turn(-lsys.angle)
    case "[":
        // push state
        stateStack.append(turtle)
    case "]":
        // pop state
        if let saved = stateStack.popLast() { turtle = saved }
    default: break
    }
}

// Build SVG with animated stroke colour
let width = turtle.maxX - turtle.minX + 20
let height = turtle.maxY - turtle.minY + 20
let viewBox = "\(turtle.minX-10) \(turtle.minY-10) \(width) \(height)"
let svgHeader = """
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="\(viewBox)" width="800" height="600">
"""

// Encode rhythm (beat interval) as comment
let beatInterval = captureDuration / Double(lastMagnitudes.count)
let rhythmComment = "<!-- Rhythm beat interval: \(beatInterval)s -->\n"

let pathElement = """
<path d="\(turtle.path)" fill="none" stroke-width="2">
  <animate attributeName="stroke" values="#ff0000;#00ff00;#0000ff;#ff0000" dur="4s" repeatCount="indefinite"/>
</path>
"""

let svgFooter = "\n</svg>"

let svgContent = svgHeader + rhythmComment + pathElement + svgFooter

let outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("output.svg")
try? svgContent.write(to: outputURL, atomically: true, encoding: .utf8)

// Helper stack for turtle state
var stateStack = [Turtle]()

print("SVG written to \(outputURL.path)")