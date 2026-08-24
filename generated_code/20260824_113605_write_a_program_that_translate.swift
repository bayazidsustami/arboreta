import Foundation

// ANSI Terminal Colors & Styling
struct ANSI {
    static let reset = "\u{001B}[0m"
    static let clearScreen = "\u{001B}[2J\u{001B}[H"
    static let hideCursor = "\u{001B}[?25l"
    static let showCursor = "\u{001B}[?25h"
    
    // 24-bit TrueColor RGB String Generator
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> String {
        return "\u{001B}[38;2;\(r);\(g);\(b)m"
    }
}

// Data models for USGS GeoJSON Feed
struct EarthquakeResponse: Codable {
    let features: [Feature]
}

struct Feature: Codable {
    let properties: Properties
}

struct Properties: Codable {
    let mag: Double?
    let place: String?
    let time: Double?
}

// Global state holding current seismic parameters
struct SeismicState {
    var magnitude: Double = 1.0  // Drives wave amplitude & color dynamic
    var count: Int = 0           // Drives density of knit patterns
    var location: String = "Monitoring Global Activity..."
    var lastUpdated: Date = Date()
}

// Knitted ASCII Texture Generator using Harmonic Waves
class DigitalKnitTapestry {
    private var state = SeismicState()
    private var step: Double = 0.0
    private let width = 80
    
    // Character glyph sets mapped to weave density
    private let knitGlyphs: [[Character]] = [
        ["·", " ", "`", "."],
        ["╱", "╲", "╳", "│"],
        ["█", "▓", "▒", "░"],
        ["𓍢", "𓍣", "𓍤", "𓍥"], // Intricate knot symbols (fallback to text-safe symbols if unsupported)
        ["#", "W", "M", "@"]
    ]
    
    func updateSeismicData(_ newState: SeismicState) {
        self.state = newState
    }
    
    // Maps magnitude to vibrant RGB palettes (Blue/Green -> Yellow -> Deep Violet/Crimson)
    private func paletteColor(intensity: Double, phase: Double) -> String {
        let normalized = min(max(intensity / 7.0, 0.0), 1.0)
        
        let r = Int((sin(phase) * 0.5 + 0.5) * 255 * normalized + (1 - normalized) * 30)
        let g = Int((cos(phase * 1.3) * 0.5 + 0.5) * 200 * (1 - normalized) + normalized * 40)
        let b = Int((sin(phase * 0.7 + 1.5) * 0.5 + 0.5) * 255 * (1 - normalized) + normalized * 180)
        
        return ANSI.rgb(r, g, b)
    }
    
    // Generates a single woven row of the infinite tapestry
    func renderRow() -> String {
        step += 0.15 + (state.magnitude * 0.05)
        var rowString = ""
        
        let densityIndex = min(Int(state.magnitude), knitGlyphs.count - 1)
        let glyphSet = knitGlyphs[densityIndex]
        
        for x in 0..<width {
            let xNorm = Double(x) / Double(width) * .pi * 4.0
            
            // Complex wave superposition representing seismic propagation
            let wave1 = sin(xNorm + step) * state.magnitude
            let wave2 = cos(xNorm * 2.1 - step * 1.2) * (state.magnitude * 0.5)
            let wave3 = sin(step * 0.8) * 2.0
            
            let combinedWave = abs(wave1 + wave2 + wave3)
            
            // Choose character based on weave tension and position
            let charIndex = Int(combinedWave.truncatingRemainder(dividingBy: Double(glyphSet.count)))
            let symbol = glyphSet[abs(charIndex) % glyphSet.count]
            
            // Color phase derived from local coordinate and quake magnitude
            let colorPhase = step + Double(x) * 0.08
            let color = paletteColor(intensity: state.magnitude, phase: colorPhase)
            
            rowString += "\(color)\(symbol)"
        }
        
        return rowString + ANSI.reset
    }
    
    func renderHeader() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        let timeStr = formatter.string(from: state.lastUpdated)
        let info = " SEISMIC KNIT | Mag: \(String(format: "%.1f", state.magnitude)) | Loc: \(state.location.prefix(30)) | Sync: \(timeStr) "
        let padded = info.centerPadded(toLength: width, withPad: "═")
        return "\(ANSI.rgb(255, 255, 255))\(padded)\(ANSI.reset)"
    }
}

extension String {
    func centerPadded(toLength length: Int, withPad pad: String) -> String {
        guard count < length else { return String(prefix(length)) }
        let totalPad = length - count
        let leftPad = totalPad / 2
        let rightPad = totalPad - leftPad
        return String(repeating: pad, count: leftPad) + self + String(repeating: pad, count: rightPad)
    }
}

// Background Seismic Monitor fetching real-time USGS GeoJSON feed
class SeismicFetcher {
    private let feedURL = URL(string: "[https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson](https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson)")!
    
    func fetchLatestActivity(completion: @escaping (SeismicState) -> Void) {
        let task = URLSession.shared.dataTask(with: feedURL) { data, _, error in
            guard let data = data, error == nil else { return }
            do {
                let decoded = try JSONDecoder().decode(EarthquakeResponse.self, from: data)
                let features = decoded.features
                
                // Find strongest quake in past hour, or default to ambient Earth hum
                if let maxQuake = features.compactMap({ $0.properties }).max(by: { ($0.mag ?? 0) < ($1.mag ?? 0) }) {
                    let state = SeismicState(
                        magnitude: max(maxQuake.mag ?? 1.0, 0.5),
                        count: features.count,
                        location: maxQuake.place ?? "Unknown Location",
                        lastUpdated: Date()
                    )
                    completion(state)
                }
            } catch {
                // Silently fallback on parse errors to maintain continuous generation
            }
        }
        task.resume()
    }
}

// Initialization & Signal Handling
print(ANSI.hideCursor)
print(ANSI.clearScreen)

let tapestry = DigitalKnitTapestry()
let fetcher = SeismicFetcher()

// Set up signal handler for clean graceful exit (restores terminal cursor)
signal(SIGINT) { _ in
    print(ANSI.showCursor + "\n")
    exit(0)
}

// Network Polling Loop (Every 30 Seconds)
let timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
    fetcher.fetchLatestActivity { newState in
        tapestry.updateSeismicData(newState)
    }
}
// Initial Fetch
fetcher.fetchLatestActivity { newState in
    tapestry.updateSeismicData(newState)
}

// Main Infinite Visual Tapestry Weaving Loop
RunLoop.current.add(timer, forMode: .default)

var lineCount = 0
while true {
    // Periodically print updated status banner
    if lineCount % 20 == 0 {
        print(tapestry.renderHeader())
    }
    
    print(tapestry.renderRow())
    
    // Frame Delay (Pacing the infinite stream)
    usleep(60000) // ~16 FPS
    
    // Process async networking events on main run loop
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.001))
    lineCount += 1
}