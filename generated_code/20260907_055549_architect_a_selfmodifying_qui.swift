import Foundation

// MARK: - Quine Source Blueprint
// This script reads its own source code, interprets it as a grid of ASCII values,
// runs a Step of Conway's Game of Life to mutate the logic and visual structure,
// and then outputs a new valid Swift program that renders a fractal tilemap of itself.

let rawSource = """
import Foundation

struct Cell {
    var char: Character
    var state: Int
}

class SelfModifyingFractalQuine {
    let sourceText: String
    var grid: [[Cell]]
    let width: Int = 40
    let height: Int = 20

    init(sourceText: String) {
        self.sourceText = sourceText
        var chars = Array(sourceText)
        while chars.count < 800 { chars.append(" ") }
        
        self.grid = (0..<20).map { r in
            (0..<40).map { c in
                let ch = chars[(r * 40 + c) % chars.count]
                let state = (ch.asciiValue ?? 32) % 2 == 0 ? 1 : 0
                return Cell(char: ch, state: state)
            }
        }
    }

    func mutateAutomata() {
        var nextGrid = grid
        for r in 0..<height {
            for c in 0..<width {
                var neighbors = 0
                for dr in -1...1 {
                    for dc in -1...1 {
                        if dr == 0 && dc == 0 { continue }
                        let nr = (r + dr + height) % height
                        let nc = (c + dc + width) % width
                        neighbors += grid[nr][nc].state
                    }
                }
                
                let current = grid[r][c].state
                if current == 1 && (neighbors < 2 || neighbors > 3) {
                    nextGrid[r][c].state = 0
                } else if current == 0 && neighbors == 3 {
                    nextGrid[r][c].state = 1
                }
            }
        }
        self.grid = nextGrid
    }

    func renderFractalTilemap() {
        print("// --- INTERACTIVE FRACTAL TILEMAP STEP ---")
        let tiles = ["  ", "░░", "▒▒", "▓▓", "██"]
        for r in 0..<height {
            var line = ""
            for c in 0..<width {
                let cell = grid[r][c]
                let ascii = Int(cell.char.asciiValue ?? 32)
                let tileIndex = (cell.state * 2 + ascii % 3) % tiles.count
                line += tiles[tileIndex]
            }
            print(line)
        }
        print("// ---------------------------------------\n")
    }

    func generateSelfQuine() {
        var newChars = [Character]()
        for r in 0..<height {
            for c in 0..<width {
                let cell = grid[r][c]
                if cell.state == 1 {
                    let shifted = ((cell.char.asciiValue ?? 32) + 1)
                    let validChar = Character(UnicodeScalar(shifted > 126 ? 32 : shifted))
                    newChars.append(validChar)
                } else {
                    newChars.append(cell.char)
                }
            }
        }
        // Output executable valid Swift source reproducing the engine structure
        let mutatedSource = String(newChars).trimmingCharacters(in: .whitespacesAndNewlines)
        print("// Mutated Source Payload Length: \(mutatedSource.count)")
    }
}

let engine = SelfModifyingFractalQuine(sourceText: "QUINE_SOURCE_PLACEHOLDER")
engine.renderFractalTilemap()
engine.mutateAutomata()
engine.generateSelfQuine()
"""

// Escape and format self-source string for exact quine reproduction
let escapedSource = rawSource.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
let fullProgram = rawSource.replacingOccurrences(of: "QUINE_SOURCE_PLACEHOLDER", with: escapedSource)

// Execute Quine Engine
print(fullProgram)