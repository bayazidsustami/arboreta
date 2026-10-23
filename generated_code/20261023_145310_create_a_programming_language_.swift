#!/usr/bin/env swift

import Foundation

// A poetic interpreter for "Meltdown", a language where variables fade into music.

enum MeltableValue {
    case number(Double)
    case chord(String)
    
    var description: String {
        switch self {
        case .number(let val):
            return String(format: "%.2f", val)
        case .chord(let name):
            return "🎶 [Melting into chord: \(name)]"
        }
    }
    
    mutating func decay() {
        switch self {
        case .number(var val):
            val *= 0.70 // Decay factor on each read
            if val < 8.0 {
                let ambientChords = ["Cmaj7 (Warm Pad)", "F#min9 (Ethereal Chord)", "Dm11 (Subtle Resonance)", "Ebmaj9/G (Harmonic Drift)"]
                let chosenChord = ambientChords[Int.random(in: 0..<ambientChords.count)]
                self = .chord(chosenChord)
            } else {
                self = .number(val)
            }
        case .chord:
            break // Already pure music
        }
    }
}

class MeltdownInterpreter {
    private var variables: [String: MeltableValue] = [:]
    
    func assign(name: String, value: Double) {
        variables[name] = .number(value)
        print("⚡️ Assigned: \(name) = \(value)")
    }
    
    func access(name: String) -> MeltableValue? {
        guard var val = variables[name] else {
            print("⚡️ Vacuum: Variable '\(name)' does not exist in this reality.")
            return nil
        }
        // Variables decay every single time they are accessed
        val.decay()
        variables[name] = val
        return val
    }
    
    func run(_ line: String) {
        let tokens = line.split(separator: " ").map { String($0) }
        if tokens.count >= 3 && tokens[1] == "=" {
            let varName = tokens[0]
            if let numericValue = Double(tokens[2]) {
                assign(name: varName, value: numericValue)
            }
        } else if tokens.count == 2 && tokens[0] == "print" {
            let varName = tokens[1]
            if let result = access(name: varName) {
                print("📖 Read \(varName) -> \(result.description)")
            }
        }
    }
}

// Execution Demonstration
let interpreter = MeltdownInterpreter()
print("--- Initializing Meltdown Session ---")

interpreter.run("x = 100")

for step in 1...6 {
    print("\n[Step \(step)] Accessing variable 'x':")
    interpreter.run("print x")
}

print("\n--- Session Complete: Silence and Chords Remain ---")