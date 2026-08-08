import Foundation

// Gravitational Call Stack & Memory Collapse Quine
struct Allocation {
    let symbol: String
    var collapsed: Bool = false
    var visual: String { collapsed ? "🕳️ [BlackHole:\(symbol)]" : "🪐 [Orbiter:\(symbol)]" }
}

func runSimulation() {
    var stack = [Allocation(symbol: "main"), Allocation(symbol: "quine_eval"), Allocation(symbol: "heap_alloc")]
    print("Call Stack Bodies: " + stack.map { $0.visual }.joined(separator: " -> "))
    stack[2].collapsed = true // GC collapse into black hole
    print("Post-GC Stack State: " + stack.map { $0.visual }.joined(separator: " -> "))
}

runSimulation()

let s = "import Foundation%C%C// Gravitational Call Stack & Memory Collapse Quine%Cstruct Allocation {%C    let symbol: String%C    var collapsed: Bool = false%C    var visual: String { collapsed ? \"🕳️ [BlackHole:\\(symbol)]\" : \"🪐 [Orbiter:\\(symbol)]\" }%C}%C%Cfunc runSimulation() {%C    var stack = [Allocation(symbol: \"main\"), Allocation(symbol: \"quine_eval\"), Allocation(symbol: \"heap_alloc\")]%C    print(\"Call Stack Bodies: \" + stack.map { $0.visual }.joined(separator: \" -> \"))%C    stack[2].collapsed = true // GC collapse into black hole%C    print(\"Post-GC Stack State: \" + stack.map { $0.visual }.joined(separator: \" -> \"))%C}%C%CrunSimulation()%C%Clet s = %@%C%Clet q = String(UnicodeScalar(34))%Clet n = String(UnicodeScalar(10))%Cprint(String(format: s.replacingOccurrences(of: \"%C\", with: n), q + s + q))"

let q = String(UnicodeScalar(34))
let n = String(UnicodeScalar(10))
print(String(format: s.replacingOccurrences(of: "%C", with: n), q + s + q))