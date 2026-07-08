import Foundation

// MARK: - Elementary Cellular Automaton (Rule 30)
// This script prints a few generations of the automaton to the console.

let ruleNumber = 30                     // Rule 30 (binary 00011110)
let width = 79                          // Cells per line (fits most terminals)
let generations = 25                    // How many rows to display

// Pre‑compute the lookup table: index = 0b111..0, value = next state (0 or 1)
var ruleTable = [Int](repeating: 0, count: 8)
for i in 0..<8 {
    ruleTable[i] = (ruleNumber >> i) & 1
}

// Helper: turn a Bool array into a printable string
func render(_ cells: [Bool]) -> String {
    cells.map { $0 ? "█" : " " }.joined()
}

// Initialize the first generation with a single live cell in the centre
var current = [Bool](repeating: false, count: width)
current[width / 2] = true

for _ in 0..<generations {
    // Print the current generation
    print(render(current))
    
    // Compute next generation
    var next = [Bool](repeating: false, count: width)
    for i in 0..<width {
        // Neighborhood as bits: left‑center‑right
        let left  = current[(i - 1 + width) % width] ? 1 : 0
        let center = current[i] ? 1 : 0
        let right = current[(i + 1) % width] ? 1 : 0
        let index = (left << 2) | (center << 1) | right   // 0…7
        next[i] = ruleTable[index] == 1
    }
    current = next
}