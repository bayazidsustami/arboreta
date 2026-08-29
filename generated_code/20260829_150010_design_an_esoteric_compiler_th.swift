import Foundation

/*
 *  PALETTE-TO-SOUNDSCAPE COMPILER & SYNTHESIZER
 *  --------------------------------------------
 *  1. Generates an in-memory 16x16 RGB digital photograph (gradient + noise).
 *  2. Compiles RGB pixels and spatial density into a custom stack-based bytecode.
 *  3. Executes the VM in an infinite loop, driving a additive synthesis engine.
 *  4. Generates an interactive audio stream via standard output (PCM RAW / WAV).
 */

// MARK: - 1. Custom Stack-Based Instruction Set & Bytecode Compiler

enum Opcode {
    case push(Double)
    case add, sub, mul, div, mod
    case sine, saw, square, noise
    case lowpass(cutoff: Double)
    case delay(feedback: Double)
    case duplicate, swap, drop
    case store(Int), load(Int)
}

struct Image {
    let width: Int
    let height: Int
    let pixels: [(r: UInt8, g: UInt8, b: UInt8)] // RGB Palette
}

final class EsotericCompiler {
    static func generateSampleImage(width: Int = 16, height: Int = 16) -> Image {
        var pixels = [(r: UInt8, g: UInt8, b: UInt8)]()
        for y in 0..<height {
            for x in 0..<width {
                let r = UInt8((Double(x) / Double(width)) * 255)
                let g = UInt8((Double(y) / Double(height)) * 255)
                let b = UInt8(UInt8.random(in: 50...200))
                pixels.append((r, g, b))
            }
        }
        return Image(width: width, height: height, pixels: pixels)
    }

    static func compile(image: Image) -> [Opcode] {
        var program = [Opcode]()
        let totalPixels = Double(image.pixels.count)
        
        // Calculate Image Spatial Density & Dominant Tones
        let avgR = image.pixels.map { Double($0.r) }.reduce(0, +) / totalPixels
        let avgG = image.pixels.map { Double($0.g) }.reduce(0, +) / totalPixels
        let avgB = image.pixels.map { Double($0.b) }.reduce(0, +) / totalPixels
        
        // Root pitch driven by average Red (60Hz to 440Hz base harmonic)
        let baseFreq = 60.0 + (avgR / 255.0) * 380.0
        program.append(.push(baseFreq))
        program.append(.store(0)) // Memory slot 0: Base Frequency
        
        // Density modulation driven by Green
        let densityMod = 0.1 + (avgG / 255.0) * 2.0
        program.append(.push(densityMod))
        program.append(.store(1)) // Memory slot 1: LFO Speed
        
        // Soundscape layering using individual pixel attributes
        for (i, pixel) in image.pixels.enumerated() where i % 8 == 0 {
            let normR = Double(pixel.r) / 255.0
            let normG = Double(pixel.g) / 255.0
            let normB = Double(pixel.b) / 255.0
            
            // Harmonic interval mapping
            let harmonicMultiplier = 1.0 + (Double(i % 7) * 0.5) + (normR * 2.0)
            
            program.append(.load(0)) // Base freq
            program.append(.push(harmonicMultiplier))
            program.append(.mul)     // Target Osc Frequency
            
            // Choose waveform family based on Blue color dominance
            if normB > 0.6 {
                program.append(.sine)
            } else if normB > 0.3 {
                program.append(.saw)
            } else {
                program.append(.square)
            }
            
            // Apply Lowpass Filter scaled by pixel Green intensity
            let cutoff = 200.0 + (normG * 3000.0)
            program.append(.lowpass(cutoff: cutoff))
            
            // Accumulate onto audio stack
            if i > 0 {
                program.append(.add)
            }
        }
        
        // Add spatial ambient delay and noise floor derived from density
        program.append(.noise)
        program.append(.push(0.02))
        program.append(.mul)
        program.append(.add)
        program.append(.delay(feedback: 0.45))
        
        return program
    }
}

// MARK: - 2. Virtual Machine & Audio Synthesizer Engine

final class AmbientVM {
    private var stack = [Double]()
    private var registers = [Int: Double]()
    private var sampleRate: Double
    private var phase = [Int: Double]()
    private var delayBuffer = [Double](repeating: 0.0, count: 22050) // 0.5s delay
    private var delayIndex = 0

    init(sampleRate: Double = 44100.0) {
        self.sampleRate = sampleRate
    }

    func step(program: [Opcode], time: Double) -> Double {
        stack.removeAll(keepingCapacity: true)
        var oscId = 0

        for op in program {
            switch op {
            case .push(let val):
                stack.append(val)

            case .add:
                let b = stack.popLast() ?? 0, a = stack.popLast() ?? 0
                stack.append(a + b)

            case .sub:
                let b = stack.popLast() ?? 0, a = stack.popLast() ?? 0
                stack.append(a - b)

            case .mul:
                let b = stack.popLast() ?? 0, a = stack.popLast() ?? 0
                stack.append(a * b)

            case .div:
                let b = stack.popLast() ?? 1, a = stack.popLast() ?? 0
                stack.append(b == 0 ? 0 : a / b)

            case .mod:
                let b = stack.popLast() ?? 1, a = stack.popLast() ?? 0
                stack.append(a.truncatingRemainder(dividingBy: b))

            case .sine:
                let freq = stack.popLast() ?? 440.0
                let currentPhase = phase[oscId, default: 0.0]
                let sample = sin(currentPhase * 2.0 * .pi)
                phase[oscId] = (currentPhase + freq / sampleRate).truncatingRemainder(dividingBy: 1.0)
                oscId += 1
                stack.append(sample * 0.15)

            case .saw:
                let freq = stack.popLast() ?? 440.0
                let currentPhase = phase[oscId, default: 0.0]
                let sample = (2.0 * currentPhase) - 1.0
                phase[oscId] = (currentPhase + freq / sampleRate).truncatingRemainder(dividingBy: 1.0)
                oscId += 1
                stack.append(sample * 0.1)

            case .square:
                let freq = stack.popLast() ?? 440.0
                let currentPhase = phase[oscId, default: 0.0]
                let sample = currentPhase < 0.5 ? 0.8 : -0.8
                phase[oscId] = (currentPhase + freq / sampleRate).truncatingRemainder(dividingBy: 1.0)
                oscId += 1
                stack.append(sample * 0.08)

            case .noise:
                let sample = (Double.random(in: -1.0...1.0))
                stack.append(sample)

            case .lowpass(let cutoff):
                let input = stack.popLast() ?? 0.0
                let rc = 1.0 / (2.0 * .pi * cutoff)
                let dt = 1.0 / sampleRate
                let alpha = dt / (rc + dt)
                let prev = registers[9900 + oscId, default: 0.0]
                let output = prev + (alpha * (input - prev))
                registers[9900 + oscId] = output
                oscId += 1
                stack.append(output)

            case .delay(let feedback):
                let input = stack.popLast() ?? 0.0
                let delayed = delayBuffer[delayIndex]
                delayBuffer[delayIndex] = input + (delayed * feedback)
                delayIndex = (delayIndex + 1) % delayBuffer.count
                stack.append(input + delayed * 0.5)

            case .duplicate:
                if let top = stack.last { stack.append(top) }

            case .swap:
                if stack.count >= 2 {
                    let end = stack.count - 1
                    stack.swapAt(end, end - 1)
                }

            case .drop:
                _ = stack.popLast()

            case .store(let reg):
                registers[reg] = stack.popLast() ?? 0.0

            case .load(let reg):
                stack.append(registers[reg, default: 0.0])
            }
        }

        return stack.last ?? 0.0
    }
}

// MARK: - 3. Execution Pipeline & Realtime Audio Streamer

let image = EsotericCompiler.generateSampleImage()
let bytecode = EsotericCompiler.compile(image: image)

let sampleRate = 44100.0
let vm = AmbientVM(sampleRate: sampleRate)

var frame = 0
let bufferSize = 1024
let stdout = FileHandle.standardOutput

// Infinite Procedural Audio Streaming Loop
while true {
    var pcmBuffer = [Int16]()
    pcmBuffer.reserveCapacity(bufferSize)

    for _ in 0..<bufferSize {
        let t = Double(frame) / sampleRate
        let rawSample = vm.step(program: bytecode, time: t)
        
        // Soft clipping / limiter
        let clamped = max(-1.0, min(1.0, rawSample))
        let pcmValue = Int16(clamped * 32767.0)
        
        pcmBuffer.append(pcmValue)
        frame += 1
    }

    // Write PCM raw 16-bit audio stream out directly to stdout
    pcmBuffer.withUnsafeBufferPointer { buffer in
        let data = Data(buffer: buffer)
        stdout.write(data)
    }
}