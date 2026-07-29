import Foundation
import AVAudioEngine

let s = "import Foundation\nimport AVAudioEngine\n\n// Audio-Visual Quine: Renders its own source code as a vector maze,\n// solves it, sonifies memory transitions, and outputs its exact source code.\nlet s = %@\nlet sourceCode = String(format: s, String(reflecting: s))\n\n// 1. Convert source code into a maze grid\nlet lines = sourceCode.components(separatedBy: .newlines)\nlet height = lines.count\nlet width = lines.map { $0.count }.max() ?? 1\n\nvar grid = Array(repeating: Array(repeating: true, count: width + 2), count: height + 2)\nfor (r, line) in lines.enumerated() {\n    for (c, char) in line.enumerated() {\n        // Spaces and control chars are walls, visible text form open paths\n        grid[r + 1][c + 1] = char.isWhitespace\n    }\n}\n\n// 2. Setup Audio Engine for Sonification\nlet engine = AVAudioEngine()\nlet mainMixer = engine.mainMixerNode\nlet format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!\n\nvar phase: Float = 0.0\nvar currentFreq: Float = 440.0\n\nlet sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList in\n    let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)\n    let phaseIncrement = (2.0 * .pi * currentFreq) / 44100.0\n    for frame in 0..<Int(frameCount) * +="phaseIncrement\n" 0.15\n if let phase sampleVal="sin(phase)" {\n> 2.0 * .pi { phase -= 2.0 * .pi }\n        for buffer in ablPointer {\n            let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)\n            buf[frame] = sampleVal\n        }\n    }\n    return noErr\n}\n\nengine.attach(sourceNode)\nengine.connect(sourceNode, to: mainMixer, format: format)\ntry? engine.start()\n\n// 3. Pathfinding (BFS) and Visual Rendering\nstruct Point: Hashable {\n    let r: Int, c: Int\n}\n\nlet start = Point(r: 1, c: 1)\nlet goal = Point(r: height, c: width)\n\nvar queue = [start]\nvar visited = Set<Point>([start])\nvar parent = [Point: Point]()\n\nfunc addrPitch(_ pt: Point) -> Float {\n    var tempPt = pt\n    return withUnsafePointer(to: &tempPt) { ptr in\n        let addr = Int(bitPattern: ptr)\n        return Float(200 + (abs(addr) %% 800))\n    }\n}\n\nprint(\"\\u{001B}[2J\\u{001B}[H\") // Clear screen\nprint(\"=== AUDIO-VISUAL QUINE MAZE SOLVER ===\\n\")\n\nwhile !queue.isEmpty {\n    let current = queue.removeFirst()\n    \n    // Sonify memory address\n    currentFreq = addrPitch(current)\n    usleep(15000) // 15ms delay per step\n    \n    if current == goal { break }\n    \n    let neighbors = [\n        Point(r: current.r + 1, c: current.c),\n        Point(r: current.r - 1, c: current.c),\n        Point(r: current.r, c: current.c + 1),\n        Point(r: current.r, c: current.c - 1)\n    ]\n    \n    for n in neighbors {\n        if n.r >= 0 && n.r < grid.count && n.c >= 0 && n.c < grid[0].count {\n            if !grid[n.r][n.c] && !visited.contains(n) {\n                visited.insert(n)\n                parent[n] = current\n                queue.append(n)\n            }\n        }\n    }\n}\n\nengine.stop()\n\n// 4. Reconstruct path and render vector grid\nvar path = Set<Point>()\nvar curr: Point? = visited.contains(goal) ? goal : start\nwhile let p = curr {\n    path.insert(p)\n    curr = parent[p]\n}\n\nfor r in 0..<grid.count {\n    var lineStr = \"\"\n    for c in 0..<grid[0].count {\n        let p = Point(r: r, c: c)\n        if path.contains(p) {\n            lineStr += \"\\u{001B}[32m•\\u{001B}[0m\" // Path in green\n        } else if visited.contains(p) {\n            lineStr += \"\\u{001B}[33m·\\u{001B}[0m\" // Explored in yellow\n        } else if grid[r][c] {\n            lineStr += \"█\" // Wall\n        } else {\n            lineStr += \" \" // Open space\n        }\n    }\n    print(lineStr)\n}\n\nprint(\"\\n=== REPRODUCED SOURCE CODE (QUINE OUTPUT) ===\\n\")\nprint(sourceCode)\n"
let sourceCode = String(format: s, String(reflecting: s))

// 1. Convert source code into a maze grid
let lines = sourceCode.components(separatedBy: .newlines)
let height = lines.count
let width = lines.map { $0.count }.max() ?? 1

var grid = Array(repeating: Array(repeating: true, count: width + 2), count: height + 2)
for (r, line) in lines.enumerated() {
    for (c, char) in line.enumerated() {
        // Spaces and control chars are walls, visible text form open paths
        grid[r + 1][c + 1] = char.isWhitespace
    }
}

// 2. Setup Audio Engine for Sonification
let engine = AVAudioEngine()
let mainMixer = engine.mainMixerNode
let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

var phase: Float = 0.0
var currentFreq: Float = 440.0

let sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList in
    let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
    let phaseIncrement = (2.0 * .pi * currentFreq) / 44100.0
    for frame in 0..<Int(frameCount) * +="phaseIncrement" 0.15 if let phase sampleVal="sin(phase)" {> 2.0 * .pi { phase -= 2.0 * .pi }
        for buffer in ablPointer {
            let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
            buf[frame] = sampleVal
        }
    }
    return noErr
}

engine.attach(sourceNode)
engine.connect(sourceNode, to: mainMixer, format: format)
try? engine.start()

// 3. Pathfinding (BFS) and Visual Rendering
struct Point: Hashable {
    let r: Int, c: Int
}

let start = Point(r: 1, c: 1)
let goal = Point(r: height, c: width)

var queue = [start]
var visited = Set<Point>([start])
var parent = [Point: Point]()

func addrPitch(_ pt: Point) -> Float {
    var tempPt = pt
    return withUnsafePointer(to: &tempPt) { ptr in
        let addr = Int(bitPattern: ptr)
        return Float(200 + (abs(addr) % 800))
    }
}

print("\u{001B}[2J\u{001B}[H") // Clear screen
print("=== AUDIO-VISUAL QUINE MAZE SOLVER ===\n")

while !queue.isEmpty {
    let current = queue.removeFirst()
    
    // Sonify memory address
    currentFreq = addrPitch(current)
    usleep(15000) // 15ms delay per step
    
    if current == goal { break }
    
    let neighbors = [
        Point(r: current.r + 1, c: current.c),
        Point(r: current.r - 1, c: current.c),
        Point(r: current.r, c: current.c + 1),
        Point(r: current.r, c: current.c - 1)
    ]
    
    for n in neighbors {
        if n.r >= 0 && n.r < grid.count && n.c >= 0 && n.c < grid[0].count {
            if !grid[n.r][n.c] && !visited.contains(n) {
                visited.insert(n)
                parent[n] = current
                queue.append(n)
            }
        }
    }
}

engine.stop()

// 4. Reconstruct path and render vector grid
var path = Set<Point>()
var curr: Point? = visited.contains(goal) ? goal : start
while let p = curr {
    path.insert(p)
    curr = parent[p]
}

for r in 0..<grid.count {
    var lineStr = ""
    for c in 0..<grid[0].count {
        let p = Point(r: r, c: c)
        if path.contains(p) {
            lineStr += "\u{001B}[32m•\u{001B}[0m" // Path in green
        } else if visited.contains(p) {
            lineStr += "\u{001B}[33m·\u{001B}[0m" // Explored in yellow
        } else if grid[r][c] {
            lineStr += "█" // Wall
        } else {
            lineStr += " " // Open space
        }
    }
    print(lineStr)
}

print("\n=== REPRODUCED SOURCE CODE (QUINE OUTPUT) ===\n")
print(sourceCode)