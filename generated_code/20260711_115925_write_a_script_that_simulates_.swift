import Foundation

// Simple 1‑dimensional cellular automaton (Elementary CA).
// Uses Rule 30 by default, but any rule (0‑255) can be supplied as a command‑line argument.
// Usage: swiftc automaton.swift -o automaton && ./automaton [width] [steps] [rule]

struct Automaton {
    let width: Int
    let rule: UInt8          // 8‑bit rule table
    var cells: [UInt8]       // current generation (0 or 1)

    init(width: Int, rule: UInt8) {
        self.width = width
        self.rule = rule
        // Start with a single live cell in the middle
        self.cells = Array(repeating: 0, count: width)
        self.cells[width / 2] = 1
    }

    // Compute next generation using periodic boundary conditions
    mutating func step() {
        var next = cells
        for i in 0..<width {
            // Neighborhood: left, center, right
            let left  = cells[(i - 1 + width) % width]
            let center = cells[i]
            let right = cells[(i + 1) % width]
            // Create a 3‑bit index: (left<<2)|(center<<1)|right
            let index = Int((left << 2) | (center << 1) | right)
            // Bit `index` of rule determines new state (rule's LSB corresponds to pattern 000)
            let newState = (rule >> UInt8(index)) & 1
            next[i] = newState
        }
        cells = next
    }

    // Render cells as a string of spaces and blocks
    func render() -> String {
        cells.map { $0 == 1 ? "█" : " " }.joined()
    }
}

// --------------------
// Parse command line arguments
// --------------------
let args = CommandLine.arguments
guard args.count >= 3,
      let width = Int(args[1]), width > 0,
      let steps = Int(args[2]), steps >= 0 else {
    print("Usage: \(args[0]) width steps [rule 0‑255 (default 30)]")
    exit(1)
}
let rule: UInt8 = {
    if args.count >= 4, let r = UInt8(args[3]) {
        return r
    } else {
        return 30   // Rule 30
    }
}()

var automaton = Automaton(width: width, rule: rule)

// Print initial state and evolve
print(automaton.render())
for _ in 0..<steps {
    automaton.step()
    print(automaton.render())
}