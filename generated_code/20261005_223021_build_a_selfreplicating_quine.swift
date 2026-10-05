#!/usr/bin/swift
import Foundation

// A self-replicating quine that simulates an imaginary punctuation-only language 
// (where symbols like !@#$ dictate state transitions) and renders its execution 
// graph as a blooming Barnsley fractal fern.

let q = """
#!/usr/bin/swift
import Foundation

// A self-replicating quine that simulates an imaginary punctuation-only language 
// (where symbols like !@#$ dictate state transitions) and renders its execution 
// graph as a blooming Barnsley fractal fern.

let q = %C%@%C
let punctuationSyntax = "!@#$%%^&*()_+-=[]{}|;':\\\\",./<>?"

// Replicate source code (Quine property)
print(String(format: q, 34, q, 34))

// Simulate the punctuation execution graph morphing into a fern
let width = 50, height = 22
var canvas = Array(repeating: Array(repeating: " ", count: width), count: height)
var x = 0.0, y = 0.0

for _ in 0..<8000 {
    let r = Double.random(in: 0...1)
    let nextX, nextY: Double
    
    if r < 0.01 {
        nextX = 0.0
        nextY = 0.16 * y
    } else if r < 0.86 {
        nextX = 0.85 * x + 0.04 * y
        nextY = -0.04 * x + 0.85 * y + 1.6
    } else if r < 0.93 {
        nextX = 0.2 * x - 0.26 * y
        nextY = 0.23 * x + 0.22 * y + 1.6
    } else {
        nextX = -0.15 * x + 0.28 * y
        nextY = 0.26 * x + 0.24 * y + 0.44
    }
    
    x = nextX
    y = nextY
    
    let px = Int(x * 4.5 + Double(width) / 2.0)
    let py = Int(Double(height) - (y * 3.8))
    
    if px >= 0 && px < width && py >= 0 && py < height {
        canvas[py][px] = "🌿"
    }
}

// Print the blooming execution graph
let fernOutput = canvas.map { $0.joined() }.joined(separator: "\\n")
print("\\nExecution Graph (Blooming Fractal Fern):\\n")
print(fernOutput)
"""

let punctuationSyntax = "!@#$%^&*()_+-=[]{}|;':\\",./<>?"

// Replicate source code (Quine property)
print(String(format: q, 34, q, 34))

// Simulate the punctuation execution graph morphing into a fern
let width = 50, height = 22
var canvas = Array(repeating: Array(repeating: " ", count: width), count: height)
var x = 0.0, y = 0.0

for _ in 0..<8000 {
    let r = Double.random(in: 0...1)
    let nextX, nextY: Double
    
    if r < 0.01 {
        nextX = 0.0
        nextY = 0.16 * y
    } else if r < 0.86 {
        nextX = 0.85 * x + 0.04 * y
        nextY = -0.04 * x + 0.85 * y + 1.6
    } else if r < 0.93 {
        nextX = 0.2 * x - 0.26 * y
        nextY = 0.23 * x + 0.22 * y + 1.6
    } else {
        nextX = -0.15 * x + 0.28 * y
        nextY = 0.26 * x + 0.24 * y + 0.44
    }
    
    x = nextX
    y = nextY
    
    let px = Int(x * 4.5 + Double(width) / 2.0)
    let py = Int(Double(height) - (y * 3.8))
    
    if px >= 0 && px < width && py >= 0 && py < height {
        canvas[py][px] = "🌿"
    }
}

// Print the blooming execution graph
let fernOutput = canvas.map { $0.joined() }.joined(separator: "\n")
print("\nExecution Graph (Blooming Fractal Fern):\n")
print(fernOutput)