import Foundation

// MARK: - Data Models

/// Represents a celestial body with its physical properties.
struct CelestialBody {
    let name: String
    let orbitalPeriod: Double // In Earth days
    let luminosity: Double    // Relative to Sun (0.1 to 100.0)
}

/// Represents a single MIDI event.
struct MIDIEvent {
    let pitch: UInt8
    let velocity: UInt8
    let duration: Double // In beats
}

// MARK: - Core Logic

class CelestialToMIDIConverter {
    
    // Musical constraints
    private let scale: [UInt8] = [60, 62, 64, 65, 67, 69, 71, 72] // C Major scale
    private let maxVelocity: UInt8 = 100
    private let minVelocity: UInt8 = 40

    /// Converts a collection of celestial bodies into a sequence of MIDI events.
    func convert(bodies: [CelestialBody]) -> [MIDIEvent] {
        return bodies.map { body in
            // 1. Map Orbital Period to Pitch
            // We use a logarithmic scale for period to handle vast differences in time
            // and map it to the indices of our musical scale.
            let logPeriod = log10(body.orbitalPeriod)
            let pitchIndex = Int(floor(abs(logPeriod) * 2)) % scale.count
            let pitch = scale[pitchIndex]

            // 2. Map Luminosity to Velocity (Volume)
            // Higher luminosity = louder note.
            // We normalize luminosity (logarithmic) to a MIDI velocity range.
            let logLum = log10(body.luminosity)
            // Offset and scale to fit between 40 and 100
            let normalizedVel = UInt8(clamping: Int(40 + (logLum * 15)))
            let velocity = max(minVelocity, min(maxVelocity, normalizedVel))

            // 3. Map Orbital Period to Duration
            // Shorter periods create faster (shorter) notes.
            let duration = max(0.25, min(2.0, 10.0 / body.orbitalPeriod))

            return MIDIEvent(pitch: pitch, velocity: velocity, duration: duration)
        }
    }

    /// Generates a pseudo-MIDI file format (Simplified MIDI-like text output for demonstration)
    /// Since writing a full binary .mid file requires complex header/track logic,
    /// we output a structured representation that describes the "playable" melody.
    func printMelody(events: [MIDIEvent]) {
        print("--- PLAYABLE CELESTIAL MELODY ---")
        print("Format: [Pitch, Velocity, Duration(beats)]")
        print("---------------------------------")
        for (index, event) in events.enumerated() {
            print(String(format: "Note %02d: Pitch %3d | Vel %3d | Dur %.2f", 
                         index + 1, event.pitch, event.velocity, event.duration))
        }
        print("---------------------------------")
        print("End of Sequence")
    }
}

// MARK: - Execution

// 1. Define a collection of celestial coordinates/bodies
let starsAndPlanets = [
    CelestialBody(name: "Mercury", orbitalPeriod: 88.0, luminosity: 0.01),
    CelestialBody(name: "Venus", orbitalPeriod: 224.7, luminosity: 0.01),
    CelestialBody(name: "Earth", orbitalPeriod: 365.2, luminosity: 0.01),
    CelestialBody(name: "Mars", orbitalPeriod: 687.0, luminosity: 0.01),
    CelestialBody(name: "Sirius", orbitalPeriod: 1000000.0, luminosity: 25.4),
    CelestialBody(name: "Betelgeuse", orbitalPeriod: 5000000.0, luminosity: 126000.0),
    CelestialBody(name: "Proxima Centauri", orbitalPeriod: 15000.0, luminosity: 0.0017),
    CelestialBody(name: "Sun", orbitalPeriod: 365.2, luminosity: 1.0)
]

// 2. Initialize Converter
let converter = CelestialToMIDIConverter()

// 3. Process Data
let melody = converter.convert(bodies: starsAndPlanets)

// 4. Output Result
// In a real-world macOS/iOS app, you would use AVFoundation to play these MIDI events.
// Here, we print the musical mapping.
converter.printMelody(events: melody)