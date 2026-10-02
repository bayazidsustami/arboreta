#!/usr/bin/swift

import Foundation

// MARK: - Models & Structures

struct Cell {
    var saturation: Double // 0.0 to 1.0 based on vowel ratio
    var hasFracture: Bool  // true if punctuation triggered a lead line fracture
    var state: Int         // CA active/inactive state
}

struct StainedGlassAutomaton {
    let width: Int
    let height: Int
    var grid: [[Cell]]

    init(width: Int, height: Int, chatLog: String) {
        self.width = width
        self.height = height
        self.grid = Array(repeating: Array(repeating: Cell(saturation: 0.5, hasFracture: false, state: 0), count: width), count: height)
        initializeGrid(with: chatLog)
    }

    // Initialize grid properties based on chat log text characteristics
    mutating func initializeGrid(with chatLog: String) {
        let lines = chatLog.components(separatedBy: .newlines)
        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "A", "E", "I", "O", "U"]
        let punctuations: Set<Character> = [".", ",", "!", "?", ";", ":"]

        for y in 0..<height {
            let line = lines[y % max(1, lines.count)]
            let chars = Array(line)
            
            for x in 0..<width {
                let char = chars[x % max(1, chars.count)]
                
                // Vowel usage determines color saturation
                let isVowel = vowels.contains(char)
                let sat = isVowel ? 0.9 : 0.3
                
                // Punctuation dictates lead line fractures
                let fractured = punctuations.contains(char)
                
                grid[y][x] = Cell(saturation: sat, hasFracture: fractured, state: isVowel ? 1 : 0)
            }
        }
    }

    // Run cellular automaton step with rules influenced by text geometry
    mutating func step() {
        var newGrid = grid
        for y in 0..<height {
            for x in 0..<width {
                let neighbors = getNeighbors(x: x, y: y)
                let activeCount = neighbors.filter { $0.state == 1 }.count
                let avgSat = neighbors.map { $0.saturation }.reduce(0, +) / Double(max(1, neighbors.count))
                let anyFracture = neighbors.contains { $0.hasFracture }

                var currentState = grid[y][x].state
                if currentState == 1 {
                    if activeCount < 2 || activeCount > 3 {
                        currentState = 0
                    }
                } else {
                    if activeCount == 3 {
                        currentState = 1
                    }
                }

                newGrid[y][x] = Cell(
                    saturation: min(1.0, max(0.1, (avgSat + grid[y][x].saturation) / 2.0)),
                    hasFracture: anyFracture || grid[y][x].hasFracture,
                    state: currentState
                )
            }
        }
        grid = newGrid
    }

    private func getNeighbors(x: Int, y: Int) -> [Cell] {
        var result: [Cell] = []
        for dy in -1...1 {
            for dx in -1...1 {
                if dx == 0 && dy == 0 { continue }
                let nx = x + dx
                let ny = y + dy
                if nx >= 0 && nx < width && ny >= 0 && ny < height {
                    result.append(grid[ny][nx])
                }
            }
        }
        return result
    }

    // Generate SVG string representing the virtual stained glass window
    func renderToSVG() -> String {
        let cellSize = 24
        let svgWidth = width * cellSize
        let svgHeight = height * cellSize
        
        var svg = "<svg xmlns=\"[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)\" width=\"\(svgWidth)\" height=\"\(svgHeight)\" viewBox=\"0 0 \(svgWidth) \(svgHeight)\">\n"
        svg += "<rect width=\"100%\" height=\"100%\" fill=\"#0d1117\"/>\n"

        for y in 0..<height {
            for x in 0..<width {
                let cell = grid[y][x]
                let px = x * cellSize
                let py = y * cellSize
                
                let hue = (Double(x + y) / Double(width + height)) * 360.0
                let lightness = cell.state == 1 ? 60 : 30
                let color = "hsl(\(Int(hue)), \(Int(cell.saturation * 100))%, \(lightness)%)"
                
                let strokeWidth = cell.hasFracture ? 3.5 : 1.0
                let strokeColor = cell.hasFracture ? "#000000" : "#1f242c"

                svg += "  <rect x=\"\(px)\" y=\"\(py)\" width=\"\(cellSize)\" height=\"\(cellSize)\" fill=\"\(color)\" stroke=\"\(strokeColor)\" stroke-width=\"\(strokeWidth)\" rx=\"2\" />\n"
            }
        }

        svg += "</svg>"
        return svg
    }
}

// MARK: - Main Execution

let chatLog = """
Alice: Hello everyone! Welcome to the virtual gallery... Are we ready to begin?
Bob: Yes, absolutely! Let's dive right into the automaton logic.
Charlie: Wait, did everyone check the color saturation and lead lines?!
Alice: Ah, magnificent catch. Let's observe the fracture patterns unfold.
"""

var automaton = StainedGlassAutomaton(width: 25, height: 16, chatLog: chatLog)

// Evolve through generations of cellular automaton rules
for _ in 0..<5 {
    automaton.step()
}

let svgOutput = automaton.renderToSVG()
let filePath = "stained_glass_window.svg"

do {
    try svgOutput.write(toFile: filePath, atomically: true, encoding: .utf8)
    print("Virtual stained glass window generated successfully at: \(filePath)")
} catch {
    print("Failed to save stained glass SVG: \(error)")
}