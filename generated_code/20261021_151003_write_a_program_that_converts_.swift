#!/usr/bin/env swift

import Foundation

// MARK: - Atmospheric & L-System Engine

struct AtmosphericData {
    let humidity: Double // 0.0 to 100.0
    let temperature: Double
}

class LSystemPoetryVisualizer {
    private var rules: [Character: String] = [:]
    private var currentHumidity: Double = 50.0
    
    // Mapping L-system tokens to organic poetic vocabulary
    let poeticDictionary: [Character: [String]] = [
        "F": ["blooms", "reaches", "unfurls", "whispers", "drifts", "awakens", "breathes"],
        "+": ["gently", "softly", "wildly", "deeply"],
        "-": ["quietly", "silently", "boldly"],
        "[": ["(root:", "(into the mist:"],
        "]": [")", ")"],
        "X": ["essence", "breath", "pulse", "rain", "dew"]
    ]

    // Dynamically update rewriting rules based on atmospheric humidity
    func updateRules(basedOn humidity: Double) {
        currentHumidity = humidity
        if humidity > 75.0 {
            // High humidity creates dense, lush branching structures
            rules = [
                "F": "FF+[+F-F-F]-[-F+F+F]",
                "X": "F-[X]+X"
            ]
        } else if humidity > 40.0 {
            // Moderate humidity yields balanced growth
            rules = [
                "F": "F[+F]F[-F]F",
                "X": "X+F"
            ]
        } else {
            // Low humidity results in sparse, minimalist structure
            rules = [
                "F": "FF",
                "X": "F"
            ]
        }
    }

    // Rewrite the L-system string for the current generation
    func evolve(_ current: String) -> String {
        var next = ""
        for char in current {
            if let replacement = rules[char] {
                next += replacement
            } else {
                next.append(char)
            }
        }
        return next
    }

    // Translate the structural L-system string into flowing poetry
    func translateToPoetry(from lsystemString: String) -> String {
        var lines: [String] = []
        var currentLine = ""
        
        for char in lsystemString {
            if let options = poeticDictionary[char], let word = options.randomElement() {
                currentLine += word + " "
                if currentLine.count > 45 {
                    lines.append(currentLine)
                    currentLine = ""
                }
            }
        }
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        return lines.joined(separator: "\n  ↳ ")
    }
}

// MARK: - Terminal Simulation Execution

print("\u{001B}[2J\u{001B}[H")
print("🌿 Initializing Real-Time Atmospheric Poetry Engine...")

let visualizer = LSystemPoetryVisualizer()
var currentString = "X"
var simulatedHumidity = 60.0

// Simulate real-time atmospheric data stream across 5 generational ticks
for step in 1...5 {
    // Introduce organic fluctuation to humidity
    simulatedHumidity = max(15.0, min(98.0, simulatedHumidity + Double.random(in: -20.0...25.0)))
    
    visualizer.updateRules(basedOn: simulatedHumidity)
    currentString = visualizer.evolve(currentString)
    
    // Render Terminal UI with ANSI Color Codes
    print("\n\u{001B}[32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\u{001B}[0m")
    print("🌍 Atmospheric Sensor | Humidity: \(String(format: "%.1f", simulatedHumidity))% | Generation: \(step)")
    print("\u{001B}[32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\u{001B}[0m")
    
    let poem = visualizer.translateToPoetry(from: currentString)
    print("\n✨ Organic Fractal Bloom:\n  \(poem)\n")
    
    sleep(1)
}

print("🌱 Bloom cycle complete. Atmospheric equilibrium reached.\n")