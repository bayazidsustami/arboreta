import Foundation

// MARK: - Weather Telemetry Engine
// Simulates continuous live local weather telemetry with smooth variation.
struct WeatherTelemetry {
    var windSpeed: Double      // Knots / MPH (drives simulation tick rates & evolution rules)
    var humidity: Double       // Percentage 0-100% (drives organic flora growth & density)
    var temperature: Double    // Celsius (drives color/tone shifts)
    
    // Smoothly mutates weather metrics over time to simulate a dynamic environment
    mutating func update() {
        windSpeed = max(0.5, min(30.0, windSpeed + Double.random(in: -0.8...0.8)))
        humidity = max(10.0, min(100.0, humidity + Double.random(in: -1.5...1.5)))
        temperature = max(-5.0, min(40.0, temperature + Double.random(in: -0.3...0.3)))
    }
}

// MARK: - ASCII Flora Generator
// Procedurally generates organic text-art flora based on ambient humidity levels.
struct FloraGenerator {
    private static let drySprouts = ["..", "🌱", "🌾", "🌵", "🌿"]
    private static let lushFlora  = ["🌿", "🌸", "🌺", "🍄", "🌳", "🌴", "🪷", "🪸"]
    
    static func renderFlora(humidity: Double, width: Int) -> String {
        let density = Int((humidity / 100.0) * Double(width / 3))
        var line = Array(repeating: " ", count: width)
        
        let pool = humidity > 60.0 ? drySprouts + lushFlora : drySprouts
        
        for _ in 0..<density {
            let index = Int.random(in: 0..<width)
            if let glyph = pool.randomElement() {
                line[index] = glyph
            }
        }
        return line.joined()
    }
}

// MARK: - Wind-Driven Cellular Automata Grid
// Grid evolution where wind speed alters Conway-style neighborhood rules and birth thresholds.
class MicroBiomeGrid {
    let width: Int
    let height: Int
    private var grid: [[Bool]]
    
    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.grid = (0..<height).map { _ in
            (0..<width).map { _ in Double.random(in: 0...1) > 0.65 }
        }
    }
    
    // Advances cellular automata generation influenced by live wind speed
    func step(windSpeed: Double) {
        var newGrid = grid
        // Higher wind speed causes chaotic directional neighborhood shifts
        let windFactor = Int(windSpeed) % 3
        
        for y in 0..<height {
            for x in 0..<width {
                let neighbors = countNeighbors(x: x, y: y, offset: windFactor)
                let isAlive = grid[y][x]
                
                // Wind-driven dynamic survival rules
                if windSpeed > 15.0 {
                    // High wind: chaotic, rapid dispersion
                    newGrid[y][x] = (neighbors == 2 || neighbors == 4)
                } else if windSpeed < 5.0 {
                    // Gentle breeze: stable growth
                    newGrid[y][x] = isAlive ? (neighbors == 2 || neighbors == 3) : (neighbors == 3)
                } else {
                    // Moderate wind: biased propagation
                    newGrid[y][x] = isAlive ? (neighbors >= 2 && neighbors <= 4) : (neighbors == 3 || neighbors == 5)
                }
            }
        }
        grid = newGrid
    }
    
    private func countNeighbors(x: Int, y: Int, offset: Int) -> Int {
        var count = 0
        for dy in -1...1 {
            for dx in -1...1 {
                if dx == 0 && dy == 0 { continue }
                // Incorporate wind offset drift across wrapping edges
                let nx = (x + dx + offset + width) % width
                let ny = (y + dy + height) % height
                if grid[ny][nx] { count += 1 }
            }
        }
        return count
    }
    
    func renderCanvas(telemetry: WeatherTelemetry) -> String {
        let aliveGlyphs = ["░", "▒", "▓", "█", "✳", "✴"]
        let baseGlyph = aliveGlyphs[min(aliveGlyphs.count - 1, Int(telemetry.temperature / 7.0))]
        
        var output = ""
        for row in grid {
            let rowStr = row.map { $0 ? baseGlyph : " " }.joined()
            output += "│ " + rowStr + " │\n"
        }
        return output
    }
}

// MARK: - Main Execution Loop
// Orchestrates continuous ecosystem visualization and real-time terminal rendering.

let gridWidth = 40
let gridHeight = 12
var weather = WeatherTelemetry(windSpeed: 8.5, humidity: 65.0, temperature: 21.0)
let biome = MicroBiomeGrid(width: gridWidth, height: gridHeight)

// Clear terminal canvas
print("\u{001B}[2J\u{001B}[H", terminator: "")

while true {
    weather.update()
    biome.step(windSpeed: weather.windSpeed)
    
    // Return cursor to top-left for smooth continuous redraw
    var render = "\u{001B}[H"
    
    render += "╔" + String(repeating: "═", count: gridWidth + 2) + "╗\n"
    render += "║ 🌐 ATMOSPHERIC TELEMETRY ASCII MICRO-BIOME".padding(toLength: gridWidth + 3, withPad: " ", startingAt: 0) + "║\n"
    render += "╠" + String(repeating: "═", count: gridWidth + 2) + "╣\n"
    
    let stats = String(format: " WIND: %.1f kn | HUMIDITY: %.0f%% | TEMP: %.1f°C", weather.windSpeed, weather.humidity, weather.temperature)
    render += "║" + stats.padding(toLength: gridWidth + 2, withPad: " ", startingAt: 0) + "║\n"
    render += "╠" + String(repeating: "═", count: gridWidth + 2) + "╣\n"
    
    render += biome.renderCanvas(telemetry: weather)
    
    let floraLine = FloraGenerator.renderFlora(humidity: weather.humidity, width: gridWidth)
    render += "╠" + String(repeating: "═", count: gridWidth + 2) + "╣\n"
    render += "│ " + floraLine + " │\n"
    render += "╚" + String(repeating: "═", count: gridWidth + 2) + "╝\n"
    
    print(render)
    
    // Sleep dynamic timing driven by wind velocity (faster wind = faster cycle speed)
    let sleepDuration = max(0.08, 0.4 - (weather.windSpeed * 0.01))
    Thread.sleep(forTimeInterval: sleepDuration)
}