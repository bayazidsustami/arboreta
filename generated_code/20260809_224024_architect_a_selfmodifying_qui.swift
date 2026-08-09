import Foundation

// Self-Modifying Quine: Renders Execution Stack & Memory Turbulence Fluid Simulation
let frame = 0
/* EXECUTION STACK & FLUID DYNAMICS CANVAS
%CANVAS%
*/
let code: [String] = [
    "import Foundation",
    "",
    "// Self-Modifying Quine: Renders Execution Stack & Memory Turbulence Fluid Simulation",
    "let frame = 0",
    "/* EXECUTION STACK & FLUID DYNAMICS CANVAS",
    "%CANVAS%",
    "*/",
    "let code: [String] = []",
    "",
    "// Evaluates fluid dynamics driven by execution stack and dynamic memory allocations",
    "func renderFluid(frame: Int) -> String {",
    "    let width = 58, height = 16",
    "    ",
    "    // 1. Inspect execution stack pointer to seed turbulence phase",
    "    var stackMarker = 0",
    "    let stackAddr = withUnsafePointer(to: &stackMarker) { UInt(bitPattern: $0) }",
    "    let stackTurbulence = Double(stackAddr & 0xFFFF) / 65535.0",
    "    ",
    "    // 2. Dynamic heap allocation drives fluid vorticity vectors",
    "    let capacity = 256 + (frame % 16) * 16",
    "    let heapBuffer = UnsafeMutablePointer<Float>.allocate(capacity: capacity)",
    "    let heapAddr = UInt(bitPattern: heapBuffer)",
    "    let heapTurbulence = Double(heapAddr & 0xFFFF) / 65535.0",
    "    ",
    "    for i in 0..<capacity {",
    "        heapBuffer[i] = Float(sin(Double(i) * 0.05 + stackTurbulence * .pi))",
    "    }",
    "    let heapEnergy = (0..<capacity).reduce(0.0) { $0 + Double(heapBuffer[$1]) } / Double(capacity)",
    "    heapBuffer.deallocate()",
    "    ",
    "    // 3. Eulerian fluid density advection rendering into ASCII raster",
    "    let chars = Array(\" .:-=+*#%@\")",
    "    var lines: [String] = []",
    "    let time = Double(frame) * 0.15",
    "    ",
    "    for y in 0..<height {",
    "        var row = \"\"",
    "        for x in 0..<width {",
    "            let u = (Double(x) / Double(width) - 0.5) * 2.2",
    "            let v = (Double(y) / Double(height) - 0.5) * 2.2",
    "            ",
    "            let turbX = sin(u * 3.5 + time + stackTurbulence * .pi * 2.0 + heapEnergy)",
    "            let turbY = cos(v * 3.5 - time + heapTurbulence * .pi * 2.0 - stackTurbulence)",
    "            let dist = sqrt(u * u + v * v)",
    "            ",
    "            let wave1 = sin((u + turbX * 0.4) * 5.0 + time)",
    "            let wave2 = cos((v + turbY * 0.4) * 5.0 - time)",
    "            let vortex = sin(dist * 8.0 - time * 2.0 + (turbX + turbY) * 0.5)",
    "            ",
    "            let density = (wave1 + wave2 + vortex + 3.0) / 6.0",
    "            let clamped = max(0.0, min(1.0, density))",
    "            let idx = Int(clamped * Double(chars.count - 1))",
    "            row.append(chars[idx])",
    "        }",
    "        lines.append(row)",
    "    }",
    "    return lines.joined(separator: \"\\n\")",
    "}",
    "",
    "// Self-reproduction logic",
    "let canvas = renderFluid(frame: frame)",
    "var source = code.joined(separator: \"\\n\")",
    "source = source.replacingOccurrences(of: \"%CANVAS%\", with: canvas)",
    "source = source.replacingOccurrences(of: \"let frame = 0\", with: \"let frame = \\(frame + 1)\")",
    "",
    "let arrayRepr = \"let code: [String] = [\\n\" + code.map { \"    \" + $0.debugDescription }.joined(separator: \",\\n\") + \"\\n]\"",
    "source = source.replacingOccurrences(of: \"let code: [String] = []\", with: arrayRepr)",
    "",
    "print(source)"
]

// Evaluates fluid dynamics driven by execution stack and dynamic memory allocations
func renderFluid(frame: Int) -> String {
    let width = 58, height = 16
    
    // 1. Inspect execution stack pointer to seed turbulence phase
    var stackMarker = 0
    let stackAddr = withUnsafePointer(to: &stackMarker) { UInt(bitPattern: $0) }
    let stackTurbulence = Double(stackAddr & 0xFFFF) / 65535.0
    
    // 2. Dynamic heap allocation drives fluid vorticity vectors
    let capacity = 256 + (frame % 16) * 16
    let heapBuffer = UnsafeMutablePointer<Float>.allocate(capacity: capacity)
    let heapAddr = UInt(bitPattern: heapBuffer)
    let heapTurbulence = Double(heapAddr & 0xFFFF) / 65535.0
    
    for i in 0..<capacity {
        heapBuffer[i] = Float(sin(Double(i) * 0.05 + stackTurbulence * .pi))
    }
    let heapEnergy = (0..<capacity).reduce(0.0) { $0 + Double(heapBuffer[$1]) } / Double(capacity)
    heapBuffer.deallocate()
    
    // 3. Eulerian fluid density advection rendering into ASCII raster
    let chars = Array(" .:-=+*#%@")
    var lines: [String] = []
    let time = Double(frame) * 0.15
    
    for y in 0..<height {
        var row = ""
        for x in 0..<width {
            let u = (Double(x) / Double(width) - 0.5) * 2.2
            let v = (Double(y) / Double(height) - 0.5) * 2.2
            
            let turbX = sin(u * 3.5 + time + stackTurbulence * .pi * 2.0 + heapEnergy)
            let turbY = cos(v * 3.5 - time + heapTurbulence * .pi * 2.0 - stackTurbulence)
            let dist = sqrt(u * u + v * v)
            
            let wave1 = sin((u + turbX * 0.4) * 5.0 + time)
            let wave2 = cos((v + turbY * 0.4) * 5.0 - time)
            let vortex = sin(dist * 8.0 - time * 2.0 + (turbX + turbY) * 0.5)
            
            let density = (wave1 + wave2 + vortex + 3.0) / 6.0
            let clamped = max(0.0, min(1.0, density))
            let idx = Int(clamped * Double(chars.count - 1))
            row.append(chars[idx])
        }
        lines.append(row)
    }
    return lines.joined(separator: "\n")
}

// Self-reproduction logic
let canvas = renderFluid(frame: frame)
var source = code.joined(separator: "\n")
source = source.replacingOccurrences(of: "%CANVAS%", with: canvas)
source = source.replacingOccurrences(of: "let frame = 0", with: "let frame = \(frame + 1)")

let arrayRepr = "let code: [String] = [\n" + code.map { "    " + $0.debugDescription }.joined(separator: ",\n") + "\n]"
source = source.replacingOccurrences(of: "let code: [String] = []", with: arrayRepr)

print(source)