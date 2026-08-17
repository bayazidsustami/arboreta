import Foundation
import Darwin

// MARK: - Terminal Canvas & ANSI Helpers

struct Point {
    var x: Int
    var y: Int
}

struct DoublePoint {
    var x: Double
    var y: Double
}

class TerminalCanvas {
    let width: Int
    let height: Int
    private var buffer: [[Character]]
    private var colorBuffer: [[String]]

    init(width: Int = 80, height: Int = 40) {
        self.width = width
        self.height = height
        self.buffer = Array(repeating: Array(repeating: " ", count: width), count: height)
        self.colorBuffer = Array(repeating: Array(repeating: "", count: width), count: height)
    }

    func clear() {
        for y in 0..<height {
            for x in 0..<width {
                buffer[y][x] = " "
                colorBuffer[y][x] = "\u{001B}[0m"
            }
        }
    }

    func draw(x: Int, y: Int, char: Character, color: String = "\u{001B}[32m") {
        guard x >= 0 && x < width && y >= 0 && y < height else { return }
        buffer[y][x] = char
        colorBuffer[y][x] = color
    }

    func drawLine(from p1: DoublePoint, to p2: DoublePoint, char: Character, color: String) {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        let steps = max(abs(dx), abs(dy))
        guard steps > 0 else {
            draw(x: Int(round(p1.x)), y: Int(round(p1.y)), char: char, color: color)
            return
        }
        let xInc = dx / steps
        let yInc = dy / steps
        var x = p1.x
        var y = p1.y

        for _ in 0...Int(steps) {
            draw(x: Int(round(x)), y: Int(round(y)), char: char, color: color)
            x += xInc
            y += yInc
        }
    }

    func render() {
        var output = "\u{001B}[H" // Move cursor to top-left
        for y in 0..<height {
            for x in 0..<width {
                output += colorBuffer[y][x]
                output.append(buffer[y][x])
            }
            output += "\n"
        }
        print(output, terminator: "")
        fflush(stdout)
    }
}

// MARK: - Memory Monitor

struct MemoryStats {
    var footprintBytes: UInt64
    var footprintMB: Double { Double(footprintBytes) / (1024.0 * 1024.0) }
}

class MemoryMonitor {
    static func currentFootprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rawPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rawPtr, &count)
            }
        }
        if result == KERN_SUCCESS {
            return UInt64(info.phys_footprint)
        }
        return 0
    }
}

// MARK: - Synthetic Memory Allocator (Simulating Leaks and Garbage Collection)

class MemorySimulator {
    private var allocations: [UnsafeMutableRawPointer] = []
    private var phaseCount = 0

    func step() {
        phaseCount += 1
        // Periodically cause artificial heap growth (leaks) vs sudden deallocations (GC sweeps)
        let cycle = phaseCount % 80
        if cycle < 60 {
            // Leak phase: Allocate memory in chunks
            let size = 2 * 1024 * 1024 // 2MB
            if let ptr = malloc(size) {
                memset(ptr, 0xAF, size) // Touch pages to ensure physical footprint grows
                allocations.append(ptr)
            }
        } else if cycle == 65 {
            // GC Sweep phase: Rapidly free allocations
            for ptr in allocations {
                free(ptr)
            }
            allocations.removeAll()
        }
    }
}

// MARK: - Procedural Fractal Plant Engine

class ProceduralPlant {
    private var defoliationProgress: Double = 0.0 // 1.0 = full defoliation (GC event)
    private var rootGnarledFactor: Double = 0.0   // Grows with persistent high memory/leaks

    func renderPlant(canvas: TerminalCanvas, memoryMB: Double, isSweeping: Bool) {
        if isSweeping {
            defoliationProgress = min(1.0, defoliationProgress + 0.25)
        } else {
            defoliationProgress = max(0.0, defoliationProgress - 0.05)
        }

        // Roots nourish and become gnarled with larger memory footprint
        rootGnarledFactor = min(3.0, max(0.2, (memoryMB - 10.0) / 10.0))

        let startX = Double(canvas.width) / 2.0
        let groundY = Double(canvas.height) * 0.65

        // Draw Ground Line
        for x in 0..<canvas.width {
            canvas.draw(x: x, y: Int(groundY), char: "─", color: "\u{001B}[38;5;240m")
        }

        // 1. Render Gnarled Roots (Below ground, nourished by memory leaks)
        let rootDepth = min(Double(canvas.height) - groundY - 1, memoryMB * 0.8)
        renderRoots(canvas: canvas, origin: DoublePoint(x: startX, y: groundY), length: rootDepth, angle: .pi / 2, depth: 4)

        // 2. Render Foliage Fractal Branches (Above ground, height proportional to heap)
        let trunkLength = min(16.0, 4.0 + memoryMB * 0.35)
        let recursionDepth = min(6, Int(3 + memoryMB * 0.15))
        renderBranch(canvas: canvas, start: DoublePoint(x: startX, y: groundY), length: trunkLength, angle: -.pi / 2, depth: recursionDepth)
    }

    private func renderRoots(canvas: TerminalCanvas, origin: DoublePoint, length: Double, angle: Double, depth: Int) {
        guard depth > 0 && length > 1.0 else { return }

        // Gnarled curvature added to roots based on leak intensity
        let jitter = sin(length * rootGnarledFactor) * 0.4
        let endX = origin.x + cos(angle + jitter) * length
        let endY = origin.y + sin(angle + jitter) * length
        let endPoint = DoublePoint(x: endX, y: endY)

        let rootColor = "\u{001B}[38;5;130m" // Earthy brown/amber for roots
        let rootChar: Character = depth > 2 ? "█" : (depth > 1 ? "║" : "│")
        canvas.drawLine(from: origin, to: endPoint, char: rootChar, color: rootColor)

        // Branch out roots
        let spread = 0.4 + (rootGnarledFactor * 0.1)
        renderRoots(canvas: canvas, origin: endPoint, length: length * 0.65, angle: angle - spread, depth: depth - 1)
        renderRoots(canvas: canvas, origin: endPoint, length: length * 0.65, angle: angle + spread, depth: depth - 1)
    }

    private func renderBranch(canvas: TerminalCanvas, start: DoublePoint, length: Double, angle: Double, depth: Int) {
        guard depth > 0 && length > 0.8 else { return }

        let endX = start.x + cos(angle) * length
        let endY = start.y + sin(angle) * (length * 0.5) // Adjust for terminal ASCII aspect ratio
        let endPoint = DoublePoint(x: endX, y: endY)

        // Choose color based on depth and defoliation state
        let branchColor: String
        let branchChar: Character

        if depth == 1 {
            // Foliage / Leaves stage
            if defoliationProgress > 0.3 {
                // Defoliation effect: Leaves turn red/yellow and detach/wither during GC sweeps
                branchColor = "\u{001B}[38;5;196m" // Crimson/Death
                branchChar = defoliationProgress > 0.7 ? " " : "░"
            } else {
                branchColor = "\u{001B}[38;5;46m"  // Vibrant Green
                branchChar = "♣"
            }
        } else {
            // Wood/Trunk stage
            branchColor = "\u{001B}[38;5;34m"
            branchChar = depth > 3 ? "║" : "│"
        }

        canvas.drawLine(from: start, to: endPoint, char: branchChar, color: branchColor)

        // Dynamic branching factor based on fractal growth
        let branchAngle = 0.45 + sin(Double(depth)) * 0.05
        let shrink = 0.73

        renderBranch(canvas: canvas, start: endPoint, length: length * shrink, angle: angle - branchAngle, depth: depth - 1)
        renderBranch(canvas: canvas, start: endPoint, length: length * shrink, angle: angle + branchAngle, depth: depth - 1)
    }
}

// MARK: - Main Application Loop

func main() {
    // Hide Terminal Cursor & Setup Screen
    print("\u{001B}[?25l\u{001B}[2J")
    
    let canvas = TerminalCanvas(width: 80, height: 36)
    let plant = ProceduralPlant()
    let simulator = MemorySimulator()

    var previousFootprint: UInt64 = MemoryMonitor.currentFootprint()

    // Restore terminal cursor on exit
    signal(SIGINT) { _ in
        print("\u{001B}[?25h\u{001B}[0m\nTerminal Fractal Utility Exited.")
        exit(0)
    }

    while true {
        // 1. Simulate Heap Activity (Leaks and GC Sweeps)
        simulator.step()

        // 2. Sample Memory Metrics
        let currentFootprint = MemoryMonitor.currentFootprint()
        let memoryMB = Double(currentFootprint) / (1024.0 * 1024.0)
        let isGCSweep = currentFootprint < previousFootprint
        previousFootprint = currentFootprint

        // 3. Clear and Render Fractal Scene
        canvas.clear()
        plant.renderPlant(canvas: canvas, memoryMB: memoryMB, isSweeping: isGCSweep)

        // 4. Overlay HUD
        let statusColor = isGCSweep ? "\u{001B}[41;30m[ GC SWEEP DETECTED ]" : "\u{001B}[32m[ LEAK NOURISHING ROOTS ]"
        let hud = String(format: " HEAP FOOTPRINT: %.2f MB | STATUS: %@\u{001B}[0m", memoryMB, statusColor)
        
        for (i, char) in hud.enumerated() where i < canvas.width {
            canvas.draw(x: i, y: 0, char: char, color: "\u{001B}[1;37m")
        }

        canvas.render()

        // Loop frame delay (~15 FPS)
        usleep(66_000)
    }
}

main()