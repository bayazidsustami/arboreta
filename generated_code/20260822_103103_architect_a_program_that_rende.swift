import Foundation

// MARK: - Models & Data Structures

struct HourlyForecast {
    let hour: String
    let temperature: Int      // Degrees Fahrenheit
    let windSpeed: Int        // MPH
    let precipitation: Double // Probability 0.0 - 1.0
}

struct PoetryStanza {
    let lines: [String]
}

// MARK: - Weather Data Generator

class WeatherEngine {
    // Generates a mock 24-hour weather forecast sequence
    static func fetchForecast() -> [HourlyForecast] {
        let hours = (0..<24).map { String(format: "%02d:00", $0) }
        
        return hours.map { time in
            let hourInt = Int(time.prefix(2))!
            // Temperature cycle mimicking daily curve (colder at night, warmer at mid-day)
            let temp = Int(65.0 + 15.0 * sin(Double(hourInt - 8) * .pi / 12.0))
            // Wind speed variation
            let wind = Int(8.0 + 7.0 * cos(Double(hourInt) * .pi / 6.0))
            // Rain probability centered around late afternoon
            let precip = max(0.0, sin(Double(hourInt - 12) * .pi / 8.0))
            
            return HourlyForecast(hour: time, temperature: temp, windSpeed: wind, precipitation: precip)
        }
    }
}

// MARK: - Weather Poetry Generator

class CloudPoet {
    private static let stanzas = [
        PoetryStanza(lines: ["Whispers of grey", "Gather overhead,", "Soft liquid steps."]),
        PoetryStanza(lines: ["Cold vapor weaves", "Through mountain pass,", "Drenching the stone."]),
        PoetryStanza(lines: ["Sky drops its load", "In steady rhythm,", "Rivers awaken."]),
        PoetryStanza(lines: ["Mist clings to peak,", "Silver tears falling,", "Earth drinks it in."])
    ]
    
    static func generateStanza(for probability: Double) -> PoetryStanza? {
        guard probability > 0.3 else { return nil }
        let index = Int(probability * 10) % stanzas.count
        return stanzas[index]
    }
}

// MARK: - ASCII Topology Renderer

class TopologyRenderer {
    private let height: Int = 18
    private let width: Int = 80
    
    func renderFrame(forecasts: [HourlyForecast], offset: Int) {
        var canvas = Array(repeating: Array(repeating: " ", count: width), count: height)
        
        // 1. Compute terrain profile (Mountain heights = Temp, Steepness = Wind)
        var terrainHeights = [Int]()
        for x in 0..<width {
            let dataIdx = (x + offset) % forecasts.count
            let fc = forecasts[dataIdx]
            
            // Temperature maps directly to mountain height (scale 50°F..85°F -> 2..14 rows)
            let baseHeight = Int(Double(fc.temperature - 50) / 35.0 * 12.0) + 2
            
            // Wind speed adds steep jaggedness modulation
            let windJitter = Int(sin(Double(x) * Double(fc.windSpeed) * 0.1) * 2.0)
            let finalHeight = max(1, min(height - 3, baseHeight + windJitter))
            
            terrainHeights.append(finalHeight)
        }
        
        // 2. Draw Terrain
        for x in 0..<width {
            let h = terrainHeights[x]
            let prevH = x > 0 ? terrainHeights[x - 1] : h
            let diff = h - prevH
            
            for y in 0..<h {
                let row = height - 1 - y
                if y == h - 1 {
                    // Pick surface glyph based on local steepness (wind speed impact)
                    if diff > 1 { canvas[row][x] = "/" }
                    else if diff < -1 { canvas[row][x] = "\\" }
                    else { canvas[row][x] = "^" }
                } else {
                    // Internal mountain texture
                    canvas[row][x] = (y % 2 == 0) ? "#" : ":"
                }
            }
        }
        
        // 3. Render Rain Clouds & Poetry Stanzas
        let currentFC = forecasts[offset % forecasts.count]
        if let stanza = CloudPoet.generateStanza(for: currentFC.precipitation) {
            let cloudRow = 1
            let cloudStartCol = 15
            
            // Render Cloud outline
            let cloudText = "(  ☁️  PRECIPITATION CLOUD  ☁️  )"
            for (i, char) in cloudText.enumerated() {
                if cloudStartCol + i < width - 5 {
                    canvas[cloudRow][cloudStartCol + i] = String(char)
                }
            }
            
            // Embed Poetry Stanza inside/under cloud
            for (lineIdx, line) in stanza.lines.enumerated() {
                let lineRow = cloudRow + 1 + lineIdx
                let formattedLine = "│  " + line.padding(toLength: 22, withPad: " ", startingAt: 0) + "│"
                for (charIdx, char) in formattedLine.enumerated() {
                    if cloudStartCol + charIdx < width - 2 {
                        canvas[lineRow][cloudStartCol + charIdx] = String(char)
                    }
                }
            }
            
            // Rain droplets falling from cloud to terrain
            for x in (cloudStartCol)..<(cloudStartCol + 26) {
                let terrainTop = height - 1 - terrainHeights[x]
                for r in (cloudRow + 5)..<terrainTop {
                    if (r + x + offset) % 3 == 0 {
                        canvas[r][x] = "💧"
                    }
                }
            }
        }
        
        // 4. Render Overlay Dashboard (Header & Telemetry)
        let headerText = " TOPOLOGICAL WEATHER MAP | TIME: \(currentFC.hour) | TEMP: \(currentFC.temperature)°F | WIND: \(currentFC.windSpeed)MPH "
        for (i, char) in headerText.enumerated() {
            if i < width { canvas[0][i] = String(char) }
        }
        
        // Output frame to console
        print("\u{001B}[2J\u{001B}[1;1H") // Clear screen terminal control
        for row in canvas {
            print(row.joined())
        }
    }
}

// MARK: - Main Execution Loop

let forecasts = WeatherEngine.fetchForecast()
let renderer = TopologyRenderer()
var tick = 0

// Run continuous real-time animation loop
while true {
    renderer.renderFrame(forecasts: forecasts, offset: tick)
    tick += 1
    Thread.sleep(forTimeInterval: 0.3)
}