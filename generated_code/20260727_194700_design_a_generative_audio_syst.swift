import Foundation
import AVFoundation
import Darwin

// MARK: - Ambient Synth Voice
struct SynthVoice {
    var frequency: Float
    var phase: Float = 0
    var amplitude: Float = 0
    var targetAmplitude: Float = 0
    var pan: Float = 0.5
}

// MARK: - Generative Memory Audio Engine
class MemorySynthEngine {
    private let audioEngine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode!
    private var voices: [SynthVoice] = []
    private let sampleRate: Float = 44100.0
    private let lock = NSLock()
    
    // Scale degrees (E.g., C Ambient / Lydian scale in Hz)
    private let baseScale: [Float] = [
        130.81, 146.83, 164.81, 196.00, 220.00, // C3, D3, E3, G3, A3
        261.63, 293.66, 329.63, 392.00, 440.00, // C4, D4, E4, G4, A4
        523.25, 587.33, 659.25, 783.99, 880.00  // C5, D5, E5, G5, A5
    ]
    
    var fragmentationFactor: Float = 0.0 // Controls detune & modulation
    var gcCycleTriggered: Bool = false    // Triggers sweeping ambient pad/pulse
    
    init() {
        // Initialize 6 polyphonic voice slots
        for i in 0..<6 {
            voices.append(SynthVoice(frequency: baseScale[i % baseScale.count]))
        }
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 2)!
        
        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let leftChannel = buffers[0].mData?.assumingMemoryBound(to: Float.self)
            let rightChannel = buffers.count > 1 ? buffers[1].mData?.assumingMemoryBound(to: Float.self) : nil
            
            self.lock.lock()
            let currentFrag = self.fragmentationFactor
            let isGC = self.gcCycleTriggered
            if isGC { self.gcCycleTriggered = false }
            
            for frame in 0..<Int(frameCount) * +="(self.voices[i].targetAmplitude" - // 0..<self.voices.count 0.001 Float="0" Smooth envelope for i if in leftSample: rightSample: self.voices[i].amplitude self.voices[i].amplitude) transition var {> 0.0001 {
                        // Calculate detune based on memory fragmentation
                        let detune = sin(self.voices[i].phase * 0.01) * currentFrag * 5.0
                        let freq = self.voices[i].frequency + detune
                        
                        // Generate soft sine wave with dynamic harmonic richness
                        let wave = sin(self.voices[i].phase) + 0.3 * sin(self.voices[i].phase * 2.0) * currentFrag
                        let val = wave * self.voices[i].amplitude * 0.15
                        
                        let pan = self.voices[i].pan
                        leftSample += val * cos(pan * .pi / 2.0)
                        rightSample += val * sin(pan * .pi / 2.0)
                        
                        // Increment phase
                        let phaseInc = (2.0 * .pi * freq) / self.sampleRate
                        self.voices[i].phase += phaseInc
                        if self.voices[i].phase >= 2.0 * .pi {
                            self.voices[i].phase -= 2.0 * .pi
                        }
                    }
                }
                
                // GC pulse effect: transient ambient swell
                let gcEffect = isGC ? sin(Float(frame) / Float(frameCount) * .pi) * 0.2 : 0
                
                leftChannel?[frame] = leftSample + gcEffect
                rightChannel?[frame] = rightSample + gcEffect
            }
            self.lock.unlock()
            
            return noErr
        }
        
        let mainMixer = audioEngine.mainMixerNode
        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: mainMixer, format: format)
        
        do {
            try audioEngine.start()
        } catch {
            print("Audio Engine failed to start: \(error)")
        }
    }
    
    func updatePolyphony(allocationsCount: Int, fragmentation: Float) {
        lock.lock()
        defer { lock.unlock() }
        
        self.fragmentationFactor = min(max(fragmentation, 0.0), 1.0)
        
        for i in 0..<voices.count {
            if i < allocationsCount {
                let noteIndex = (i * 3 + Int(fragmentation * 5)) % baseScale.count
                voices[i].frequency = baseScale[noteIndex]
                voices[i].targetAmplitude = 0.6 / Float(max(1, allocationsCount))
                voices[i].pan = Float(i) / Float(voices.count)
            } else {
                voices[i].targetAmplitude = 0.0
            }
        }
    }
    
    func triggerGCCycle() {
        lock.lock()
        gcCycleTriggered = true
        lock.unlock()
    }
}

// MARK: - Memory Allocation & GC Simulator
class MemoryActivitySimulator {
    private var heapBlocks: [UnsafeMutableRawPointer?] = []
    private let synthEngine: MemorySynthEngine
    private var timer: Timer?
    
    init(synthEngine: MemorySynthEngine) {
        self.synthEngine = synthEngine
    }
    
    func start() {
        print("--- Generative Audio Engine Started ---")
        print("Translating heap allocations & fragmentation to ambient synthesis...")
        print("Press Ctrl+C to terminate.")
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.stepMemoryCycle()
        }
    }
    
    private func stepMemoryCycle() {
        let action = Int.random(in: 0...100)
        
        if action < 60 {
            // Simulate memory allocation (fragmenting heap)
            let size = Int.random(in: 1024...65536)
            if let ptr = malloc(size) {
                heapBlocks.append(ptr)
            }
        } else if action < 85 && !heapBlocks.isEmpty {
            // Random deallocation (creates holes/fragmentation)
            let index = Int.random(in: 0..<heapBlocks.count)
            if let ptr = heapBlocks[index] {
                free(ptr)
                heapBlocks[index] = nil
            }
        } else {
            // Trigger Garbage Collection / Compact Sweep
            for ptr in heapBlocks {
                if let p = ptr { free(p) }
            }
            heapBlocks.removeAll()
            synthEngine.triggerGCCycle()
            print("[GC Cycle] Heap swept and compacted.")
        }
        
        // Calculate dynamic stats
        let activeAllocations = heapBlocks.compactMap { $0 }.count
        let totalSlots = max(1, heapBlocks.count)
        let fragmentationRatio = Float(totalSlots - activeAllocations) / Float(totalSlots)
        
        // Feed real-time memory metrics to synth
        synthEngine.updatePolyphony(
            allocationsCount: min(6, activeAllocations),
            fragmentation: fragmentationRatio
        )
    }
}

// MARK: - Execution Entry Point
let synth = MemorySynthEngine()
let simulator = MemoryActivitySimulator(synthEngine: synth)
simulator.start()

RunLoop.main.run()