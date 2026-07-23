import AppKit
import AVFoundation
import CoreGraphics
import QuartzCore

// MARK: - Memory Heap Simulator & Data Models

struct MemoryBlock {
    var address: UInt64
    var size: Int
    var isAllocated: Bool
    var age: Double
}

class HeapTracker {
    static let shared = HeapTracker()
    var blocks: [MemoryBlock] = []
    let totalSize: Int = 1024 * 1024 // 1MB simulated heap
    var fragmentationIndex: Float = 0.0
    var onGarbageCollection: ((Int) -> Void)?
    
    init() {
        resetHeap()
    }
    
    func resetHeap() {
        blocks = [MemoryBlock(address: 0, size: totalSize, isAllocated: false, age: 0)]
    }
    
    func stepSimulation() {
        // Randomly allocate or deallocate memory to model runtime activity
        if Double.random(in: 0...1) > 0.3 {
            let allocSize = Int.random(in: 1024...32768)
            allocate(size: allocSize)
        } else {
            deallocateRandom()
        }
        
        // Trigger GC when fragmentation or block count exceeds threshold
        if fragmentationIndex > 0.65 || blocks.count > 150 {
            triggerGC()
        }
        
        calculateFragmentation()
    }
    
    private func allocate(size: Int) {
        for i in 0..<blocks.count {
            if !blocks[i].isAllocated && blocks[i].size >= size {
                let current = blocks[i]
                let allocated = MemoryBlock(address: current.address, size: size, isAllocated: true, age: 0)
                blocks[i] = allocated
                
                let remaining = current.size - size
                if remaining > 0 {
                    let freeBlock = MemoryBlock(address: current.address + UInt64(size), size: remaining, isAllocated: false, age: 0)
                    blocks.insert(freeBlock, at: i + 1)
                }
                break
            }
        }
    }
    
    private func deallocateRandom() {
        let allocatedIndices = blocks.enumerated().compactMap { $1.isAllocated ? $0 : nil }
        guard let randomIndex = allocatedIndices.randomElement() else { return }
        blocks[randomIndex].isAllocated = false
    }
    
    private func triggerGC() {
        var reclaimed = 0
        var newBlocks: [MemoryBlock] = []
        for block in blocks {
            if block.isAllocated && Double.random(in: 0...1) < 0.4 {
                reclaimed += block.size
                var freed = block
                freed.isAllocated = false
                newBlocks.append(freed)
            } else {
                newBlocks.append(block)
            }
        }
        
        // Coalesce adjacent unallocated memory blocks
        var compacted: [MemoryBlock] = []
        for block in newBlocks {
            if let last = compacted.last, !last.isAllocated && !block.isAllocated {
                compacted[compacted.count - 1].size += block.size
            } else {
                compacted.append(block)
            }
        }
        self.blocks = compacted
        onGarbageCollection?(reclaimed)
    }
    
    private func calculateFragmentation() {
        let freeBlocks = blocks.filter { !$0.isAllocated }
        guard !freeBlocks.isEmpty else { fragmentationIndex = 0; return }
        let maxFree = freeBlocks.map { $0.size }.max() ?? 0
        let totalFree = freeBlocks.reduce(0) { $0 + $1.size }
        if totalFree == 0 { fragmentationIndex = 0; return }
        fragmentationIndex = 1.0 - (Float(maxFree) / Float(totalFree))
    }
}

// MARK: - Generative DarkSynth Audio Engine

class DarkSynthEngine {
    private let audioEngine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode!
    private var filter: AVAudioUnitLowPassFilter!
    private var reverb: AVAudioUnitReverb!
    
    private var phase1: Double = 0
    private var phase2: Double = 0
    private var baseFreq: Double = 55.0 // A1 Root
    private var currentFreq: Double = 55.0
    private var targetFreq: Double = 55.0
    private var gcTriggerIntensity: Double = 0.0
    
    // Minor pentatonic darksynth scale intervals
    private let scaleIntervals: [Double] = [1.0, 1.189, 1.334, 1.498, 1.781, 2.0]
    
    init() {
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        let mainMixer = audioEngine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate
        
        filter = AVAudioUnitLowPassFilter()
        filter.cutoffFrequency = 400.0
        filter.resonance = 5.0
        
        reverb = AVAudioUnitReverb()
        reverb.loadFactoryPreset(.largeHall)
        reverb.wetDryMix = 60.0
        
        sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let phaseIncrement1 = (2.0 * .pi * self.currentFreq) / sampleRate
            let phaseIncrement2 = (2.0 * .pi * (self.currentFreq * 1.006)) / sampleRate // Detune offset
            
            for frame in 0..<Int(frameCount) * +="phaseIncrement2" - 0.0005 if self.currentFreq self.currentFreq) self.phase1 self.phase2 {> 2.0 * .pi { self.phase1 -= 2.0 * .pi }
                if self.phase2 > 2.0 * .pi { self.phase2 -= 2.0 * .pi }
                
                // Aggressive darksynth waveform generation
                let saw1 = 1.0 - (self.phase1 / .pi)
                let saw2 = 1.0 - (self.phase2 / .pi)
                let pulse = (sin(self.phase1 * 0.5) > 0) ? 0.3 : -0.3
                
                // Sub-bass GC trigger burst
                let subGCOsc = sin(self.phase1 * 0.5) * self.gcTriggerIntensity
                self.gcTriggerIntensity *= 0.99995
                
                let sampleVal = Float((saw1 * 0.4 + saw2 * 0.3 + pulse * 0.2 + subGCOsc * 0.5) * 0.2)
                
                for buffer in ablPointer {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    buf[frame] = sampleVal
                }
            }
            return noErr
        }
        
        audioEngine.attach(sourceNode)
        audioEngine.attach(filter)
        audioEngine.attach(reverb)
        
        audioEngine.connect(sourceNode, to: filter, format: outputFormat)
        audioEngine.connect(filter, to: reverb, format: outputFormat)
        audioEngine.connect(reverb, to: mainMixer, format: outputFormat)
        
        try? audioEngine.start()
    }
    
    func updateHarmony(fragmentation: Float) {
        filter.cutoffFrequency = 200.0 + (fragmentation * 2800.0)
        filter.resonance = 2.0 + (fragmentation * 12.0)
        
        let intervalIndex = Int(fragmentation * Float(scaleIntervals.count - 1))
        let interval = scaleIntervals[min(intervalIndex, scaleIntervals.count - 1)]
        targetFreq = baseFreq * interval
    }
    
    func triggerGCHarmony(reclaimedBytes: Int) {
        gcTriggerIntensity = 1.5
        let octaveShift = [0.5, 1.0, 2.0, 4.0].randomElement() ?? 1.0
        let newInterval = scaleIntervals.randomElement() ?? 1.0
        targetFreq = baseFreq * newInterval * octaveShift
    }
}

// MARK: - Visualizer View

class NebulaVisualizerView: NSView {
    private var timer: Timer?
    private let synth = DarkSynthEngine()
    private var angle: CGFloat = 0.0
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupEngine()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupEngine()
    }
    
    private func setupEngine() {
        HeapTracker.shared.onGarbageCollection = { [weak self] reclaimed in
            self?.synth.triggerGCHarmony(reclaimedBytes: reclaimed)
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            HeapTracker.shared.stepSimulation()
            self?.synth.updateHarmony(fragmentation: HeapTracker.shared.fragmentationIndex)
            self?.angle += 0.015
            self?.needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        // Deep space background
        ctx.setFillColor(CGColor(red: 0.02, green: 0.01, blue: 0.05, alpha: 1.0))
        ctx.fill(bounds)
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let maxRadius = min(bounds.width, bounds.height) * 0.45
        let tracker = HeapTracker.shared
        let frag = CGFloat(tracker.fragmentationIndex)
        
        // Render heap memory blocks as rotating cosmic nebula particles
        for (i, block) in tracker.blocks.enumerated() {
            let progress = CGFloat(i) / CGFloat(max(1, tracker.blocks.count))
            let theta = progress * .pi * 2.0 * 3.0 + angle
            let radiusOffset = sin(CGFloat(i) * 0.3 + angle * 2.0) * (frag * 60.0)
            let distance = (progress * maxRadius) + radiusOffset
            
            let x = center.x + cos(theta) * distance
            let y = center.y + sin(theta) * distance
            
            let size = max(3.0, CGFloat(block.size) / 2048.0)
            
            if block.isAllocated {
                let red = 0.4 + frag * 0.6
                let green = 0.2 + (1.0 - frag) * 0.5
                let blue = 0.8 + sin(progress * .pi) * 0.2
                
                ctx.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 0.75))
                ctx.addEllipse(in: CGRect(x: x - size/2, y: y - size/2, width: size, height: size))
                ctx.fillPath()
            } else {
                let ringSize = size * (1.0 + frag * 1.5)
                ctx.setStrokeColor(CGColor(red: 0.9, green: 0.1, blue: 0.4, alpha: 0.4))
                ctx.setLineWidth(1.2)
                ctx.addEllipse(in: CGRect(x: x - ringSize/2, y: y - ringSize/2, width: ringSize, height: ringSize))
                ctx.strokePath()
            }
        }
        
        // Central fragmentation glow
        let coreRadius = 40.0 + (frag * 50.0)
        let gradientColors = [
            CGColor(red: 0.9, green: 0.2, blue: 0.6, alpha: 0.8),
            CGColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 0.0)
        ] as CFArray
        
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors, locations: [0.0, 1.0]) {
            ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: coreRadius, options: .drawsAfterEndLocation)
        }
    }
}

// MARK: - App Delegate

class VisualizerAppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let frame = NSRect(x: 0, y: 0, width: 900, height: 700)
        
        window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Heap Nebula Synthesizer // Generative DarkSynth"
        window.center()
        
        let visualizerView = NebulaVisualizerView(frame: frame)
        visualizerView.autoresizingMask = [.width, .height]
        
        window.contentView = visualizerView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

let app = NSApplication.shared
let delegate = VisualizerAppDelegate()
app.delegate = delegate
app.run()