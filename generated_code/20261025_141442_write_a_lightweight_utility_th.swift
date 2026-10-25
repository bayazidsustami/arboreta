#!/usr/bin/env swift

import Foundation

// Thermal Ink Blot Visualizer
// Simulates and translates real-time CPU thermal fluctuations into 
// an evolving, organic ASCII art score of dancing ink blots.

let width = 64
let height = 24
let palette = " .·:=+*#%@"

var temperature: Double = 45.0
var time: Double = 0.0

// Hide cursor and clear screen for smooth rendering
print("\u{001B}[?25l", terminator: "")
defer { print("\u{001B}[?25h") }

// Handle graceful exit on Ctrl+C
signal(SIGINT) { _ in
    print("\u{001B}[?25h\u{001B}[0E")
    exit(0)
}

while true {
    // Simulate dynamic CPU thermal behavior (workload spikes + cooling)
    let workload = (sin(time * 0.8) + cos(time * 1.5) + sin(time * 0.3) * 0.5) * 18.0
    let jitter = Double.random(in: -1.5...1.5)
    let targetTemp = 55.0 + workload + jitter
    temperature += (targetTemp - temperature) * 0.25
    
    // Build frame buffer
    var frame = "\u{001B}[H"
    let tempStr = String(format: "%.1f", temperature)
    let barLength = Int(max(0, min(20, (temperature - 40.0) / 2.5)))
    let thermalBar = String(repeating: "█", count: barLength) + String(repeating: "░", count: max(0, 20 - barLength))
    
    frame += "🔥 CPU THERMAL SCORE: [\(thermalBar)] \(tempStr)°C\n"
    frame += String(repeating: "─", count: width) + "\n"
    
    let intensity = (temperature - 35.0) / 45.0
    
    for y in 0..<height {
        let fy = (Double(y) / Double(height)) * 3.0 - 1.5
        for x in 0..<width {
            let fx = (Double(x) / Double(width)) * 3.0 - 1.5
            
            // Organic ink blot equation using multi-frequency interference
            let r = sqrt(fx * fx + fy * fy)
            let wave1 = sin(r * 4.0 - time * 2.0)
            let wave2 = cos(fx * intensity * 3.0 + time)
            let wave3 = sin(fy * 3.0 - time * 1.5)
            
            let combined = (wave1 + wave2 + wave3 + 3.0) / 6.0
            let adjusted = pow(combined, 1.2) * intensity
            
            let index = Int(adjusted * Double(palette.count - 1))
            let clampedIndex = max(0, min(palette.count - 1, index))
            
            let charIndex = palette.index(palette.startIndex, offsetBy: clampedIndex)
            frame.append(palette[charIndex])
        }
        frame.append("\n")
    }
    
    print(frame, terminator: "")
    fflush(stdout)
    
    usleep(65_000) // ~15 frames per second
    time += 0.12
}