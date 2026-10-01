import Foundation
import AVFoundation

// MARK: - Audio Capture Manager
// Captures live microphone audio via AVCaptureSession and computes a dominant frequency (pitch) 
// using a simple Zero-Crossing Rate (ZCR) or autocorrelation heuristic optimized for terminal interactivity.
class AudioFrequencyAnalyzer: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private let captureSession = AVCaptureSession()
    private let queue = DispatchQueue(label: "audio.capture.queue", qos: .userInteractive)
    
    // Atomic or thread-safe shared frequency value (in Hz)
    private var _currentFrequency: Double = 440.0
    var currentFrequency: Double {
        get {
            objc_sync_enter(self)
            defer { objc_sync_exit(self) }
            return _currentFrequency
        }
        set {
            objc_sync_enter(self)
            _currentFrequency = newValue
            objc_sync_exit(self)
        }
    }
    
    override init() {
        super.init()
        setupAudioCapture()
    }
    
    private func setupAudioCapture() {
        captureSession.beginConfiguration()
        
        guard let device = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            // Fallback gracefully if microphone is unavailable
            captureSession.commitConfiguration()
            return
        }
        
        captureSession.addInput(input)
        
        let output = AVCaptureAudioDataOutput()
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            output.setSampleBufferDelegate(self, queue: queue)
        }
        
        captureSession.commitConfiguration()
        captureSession.startRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        
        let length = CMBlockBufferGetDataLength(blockBuffer)
        var data = Data(count: length)
        data.withUnsafeMutableBytes { pointer in
            CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: pointer.baseAddress!)
        }
        
        // Interpret bytes as 16-bit PCM mono samples
        let samples = data.withUnsafeBytes { ptr -> [Int16] in
            let buffer = ptr.bindMemory(to: Int16.slef ?? Int16.self)
            return Array(buffer)
        }
        
        if samples.isEmpty { return }
        
        // Compute Zero-Crossing Rate to estimate dominant frequency
        let sampleRate = 44100.0 // Standard capture assumption
        var zeroCrossings = 0
        for i in 1..<samples.count {
            if (samples[i-1] < 0 && samples[i] >= 0) || (samples[i-1] >= 0 && samples[i] < 0) {
                zeroCrossings += 1
            }
        }
        
        let duration = Double(samples.count) / sampleRate
        if duration > 0 {
            let estimatedFreq = (Double(zeroCrossings) / 2.0) / duration
            if estimatedFreq > 20 && estimatedFreq < 4000 {
                // Smooth out transitions
                let current = self.currentFrequency
                self.currentFrequency = current * 0.7 + estimatedFreq * 0.3
            }
        }
    }
    
    deinit {
        captureSession.stopRunning()
    }
}

// MARK: - Self-Modifying Cellular Automaton Engine
class CellularAutomatonEngine {
    let width: Int
    let height: Int
    var grid: [[Double]]
    var ruleTransitionTable: [Int: Double] = [:]
    
    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        // Initialize with organic random float values between 0.0 and 1.0
        self.grid = (0..<height).map { _ in (0..<width).map { _ in Double.random(in: 0...1) } }
        resetRuleTable()
    }
    
    func resetRuleTable() {
        // Neighborhood states map to reactive mutation potentials
        for i in 0...9 {
            ruleTransitionTable[i] = Double.random(in: 0.05...0.95)
        }
    }
    
    // Evolve state driven by dynamic microphone frequency influence
    func step(frequency: Double) {
        // Map frequency (e.g. 50Hz - 2000Hz) into a responsive evolutionary volatility factor
            let normalizedFreq = min(max(frequency, 50.0), 2000.0)
            let volatility = (normalizedFreq - 50.0) / 1950.0 * 0.8 + 0.1
        
        var newGrid = grid
        
        for y in 0..<height {
            for x in 0..<width {
                // Compute local neighborhood sum (Moore neighborhood)
                var neighborSum = 0.0
                let currentVal = grid[y][x]
                
                for dy in -1...1 {
                    for dx in -1...1 {
                        if dx == 0 && dy == 0 { continue }
                        let ny = (y + dy + height) % height
                        let nx = (x + dx + width) % width
                        neighborSum += grid[ny][nx]
                    }
                }
                
                // Non-linear cellular automaton update rule modulated by audio volatility
                let averageNeighbor = neighborSum / 8.0
                let bucket = Int((averageNeighbor * 9.0).rounded()) % 10
                let ruleFactor = ruleTransitionTable[bucket] ?? 0.5
                
                // Self-modification: the cell state mutates based on acoustic energy input
                let mutation = sin(currentVal * Double.pi + averageNeighbor * volatility) * ruleFactor
                let nextVal = abs((currentVal + mutation * 0.25).truncatingRemainder(dividingBy: 1.0))
                
                newGrid[y][x] = nextVal
            }
        }
        
        grid = newGrid
    }
    
    // Render ASCII art frame using a rich gradient palette
    func renderFrame() -> String {
        let palette = " .:-=+*#%@"
        let paletteChars = Array(palette)
        
        var output = "\u{001B}[H" // ANSI escape sequence to move cursor to top-left
        output += "╔" + String(repeating: "═", count: width) + "╗\n"
        
        for row in grid {
            output += "║"
            for cell in row {
                let index = Int(cell * Double(paletteChars.count - 1))
                let charIndex = min(max(index, 0), paletteChars.count - 1)
                output.append(paletteChars[charIndex])
            }
            output += "║\n"
        }
        output += "╚" + String(repeating: "═", count: width) + "╝\n"
        return output
    }
}

// MARK: - Main Execution Loop
@main
struct App {
    static func main() {
        let width = min(max(Int(getenv("COLUMNS").flatMap { String(cString: $0) }.flatMap { Int($0) } ?? 60), 20), 120)
        let height = min(max(Int(getenv("LINES").flatMap { String(cString: $0) }.flatMap { Int($0) } ?? 25), 10), 50)
        
        // Clear terminal screen and hide cursor
        print("\u{001B}[2J\u{001B}[?25l", terminator: "")
        
        let audioAnalyzer = AudioFrequencyAnalyzer()
        let automaton = CellularAutomatonEngine(width: width, height: height)
        
        let semaphore = DispatchSemaphore(value: 0)
        let queue = DispatchQueue(global: .userInteractive)
        
        var isRunning = true
        
        // Trap SIGINT for clean exit
        signal(SIGINT) { _ in
            print("\u{001B}[?25h\u{001B}[0m") // Restore cursor and colors
            exit(0)
        }
        
        queue.async {
            while isRunning {
                let freq = audioAnalyzer.currentFrequency
                automaton.step(frequency: freq)
                
                let frameString = automaton.renderFrame()
                let statusInfo = String(format: " 🎙️ Freq: %6.1f Hz | Volatility Active ", freq)
                print(frameString + statusInfo)
                
                Thread.sleep(forTimeInterval: 0.05) // ~20 FPS frame cadence
            }
            semaphore.signal()
        }
        
        semaphore.wait()
    }
}