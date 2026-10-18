#!/usr/bin/swift

import Foundation

// Seismic Weaver: Translates real-time USGS earthquake data into an ASCII textile pattern.
// Tectonic shifts alter the weaving rhythm and thread density.

struct EarthquakeFeature: Codable {
    struct Properties: Codable {
        let mag: Double?
        let place: String?
    }
    let properties: Properties
}

struct EarthquakeResponse: Codable {
    let features: [EarthquakeFeature]
}

// Fetch live global seismic activity from USGS
func fetchSeismicActivity() -> (density: Int, rhythm: Int, summary: String) {
    let urlString = "[https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson](https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson)"
    guard let url = URL(string: urlString),
          let data = try? Data(contentsOf: url),
          let response = try? JSONDecoder().decode(EarthquakeResponse.self, from: data) else {
        // Fallback baseline resonance if offline
        return (density: 4, rhythm: 2, summary: "Offline baseline resonance")
    }
    
    let magnitudes = response.features.compactMap { $0.properties.mag }
    let avgMag = magnitudes.isEmpty ? 1.0 : magnitudes.reduce(0, +) / Double(magnitudes.count)
    let count = response.features.count
    
    // Map seismic energy to textile parameters
    let density = max(2, min(8, Int(avgMag * 2) + (count > 20 ? 2 : 0)))
    let rhythm = max(1, min(5, Int(avgMag)))
    let summary = "Recent Shocks: \(count) | Avg Magnitude: \(String(format: "%.2f", avgMag))"
    return (density, rhythm, summary)
}

// Generative ASCII loom rendering based on tectonic metrics
func weaveTextile(density: Int, rhythm: Int, rows: Int = 22, cols: Int = 64) {
    let threads = ["╱", "╲", "─", "│", "┼", "╳", "░", "▒", "▓"]
    
    for r in 0..<rows {
        var rowString = ""
        for c in 0..<cols {
            let patternIndex = (r / rhythm + c / density + (r * c) % rhythm) % threads.count
            // Introduce tectonic fault lines based on rhythm
            if (r + c) % (density * 2) == 0 {
                rowString += "╫"
            } else if c % (density + rhythm) == 0 {
                rowString += "║"
            } else {
                rowString += threads[patternIndex]
            }
        }
        print(rowString)
    }
}

print("--- REAL-TIME SEISMIC TEXTILE LOOM ---")
let (density, rhythm, summary) = fetchSeismicActivity()
print(summary)
print("Weaving Parameters -> Density: \(density), Rhythm: \(rhythm)\n")
weaveTextile(density: density, rhythm: rhythm)
print("\n--- END OF LOOM RUN ---")