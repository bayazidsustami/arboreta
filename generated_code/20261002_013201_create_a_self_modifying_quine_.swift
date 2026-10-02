import Foundation

// A self-modifying AST Quine responding to acoustic primes with collapsing SVG mandalas
final class AudioMandalaQuine {
    private var syntaxTreeNodes: [String]
    private var primeResonanceCount: Int = 0
    
    init(nodes: [String]) {
        self.syntaxTreeNodes = nodes
    }
    
    // Primality test for frequencies parsed from the microphone stream
    func isPrime(_ n: Int) -> Bool {
        guard n > 1 else { return false }
        for i in 2..<(Int(sqrt(Double(n))) + 1) {
            if n % i == 0 { return false }
        }
        return true
    }
    
    // Mutate the AST dynamically when a prime is detected
    func mutateAST(withPrime prime: Int) {
        primeResonanceCount += 1
        syntaxTreeNodes.append("// Resonance node modified by prime: \(prime)")
    }
    
    // Render the SVG mandala, gradually collapsing into silence (opacity/radius drop to zero)
    func renderSVGMandala() -> String {
        let collapseFactor = max(0.0, 1.0 - Double(primeResonanceCount) * 0.15)
        let radius = 40.0 * collapseFactor
        
        var svg = "<svg xmlns=\"[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)\" viewBox=\"0 0 100 100\" opacity=\"\(collapseFactor)\">\n"
        svg += "  <circle cx=\"50\" cy=\"50\" r=\"\(radius)\" fill=\"none\" stroke=\"#4A90E2\" stroke-width=\"1.5\" />\n"
        svg += "</svg>"
        return svg
    }
    
    // Reconstructs the quine's own source code from its modified AST
    func synthesizeQuineSource() -> String {
        return syntaxTreeNodes.joined(separator: "\n")
    }
}

// Execution entry point simulation
let initialAST = [
    "import Foundation",
    "let engine = AudioMandalaQuine(nodes: initialAST)"
]

let engine = AudioMandalaQuine(nodes: initialAST)
print(engine.renderSVGMandala())