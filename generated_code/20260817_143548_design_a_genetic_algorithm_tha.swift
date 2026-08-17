import Foundation

// MARK: - Core Models & Types

typealias SoundFrequency = Double

struct Organism: CustomStringConvertible {
    var dna: [SoundFrequency] // DNA expressed as audio frequencies in Hz (e.g., 20Hz - 2000Hz)
    var energy: Double        // Bioluminescence intensity / viability [0.0, 1.0]
    var generation: Int
    
    init(dna: [SoundFrequency], generation: Int = 0) {
        self.dna = dna
        self.generation = generation
        self.energy = 1.0
    }
    
    // Random organism initializer
    static func random(dnaLength: Int = 16) -> Organism {
        let freqs = (0..<dnaLength).map { _ in Double.random(in: 40.0...1200.0) }
        return Organism(dna: freqs)
    }
    
    // Fitness function: Evaluates harmony, frequency balance, and acoustic resonance
    var fitness: Double {
        guard !dna.isEmpty else { return 0.0 }
        
        // 1. Harmonics score: Proximity of adjacent intervals to pleasant ratios (3:2 fifth, 4:3 fourth, 5:4 major third)
        var harmonicScore = 0.0
        let harmonicRatios = [1.5, 1.333, 1.25, 2.0]
        for i in 0..<(dna.count - 1) {
            let ratio = max(dna[i], dna[i+1]) / max(1.0, min(dna[i], dna[i+1]))
            if let bestMatch = harmonicRatios.min(by: { abs($0 - ratio) < abs($1 - ratio) }) {
                let diff = abs(bestMatch - ratio)
                harmonicScore += max(0, 1.0 - diff)
            }
        }
        harmonicScore /= Double(dna.count - 1)
        
        // 2. Frequency variance: Prevents monotonic stagnation
        let meanFreq = dna.reduce(0, +) / Double(dna.count)
        let variance = dna.map { pow($0 - meanFreq, 2) }.reduce(0, +) / Double(dna.count)
        let balanceScore = min(1.0, sqrt(variance) / 300.0)
        
        return (harmonicScore * 0.7) + (balanceScore * 0.3)
    }
    
    // ASCII Phenotype rendering based on frequency spectrum and current energy (decay)
    var description: String {
        let asciiLuminance = [" ", ".", "·", "°", ":", "o", "*", "*", "#", "@", "█"]
        let baseGlow = ["~", "≈", "∞", "░", "▒", "▓"]
        
        var render = ""
        for (idx, freq) in dna.enumerated() {
            // Map frequency to pitch-based character representation
            let normalizedFreq = (freq - 40.0) / (1200.0 - 40.0)
            let charIndex = Int(clamp(normalizedFreq, min: 0.0, max: 1.0) * Double(asciiLuminance.count - 1))
            
            // Apply decay dampening from organism's current energy state
            let effectiveEnergy = energy * (1.0 - (Double(idx) * 0.02))
            if effectiveEnergy < 0.15 {
                render += " "
            } else if effectiveEnergy < 0.45 {
                let glowIdx = Int(Double(baseGlow.count - 1) * effectiveEnergy)
                render += baseGlow[clamp(glowIdx, min: 0, max: baseGlow.count - 1)]
            } else {
                render += asciiLuminance[charIndex]
            }
        }
        
        let energyPercent = Int(energy * 100)
        let fitScore = String(format: "%.2f", fitness)
        return "Gen \(String(format: "%2d", generation)) [\(render)] Lum: \(String(format: "%3d", energyPercent))% | Fit: \(fitScore)"
    }
}

// Utility clamp function
func clamp<T: Comparable>(_ value: T, min minValue: T, max maxValue: T) -> T {
    return Swift.max(minValue, Swift.min(maxValue, value))
}

// MARK: - Genetic Algorithm Engine

class BioluminescentEcosystem {
    var population: [Organism]
    let populationSize: Int
    let mutationRate: Double
    let decayRate: Double
    var currentGeneration: Int = 0
    
    init(populationSize: Int = 12, mutationRate: Double = 0.15, decayRate: Double = 0.08) {
        self.populationSize = populationSize
        self.mutationRate = mutationRate
        self.decayRate = decayRate
        self.population = (0..<populationSize).map { _ in Organism.random() }
    }
    
    // Crossover sound wave frequencies using uniform interpolation (acoustic synthesis)
    func crossover(parentA: Organism, parentB: Organism) -> Organism {
        var childDNA = [SoundFrequency]()
        for i in 0..<parentA.dna.count {
            let blend = Double.random(in: 0.0...1.0)
            let freq = (parentA.dna[i] * blend) + (parentB.dna[i] * (1.0 - blend))
            childDNA.append(freq)
        }
        return Organism(dna: childDNA, generation: currentGeneration + 1)
    }
    
    // Mutate sound wave DNA (pitch shifts, harmonics, and detuning)
    func mutate(organism: inout Organism) {
        for i in 0..<organism.dna.count {
            if Double.random(in: 0.0...1.0) < mutationRate {
                let shiftType = Int.random(in: 0...2)
                switch shiftType {
                case 0: // Octave shift (harmonic double/half)
                    organism.dna[i] *= Bool.random() ? 2.0 : 0.5
                case 1: // Microtonal pitch bend
                    organism.dna[i] += Double.random(in: -25.0...25.0)
                default: // Complete frequency mutation
                    organism.dna[i] = Double.random(in: 40.0...1200.0)
                }
                organism.dna[i] = clamp(organism.dna[i], min: 40.0, max: 1200.0)
            }
        }
    }
    
    // Advance generation through natural selection, breeding, and evolutionary decay
    func step() {
        currentGeneration += 1
        
        // 1. Evolutionary Decay: Organisms lose energy/bioluminescence over time
        for i in 0..<population.count {
            let decayFactor = decayRate * (1.5 - population[i].fitness) // Lower fitness decays faster
            population[i].energy = max(0.0, population[i].energy - decayFactor)
        }
        
        // Filter out completely decayed/dead organisms
        let survivors = population.filter { $0.energy > 0.05 }
        
        // 2. Selection: Sort by fitness
        let sortedPool = (survivors.isEmpty ? population : survivors).sorted { $0.fitness > $1.fitness }
        
        // 3. Reproduction: Breed top performers to replenish population
        var nextGen = [Organism]()
        
        // Elitism: Preserve best organism with restored vitality
        if var elite = sortedPool.first {
            elite.energy = min(1.0, elite.energy + 0.3) // Re-energize slightly through adaptation
            nextGen.append(elite)
        }
        
        while nextGen.count < populationSize {
            let parentA = selectParent(from: sortedPool)
            let parentB = selectParent(from: sortedPool)
            var child = crossover(parentA: parentA, parentB: parentB)
            mutate(organism: &child)
            nextGen.append(child)
        }
        
        population = nextGen
    }
    
    private func selectParent(from pool: [Organism]) -> Organism {
        // Tournament selection
        let k = 3
        var best: Organism?
        for _ in 0..<k {
            if let candidate = pool.randomElement() {
                if best == nil || candidate.fitness > best!.fitness {
                    best = candidate
                }
            }
        }
        return best ?? pool.randomElement()!
    }
}

// MARK: - Simulation Execution & ASCII Visualizer

func clearScreen() {
    print("\u{001B}[2J\u{001B}[H", terminator: "")
}

let ecosystem = BioluminescentEcosystem(populationSize: 10, mutationRate: 0.20, decayRate: 0.06)

print("--- Starting Bioluminescent Frequency Evolution Simulation ---")
Thread.sleep(forTimeInterval: 1.0)

for iteration in 1...60 {
    clearScreen()
    print("==========================================================================")
    print("  PROCEDURAL BIOLUMINESCENT ORGANISMS (ACOUSTIC DNA SELECTION)  ")
    print("==========================================================================")
    print("  Frame: \(iteration) | Active Generation: \(ecosystem.currentGeneration)")
    print("  Phenotype: Sound Frequencies [40Hz-1200Hz] mapped to Luminescent ASCII")
    print("--------------------------------------------------------------------------\n")
    
    // Sort for display
    let displayPopulation = ecosystem.population.sorted { $0.fitness > $1.fitness }
    for organism in displayPopulation {
        print("  \(organism)")
    }
    
    // Find average fitness and primary dominant pitch
    let avgFit = displayPopulation.map { $0.fitness }.reduce(0, +) / Double(displayPopulation.count)
    let dominantFreq = displayPopulation.first?.dna.reduce(0, +) ?? 0.0 / Double(displayPopulation.first?.dna.count ?? 1)
    
    print("\n--------------------------------------------------------------------------")
    print("  Ecosystem Metrics -> Avg Fitness: \(String(format: "%.3f", avgFit)) | Dominant Pitch: \(String(format: "%.1f", dominantFreq)) Hz")
    print("==========================================================================")
    
    ecosystem.step()
    Thread.sleep(forTimeInterval: 0.25)
}

print("\nSimulation Complete. Final dominant organism genetic sequence preserved.")