import Foundation
import CoreGraphics

// MARK: - Models & Protocols

/// Represents the emotional state of the stream
struct EmotionalValence {
    let intensity: Double // 0.0 to 1.0
    let hueShift: CGFloat // How much it nudges the color palette
    let complexity: Double // Affects the fractal iteration depth
}

/// A simulated stream of tweets to satisfy the "live stream" requirement in a runnable environment
protocol TweetStream {
    func nextTweet() -> EmotionalValence
}

class MockTwitterStream: TweetStream {
    func nextTweet() -> EmotionalValence {
        // Simulate organic fluctuations in sentiment
        let sentiment = Double.random(in: 0...1)
        let hue = CGFloat.random(in: 0...1)
        return EmotionalValence(
            intensity: sentiment,
            hueShift: hue,
            complexity: 0.5 + (sentiment * 0.5)
        )
    }
}

// MARK: - The Mandelbrot Garden Engine

/// An engine that renders a Mandelbrot set where the "growth" is influenced by sentiment
class MandelbrotGarden {
    let width: Int
    let height: Int
    var currentValence: EmotionalValence = EmotionalValence(intensity: 0.5, hueShift: 0.0, complexity: 0.5)
    
    init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
    
    func updateSentiment(_ valence: EmotionalValence) {
        self.currentValence = valence
    }
    
    /// Generates a procedural tapestry (a 2D array of colors)
    func render() -> [[CGColor]] {
        var canvas = Array(repeating: Array(repeating: CGColor(red: 0, green: 0, blue: 0, alpha: 1), count: width), count: height)
        
        let maxIterations = Int(10 + (currentValence.complexity * 40))
        let zoom = 1.5
        
        for y in 0..<height {
            for x in 0..<width {
                // Map pixel to complex plane
                let cx = (Double(x) / Double(width) - 0.5) * zoom
                let cy = (Double(y) / Double(height) - 0.5) * zoom
                
                var zx = 0.0
                var zy = 0.0
                var iteration = 0
                
                while zx*zx + zy*zy <= 4.0 && iteration < maxIterations {
                    let xtemp = zx*zx - zy*zy + cx
                    zy = 2.0*zx*zy + cy
                    zx = xtemp
                    iteration += 1
                }
                
                if iteration < maxIterations {
                    // Calculate color based on iteration and emotional hue shift
                    let t = CGFloat(iteration) / CGFloat(maxIterations)
                    let hue = (t + currentValence.hueShift).truncatingRemainder(dividingBy: 1.0)
                    let saturation = CGFloat(0.4 + (currentValence.intensity * 0.6))
                    let brightness = CGFloat(0.5 + (currentValence.intensity * 0.5))
                    
                    canvas[y][x] = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(),
                                           components: [hue, saturation, brightness, 1.0])
                }
            }
        }
        return canvas
    }
}

// MARK: - The Decoder (LED Matrix Logic)

/// Simulates the hardware-level requirement: Displaying in reverse on a scrolling LED matrix
class LEDMatrixDecoder {
    let columns: Int
    let rows: Int
    
    init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
    }
    
    /// Decodes the tapestry by flipping it horizontally and vertically (reversing the scanline)
    /// and simulating a scroll effect.
    func decodeAndDisplay(tapestry: [[CGColor]]) {
        print("\n--- [ LED MATRIX OUTPUT: DECODING SIGNAL ] ---")
        
        // The "Reversal" logic: To decode the procedural tapestry, we must read it 
        // from the bottom-right to the top-left (reverse scanning).
        for y in stride(from: tapestry.count - 1, through: 0, by: -1) {
            var line = ""
            for x in stride(from: tapestry[y].count - 1, through: 0, by: -1) {
                // We represent color intensity via ASCII characters for the console simulation
                let color = tapestry[y][x]
                let components = color.components ?? [0,0,0,0]
                let brightness = components[1] + components[2] // Green + Blue intensity
                
                if brightness > 0.7 { line += "█" }
                else if brightness > 0.4 { line += "▓" }
                else if brightness > 0.1 { line += "▒" }
                else { line += " " }
            }
            print(line)
        }
        print("--- [ END SIGNAL ] ---\n")
    }
}

// MARK: - Main Execution Loop

class ProgramController {
    let garden: MandelbrotGarden
    let stream: TweetStream
    let decoder: LEDMatrixDecoder
    var frameCount = 0
    
    init() {
        // Small resolution for terminal-based visual simulation
        self.garden = MandelbrotGarden(width: 40, height: 20)
        self.stream = MockTwitterStream()
        self.decoder = LEDMatrixDecoder(columns: 40, rows: 20)
    }
    
    func run(iterations: Int) {
        print("Initializing Sentiment-Fractal Fusion...")
        print("Observing Twitter streams and generating Mandelbrot garden...")
        
        for _ in 0..<iterations {
            // 1. Fetch live sentiment
            let newSentiment = stream.nextTweet()
            
            // 2. Update the garden's parameters
            garden.updateSentiment(newSentiment)
            
            // 3. Generate the procedural tapestry
            let tapestry = garden.render()
            
            // 4. Decode through the LED Matrix (Reversed view)
            decoder.decodeAndDisplay(tapestry: tapestry)
            
            // Artificial delay to simulate real-time stream
            Thread.sleep(forTimeInterval: 0.8)
            frameCount += 1
        }
        
        print("Stream terminated. Tapestry archived.")
    }
}

// Entry Point
let controller = ProgramController()
controller.run(iterations: 10)