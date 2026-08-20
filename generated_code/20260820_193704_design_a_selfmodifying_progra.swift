import Foundation

// MARK: - Core Execution Stack & ASCII Canvas Configuration
let width = 80
let height = 30
var velocity = Array(repeating: Array(repeating: 0.0, count: width), count: height)
var density = Array(repeating: Array(repeating: 0.0, count: width), count: height)
var terrain = Array(repeating: Array(repeating: false, count: width), count: height)

// ASCII density ramp from fluid intensity to structural crystal
let asciiRamp = Array(" .:-=+*#%@")
let crystalChar: Character = "█"

// MARK: - Self-Modifying Code Representation & Execution Stack
enum Instruction {
    case pulse(x: Int, y: Int, amount: Double)
    case flow(dx: Double, dy: Double)
    case crystallize(x: Int, y: Int)
    case mutateStack
}

var executionStack: [Instruction] = [
    .pulse(x: 40, y: 15, amount: 8.0),
    .flow(dx: 0.2, dy: 0.1),
    .pulse(x: 20, y: 10, amount: 5.0),
    .mutateStack,
    .crystallize(x: 10, y: 25)
]

var stepCount = 0

// MARK: - Fluid Simulation & Self-Modification Engine
func simulateFluidStep() {
    var newDensity = density
    
    // Diffuse density and create fluid ripple propagation
    for y in 1..<(height - 1) {
        for x in 1..<(width - 1) {
            if terrain[y][x] { continue } // Dead code terrain blocks flow
            
            let neighbors = density[y-1][x] + density[y+1][x] + density[y][x-1] + density[y][x+1]
            let avg = neighbors / 4.0
            newDensity[y][x] += (avg - density[y][x]) * 0.4 + velocity[y][x]
            newDensity[y][x] *= 0.96 // Dissipation
        }
    }
    density = newDensity
}

func executeNextInstruction() {
    guard !executionStack.isEmpty else { return }
    let current = executionStack.removeFirst()
    
    switch current {
    case .pulse(let x, let y, let amount):
        let cx = max(1, min(width - 2, x))
        let cy = max(1, min(height - 2, y))
        density[cy][cx] += amount
        velocity[cy][cx] += amount * 0.5
        
    case .flow(let dx, let dy):
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                velocity[y][x] += (dx + dy) * 0.1
            }
        }
        
    case .crystallize(let x, let y):
        let cx = max(1, min(width - 2, x))
        let cy = max(1, min(height - 2, y))
        terrain[cy][cx] = true
        density[cy][cx] = 0
        
    case .mutateStack:
        // Self-modification: Generate new stack instructions based on current fluid state
        stepCount += 1
        let rx = (stepCount * 13 + 7) % (width - 4) + 2
        let ry = (stepCount * 7 + 3) % (height - 4) + 2
        
        executionStack.append(.pulse(x: rx, y: ry, amount: Double((stepCount % 5) + 3)))
        
        if stepCount % 3 == 0 {
            executionStack.append(.flow(dx: Double(stepCount % 3 - 1) * 0.3, dy: Double(stepCount % 2 - 1) * 0.3))
        }
        
        // Accumulate dead code into permanent visual crystal terrain
        if stepCount % 4 == 0 {
            let tx = (rx + 5) % (width - 2)
            let ty = (ry + 3) % (height - 2)
            executionStack.append(.crystallize(x: tx, y: ty))
        }
        
        executionStack.append(.mutateStack)
    }
}

func renderFrame() {
    // Clear screen terminal sequence
    print("\u{001B}[2J\u{001B}[H", terminator: "")
    
    var output = ""
    output += "--- SELF-MODIFYING STACK FLUID SIMULATION --- [Stack Size: \(executionStack.count)] [Step: \(stepCount)]\n"
    
    for y in 0..<height {
        for x in 0..<width {
            if terrain[y][x] {
                output.append(crystalChar)
            } else {
                let val = density[y][x]
                let index = max(0, min(asciiRamp.count - 1, Int(val)))
                output.append(asciiRamp[index])
            }
        }
        output.append("\n")
    }
    
    print(output)
}

// MARK: - Main Execution Loop
for _ in 0..<200 {
    executeNextInstruction()
    simulateFluidStep()
    renderFrame()
    Thread.sleep(forTimeInterval: 0.05)
}