import AppKit
import AVFoundation
import Foundation

// MARK: - CPU Thermal & Performance Monitor
final class ThermalMonitor {
    // Reads thermal pressure and simulates micro-fluctuations based on CPU work cycles
    func fetchThermalEnergy() -> Double {
        let thermalState = ProcessInfo.processInfo.thermalState
        let baseEnergy: Double
        switch thermalState {
        case .nominal:  baseEnergy = 0.25
        case .fair:     baseEnergy = 0.50
        case .serious:  baseEnergy = 0.75
        case .critical: baseEnergy = 1.00
        @unknown default: baseEnergy = 0.30
        }
        
        // Sample micro-fluctuations using execution jitter
        let t0 = CFAbsoluteTimeGetCurrent()
        var dummy = 0.0
        for i in 1...2000 { dummy += sin(Double(i)) }
        let elapsed = CFAbsoluteTimeGetCurrent() - t0
        
        let jitter = min(elapsed * 10000.0, 0.2)
        return min(max(baseEnergy + jitter + Double.random(in: -0.05...0.05), 0.05), 1.0)
    }
}

// MARK: - Polyphonic Acoustic Synthesizer
final class PolyphonicResonator {
    private let audioEngine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var phase: [Double] = Array(repeating: 0.0, count: 6)
    private var frequencies: [Double] = Array(repeating: 220.0, count: 6)
    private var amplitudes: [Double] = Array(repeating: 0.0, count: 6)
    private let lock = NSLock()
    
    init() {
        let mainMixer = audioEngine.mainMixerNode
        let format = mainMixer.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        
        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let numChannels = abl.count
            
            self.lock.lock()
            let currentFreqs = self.frequencies
            let currentAmps = self.amplitudes
            self.lock.unlock()
            
            for frame in 0..<Int(frameCount) * +="phaseIncrement" .pi / 0..<currentFreqs.count currentFreqs[i]) for i if in let phaseIncrement="(2.0" sample="0.0" sampleRate self.phase[i] var {>= 2.0 * .pi { self.phase[i] -= 2.0 * .pi }
                    
                    // Resonant harmonic generation with soft saturation
                    let voiceSample = sin(self.phase[i]) + 0.3 * sin(2.0 * self.phase[i])
                    sample += voiceSample * currentAmps[i]
                }
                
                let outputSample = Float(tanh(sample * 0.4)) // Soft clipping
                for channel in 0..<numChannels {
                    let buffer = abl[channel]
                    let pointer = buffer.mData?.assumingMemoryBound(to: Float.self)
                    pointer?[frame] = outputSample
                }
            }
            return noErr
        }
        
        if let node = sourceNode {
            audioEngine.attach(node)
            audioEngine.connect(node, to: mainMixer, format: format)
            try? audioEngine.start()
        }
    }
    
    func updateResonance(harmonics: [Double], thermalEnergy: Double) {
        lock.lock()
        defer { lock.unlock() }
        let pentatonicScale = [130.81, 146.83, 164.81, 196.00, 220.00, 261.63, 293.66, 329.63, 392.00, 440.00, 523.25, 659.25]
        
        for i in 0..<min(harmonics.count, frequencies.count) {
            let scaleIndex = Int(harmonics[i] * Double(pentatonicScale.count - 1))
            let baseFreq = pentatonicScale[min(max(scaleIndex, 0), pentatonicScale.count - 1)]
            let detune = (thermalEnergy - 0.5) * 12.0 // Microtonal shift driven by heat
            
            frequencies[i] = baseFreq * pow(2.0, detune / 1200.0)
            amplitudes[i] = (harmonics[i] * 0.15) * (0.5 + thermalEnergy * 0.5)
        }
    }
}

// MARK: - Esoteric Thermal Cellular Automata
final class ThermalAutomataView: NSView {
    var width = 64
    var height = 64
    private var grid: [[Double]]
    private var nextGrid: [[Double]]
    private let monitor = ThermalMonitor()
    private let resonator = PolyphonicResonator()
    private var timer: Timer?
    private var currentThermal: Double = 0.25
    
    override init(frame frameRect: NSRect) {
        grid = Array(repeating: Array(repeating: 0.0, count: height), count: width)
        nextGrid = grid
        super.init(frame: frameRect)
        
        // Seed grid with initial seeds
        for _ in 0..<200 {
            let rx = Int.random(in: 0..<width)
            let ry = Int.random(in: 0..<height)
            grid[rx][ry] = Double.random(in: 0.5...1.0)
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.stepAutomata()
        }
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) unfulfilled") }
    
    private func stepAutomata() {
        currentThermal = monitor.fetchThermalEnergy()
        
        var sectorHarmonics = Array(repeating: 0.0, count: 6)
        let sectorWidth = width / 6
        
        // CA Evolution powered by continuous thermal decay and excitation
        for x in 0..<width {
            for y in 0..<height {
                var sum = 0.0
                for dx in -1...1 {
                    for dy in -1...1 {
                        if dx == 0 && dy == 0 { continue }
                        let nx = (x + dx + width) % width
                        let ny = (y + dy + height) % height
                        sum += grid[nx][ny]
                    }
                }
                
                let avg = sum / 8.0
                let current = grid[x][y]
                
                // Esoteric rule set: Thermal energy acts as a chaotic diffusion coefficient
                if avg > 0.2 && avg < (0.5 + currentThermal * 0.3) {
                    nextGrid[x][y] = min(current + avg * 0.4 + currentThermal * 0.1, 1.0)
                } else {
                    nextGrid[x][y] = max(current - (0.15 / max(currentThermal, 0.01)), 0.0)
                }
                
                // Inject thermal noise at center
                if x == width / 2 && y == height / 2 && Double.random(in: 0...1) < currentThermal {
                    nextGrid[x][y] = currentThermal
                }
                
                let sIdx = min(x / sectorWidth, 5)
                sectorHarmonics[sIdx] += nextGrid[x][y]
            }
        }
        
        grid = nextGrid
        
        // Normalize harmonics for acoustic synthesis
        let maxEnergy = Double(sectorWidth * height)
        let normalizedHarmonics = sectorHarmonics.map { min($0 / maxEnergy, 1.0) }
        resonator.updateResonance(harmonics: normalizedHarmonics, thermalEnergy: currentThermal)
        
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let cellW = bounds.width / CGFloat(width)
        let cellH = bounds.height / CGFloat(height)
        
        context.setFillColor(CGColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1.0))
        context.fill(bounds)
        
        for x in 0..<width {
            for y in 0..<height {
                let val = grid[x][y]
                if val > 0.01 {
                    // Thermal chromatic translation: Cold (Blue/Purple) -> Hot (Orange/Crimson)
                    let r = CGFloat(min(val * (0.5 + currentThermal * 1.5), 1.0))
                    let g = CGFloat(min(pow(val, 2.0) * currentThermal, 0.8))
                    let b = CGFloat(min((1.0 - val) * 0.8 + currentThermal * 0.2, 1.0))
                    let alpha = CGFloat(min(val + 0.2, 1.0))
                    
                    context.setFillColor(CGColor(red: r, green: g, blue: b, alpha: alpha))
                    let rect = CGRect(x: CGFloat(x) * cellW, y: CGFloat(y) * cellH, width: cellW - 0.5, height: cellH - 0.5)
                    context.fill(rect)
                }
            }
        }
    }
}

// MARK: - App Architecture & Lifecycle
final class InterpreterAppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let windowMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 700),
            styleMask: windowMask,
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Thermal Resonance Automata Interpreter"
        window.backgroundColor = .black
        
        let caView = ThermalAutomataView(frame: window.contentView!.bounds)
        caView.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(caView)
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// Entry Point
let app = NSApplication.shared
let delegate = InterpreterAppDelegate()
app.delegate = delegate
app.run()