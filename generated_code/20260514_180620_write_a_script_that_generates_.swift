import Foundation

// This script converts a text file's hexadecimal representation into a MIDI-like sequence.
// Since standard Swift doesn't have a built-in MIDI synthesizer, this script outputs 
// a "MIDI-compatible" text format (simplified MIDI events) and simulates the logic.

struct MIDIEvent {
    let pitch: Int
    let duration: Double // in beats
}

class MelodyGenerator {
    // MIDI Note range: 21 (A0) to 108 (C8)
    private let minPitch = 21
    private let maxPitch = 108
    
    func generateMelody(from filePath: String) -> [MIDIEvent] {
        guard let data = FileManager.default.contents(atPath: filePath) else {
            print("Error: Could not read file at \(filePath)")
            return []
        }
        
        // Convert file data to a hex string
        let hexString = data.map { String(format: "%02x", $0) }.joined()
        let hexChars = Array(hexString)
        
        var melody: [MIDIEvent] = []
        
        // Iterate through hex characters to determine pitch and duration
        // We process pairs of hex characters to get a byte-like value (0-255)
        for i in stride(from: 0, to: hexChars.count, by: 2) {
            guard i + 1 < hexChars.count else { break }
            
            let pair = String(hexChars[i...i+1], radix: 16)
            if let byteValue = Int(pair, radix: 16) {
                
                // Map byteValue (0-255) to MIDI pitch (21-108)
                // Formula: min + (value % range)
                let pitchRange = maxPitch - minPitch
                let pitch = minPitch + (byteValue % (pitchRange + 1))
                
                // Use the next character (if available) or a hash to determine duration
                // Durations: 0.25 (16th), 0.5 (8th), 1.0 (quarter), 2.0 (half)
                let durationOptions: [Double] = [0.25, 0.5, 1.0, 2.0]
                let durationIdx = byteValue % durationOptions.count
                let duration = durationOptions[durationIdx]
                
                melody.append(MIDIEvent(pitch: pitch, duration: duration))
            }
        }
        
        return melody
    }
}

// --- Execution Logic ---

let fileName = "input_text.txt"
let fileManager = FileManager.default
let currentPath = fileManager.currentDirectoryPath
let fullPath = "\(currentPath)/\(fileName)"

// 1. Create a dummy file for demonstration if it doesn't exist
let dummyContent = "Hello, this is a test file for musical conversion!"
try? dummyContent.write(toFile: fullPath, atomically: true, encoding: .utf8)

print("--- Melody Generator ---")
print("Reading file: \(fileName)")

let generator = MelodyGenerator()
let melody = generator.generateMelody(from: fullPath)

if melody.isEmpty {
    print("Failed to generate melody. Check file permissions or path.")
} else {
    print("Generated \(melody.count) notes.\n")
    print("Format: [Pitch (MIDI) | Duration (Beats)]")
    print("---------------------------------------")
    
    // Print the first 20 notes to avoid flooding the console
    for (index, note) in melody.prefix(20).enumerated() {
        let pitchChar = String(format: "%03d", note.pitch)
        let durChar = String(format: "%.2f", note.duration)
        print("Note \(index + 1): Pitch \(pitchChar) | Duration \(durChar)")
    }
    
    if melody.count > 20 {
        print("... and \(melody.count - 20) more notes.")
    }
    
    print("---------------------------------------")
    print("Process complete.")
}

// Clean up dummy file
try? fileManager.removeItem(atPath: fullPath)