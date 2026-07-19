import Foundation
import AVFoundation

// MARK: - Cellular Automaton Engine

/// A lightweight implementation of Conway's Game of Life.
class CellularAutomaton {
    let width: Int
    let height: Int
    var grid: [[Bool]]
    
    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.grid = Array(repeating: Array(repeating: false, count: height), count: width)
        seedGliders()
    }
    
    /// Seeds the grid with gliders and random noise to spark collisions.
    private func seedGliders() {
        // Standard 5-pixel glider shape
        let glider = [(0, 1), (1, 2), (2, 0), (2, 1), (2, 2)]
        
        // Spawn a few gliders on collision courses
        for offset in [(2, 2), (10, 5), (18, 2)] {
            for pt in glider {
                let x = (offset.0 + pt.0) % width
                let y = (offset.1 + pt.1) % height
                grid[x][y] = true
            }
        }
        
        // Add minimal ambient noise
        for _ in 0..<40 {
            grid[Int.random(in: 0..<width)][Int.random(in: 0..<height)] = true
        }
    }
    
    /// Steps the simulation forward and returns a structural hash to track harmony state.
    func step() -> (activePixels: Int, collisionHash: Int) {
        var nextGrid = grid
        var activeCount = 0
        var hash = 0
        
        for x in 0..<width {
            for y in 0..<height {
                let neighbors = countNeighbors(x: x, y: y)
                if grid[x][y] {
                    nextGrid[x][y] = neighbors == 2 || neighbors == 3
                } else {
                    nextGrid[x][y] = neighbors == 3
                }
                
                if nextGrid[x][y] {
                    activeCount += 1
                    // XOR-based spatial hash to capture structural transformations (e.g., collisions)
                    hash ^= (x * 13 + y * 37)
                }
            }
        }
        
        grid = nextGrid
        return (activeCount, hash)
    }
    
    private func countNeighbors(x: Int, y: Int) -> Int {
        var count = 0
        for dx in -1...1 {
            for dy in -1...1 {
                if dx == 0 && dy == 0 { continue }
                let nx = (x + dx + width) % width
                let ny = (y + dy + height) % height
                if grid[nx][ny] { count += 1 }
            }
        }
        return count
    }
}

// MARK: - Ambient Audio Synthesizer

/// Procedural audio generator mapping grid states to evolving harmonies.
class CellAudioSynthesizer {
    private let audioEngine = AVAudioEngine()
    private let srcNode: AVAudioSourceNode
    private let sampleRate: Double = 44100.0
    
    // Synthesis state variables
    private var time: Double = 0.0
    private var baseFrequency: Double = 220.0 // A3
    private var targetFrequency: Double = 220.0
    private var currentIntervalRatio: Double = 1.0
    private var lowpassCutoff: Float = 800.0
    
    // Pentatonic scale multipliers for harmonious shifts
    private let scaleIntervals = [1.0, 1.125, 1.25, 1.5, 1.667, 2.0]
    
    init() {
        // Set up raw PCM buffer source node
        self.srcNode = AVAudioSourceNode { [weak self] (_, _, frameCount, audioBufferList) -> OSStatus in
            guard let self = self else { return noErr }
            
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) * + - .pi // 0.0005 0.15 0.4 2.0 Exponential Mix Prevent UnsafeMutableBufferPointer<Float ablPointer buf: buffer clipping currentFreq="self.baseFrequency" currentFreq) drone for frequency glide in let mixedSample="Float(sample" sample="sin(self.time" seamless self.baseFrequency self.baseFrequency) self.currentIntervalRatio sub-octave subSample="sin(self.time" subSample) subtle target toward transitions warmth {> = UnsafeMutableBufferPointer(buffer)
                    buf[frame] = mixedSample
                }
                
                self.time += 1.0 / self.sampleRate
            }
            return noErr
        }
        
        setupGraph()
    }
    
    private func setupGraph() {
        let lowpass = AVAudioUnitEQ(numberofBands: 1)
        lowpass.bands[0].filterType = .lowPass
        lowpass.bands[0].frequency = lowpassCutoff
        lowpass.bands[0].bypass = false
        
        let delay = AVAudioUnitDelay()
        delay.delayTime = 0.4
        delay.feedback = 60.0
        delay.wetDryMix = 40.0
        
        audioEngine.attach(srcNode)
        audioEngine.attach(lowpass)
        audioEngine.attach(delay)
        
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        audioEngine.connect(srcNode, to: lowpass, format: format)
        audioEngine.connect(lowpass, to: delay, format: format)
        audioEngine.connect(delay, to: audioEngine.outputNode, format: format)
    }
    
    func start() {
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine error: \(error)")
        }
    }
    
    /// Modulates sound properties dynamically based on simulation metrics.
    func modulate(density: Int, structuralHash: Int) {
        // Map grid cell density directly to the base pitch
        let normalizedDensity = Double(density % 200)
        self.targetFrequency = 110.0 + normalizedDensity // Dynamic drift
        
        // Trigger structural harmonic jumps on glider interactions/collisions
        let intervalIndex = abs(structuralHash) % scaleIntervals.count
        self.currentIntervalRatio = scaleIntervals[intervalIndex]
    }
}

// MARK: - Simulation Orchestration

print("Initializing Cellular Automaton Ambient Synthesizer...")
let automaton = CellularAutomaton(width: 32, height: 24)
let synth = CellAudioSynthesizer()

synth.start()
print("Soundscape active. Simulating cellular universe... Press Ctrl+C to terminate.")

// Infinite execution block updating at a visual frame rate interval (~10Hz)
let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
    let (density, structuralHash) = automaton.step()
    synth.modulate(density: density, structuralHash: structuralHash)
}

RunLoop.current.run()