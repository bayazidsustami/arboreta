import Foundation

// PacketHaiku: A terminal utility translating network traffic into haikus.
// Maps packet metrics (length, entropy, protocol) into poetic 5-7-5 syllable structures.

struct Packet {
    let id: UUID = UUID()
    let length: Int
    let entropy: Double
    let protocolName: String
}

enum EmotionalTone: CaseIterable {
    case serene    // Low entropy (< 3.0): repetitive, structured data
    case curious   // Moderate entropy (3.0 - 5.5): text, code, standard streams
    case chaotic   // High entropy (> 5.5): encrypted payloads, compressed media
    
    static func from(entropy: Double) -> EmotionalTone {
        switch entropy {
        case ..<3.0: return .serene
        case 3.0..<5.5: return .curious
        default: return .chaotic
        }
    }
}

struct Vocabulary {
    // 5-syllable phrases by tone
    static let line1: [EmotionalTone: [String]] = [
        .serene:  ["Quiet digital", "Still waters of bytes", "Soft pulse in the wire", "Silent copper stream"],
        .curious: ["A whisper of light", "Data starts to flow", "Seeking distant nodes", "Packets dance along"],
        .chaotic: ["Storm of random bits", "Wild electric rush", "Cipher in the dark", "Frenzied torrents rise"]
    ]
    
    // 7-syllable phrases by tone
    static let line2: [EmotionalTone: [String]] = [
        .serene:  ["Rhythm of an idle heart", "Calmly passing through the void", "Order in the steady pulse"],
        .curious: ["Tracing paths through unseen webs", "Searching for a friend's reply", "Messages bound for the shore"],
        .chaotic: ["Entropy unfolds its secrets", "Tangled noise without a shape", "Thunder crashing through the switch"]
    ]
    
    // 5-syllable phrases by tone
    static let line3: [EmotionalTone: [String]] = [
        .serene:  ["Peace upon the wire", "Resting in the dark", "Fading to silence", "Steady and serene"],
        .curious: ["Finding home at last", "Echoes answer back", "Journey just begun", "Signal meets the dawn"],
        .chaotic: ["Lost in encrypted", "Sparks inside the void", "Drowned in noisy seas", "Vanishing in mist"]
    ]
}

class ShannonEntropyCalculator {
    static func calculate(for data: [UInt8]) -> Double {
        guard !data.isEmpty else { return 0.0 }
        var frequency = [UInt8: Int]()
        for byte in data { frequency[byte, default: 0] += 1 }
        
        let length = Double(data.count)
        var entropy = 0.0
        for count in frequency.values {
            let p = Double(count) / length
            entropy -= p * log2(p)
        }
        return entropy
    }
}

class NetworkSniffer {
    // Generates real-time packet stream representing network activity
    func startStreaming(handler: @escaping (Packet) -> Void) {
        let protocols = ["TCP", "UDP", "TLS", "HTTP/3", "ICMP"]
        
        Timer.scheduledTimer(withTimeInterval: Double.random(in: 0.8...2.2), repeats: true) { _ in
            let payloadSize = Int.random(in: 40...1500)
            var dummyPayload = [UInt8](repeating: 0, count: payloadSize)
            
            // Generate payload with varying randomness to simulate real entropy levels
            let entropyType = Int.random(in: 0...2)
            for i in 0..<payloadSize {
                switch entropyType {
                case 0: dummyPayload[i] = UInt8(i % 4) // Low entropy
                case 1: dummyPayload[i] = UInt8(i % 128) // Moderate entropy
                default: dummyPayload[i] = UInt8.random(in: 0...255) // High entropy
                }
            }
            
            let entropy = ShannonEntropyCalculator.calculate(for: dummyPayload)
            let proto = protocols.randomElement()!
            let packet = Packet(length: payloadSize, entropy: entropy, protocolName: proto)
            handler(packet)
        }
    }
}

class HaikuGenerator {
    func generateHaiku(from packet: Packet) -> String {
        let tone = EmotionalTone.from(entropy: packet.entropy)
        
        let l1 = Vocabulary.line1[tone]!.randomElement()!
        let l2 = Vocabulary.line2[tone]!.randomElement()!
        let l3 = Vocabulary.line3[tone]!.randomElement()!
        
        let colorCode: String
        switch tone {
        case .serene:  colorCode = "\u{001B}[36m" // Cyan
        case .curious: colorCode = "\u{001B}[32m" // Green
        case .chaotic: colorCode = "\u{001B}[35m" // Magenta
        }
        let reset = "\u{001B}[0m"
        
        return """
        \(colorCode)--- [\(packet.protocolName) | Length: \(packet.length)B | Entropy: \(String(format: "%.2f", packet.entropy))] ---
          \(l1)
          \(l2)
          \(l3)\(reset)
        """
    }
}

// Main Execution Loop
print("\u{001B}[2J\u{001B}[H") // Clear terminal
print("🌊 Listening to the digital ether... Press Ctrl+C to stop.\n")

let sniffer = NetworkSniffer()
let generator = HaikuGenerator()

sniffer.startStreaming { packet in
    let haiku = generator.generateHaiku(from: packet)
    print(haiku)
    print()
}

RunLoop.main.run()