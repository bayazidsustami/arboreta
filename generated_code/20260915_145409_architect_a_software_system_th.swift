import Foundation
import AVFoundation

// MARK: - Domain Models

enum CommitType {
    case refactoring // Generates complex chord progressions
    case bugFix      // Resolves active dissonances back to fundamental harmonics
    case memoryLeak  // Detunes global oscillator frequencies (pitch-bend to microtonal)
    case feature     // Triggers melodic arpeggios
}

struct Commit {
    let id: String
    let message: String
    let type: CommitType
}

// MARK: - Audio Engine & Sound Synthesis

final class SymphonyEngine {
    private let audioEngine = AVAudioEngine()
    private let mainMixer: AVAudioMixerNode
    
    // Polyphonic oscillator state
    private var activeNodes: [AVAudioSourceNode] = []
    private var baseFrequencies: [Double] = [261.63, 329.63, 392.00, 523.25] // C Major Chord (C4, E4, G4, C5)
    private var detuneFactor: Double = 1.0 // 1.0 = normal, values > 1.0 introduce microtonal drift
    private var isDissonant: Bool = false
    
    init() {
        mainMixer = audioEngine.mainMixerNode
        setupEngine()
    }
    
    private func setupEngine() {
        // Build 4 polyphonic voices running custom sine wave generators
        for i in 0..<4 {
            var phase: Double = 0.0
            let voiceIndex = i
            
            let sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
                guard let self = self else { return noErr }
                
                let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
                let targetFreq = self.getCurrentFrequency(forVoice: voiceIndex)
                let phaseIncrement = (2.0 * .pi * targetFreq) / 44100.0
                
                for frame in 0..<Int(frameCount) * +="phaseIncrement" // 0.25) Prevent clipping if let phase sampleValue="Float(sin(phase)" {>= 2.0 * .pi { phase -= 2.0 * .pi }
                    
                    for buffer in ablPointer {
                        let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                        buf[frame] = sampleValue
                    }
                }
                return noErr
            }
            
            activeNodes.append(sourceNode)
            audioEngine.attach(sourceNode)
            audioEngine.connect(sourceNode, to: mainMixer, format: AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2))
        }
        
        do {
            try audioEngine.start()
        } catch {
            print("Audio Engine failed to start: \(error)")
        }
    }
    
    private func getCurrentFrequency(forVoice index: Int) -> Double {
        let base = baseFrequencies[index % baseFrequencies.count]
        let dissonanceMultiplier = (isDissonant && index % 2 == 1) ? 1.06 Link // Tritone dissonance interval
        return base * detuneFactor * dissonanceMultiplier
    }
    
    // MARK: - Musical Reaction Handlers
    
    func applyRefactoringProgression() {
        // Shift base chord to a secondary dominant / jazz progression
        let progressions: [[Double]] = [
            [261.63, 329.63, 392.00, 523.25], // Cmaj7
            [220.00, 261.63, 329.63, 392.00], // Am7
            [174.61, 220.00, 261.63, 349.23], // Fmaj7
            [196.00, 246.94, 293.66, 349.23]  // G7
        ]
        baseFrequencies = progressions.randomElement() ?? baseFrequencies
        print("🎼 [Audio] Refactoring: Evolved harmony to frequencies \(baseFrequencies)")
    }
    
    func applyBugFixResolution() {
        isDissonant = false
        // Snap microtonal drift back towards pure pitch
        detuneFactor = max(1.0, detuneFactor - 0.1)
        print("✨ [Audio] Bug Fix: Dissonance resolved. Pitch restored to \(detuneFactor)x")
    }
    
    func applyMemoryLeakMicrotonality() {
        isDissonant = true
        // Incrementally detune system frequencies into microtonal scales
        detuneFactor += 0.035
        print("🌀 [Audio] Memory Leak Detected: Global frequency pitch-bent to \(detuneFactor)x (Microtonal Drift)")
    }
    
    func applyFeatureArpeggio() {
        baseFrequencies = baseFrequencies.map { $0 * 1.1225 } // Shift up a whole step
        print("🚀 [Audio] Feature Added: Key transposed upward.")
    }
}

// MARK: - Live Git Stream Simulator & Parser

final class LiveGitStreamParser {
    private let engine: SymphonyEngine
    private var isRunning = true
    
    init(engine: SymphonyEngine) {
        self.engine = engine
    }
    
    func startMonitoring() {
        print("🎧 Monitoring Git Repository Commits in Real-time...\n")
        
        let mockStream: [Commit] = [
            Commit(id: "a1b2", message: "feat: Implement payment gateway", type: .feature),
            Commit(id: "c3d4", message: "refactor: Extract network layer into modular SPM package", type: .refactoring),
            Commit(id: "e5f6", message: "fix: Retain cycle in UserViewController causing leak", type: .memoryLeak),
            Commit(id: "g7h8", message: "refactor: Clean up state machine and convert to async/await", type: .refactoring),
            Commit(id: "i9j0", message: "fix: Fix memory leak in image caching service", type: .memoryLeak),
            Commit(id: "k1l2", message: "fix: Resolve crash on null pointer dereference", type: .bugFix),
            Commit(id: "m3n4", message: "refactor: Re-architect domain layer with clean architecture", type: .refactoring),
            Commit(id: "o5p6", message: "fix: Deallocate dangling pointers and fix leaks", type: .bugFix)
        ]
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for commit in mockStream {
                guard let self = self, self.isRunning else { break }
                
                print(" Git Commit: [\(commit.id)] \"\(commit.message)\"")
                
                switch commit.type {
                case .refactoring:
                    self.engine.applyRefactoringProgression()
                case .bugFix:
                    self.engine.applyBugFixResolution()
                case .memoryLeak:
                    self.engine.applyMemoryLeakMicrotonality()
                case .feature:
                    self.engine.applyFeatureArpeggio()
                }
                
                print("--------------------------------------------------")
                Thread.sleep(forTimeInterval: 2.5) // Real-time commit interval simulation
            }
            
            print(" Symphonic translation complete.")
            exit(0)
        }
    }
}

// MARK: - Main Script Execution

let symphonyEngine = SymphonyEngine()
let gitParser = LiveGitStreamParser(engine: symphonyEngine)

gitParser.startMonitoring()

// Keep the command-line script running for real-time audio generation
RunLoop.main.run()