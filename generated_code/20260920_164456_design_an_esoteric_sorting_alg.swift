import Foundation

// Calculates the "melancholy" of a float based on wave interference and fractional weight
func melancholyScore(of value: Double) -> Double {
    return sin(value * Double.pi) - (value.truncatingRemainder(dividingBy: 1.0))
}

// Renders a generative stained-glass frame representing the current emotional state of the array
func renderStainedGlass(state: [Double], frame: Int) {
    let symbols = ["·", "░", "▒", "▓", "█", "◆", "◇", "◈"]
    print("--- Stained Glass Projection [Frame \(frame)] ---")
    
    for row in 0..<2 {
        let line = state.enumerated().map { (index, val) -> String in
            let harmonic = melancholyScore(of: val * Double(row + 1))
            let symbolIndex = abs(Int(harmonic * 100)) % symbols.count
            return "\(symbols[symbolIndex])(\(String(format: "%+.2f", val)))"
        }.joined(separator: " | ")
        print("[\(row)] \(line)")
    }
    print()
}

// Esoteric Melancholy Sort: emotional weights settle into structured harmony
func melancholySort(_ array: [Double]) -> [Double] {
    var collection = array
    var frameCount = 0
    
    print("Commencing emotional arrangement...")
    renderStainedGlass(state: collection, frame: frameCount)
    
    let count = collection.count
    for i in 0..<count {
        for j in 0..<count - 1 - i {
            let scoreA = melancholyScore(of: collection[j])
            let scoreB = melancholyScore(of: collection[j+1])
            
            // Sort by descending melancholy (deepest sorrow sinks to the end)
            if scoreA < scoreB {
                collection.swapAt(j, j + 1)
                frameCount += 1
                renderStainedGlass(state: collection, frame: frameCount)
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }
    return collection
}

// Execution entry point
let initialValues: [Double] = [3.1415, -2.7182, 1.4142, -0.5772, 2.7182, -1.4142]
let finalValues = melancholySort(initialValues)
print("Harmonization complete. Final state: \(finalValues)")