import Foundation

// MARK: - Cellular Automaton types

struct Cell {
    var ch: Character?          // displayed character or nil for empty
    var age: Int = 0            // how long the cell has existed (self‑modifying)
}

typealias Grid = [[Cell]]

// MARK: - Haiku definition (5‑7‑5 syllable)

let haikuLines = [
    "Silent spring",          // 5 syllables
    "whispers on cold wind",  // 7 syllables
    "old stones listen"       // 5 syllables
]

// Canvas size
let rows = 24
let cols = 80

// Create empty grid
var grid: Grid = Array(repeating: Array(repeating: Cell(ch: nil), count: cols), count: rows)

// Starting positions for each line (centered horizontally)
var lineStarts: [Int] = []
for (i, line) in haikuLines.enumerated() {
    let y = 4 + i * 6                     // vertical spacing
    let x = (cols - line.count) / 2
    lineStarts.append(x)
    // Seed first character of each line at its start cell
    let idx = line.startIndex
    grid[y][x].ch = line[idx]
}

// Indexes tracking what character of each line has been placed
var placedIdx = [Int](repeating: 1, count: haikuLines.count) // 1 because first char already placed

// Generation counter
let targetGeneration = 173
var generation = 0

// Helper to copy grid (value semantics)
func copyGrid(_ src: Grid) -> Grid {
    var dst = src
    return dst
}

// Main CA loop
while generation < targetGeneration {
    var next = copyGrid(grid)
    
    // Rule 1: propagate characters to the right if empty
    for y in 0..<rows {
        for x in 0..<cols-1 {
            if let c = grid[y][x].ch, grid[y][x+1].ch == nil {
                next[y][x+1].ch = c
                next[y][x+1].age = grid[y][x].age + 1
            }
        }
    }
    
    // Rule 2: self‑modify – after a character has lived 5 generations it becomes a wall (blocks further spread)
    for y in 0..<rows {
        for x in 0..<cols {
            if let _ = next[y][x].ch, next[y][x].age >= 5 {
                // turn into an immutable block (represented by a space that never changes)
                next[y][x].ch = " "
                next[y][x].age = Int.max
            }
        }
    }
    
    // Rule 3: introduce next character of each line when there is space ahead
    for (lineIdx, line) in haikuLines.enumerated() {
        let y = 4 + lineIdx * 6
        let curPos = lineStarts[lineIdx] + placedIdx[lineIdx] - 1
        if placedIdx[lineIdx] < line.count {
            // look right for empty cell
            let nextX = curPos + 1
            if nextX < cols, next[y][nextX].ch == nil {
                let charIdx = line.index(line.startIndex, offsetBy: placedIdx[lineIdx])
                next[y][nextX].ch = line[charIdx]
                next[y][nextX].age = 0
                placedIdx[lineIdx] += 1
            }
        }
    }
    
    grid = next
    generation += 1
}

// After 173 generations, read the three lines from the grid
var outputLines: [String] = []
for i in 0..<haikuLines.count {
    let y = 4 + i * 6
    var lineStr = ""
    for cell in grid[y] {
        if let c = cell.ch, c != " " {
            lineStr.append(c)
        }
    }
    outputLines.append(lineStr.trimmingCharacters(in: .whitespaces))
}

// Print the final haiku
for l in outputLines {
    print(l)
}