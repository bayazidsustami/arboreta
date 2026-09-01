import Foundation
import Darwin

// MARK: - Data Models

struct ProcessInfo {
    let pid: Int32
    let ppid: Int32
    let name: String
    let cpuUsage: Double   // Percentage (0.0 - 100.0+)
    let memoryMB: Double   // Megabytes
    let threadCount: Int
}

enum FloraType {
    case bloom(petals: Int)
    case weed(length: Int)
    case spore(phase: Int)
}

struct NodeVisual {
    var flora: FloraType
    var glyph: String = ""
    var detail: String = ""
}

// MARK: - Process Tree Node

final class ProcessNode {
    let info: ProcessInfo
    var children: [ProcessNode] = []
    var visual: NodeVisual

    init(info: ProcessInfo) {
        self.info = info
        self.visual = NodeVisual(flora: .spore(phase: 0))
        updateVisual()
    }

    func updateVisual() {
        // High CPU -> Blooming Flower
        if info.cpuUsage > 5.0 {
            let petals = min(8, max(3, Int(info.cpuUsage / 10.0) + 3))
            visual.flora = .bloom(petals: petals)
            let bloomGlyphs = ["🌸", "🌺", "🌻", "🌹", "🌼", "💐"]
            let idx = min(bloomGlyphs.count - 1, Int(info.cpuUsage / 20.0))
            visual.glyph = bloomGlyphs[idx]
            visual.detail = String(repeating: "✿", count: min(5, Int(info.cpuUsage / 15.0) + 1))
        }
        // High Memory -> Runaway Weed
        else if info.memoryMB > 100.0 {
            let length = min(10, max(1, Int(info.memoryMB / 100.0)))
            visual.flora = .weed(length: length)
            visual.glyph = "🌾"
            visual.detail = String(repeating: "🌿", count: min(4, length))
        }
        // Low CPU & High Threads/Idle -> Quiet Geometric Spore
        else {
            let phase = (info.threadCount + Int(Date().timeIntervalSince1990)) % 4
            visual.flora = .spore(phase: phase)
            let spores = ["◌", "✦", "✧", "✦"]
            visual.glyph = spores[phase]
            visual.detail = "･ﾟ"
        }
    }
}

// MARK: - Process Sampler (macOS / BSD `ps` Bridge)

final class ProcessSampler {
    static func fetchProcesses() -> [ProcessInfo] {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.arguments = ["-e", "-o", "pid,ppid,%cpu,rss,comm"]
        task.executableURL = URL(fileURLWithPath: "/bin/ps")

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()

            guard let output = String(data: data, encoding: .utf8) else { return [] }
            return parsePsOutput(output)
        } catch {
            return []
        }
    }

    private static func parsePsOutput(_ output: String) -> [ProcessInfo] {
        var processes: [ProcessInfo] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines.dropFirst() {
            let tokens = line.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            guard tokens.count >= 5,
                  let pid = Int32(tokens[0]),
                  let ppid = Int32(tokens[1]),
                  let cpu = Double(tokens[2]),
                  let rssKB = Double(tokens[3]) else { continue }

            let path = tokens[4...]
            let rawName = path.joined(separator: " ")
            let name = (rawName as NSString).lastPathComponent

            // Rough thread count metric using RSS scale as proxy for demonstration
            let threadEstimate = max(1, Int(rssKB / 8192.0))

            processes.append(ProcessInfo(
                pid: pid,
                ppid: ppid,
                name: name.isEmpty ? "unknown" : name,
                cpuUsage: cpu,
                memoryMB: rssKB / 1024.0,
                threadCount: threadEstimate
            ))
        }
        return processes
    }

    static func buildTree(from processes: [ProcessInfo]) -> [ProcessNode] {
        var nodeMap: [Int32: ProcessNode] = [:]
        for proc in processes {
            nodeMap[proc.pid] = ProcessNode(info: proc)
        }

        var roots: [ProcessNode] = []
        for proc in processes {
            guard let node = nodeMap[proc.pid] else { continue }
            if proc.ppid != proc.pid, let parent = nodeMap[proc.ppid] {
                parent.children.append(node)
            } else {
                roots.append(node)
            }
        }
        return roots
    }
}

// MARK: - ASCII Terrarium Renderer

final class TerrariumRenderer {
    private var buffer: [String] = []

    func clearScreen() {
        print("\u{001B}[2J\u{001B}[H", terminator: "")
    }

    func render(roots: [ProcessNode]) {
        buffer.removeAll()

        let title = "╔══════════════════════════════════════════════════════════════════════════════╗\n" +
                    "║               🌲 GENERATIVE ASCII PROCESS TERRARIUM 🌾                      ║\n" +
                    "║  🌸 Bloom = High CPU  |  🌾 Weed = High Memory  |  ✦ Spore = Idle Thread      ║\n" +
                    "╚══════════════════════════════════════════════════════════════════════════════╝"
        buffer.append(title)
        buffer.append("")

        // Find significant trees (limit depth and display width for terminal fit)
        let sortedRoots = roots.sorted { $0.children.count > $1.children.count }
        let displayedRoots = Array(sortedRoots.prefix(6))

        for (idx, root) in displayedRoots.enumerated() {
            let isLast = idx == displayedRoots.count - 1
            renderNode(root, prefix: "", isLast: isLast, depth: 0)
        }

        buffer.append("\n" + String(repeating: "═", count: 78))
        buffer.append(" [Press Ctrl+C to exit]  " + Date().description)

        print(buffer.joined(separator: "\n"))
    }

    private func renderNode(_ node: ProcessNode, prefix: String, isLast: Bool, depth: Int) {
        guard depth < 4 else { return } // Depth ceiling to prevent terminal flood

        node.updateVisual()

        let connector = isLast ? "└── " : "├── "
        let processLabel = "\(node.info.name) (PID: \(node.info.pid))"
        let stats = String(format: "CPU: %.1f%% | Mem: %.1fMB", node.info.cpuUsage, node.info.memoryMB)

        var line = "\(prefix)\(connector)\(node.visual.glyph) \(processLabel) [\(stats)] "

        switch node.visual.flora {
        case .bloom:
            line += "\u{001B}[31m\(node.visual.detail)\u{001B}[0m" // Red/Pink bloom
        case .weed:
            line += "\u{001B}[32m\(node.visual.detail)\u{001B}[0m" // Green weed
        case .spore:
            line += "\u{001B}[36m\(node.visual.detail)\u{001B}[0m" // Cyan spore
        }

        buffer.append(line)

        let childPrefix = prefix + (isLast ? "    " : "│   ")
        let visibleChildren = Array(node.children.prefix(5)) // Cap rendering width

        for (idx, child) in visibleChildren.enumerated() {
            let lastChild = idx == visibleChildren.count - 1
            renderNode(child, prefix: childPrefix, isLast: lastChild, depth: depth + 1)
        }

        if node.children.count > 5 {
            buffer.append("\(childPrefix)└── … (\(node.children.count - 5) more child processes)")
        }
    }
}

// MARK: - Main Loop

let renderer = TerrariumRenderer()
print("Starting ASCII Terrarium... Press Ctrl+C to stop.")

// Set up signal handling for graceful shutdown
signal(SIGINT) { _ in
    print("\n\u{001B}[2J\u{001B}[H")
    print("Terrarium closed. Environmental balance restored.")
    exit(0)
}

while true {
    let procs = ProcessSampler.fetchProcesses()
    let tree = ProcessSampler.buildTree(from: procs)

    renderer.clearScreen()
    renderer.render(roots: tree)

    Thread.sleep(forTimeInterval: 1.5)
}