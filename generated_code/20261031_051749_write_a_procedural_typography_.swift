import Foundation

/// A procedural typography engine that maps simulated ambient thermal fluctuations
/// from a webcam stream into an evolving topological map of ancient city streets
/// interwoven with forgotten folklore fragments.

struct FolkloreEngine {
    let folkloreFragments = [
        "Beneath the cobbled stones of Oakhaven, the silver river still whispers in forgotten tongues.",
        "The North Gate crumbled when the third moon turned the color of dried copper.",
        "Measure not the city by its walls, but by the echoes trapped within its mortar.",
        "Where the weavers gathered, only the ghosts of looms remain, spinning air into memory.",
        "A labyrinth of ash and slate, built to confuse the winter wind and preserve the old songs."
    ]
    
    var temperature: Double = 21.5 // Celsius, modulated by ambient environment
    
    mutating func updateTemperature() {
        // Simulate real-time thermal sensor integration from optical/IR camera feeds
        let fluctuation = (Double.random(in: -0.4...0.4))
        temperature = max(15.0, min(30.0, temperature + fluctuation))
    }
    
    func generateTopography() {
        let width = 64
        let height = 18
        
        print("\n--- THERMAL AMBIENT MAP | TEMP: \(String(format: "%.2f", temperature))°C ---")
        
        for y in 0..<height {
            var line = ""
            for x in 0..<width {
                // Procedural topological generation driven by coordinates and thermal variance
                let val = sin(Double(x) * 0.12 + temperature * 0.2) + cos(Double(y) * 0.15 - temperature * 0.1)
                let char: Character
                if val > 1.2 {
                    char = "█" // Citadel / Ancient Wall
                } else if val > 0.6 {
                    char = "▓" // Residential Quarter
                } else if val > 0.0 {
                    char = "▒" // Market Square
                } else if val > -0.6 {
                    char = "░" // Winding Alleyways
                } else {
                    char = "·" // Forgotten Ruins / Outskirts
                }
                line.append(char)
            }
            print(line)
        }
        
        let index = abs(Int(temperature * 7)) % folkloreFragments.count
        print("\n[FOLKLORE]: \(folkloreFragments[index])\n")
    }
    
    mutating func run(iterations: Int = 3) {
        for _ in 0..<iterations {
            updateTemperature()
            generateTopography()
            Thread.sleep(forTimeInterval: 1.2)
        }
    }
}

// Execute engine
var engine = FolkloreEngine()
engine.run(iterations: 3)