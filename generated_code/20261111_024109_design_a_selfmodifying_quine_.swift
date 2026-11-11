#!/usr/bin/env swift

import Foundation

// Celestial-Warped Grid Quine Interpreter in Swift
// A grid-based esoteric language where instruction pointers (IPs) 
// drift under gravitational vectors derived from pseudo-ephemeris positions.

struct CelestialBody {
    let name: String
    let mass: Double
    var position: (x: Double, y: Double)
    var velocity: (dx: Double, dy: Double)
    
    mutating func update(time: Double) {
        // Orbital mechanics simulation as live ephemeris proxy
        position.x += velocity.dx
        position.y += velocity.dy
        let r = sqrt(position.x * position.x + position.y * position.y)
        if r > 50 {
            velocity.dx = -position.y * 0.05
            velocity.dy = position.x * 0.05
        }
    }
}

class GridMachine {
    var grid: [[Character]]
    var ip: (x: Double, y: Double)
    var ipVelocity: (dx: Double, dy: Double)
    var bodies: [CelestialBody]
    var sourceTemplate: String
    
    init(source: String) {
        self.sourceTemplate = source
        let lines = source.split(separator: "\n").map { Array($0) }
        let height = lines.count
        let width = lines.map { $0.count }.max() ?? 10
        
        grid = Array(repeating: Array(repeating: " ", count: width), count: height)
        for (y, row) in lines.enumerated() {
            for (x, char) in row.enumerated() {
                grid[y][x] = char
            }
        }
        
        ip = (0.0, 0.0)
        ipVelocity = (1.0, 0.0)
        
        bodies = [
            CelestialBody(name: "Sol-Alpha", mass: 1000.0, position: (15.0, 5.0), velocity: (0.0, 0.2)),
            CelestialBody(name: "Kepler-X", mass: 450.0, position: (5.0, 10.0), velocity: (-0.1, 0.1))
        ]
    }
    
    func applyGravity() {
        var gx = 0.0
        var gy = 0.0
        
        for body in bodies {
            let dx = body.position.x - ip.x
            let dy = body.position.y - ip.y
            let r2 = dx * dx + dy * dy + 1.0 // softening factor
            let force = body.mass / (r2 * sqrt(r2))
            gx += dx * force * 0.01
            gy += dy * force * 0.01
        }
        
        ipVelocity.dx += gx
        ipVelocity.dy += gy
    }
    
    func step(time: Double) {
        for i in 0..<bodies.count {
            bodies[i].update(time: time)
        }
        applyGravity()
        
        ip.x += ipVelocity.dx
        ip.y += ipVelocity.dy
        
        let h = Double(grid.count)
        let w = Double(grid[0].count)
        if h > 0 && w > 0 {
            ip.x = fmod(fmod(ip.x, w) + w, w)
            ip.y = fmod(fmod(ip.y, h) + h, h)
        }
    }
    
    func executeQuineCycle() {
        print("--- Celestial Ephemeris Quine State ---")
        print("Current IP Position: (\(String(format: "%.2f", ip.x)), \(String(format: "%.2f", ip.y)))")
        let quineOutput = sourceTemplate.replacingOccurrences(of: "/\*STATE\*/", with: "/* IP: \(ip.x),\(ip.y) */", options: .regularExpression)
        print(quineOutput)
    }
}

let rawSource = """
#!/usr/bin/env swift
// Quine template body
/*STATE*/
print("Self-replicating grid node active.")
"""

let machine = GridMachine(source: rawSource)
for t in 0..<3 {
    machine.step(time: Double(t))
    machine.executeQuineCycle()
}