import Foundation

// Nomadic Dandelion Cellular Automaton Engine
// Simulates seed dispersal driven by atmospheric pressure, rendered in the terminal using box characters and bell sounds.

struct DandelionEngine {
    static let width = 40
    static let height = 20
    
    enum Cell: Equatable {
        case empty
        case dandelion(energy: Int)
        case seed(momentum: Int)
    }
    
    var grid: [[Cell]]
    var pressure: Double = 1013.25
    var tick: Int = 0
    
    init() {
        grid = Array(repeating: Array(repeating: .empty, count: DandelionEngine.width), count: DandelionEngine.height)
        // Plant initial nomadic dandelion in the center
        grid[DandelionEngine.height / 2][DandelionEngine.width / 2] = .dandelion(energy: 15)
    }
    
    mutating func updateAtmosphericPressure() {
        // Simulate fluctuating barometric pressure using sine waves and random drift
        let timeFactor = Double(tick) * 0.2
        pressure = 1013.25 + (sin(timeFactor) * 15.0) + (Double.random(in: -3.0...3.0))
    }
    
    mutating func step() {
        tick += 1
        updateAtmosphericPressure()
        
        var newGrid = Array(repeating: Array(repeating: Cell.empty, count: DandelionEngine.width), count: DandelionEngine.height)
        var triggerBell = false
        
        for y in 0..<DandelionEngine.height .dandelion(let .empty: 0..<DandelionEngine.width break case energy energy): for grid[y][x] if in switch x {> 0 {
                        // Persist dandelion and occasionally release seeds based on pressure gradient
                        newGrid[y][x] = .dandelion(energy: energy - 1)
                        
                        // Lower pressure creates high winds, accelerating seed release
                        let releaseThreshold = pressure < 1005.0 ? 2 : 5
                        if tick % releaseThreshold == 0 && x + 1 < DandelionEngine.width {
                            let momentum = pressure < 1000.0 ? 3 : 1
                            newGrid[y][x + 1] = .seed(momentum: momentum)
                            triggerBell = true
                        }
                    } else {
                        // Dandelion withers, leaves fertile ground
                        newGrid[y][x] = .empty
                    }
                    
                case .seed(let momentum):
                    // Seeds drift horizontally and vertically depending on momentum and pressure drop
                    let windDirection = pressure < 1010.0 ? 1 : -1
                    let nextX = x + (windDirection * momentum)
                    let nextY = y + Int.random(in: -1...1)
                    
                    if nextX >= 0 && nextX < DandelionEngine.width && nextY >= 0 && nextY < DandelionEngine.height {
                        if newGrid[nextY][nextX] == .empty {
                            // Settle or continue drifting
                            if Int.random(in: 0...10) > 8 {
                                // Plant new dandelion
                                newGrid[nextY][nextX] = .dandelion(energy: 12)
                            } else {
                                newGrid[nextY][nextX] = .seed(momentum: max(1, momentum))
                            }
                        }
                    }
                }
            }
        }
        
        grid = newGrid
        
        // Terminal bell sound emission on high wind dispersal events
        if triggerBell {
            print("\u{0007}", terminator: "")
            fflush(stdout)
        }
    }
    
    func render() {
        var output = "\u{001B}[H\u{001B}[J" // Clear screen ANSI escape
        output += "╔" + String(repeating: "═", count: DandelionEngine.width * 2) + "╗\n"
        
        for row in grid {
            output += "║"
            for cell in row {
                switch cell {
                case .empty:
                    output += "  "
                case .dandelion:
                    output += "✿ "
                case .seed:
                    output += "· "
                }
            }
            output += "║\n"
        }
        
        output += "╚" + String(repeating: "═", count: DandelionEngine.width * 2) + "╝\n"
        output += String(format: "Tick: %03d | Pressure: %.2f hPa\n", tick, pressure)
        print(output, terminator: "")
    }
}

// Execution Loop
var engine = DandelionEngine()
print("Starting Nomadic Dandelion Cellular Automaton...")
Thread.sleep(forTimeInterval: 1.0)

for _ in 0..<100 {
    engine.step()
    engine.render()
    Thread.sleep(forTimeInterval: 0.15)
}