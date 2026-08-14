#!/usr/bin/env swift

import Foundation

// ============================================================================
// CATHEDRAL OF CODES: A Git Hook Markov Chain Gothic Architect
// ============================================================================

struct MarkovChain {
    private var transitions: [String: [String]] = [:]

    init(corpus: [String]) {
        for line in corpus {
            let tokens = line.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            guard tokens.count > 1 else { continue }
            for i in 0..<(tokens.count - 1) {
                let current = tokens[i]
                let next = tokens[i + 1]
                transitions[current, default: []].append(next)
            }
        }
    }

    func generateSeed(length: Int = 5) -> [Double] {
        var result: [Double] = []
        var currentToken = transitions.keys.randomElement() ?? "feat"
        
        for _ in 0..<length {
            let hashValue = abs(currentToken.hashValue)
            let normalized = Double(hashValue % 100) / 100.0
            result.append(normalized)
            if let nextOptions = transitions[currentToken], let nextToken = nextOptions.randomElement() {
                currentToken = nextToken
            } else {
                currentToken = transitions.keys.randomElement() ?? "fix"
            }
        }
        return result
    }
}

// Shell execution helper
func runShell(_ command: String) -> String {
    let task = Process()
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()
    task.arguments = ["-c", command]
    task.executableURL = URL(fileURLWithPath: "/bin/sh")
    do {
        try task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    } catch {
        return ""
    }
}

// 1. Fetch Git Commit Messages
let gitLogOutput = runShell("git log --pretty=format:'%s' -n 50")
let commitMessages = gitLogOutput.components(separatedBy: "\n").filter { !$0.isEmpty }
let corpus = commitMessages.isEmpty ? ["feat: initial spire", "fix: reinforce flying buttress", "docs: sanctify nave"] : commitMessages

let markov = MarkovChain(corpus: corpus)
let proceduralSeeds = markov.generateSeed(length: 10)

// 2. Extract Test Coverage Percentage
let xccovOutput = runShell("xcrun xccov view --report --json *.xcresult 2>/dev/null")
var coveragePercentage: Double = 0.85 // Default fallback

if let data = xccovOutput.data(using: .utf8),
   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
   let lineCoverage = json["lineCoverage"] as? Double {
    coveragePercentage = lineCoverage
} else {
    // Check swift test output as fallback
    let swiftTestOutput = runShell("swift test --enable-code-coverage 2>&1")
    let regex = try? NSRegularExpression(pattern: "(\\d+)% executed")
    if let match = regex?.firstMatch(in: swiftTestOutput, range: NSRange(swiftTestOutput.startIndex..., in: swiftTestOutput)),
       let range = Range(match.range(at: 1), in: swiftTestOutput),
       let val = Double(swiftTestOutput[range]) {
        coveragePercentage = val / 100.0
    }
}

// 3. ASCII Cathedral Generator with Weathering Effects
func renderCathedral(seeds: [Double], integrity: Double) -> String {
    let spireHeight = Int(3.0 + (seeds[0] * 4.0))
    let naveWidth = Int(7.0 + (seeds[1] * 5.0)) * 2 + 1
    let buttressCount = Int(2.0 + (seeds[2] * 3.0))

    // Characters based on integrity
    let solidWall = "#"
    let ruinChars = [" ", ".", ":", ";", "/", "\\", "x"]
    
    func degrade(_ char: String) -> String {
        if char == " " { return " " }
        if Double.random(in: 0.0...1.0) > integrity {
            return ruinChars.randomElement()!
        }
        return char
    }

    var lines: [String] = []

    // Spire Top
    let padding = String(repeating: " ", count: naveWidth / 2)
    lines.append("\(padding)\(degrade("A"))\(padding)")
    lines.append("\(padding)\(degrade("+"))\(padding)")

    // Spires
    for i in 0..<spireHeight {
        let sideSpace = String(repeating: " ", count: (naveWidth / 2) - i)
        let innerSpace = String(repeating: " ", count: max(0, (i * 2) - 1))
        let row = i == 0 ? "\(sideSpace)/|\\\(sideSpace)" : "\(sideSpace)/\(innerSpace}\\\(sideSpace)"
        lines.append(row.map { degrade(String($0)) }.joined())
    }

    // Rose Window Level
    let leftButtress = String(repeating: "|", count: buttressCount)
    let rightButtress = String(repeating: "|", count: buttressCount)
    let midSpace = String(repeating: " ", count: (naveWidth - 5) / 2)
    let roseRow = "\(leftButtress)\(midSpace)( O )\(midSpace)\(rightButtress)"
    lines.append(roseRow.map { degrade(String($0)) }.joined())

    // Main Body & Archways
    for level in 0..<4 {
        let wallInner = level == 3 ? "  /|||\\  " : "  [   ]  "
        let sidePadding = String(repeating: solidWall, count: max(1, (naveWidth - wallInner.count) / 2))
        let row = "\(leftButtress)\(sidePadding)\(wallInner)\(sidePadding)\(rightButtress)"
        lines.append(row.map { degrade(String($0)) }.joined())
    }

    // Base Foundation
    let base = String(repeating: "=", count: naveWidth + (buttressCount * 2))
    lines.append(base.map { degrade(String($0)) }.joined())

    // Status Header
    let integrityPercent = Int(integrity * 100)
    let banner = "--- GOTHIC CATHEDRAL OF COMMITS --- [COVERAGE / INTEGRITY: \(integrityPercent)%] ---"
    
    return banner + "\n" + lines.joined(separator: "\n")
}

// 4. Output Rendered Cathedral
print("\n" + renderCathedral(seeds: proceduralSeeds, integrity: coveragePercentage) + "\n")
exit(0)