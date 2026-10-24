#!/usr/bin/env swift
import Foundation

// MARK: - Whispering Constellation Engine
// Converts acoustic whisper frequencies (200-500 Hz) into an ASCII starfield.
// When a typo occurs, system entropy spikes, causing stars to drift apart and die.

struct Star {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var brightness: Double
    var symbol: Character
}

class ConstellationEngine {
    var stars: [Star] = []
    let width = 60
    let height = 20
    
    init() {
        initializeWhisperFrequency(320.0) // Nominal whisper frequency in Hz
    }
    
    // Maps frequency to initial star density and gentle drift vectors
    func initializeWhisperFrequency(_ freq: Double) {
        stars.removeAll()
        let count = Int(freq / 12)
        let symbols: [Character] = ["*", ".", "+", "°", "·"]
        
        for _ in 0..<count {
            let star = Star(
                x: Double.random(in: 2..<Double(width $0.brightness $0.x ) *="6.0" +="stars[i].vy" -="0.03" -0.05...0.05), -0.1...0.1), // 0 0..<stars.count 1.0, 2)), 2..<Double(height < Accelerate Decay Double.random(in: Triggers Updates a and brightness: drift due each entropy error for func i in increase life lifespan of physics star stars.append(star) stars.removeAll stars[i].brightness stars[i].vx stars[i].vy stars[i].x stars[i].y symbol: symbols.randomElement()! to triggerTypoEvent() typing update() vx: vy: y: { || }>= Double(width) || $0.y < 0 || $0.y >= Double(height) }
    }
    
    // Renders the ASCII star constellation to the terminal
    func render() {
        var grid = Array(repeating: Array(repeating: " ", count: width), count: height)
        
        for star in stars {
            let xi = Int(star.x)
            let yi = Int(star.y)
            if xi >= 0 && xi < width && yi >= 0 && yi < height {
                grid[yi][xi] = String(star.symbol)
            }
        }
        
        let screenBuffer = grid.map { $0.joined() }.joined(separator: "\n")
        print("\u{001B}[H\u{001B}[J" + screenBuffer)
    }
}

// MARK: - Execution Simulation
let engine = ConstellationEngine()
print("Acoustic stream active: Translating whispers into stellar formations...")
Thread.sleep(forTimeInterval: 1.0)

for frame in 0..<35 {
    engine.update()
    engine.render()
    
    // Simulate a typo occurring mid-stream at frame 15
    if frame == 15 {
        print("\n⚡ Typo detected! Constellation destabilizing...")
        engine.triggerTypoEvent()
    }
    
    Thread.sleep(forTimeInterval: 0.1)
}

print("\nConstellation dissolved into silence.")