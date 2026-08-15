import SwiftUI
import Combine
import AVFoundation

// MARK: - Core Models

enum ParticleGroup: Int, CaseIterable {
    case crimson = 0, amber, emerald, sapphire, violet
    
    var color: Color {
        switch self {
        case .crimson: return Color(red: 0.95, green: 0.25, blue: 0.35)
        case .amber:   return Color(red: 0.98, green: 0.65, blue: 0.15)
        case .emerald: return Color(red: 0.15, green: 0.85, blue: 0.55)
        case .sapphire:return Color(red: 0.20, green: 0.55, blue: 0.95)
        case .violet:  return Color(red: 0.65, green: 0.35, blue: 0.90)
        }
    }
    
    // Fundamental frequency for generative audio mapping (Hz)
    var baseFrequency: Float {
        switch self {
        case .crimson: return 130.81 // C3
        case .amber:   return 146.83 // D3
        case .emerald: return 164.81 // E3
        case .sapphire:return 196.00 // G3
        case .violet:  return 220.00 // A3
        }
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    var group: ParticleGroup
    var value: Double // Sorting key (0.0 to 1.0)
    var pulse: Double = 0.0
}

// MARK: - Generative Polyrhythmic Audio Engine

final class AmbientAudioEngine {
    private let audioEngine = AVAudioEngine()
    private let sourceNode: AVAudioSourceNode
    private var sampleRate: Double = 44100.0
    
    // Polyphonic oscillator state tracking across 5 groups
    private struct ToneState {
        var phase: Double = 0.0
        var targetVolume: Float = 0.0
        var currentVolume: Float = 0.0
        var frequency: Float = 440.0
    }
    
    private var toneStates = [ParticleGroup: ToneState]()
    private let lock = NSLock()
    
    init() {
        for group in ParticleGroup.allCases {
            toneStates[group] = ToneState(frequency: group.baseFrequency)
        }
        
        let format = audioEngine.mainMixerNode.outputFormat(forBus: 0)
        self.sampleRate = format.sampleRate
        
        let localLock = self.lock
        sourceNode = AVAudioSourceNode { [weak audioEngine] _, _, frameCount, audioBufferList -> OSStatus in
            guard audioEngine != nil else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            localLock.lock()
            defer { localLock.unlock() }
            
            for frame in 0..<Int(frameCount) * +="phaseIncrement" - .pi / // 0.001 Double(state.frequency)) Float="0.0" ParticleGroup.allCases Sine Smooth continue else envelope for group guard if in let mixedSample: overtone phaseIncrement="(2.0" self.sampleRate state="self.toneStates[group]" state.currentVolume state.currentVolume) state.phase subtle synthesis transition var volume warmth wave with { }> 2.0 * .pi { state.phase -= 2.0 * .pi }
                    
                    let fundamental = sin(state.phase)
                    let overtone = sin(state.phase * 2.0) * 0.25
                    let groupSample = Float(fundamental + overtone) * state.currentVolume * 0.12
                    
                    mixedSample += groupSample
                    self.toneStates[group] = state
                }
                
                // Soft limiter clipping protection
                mixedSample = max(-0.8, min(0.8, mixedSample))
                
                for buffer in buffers {
                    let ptr = buffer.mData?.assumingMemoryBound(to: Float.self)
                    ptr?[frame] = mixedSample
                }
            }
            return noErr
        }
        
        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: audioEngine.mainMixerNode, format: format)
        try? audioEngine.start()
    }
    
    func updateSoundscape(sortedRatio: Double, sortingActivity: [ParticleGroup: Float]) {
        lock.lock()
        defer { lock.unlock() }
        for group in ParticleGroup.allCases {
            let activity = sortingActivity[group] ?? 0.0
            // Shift pitch polyrhythmically based on overall ecosystem sorting state
            let scaleMultiplier: Float = 1.0 + Float(group.rawValue) * 0.25 * Float(1.0 - sortedRatio)
            toneStates[group]?.frequency = group.baseFrequency * scaleMultiplier
            toneStates[group]?.targetVolume = activity
        }
    }
}

// MARK: - Ecosystem Engine (Simulation & Custom Sorting)

final class EcosystemViewModel: ObservableObject {
    @Published var particles: [Particle] = []
    @Published var sortedRatio: Double = 0.0
    
    private var bounds: CGSize = .zero
    private var timer: AnyCancellable?
    private let audioEngine = AmbientAudioEngine()
    private var sortingStepIndex = 0
    private var activityMetrics: [ParticleGroup: Float] = [:]
    
    func setup(bounds: CGSize, count: Int = 120) {
        self.bounds = bounds
        var initialParticles: [Particle] = []
        
        for _ in 0..<count {
            let group = ParticleGroup.allCases.randomElement()!
            let val = Double.random(in: 0...1)
            let particle = Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 20...(bounds.width - 20)),
                    y: CGFloat.random(in: 20...(bounds.height - 20))
                ),
                velocity: CGPoint(
                    x: CGFloat.random(in: -1...1),
                    y: CGFloat.random(in: -1...1)
                ),
                group: group,
                value: val
            )
            initialParticles.append(particle)
        }
        
        self.particles = initialParticles
        startSimulation()
    }
    
    private func startSimulation() {
        timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.step()
            }
    }
    
    private func step() {
        guard bounds.width > 0, !particles.isEmpty else { return }
        
        // 1. Fluid Spatial Physics Simulation
        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        for i in 0..<particles.count {
            var p = particles[i]
            
            // Subtle central gravitational force
            let dx = center.x - p.position.x
            let dy = center.y - p.position.y
            p.velocity.x += dx * 0.00005
            p.velocity.y += dy * 0.00005
            
            // Move particle
            p.position.x += p.velocity.x
            p.position.y += p.velocity.y
            
            // Damping
            p.velocity.x *= 0.98
            p.velocity.y *= 0.98
            
            // Screen Boundary Bouncing
            if p.position.x < 15 || p.position.x > bounds.width - 15 { p.velocity.x *= -1 }
            if p.position.y < 15 || p.position.y > bounds.height - 15 { p.velocity.y *= -1 }
            
            // Decaying pulse glow effect
            p.pulse = max(0, p.pulse - 0.03)
            particles[i] = p
        }
        
        // 2. Custom Hybrid Sorting Step (Combining Spatial QuickSort & Bubble Transposition)
        performEcosystemSortStep()
        
        // 3. Fluid Hydrodynamic Target Positioning
        let sectionWidth = bounds.width / CGFloat(ParticleGroup.allCases.count)
        var outOfOrderCount = 0
        var currentActivity: [ParticleGroup: Float] = [:]
        
        for i in 0..<particles.count {
            let targetGroupIndex = Int(particles[i].value * Double(ParticleGroup.allCases.count - 1))
            let targetGroup = ParticleGroup(rawValue: targetGroupIndex) ?? .crimson
            particles[i].group = targetGroup
            
            let targetX = (CGFloat(targetGroupIndex) + 0.5) * sectionWidth
            let distanceToTarget = targetX - particles[i].position.x
            
            // Fluid sorting force directing particles to their color group band
            particles[i].velocity.x += distanceToTarget * 0.003
            
            // Evaluate sorting alignment score
            if abs(distanceToTarget) > sectionWidth * 0.6 {
                outOfOrderCount += 1
                currentActivity[targetGroup, default: 0.0] += 1.0
            }
        }
        
        // Normalize ecosystem entropy score
        let total = Double(particles.count)
        sortedRatio = max(0.0, 1.0 - (Double(outOfOrderCount) / total))
        
        // Normalize soundscape activity metrics per color band
        for group in ParticleGroup.allCases {
            let rawVal = currentActivity[group] ?? 0.0
            activityMetrics[group] = min(1.0, rawVal / (Float(total) / 5.0))
        }
        
        // 4. Update Polyrhythmic Generative Sound Engine
        audioEngine.updateSoundscape(sortedRatio: sortedRatio, sortingActivity: activityMetrics)
    }
    
    private func performEcosystemSortStep() {
        guard particles.count > 1 else { return }
        
        // Interactive spatial exchange sort pass
        let i = sortingStepIndex % particles.count
        let j = (sortingStepIndex + 1) % particles.count
        
        if particles[i].value > particles[j].value && i < j {
            particles.swapAt(i, j)
            particles[i].pulse = 1.0
            particles[j].pulse = 1.0
            
            // Exchange kinetic energy upon sort collision
            let tempV = particles[i].velocity
            particles[i].velocity = particles[j].velocity
            particles[j].velocity = tempV
        }
        
        sortingStepIndex += 1
    }
    
    func disruptEcosystem() {
        // Randomize values to trigger dynamic self-sorting fluid reorganization
        for i in 0..<particles.count {
            particles[i].value = Double.random(in: 0...1)
            particles[i].velocity = CGPoint(
                x: CGFloat.random(in: -8...8),
                y: CGFloat.random(in: -8...8)
            )
            particles[i].pulse = 1.0
        }
    }
}

// MARK: - Fluid Visual Components

struct ParticleView: View {
    let particle: Particle
    
    var body: some View {
        ZStack {
            Circle()
                .fill(particle.group.color)
                .frame(width: 14, height: 14)
                .blur(radius: particle.pulse > 0 ? 3 : 0)
            
            Circle()
                .stroke(Color.white.opacity(0.8), lineWidth: CGFloat(particle.pulse * 3))
                .frame(width: 20, height: 20)
                .scaleEffect(1.0 + CGFloat(particle.pulse * 0.5))
        }
        .position(particle.position)
        .shadow(color: particle.group.color.opacity(0.6), radius: 8)
    }
}

struct EcosystemCanvas: View {
    @ObservedObject var viewModel: EcosystemViewModel
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Background Ambient Fluid Gradient
                LinearGradient(
                    colors: ParticleGroup.allCases.map { $0.color.opacity(0.25) },
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .blur(radius: 40)
                .edgesIgnoringSafeArea(.all)
                
                // Living Particle Ecosystem Layer
                ForEach(viewModel.particles) { particle in
                    ParticleView(particle: particle)
                }
                
                // Overlay HUD Data
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SELF-SORTING FLUID ECOSYSTEM")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            
                            Text("ORGANIZATION: \(Int(viewModel.sortedRatio * 100))%")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                        
                        Button(action: {
                            viewModel.disruptEcosystem()
                        }) {
                            Text("DISRUPT ENTROPY")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().stroke(Color.white.opacity(0.5), lineWidth: 1))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(20)
                    Spacer()
                }
            }
            .onAppear {
                viewModel.setup(bounds: proxy.size)
            }
        }
    }
}

// MARK: - Main Application Entry Point

@main
struct FluidEcosystemApp: App {
    @StateObject private var viewModel = EcosystemViewModel()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                EcosystemCanvas(viewModel: viewModel)
            }
        }
    }
}