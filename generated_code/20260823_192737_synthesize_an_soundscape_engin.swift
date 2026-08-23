import Foundation
import AVFoundation
import Accelerate
import AppKit

// MARK: - Genetic Genome & FM Voice Architecture

/// Represents a single FM synthesis voice whose parameters are encoded in binary genes.
struct VoiceGenome {
    var carrierFreqRatio: Float     // Ratio relative to base frequency
    var modulatorFreqRatio: Float   // Modulator frequency ratio
    var modulationIndex: Float      // Depth of FM synthesis
    var attack: Float               // Attack time in seconds
    var release: Float              // Release time in seconds
    var microtonalPitchOffset: Float // Pitch shift in cents (-100 to +100)
    var pan: Float                  // Stereo panning (-1.0 to 1.0)
    var fitness: Float = 0.0        // Evaluated harmonic alignment / aesthetic score

    /// Parse a 16-byte slice of raw binary data into a structured genome.
    static func decode(from bytes: ArraySlice<UInt8>, basePitch: Float) -> VoiceGenome {
        let b = Array(bytes.prefix(16))
        func norm(_ idx: Int) -> Float {
            guard idx < b.count else { return 0.5 }
            return Float(b[idx]) / 255.0
        }

        let carrierRatio = 0.5 + (norm(0) * 7.5)          // 0.5x to 8.0x
        let modRatio = 0.25 + (norm(1) * 11.75)           // 0.25x to 12.0x
        let modIndex = norm(2) * norm(3) * 12.0           // Modulation index 0 to 12
        let attackTime = 0.05 + (norm(4) * norm(5) * 2.0) // 50ms to 2.05s
        let releaseTime = 0.1 + (norm(6) * 3.0)           // 100ms to 3.1s
        let cents = (norm(7) - 0.5) * 200.0               // Microtonal offset in cents
        let stereoPan = (norm(8) - 0.5) * 2.0             // Panning -1.0 to 1.0

        return VoiceGenome(
            carrierFreqRatio: carrierRatio,
            modulatorFreqRatio: modRatio,
            modulationIndex: modIndex,
            attack: attackTime,
            release: releaseTime,
            microtonalPitchOffset: cents,
            pan: stereoPan
        )
    }

    /// Mutate genome parameters based on binary entropy.
    mutating func mutate(rate: Float, entropyByte: UInt8) {
        let factor = Float(entropyByte) / 255.0
        if Float.random(in: 0...1) < rate {
            carrierFreqRatio *= (1.0 + (factor - 0.5) * 0.2)
        }
        if Float.random(in: 0...1) < rate {
            modulationIndex = max(0, modulationIndex + (factor - 0.5) * 2.0)
        }
        if Float.random(in: 0...1) < rate {
            microtonalPitchOffset += (factor - 0.5) * 20.0
        }
    }

    /// Crossover two genomes to breed a child voice.
    static func breed(_ parentA: VoiceGenome, _ parentB: VoiceGenome) -> VoiceGenome {
        return VoiceGenome(
            carrierFreqRatio: Bool.random() ? parentA.carrierFreqRatio : parentB.carrierFreqRatio,
            modulatorFreqRatio: Bool.random() ? parentA.modulatorFreqRatio : parentB.modulatorFreqRatio,
            modulationIndex: (parentA.modulationIndex + parentB.modulationIndex) * 0.5,
            attack: Bool.random() ? parentA.attack : parentB.attack,
            release: Bool.random() ? parentA.release : parentB.release,
            microtonalPitchOffset: (parentA.microtonalPitchOffset + parentB.microtonalPitchOffset) * 0.5,
            pan: (parentA.pan + parentB.pan) * 0.5
        )
    }
}

// MARK: - Real-time FM DSP Engine

/// Active DSP state for rendering a microtonal FM synth voice.
final class FMVoiceDSP {
    var genome: VoiceGenome
    var baseFrequency: Float
    var carrierPhase: Float = 0
    var modulatorPhase: Float = 0
    var envelopePhase: Float = 0
    var isTriggered: Bool = true
    var age: Float = 0

    init(genome: VoiceGenome, baseFrequency: Float) {
        self.genome = genome
        self.baseFrequency = baseFrequency
    }

    /// Calculate effective pitch incorporating microtonal offset in cents.
    var frequency: Float {
        let microtonalFactor = powf(2.0, genome.microtonalPitchOffset / 1200.0)
        return baseFrequency * genome.carrierFreqRatio * microtonalFactor
    }

    /// Process next audio buffer sample for this voice.
    func renderSample(sampleRate: Float) -> (left: Float, right: Float) {
        guard isTriggered else { return (0, 0) }

        let fc = frequency
        let fm = fc * genome.modulatorFreqRatio

        // Phase accumulation
        modulatorPhase += (2.0 * .pi * fm) / sampleRate
        if modulatorPhase > 2.0 * .pi { modulatorPhase -= 2.0 * .pi }

        let modulatorSignal = sinf(modulatorPhase) * genome.modulationIndex * fm
        carrierPhase += (2.0 * .pi * fc + modulatorSignal) / sampleRate
        if carrierPhase > 2.0 * .pi { carrierPhase -= 2.0 * .pi }

        let carrierSignal = sinf(carrierPhase)

        // Envelope computation (Simple AR)
        age += 1.0 / sampleRate
        let env: Float
        if age < genome.attack {
            env = age / genome.attack
        } else if age < (genome.attack + genome.release) {
            env = 1.0 - ((age - genome.attack) / genome.release)
        } else {
            env = 0
            isTriggered = false
        }

        let output = carrierSignal * env * 0.15
        let panL = cosf((genome.pan + 1.0) * .pi / 4.0)
        let panR = sinf((genome.pan + 1.0) * .pi / 4.0)

        return (output * panL, output * panR)
    }
}

// MARK: - Generative Visualizer Window

/// NSView rendering real-time spectrum and evolutionary history visualizer.
final class VisualizerView: NSView {
    var audioBuffer: [Float] = Array(repeating: 0, count: 512)
    var generationHistory: [[Float]] = []
    let maxHistory = 100
    private let lock = NSLock()

    func pushAudioData(_ samples: [Float]) {
        lock.lock()
        defer { lock.unlock() }
        self.audioBuffer = samples
        if generationHistory.count >= maxHistory {
            generationHistory.removeFirst()
        }
        generationHistory.append(samples)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Background dark void
        context.setFillColor(CGColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1.0))
        context.fill(bounds)

        lock.lock()
        let historyCopy = generationHistory
        let bufferCopy = audioBuffer
        lock.unlock()

        let width = bounds.width
        let height = bounds.height

        // Render Evolutionary Waterfall / History Grid
        for (hIndex, frame) in historyCopy.enumerated() {
            let y = (Float(hIndex) / Float(maxHistory)) * Float(height)
            let alpha = CGFloat(hIndex) / CGFloat(maxHistory) * 0.4

            let path = CGMutablePath()
            let step = width / CGFloat(frame.count)

            path.move(to: CGPoint(x: 0, y: CGFloat(y)))
            for (i, val) in frame.enumerated() {
                let x = CGFloat(i) * step
                let sampleY = CGFloat(y) + CGFloat(val * 40.0)
                path.addLine(to: CGPoint(x: x, y: sampleY))
            }

            context.setStrokeColor(CGColor(red: 0.2, green: 0.8, blue: 0.9, alpha: alpha))
            context.setLineWidth(1.0)
            context.addPath(path)
            context.strokePath()
        }

        // Render Active Waveform Overlay
        let currentPath = CGMutablePath()
        let step = width / CGFloat(bufferCopy.count)
        let centerY = height * 0.5

        currentPath.move(to: CGPoint(x: 0, y: centerY))
        for (i, val) in bufferCopy.enumerated() {
            let x = CGFloat(i) * step
            let y = centerY + CGFloat(val * Float(height) * 0.4)
            currentPath.addLine(to: CGPoint(x: x, y: y))
        }

        context.setStrokeColor(CGColor(red: 1.0, green: 0.3, blue: 0.6, alpha: 0.9))
        context.setLineWidth(2.5)
        context.addPath(currentPath)
        context.strokePath()
    }
}

// MARK: - Binary Soundscape Engine Controller

final class BinarySoundscapeEngine {
    private let audioEngine = AVAudioEngine()
    private var sourceData: Data
    private var population: [VoiceGenome] = []
    private var activeDSPVoices: [FMVoiceDSP] = []
    private let populationSize = 12
    private var dataPointer = 0
    private var generation = 0

    private var visualizerView: VisualizerView?
    private let engineQueue = DispatchQueue(label: "com.soundscape.engine", qos: .userInteractive)

    init(rawData: Data) {
        self.sourceData = rawData.isEmpty ? Data((0..<1024).map { _ in UInt8.random(in: 0...255) }) : rawData
        bootstrapInitialPopulation()
    }

    /// Seed the initial choir from binary payload chunks.
    private func bootstrapInitialPopulation() {
        let chunkSize = 16
        let basePitch: Float = 110.0 // A2 fundamental

        for i in 0..<populationSize {
            let offset = (i * chunkSize) % max(1, sourceData.count - chunkSize)
            let sub = sourceData.subdata(in: offset..<offset + chunkSize)
            let genome = VoiceGenome.decode(from: ArraySlice(sub), basePitch: basePitch)
            population.append(genome)
        }
    }

    /// Evolution loop: evaluate fitness, breed, and trigger new voices.
    func evolveNextGeneration() {
        generation += 1

        // Evaluate fitness based on spectral/harmonic ratios relative to golden ratio
        let goldenRatio: Float = 1.61803398875
        for i in 0..<population.count {
            let ratioDiff = abs(population[i].carrierFreqRatio - goldenRatio)
            population[i].fitness = 1.0 / (1.0 + ratioDiff)
        }

        // Sort by fitness
        population.sort { $0.fitness > $1.fitness }

        // Select top performers & breed next generation
        var newPopulation: [VoiceGenome] = Array(population.prefix(populationSize / 2))
        let entropyByte = sourceData[dataPointer % sourceData.count]
        dataPointer += 1

        while newPopulation.count < populationSize {
            let parentA = population[Int.random(in: 0..<(populationSize / 2))]
            let parentB = population[Int.random(in: 0..<(populationSize / 2))]
            var child = VoiceGenome.breed(parentA, parentB)
            child.mutate(rate: 0.25, entropyByte: entropyByte)
            newPopulation.append(child)
        }

        population = newPopulation

        // Instantiate DSP nodes for the new generation
        let basePitches: [Float] = [110.0, 146.83, 164.81, 220.0, 246.94, 293.66]
        let selectedPitch = basePitches[generation % basePitches.count]

        let newVoices = population.prefix(4).map { genome in
            FMVoiceDSP(genome: genome, baseFrequency: selectedPitch)
        }

        engineQueue.async {
            self.activeDSPVoices.append(contentsOf: newVoices)
        }
    }

    /// Setup AudioEngine and Realtime Audio Rendering Source
    func startAudioEngine(visualizer: VisualizerView) {
        self.visualizerView = visualizer
        let mainMixer = audioEngine.mainMixerNode
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)!

        let sourceNode = AVAudioSourceNode { [weak self] (_, _, frameCount, audioBufferList) -> OSStatus in
            guard let self = self else { return noErr }

            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let leftChannel = buffers[0].mData?.assumingMemoryBound(to: Float.self)
            let rightChannel = buffers[1].mData?.assumingMemoryBound(to: Float.self)

            let sampleRate: Float = 44100.0
            var vizSamples = [Float]()

            for frame in 0..<Int(frameCount) !$0.isTriggered % & ) * + - .buffered, .closable, .height] .miniaturizable, .resizable], .zero, / // 0 0.5) 0.8, 600) 8="=" 900, ?? AppDelegate: Application BinarySoundscapeEngine! Data() Data(contentsOf: DispatchQueue.main.async Engine Entry Evolutionary Failure: Float="0" GUI Limiter MARK: NSApplication) NSApplicationDelegate NSObject, NSWindow! Notification) Point Read Setup Start Timer Timer.scheduledTimer(withTimeInterval: URL(fileURLWithPath: [.titled, [weak \(error)") _ applicationDidFinishLaunching(_ applicationShouldTerminateAfterLastWindowClosed(_ as audioEngine.attach(sourceNode) audioEngine.connect(sourceNode, audioEngine.start() backing: binary catch class clipping contentRect: defer: do engine="BinarySoundscapeEngine(rawData:" engine.startAudioEngine(visualizer: engine: executable executionPath="CommandLine.arguments[0]" executionPath))) false final for format) format: frame func height: if in input leftChannel?[frame]="sumL" let mainMixer, noErr notification: payload payloadData="(try?" payloadData) print("Audio rect="NSRect(origin:" rect) rect, repeats: return rightChannel?[frame]="sumR" sample="voice.renderSample(sampleRate:" sampleRate) self.activeDSPVoices self.activeDSPVoices.removeAll(where: self.engineQueue.sync self.visualizerView?.needsDisplay="true" self.visualizerView?.pushAudioData(vizSamples) self?.evolveNextGeneration() self] sender: size: soft styleMask: sumL="tanhf(sumL)" sumL: sumR="tanhf(sumR)" sumR) sumR: to: true) try var visualizer="VisualizerView(frame:" visualizer) visualizer.autoresizingMask="[.width," vizSamples.append((sumL voice window="NSWindow(" window.center() window.contentView?.addSubview(visualizer) window.makeKeyAndOrderFront(nil) window.title="Binary Genome FM Choir Soundscape Engine" window: windowSize="NSSize(width:" windowSize) { } })> Bool {
        return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()