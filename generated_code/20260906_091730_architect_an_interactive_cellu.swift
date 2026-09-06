import Foundation
import AVFoundation
import CoreAudio
import Accelerate

// MARK: - Non-Euclidean Graph Node Architecture
final class MazeNode {
    let id: UUID = UUID()
    var neighbors: [MazeNode] = [] // Hyper-dimensional graph links (non-Euclidean connectivity)
    var isWall: Bool
    var energy: Float = 0.0
    var age: Int = 0

    init(isWall: Bool) {
        self.isWall = isWall
    }
}

// MARK: - Audio Analysis Engine
final class HarmonicAnalyzer {
    private let audioEngine = AVAudioEngine()
    private let fftSize = 1024
    private var fftSetup: FFTSetup?

    var onDissonanceUpdated: ((Float) -> Void)?

    init() {
        fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(fftSize))), FFTRadix(kFFTRadix2))
    }

    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    func start() throws {
        let inputNode = audioEngine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: format) { [weak self] buffer, _ in
            self?.processAudio(buffer: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func processAudio(buffer: AVAudioPCMBuffer) {
        guard let floatData = buffer.floatChannelData?[0], let setup = fftSetup else { return }

        var real = [Float](repeating: 0, count: fftSize / 2)
        var imag = [Float](repeating: 0, count: fftSize / 2)

        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                let windowed = [Float](repeating: 0, count: fftSize)

                vDSP_hann_window(UnsafeMutablePointer(mutating: windowed), vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
                vDSP_vmul(floatData, 1, windowed, 1, UnsafeMutablePointer(mutating: windowed), 1, vDSP_Length(fftSize))

                windowed.withUnsafeBufferPointer { winPtr in
                    winPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                    }
                }

                vDSP_fft_zrip(setup, &splitComplex, 1, vDSP_Length(log2(Float(fftSize))), FFTDirection(FFT_FORWARD))

                var magnitudes = [Float](repeating: 0, count: fftSize / 2)
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

                // Calculate roughness/dissonance via spectral peak distance variance
                let dissonance = self.calculateSpectralDissonance(magnitudes: magnitudes)
                self.onDissonanceUpdated?(dissonance)
            }
        }
    }

    private func calculateSpectralDissonance(magnitudes: [Float]) -> Float {
        let threshold: Float = 0.01
        var peaks: [Int] = []
        for i in 1..<(magnitudes.count - 1) {
            if magnitudes[i] > threshold && magnitudes[i] > magnitudes[i-1] && magnitudes[i] > magnitudes[i+1] {
                peaks.append(i)
            }
        }

        guard peaks.count > 1 else { return 0.0 }
        var intervals: [Float] = []
        for i in 0..<(peaks.count - 1) {
            intervals.append(Float(peaks[i+1] - peaks[i]))
        }

        let mean = intervals.reduce(0, +) / Float(intervals.count)
        let variance = intervals.reduce(0) { $0 + pow($1 - mean, 2) } / Float(intervals.count)
        return min(1.0, sqrt(variance) / 10.0) // Normalized dissonance metric
    }
}

// MARK: - Real-Time Audio Sonifier
final class MazeSonifier {
    private let audioEngine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var phase: Float = 0.0
    var baseFrequency: Float = 220.0
    var resonance: Float = 0.0

    func start() throws {
        let mainMixer = audioEngine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)

        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let phaseIncrement = (2.0 * Float.pi * self.baseFrequency) / Float(outputFormat.sampleRate)

            for frame in 0..<Int(frameCount) +="phaseIncrement" if self.phase {> 2.0 * Float.pi { self.phase -= 2.0 * Float.pi }

                let value = (sin(self.phase) + 0.5 * sin(self.phase * (1.0 + self.resonance))) * 0.1
                for buffer in ablPointer {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    buf[frame] = value
                }
            }
            return noErr
        }

        if let sourceNode = sourceNode {
            audioEngine.attach(sourceNode)
            audioEngine.connect(sourceNode, to: mainMixer, format: outputFormat)
            audioEngine.prepare()
            try audioEngine.start()
        }
    }
}

// MARK: - Non-Euclidean Cellular Automaton
final class NonEuclideanAutomaton {
    private(set) var nodes: [MazeNode] = []
    private var dissonanceFactor: Float = 0.0

    init(nodeCount: Int = 100) {
        // Construct non-Euclidean graph topology (Möbius-like hyper-connected loop)
        for _ in 0..<nodeCount {
            nodes.append(MazeNode(isWall: Bool.random()))
        }

        for i in 0..<nodeCount {
            let leftIndex = (i - 1 + nodeCount) % nodeCount
            let rightIndex = (i + 1) % nodeCount
            let nonEuclideanWarpIndex = (i + nodeCount / 2 + 3) % nodeCount // Non-local shortcut

            nodes[i].neighbors.append(nodes[leftIndex])
            nodes[i].neighbors.append(nodes[rightIndex])
            nodes[i].neighbors.append(nodes[nonEuclideanWarpIndex])
        }
    }

    func updateDissonance(_ dissonance: Float) {
        self.dissonanceFactor = dissonance
    }

    func step() {
        var newStates = [(MazeNode, Bool)]()

        for node in nodes {
            let activeNeighbors = node.neighbors.filter { $0.isWall }.count
            var nextIsWall = node.isWall

            if node.isWall {
                // High dissonance forces structural breakdown; low dissonance repairs walls
                if dissonanceFactor > 0.6 {
                    nextIsWall = activeNeighbors >= 2 // Mutation/Collapse
                } else {
                    nextIsWall = activeNeighbors >= 1 // Self-Repairing state
                }
            } else {
                // Spontaneous non-Euclidean geometry generation
                if activeNeighbors == 2 || dissonanceFactor > 0.8 {
                    nextIsWall = true
                }
            }
            newStates.append((node, nextIsWall))
        }

        for (node, state) in newStates {
            node.isWall = state
            node.age = state ? node.age + 1 : 0
            node.energy = min(1.0, Float(node.age) * 0.1 + dissonanceFactor)
        }
    }

    func renderAscii() -> String {
        return nodes.map { node in
            if node.isWall {
                return node.energy > 0.5 ? "▓" : "▒"
            } else {
                return " "
            }
        }.joined()
    }

    var averageEnergy: Float {
        return nodes.reduce(0.0) { $0 + $1.energy } / Float(nodes.count)
    }
}

// MARK: - Orchestrator Script Execution
final class Orchestrator {
    private let analyzer = HarmonicAnalyzer()
    private let sonifier = MazeSonifier()
    private let automaton = NonEuclideanAutomaton(nodeCount: 64)
    private var isRunning = true

    func run() {
        print("\u{001B}[2J") // Clear terminal
        print("=== Non-Euclidean Cellular Automaton & Audio Interactive Sonifier ===")
        print("Listening to live audio... Sing or make noise to mutate geometry!")

        analyzer.onDissonanceUpdated = { [weak self] dissonance in
            self?.automaton.updateDissonance(dissonance)
        }

        do {
            try analyzer.start()
            try sonifier.start()
        } catch {
            print("Audio Engine Failure: \(error.localizedDescription)")
            print("Running in simulated audio mode...")
        }

        let timer = DispatchSource.makeTimerSource()
        timer.schedule(deadline: .now(), repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.automaton.step()

            // Update Audio Synthesis Parameters based on Automaton State
            self.sonifier.baseFrequency = 150.0 + (self.automaton.averageEnergy * 300.0)
            self.sonifier.resonance = self.automaton.averageEnergy

            // Visual Rendering in Terminal
            let frame = self.automaton.renderAscii()
            print("\r[\(frame)] Energy: \(String(format: "%.2f", self.automaton.averageEnergy))", terminator: "")
            fflush(stdout)
        }
        timer.resume()

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 15.0))
        timer.cancel()
        print("\nSimulation complete.")
    }
}

let orchestrator = Orchestrator()
orchestrator.run()