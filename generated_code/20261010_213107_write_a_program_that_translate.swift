#!/usr/bin/swift

import Foundation

// MARK: - ASCII Forest & Audio-Reactive Synthesizer
// This script simulates a living ambient audio environment, translates frequencies
// into phonetic elements, and renders a dynamic ASCII forest where vowels grow 
// expanding branches and consonants drop executable Swift code "pinecones".

struct ForestConfig {
    static let width = 60
    static let height = 20
    static let vowels: Set<Character> = ["A", "E", "I", "O", "U", "a", "e", "i", "o", "u"]
    static let consonants: Set<Character> = [
        "B", "C", "D", "F", "G", "H", "J", "K", "L", "M", 
        "N", "P", "Q", "R", "S", "T", "V", "W", "X", "Y", "Z",
        "b", "c", "d", "f", "g", "h", "j", "k", "l", "m", 
        "n", "p", "q", "r", "s", "t", "v", "w", "x", "y", "z"
    ]
    static let codeSnippets = [
        "print(\"🌲\")",
        "let x = 42",
        "for i in 0..<3 { print(i) }",
        "let r = Double.random(in: 0...1)",
        "extension Tree { func bloom() {} }",
        "let code = \"pinecone\""
    ]
}

class TreeNode {
    var char: Character
    var x: Int
    var y: Int
    var height: Int
    var isBranch: Bool
    
    init(char: Character, x: Int, y: Int) {
        self.char = char
        self.x = x
        self.y = y
        self.height = 1
        self.isBranch = ForestConfig.vowels.contains(char)
    }
}

class ASCIIForestSimulation {
    private var grid: [[Character]]
    private var nodes: [TreeNode] = []
    private var frequencyBuffer: [Double] = []
    private let phoneticAlphabet = Array("AmbientForestAudioStreamSynthesizerSwiftExecutionEngine".unicodeScalars).map { Character($0) }
    private var streamIndex = 0
    
    init() {
        self.grid = Array(repeating: Array(repeating: " ", count: ForestConfig.width), count: ForestConfig.height)
    }
    
    // Simulate ambient frequency spectrum reading (e.g., FFT bins)
    private func sampleAmbientFrequencies() -> [Double] {
        // Generates pseudo-random frequency magnitudes mimicking ambient soundwaves
        let time = CFAbsoluteTimeGetCurrent()
        return (0..<5).map { i in
            sin(time * Double(i + 1) * 0.5) * 50.0 + 50.0 + Double.random(in: 0...20)
        }
    }
    
    func step() {
        // Clear grid
        grid = Array(repeating: Array(repeating: " ", count: ForestConfig.width), count: ForestConfig.height)
        
        // Sample frequencies
        let frequencies = sampleAmbientFrequencies()
        let avgAmplitude = frequencies.reduce(0, +) / Double(frequencies.count)
        
        // Occasionally spawn new elements based on audio energy spikes
        if avgAmplitude > 60 && nodes.count < 15 {
            let char = phoneticAlphabet[streamIndex % phoneticAlphabet.count]
            streamIndex += 1
            let randomX = Int.random(in: 5..<(ForestConfig.width - 5))
            nodes.append(TreeNode(char: char, x: randomX, y: ForestConfig.height - 2))
        }
        
        // Update and render nodes
        for node in nodes {
            if ForestConfig.vowels.contains(node.char) {
                // Vowels grow branches upward
                if node.y > 2 && Int.random(in: 0...2) == 0 {
                    node.y -= 1
                    node.height += 1
                }
                if node.y >= 0 && node.y < ForestConfig.height && node.x >= 0 && node.x < ForestConfig.width {
                    grid[node.y][node.x] = node.height > 5 ? "Y" : "V"
                }
            } else if ForestConfig.consonants.contains(node.char) {
                // Consonants drop pinecones of executable code downwards
                if node.y < ForestConfig.height - 1 {
                    node.y += 1
                }
                if node.y >= 0 && node.y < ForestConfig.height && node.x >= 0 && node.x < ForestConfig.width {
                    grid[node.y][node.x] = "o" // Pinecone symbol
                }
            }
        }
        
        // Cleanup old nodes
        nodes = nodes.filter { $0.y > 0 && $0.y < ForestConfig.height - 1 }
    }
    
    func render() {
        // Clear terminal screen and move cursor to top
        print("\u{001B}[H\u{001B}[J", terminator: "")
        print("=== 🌲 AMBIENT AUDIO ASCII FOREST & CODE SYNTHESIZER 🌲 ===")
        print(String(repeating: "-", count: ForestConfig.width))
        
        for row in grid {
            print(String(row))
        }
        
        print(String(repeating: "-", count: ForestConfig.width))
        print("Legend: [V/Y] Vowel Branches  [o] Consonant Pinecones")
        print("Active Code Snippet Synthesized: \(ForestConfig.codeSnippets.randomElement()!)")
        print("Press Ctrl+C to exit.")
    }
    
    func run() {
        print("Initializing audio frequency capture simulation...")
        Thread.sleep(forTimeInterval: 1.0)
        
        while true {
            step()
            render()
            Thread.sleep(forTimeInterval: 0.15)
        }
    }
}

// Execute the simulation
let forest = ASCIIForestSimulation()
forest.run()