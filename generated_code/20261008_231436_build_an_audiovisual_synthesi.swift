#!/usr/bin/swift

import Foundation

// Baroque Fugue Synthesizer from Crash Memory Addresses
// Maps hex memory addresses from unhandled exception crashes into a 
// polyphonic baroque fugue in D minor, rendering an ANSI audio-visual 
// ASCII art visualization in the terminal.

struct CrashAddress {
    let raw: String
    let numericValue: UInt64
    
    init(_ address: String) {
        self.raw = address
        let clean = address.hasPrefix("0x") ? String(address.dropFirst(2)) : address
        self.numericValue = UInt64(clean, radix: 16) ?? 0
    }
}

class FugueSynthesizer {
    // D natural/harmonic minor scale frequencies (Hz)
    private let scale: [Double] = [
        146.83, 164.81, 174.61, 196.00, 220.00, 233.08, 246.94, // D3 to B3
        293.66, 329.63, 349.23, 392.00, 440.00, 466.16, 493.88  // D4 to B4
    ]
    
    private let noteNames = ["D", "E", "F", "G", "A", "Bb", "C", "d", "e", "f", "g", "a", "bb", "c"]
    private let voices = ["Soprano", "Alto", "Tenor", "Bass"]
    
    func synthesize(from addresses: [CrashAddress]) {
        print("\u{001B}[2J\u{001B}[H") // Clear terminal screen
        print("==================================================")
        print("  BAROQUE FUGUE SYNTHESIZER: CRASH MEMORY PARSER  ")
        print("==================================================\n")
        
        for (index, addr) in addresses.enumerated() {
            let voiceIndex = index % voices.count
            let voice = voices[voiceIndex]
            
            // Extract musical parameters from hex bytes
            let byte1 = (addr.numericValue >> 24) & 0xFF
            let byte2 = (addr.numericValue >> 16) & 0xFF
            let noteIndex = Int(byte1) % scale.count
            let duration = Double((byte2 % 4) + 1) * 0.15
            
            let noteName = noteNames[noteIndex]
            let frequency = scale[noteIndex]
            
            // Render visual representation
            let barLength = Int((byte1 % 20) + 5)
            let bar = String(repeating: "█", count: barLength)
            let colorCode = 31 + (voiceIndex % 6)
            
            print(String(format: "\u{001B}[%dm[%@]\u{001B}[0m Addr: %@ -> Note: %-3s (%.2fHz) | %@", 
                  colorCode, voice, addr.raw, noteName, frequency, bar))
            
            // Pause to simulate rhythmic tempo
            Thread.sleep(forTimeInterval: duration)
        }
        
        print("\n==================================================")
        print("  Fugue generation complete. Silence restored.    ")
        print("==================================================")
    }
}

// Sample unhandled exception crash memory addresses
let crashLogs = [
    CrashAddress("0x7ffee3b41a88"),
    CrashAddress("0x00007fff72a14b00"),
    CrashAddress("0x7ffeefbff568"),
    CrashAddress("0x000000010f3c4000"),
    CrashAddress("0x7ffee3b42c10"),
    CrashAddress("0x00007fff88123c50"),
    CrashAddress("0x7ffeefbffe10"),
    CrashAddress("0x000000010f3c52a0")
]

let synthesizer = FugueSynthesizer()
synthesizer.synthesize(from: crashLogs)