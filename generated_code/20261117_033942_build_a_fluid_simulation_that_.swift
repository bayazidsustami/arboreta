#!/usr/bin/swift
import Foundation

// A Swift script that programmatically generates a self-contained HTML file.
// It creates a fluid simulation running purely within the CSS box-shadow 
// properties of a single HTML element to visualize the ethereal passage of a dream.

func generateDreamSimulationHTML() -> Int {
    let particleCount = 150
    var shadows: [String] = []
    
    let canvasWidth = 400.0
    let canvasHeight = 400.0
    
    // Calculate complex layered box-shadows using mathematical curves to simulate fluid flow
    for i in 0..<particleCount {
        let t = Double(i) * (2.0 * Double.pi / Double(particleCount))
        
        // Parametric equations for a dreamy vortex / fluid swirl
        let xOffset = 100.0 * sin(t * 1.5) + 50.0 * cos(t * 0.5)
        let yOffset = 100.0 * cos(t * 1.2) + 50.0 * sin(t * 2.0)
        
        let x = Int(canvasWidth / 2.0 + xOffset)
        let y = Int(canvasHeight / 2.0 + yOffset)
        
        let blur = Int(8 + 12 * abs(sin(t)))
        let spread = Int(1 + 4 * abs(cos(t)))
        
        // Ethereal dream palette using HSLA with shifting hues and alpha transparency
        let hue = Int((Double(i) / Double(particleCount)) * 240.0 + 180.0) % 360
        let lightness = 55 + Int(20 * sin(t))
        let alpha = 0.5 + 0.5 * sin(t * 3.0)
        
        let color = "hsla(\(hue), 85%, \(lightness)%, \(String(format: "%.2f", alpha)))"
        shadows.append("\(x)px \(y)px \(blur)px \(spread)px \(color)")
    }
    
    let shadowString = shadows.joined(separator: ",\n")
    
    let htmlContent = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Passage of a Dream - CSS Box-Shadow Fluid Simulation</title>
        <style>
            body {
                margin: 0;
                height: 100vh;
                background: radial-gradient(circle at center, #0f0c29, #302b63, #24243e);
                display: flex;
                justify-content: center;
                align-items: center;
                overflow: hidden;
            }
            
            /* The single HTML element driving the entire fluid simulation via box-shadow */
            #dream-element {
                position: relative;
                width: 400px;
                height: 400px;
                border-radius: 50%;
                background: rgba(255, 255, 255, 0.02);
                box-shadow: 
                \(shadowString);
                animation: fluidSwirl 18s ease-in-out infinite alternate, 
                           dreamMorph 25s linear infinite,
                           luminescence 8s ease-in-out infinite alternate;
                backdrop-filter: blur(1px);
            }
            
            @keyframes fluidSwirl {
                0% {
                    transform: scale(0.7) rotate(0deg);
                }
                50% {
                    transform: scale(1.2) rotate(190deg);
                }
                100% {
                    transform: scale(0.9) rotate(360deg);
                }
            }
            
            @keyframes dreamMorph {
                0%, 100% {
                    border-radius: 60% 40% 70% 30% / 50% 60% 40% 50%;
                }
                33% {
                    border-radius: 40% 60% 30% 70% / 60% 40% 70% 30%;
                }
                66% {
                    border-radius: 50% 50% 60% 40% / 40% 50% 50% 60%;
                }
            }
            
            @keyframes luminescence {
                0% {
                    filter: hue-rotate(0deg) brightness(0.9);
                }
                100% {
                    filter: hue-rotate(60deg) brightness(1.3);
                }
            }
        </style>
    </head>
    <body>
        <div id="dream-element"></div>
    </body>
    </html>
    """
    
    let filePath = "dream_fluid_simulation.html"
    do {
        try htmlContent.write(toFile: filePath, atomically: true, encoding: .utf8)
        print("Success! Dream simulation written to \(filePath)")
        return 0
    } catch {
        print("Error writing file: \(error)")
        return 1
    }
}

exit(Int32(generateDreamSimulationHTML()))