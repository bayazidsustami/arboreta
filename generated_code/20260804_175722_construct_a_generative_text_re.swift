import Foundation

// MARK: - Heap Node & GC Simulation Core
// Represents an allocated memory chunk on the heap. Leaked nodes persist
// across GC sweeps, corrupting the cathedral aesthetics into stained glass rot.
struct HeapNode {
    let id: UInt
    let address: String
    var size: Int
    var isLeaked: Bool
    var rotPhase: Int = 0
}

// MARK: - Generative Cathedral Renderer
// Maps real-time garbage collection state and heap allocations to an evolving ASCII Cathedral.
class GothicHeapCathedral {
    private var heap: [HeapNode] = []
    private var nextID: UInt = 0
    private var gcCycleCount: Int = 0
    private var lastSweptCount: Int = 0
    private var rotEntropy: Double = 0.0

    // ANSI escape sequences for terminal animation & spectral lighting
    private let clearScreen = "\u{001B}[2J\u{001B}[H"
    private let hideCursor  = "\u{001B}[?25l"
    private let showCursor  = "\u{001B}[?25h"
    private let reset       = "\u{001B}[0m"
    private let gold        = "\u{001B}[38;5;220m"
    private let obsidian    = "\u{001B}[38;5;238m"
    private let marble      = "\u{001B}[38;5;253m"
    private let rotGreen    = "\u{001B}[38;5;71m"
    private let rotPlum     = "\u{001B}[38;5;133m"
    private let gcCyan      = "\u{001B}[38;5;51m"
    private let emberRed    = "\u{001B}[38;5;196m"

    // Symbols for stained-glass corruption & architectural masonry
    private let rotGlyphs = ["❖", "✦", "✟", "░", "▒", "▓", "█", "‡", "†", "◊", "⚜", "✵"]
    private let archGargoyles = ["Ϡ", "❡", "Ψ", "Ω", "Ϙ"]

    func run() {
        print(hideCursor)
        
        // Restore terminal state on exit signal
        signal(SIGINT) { _ in
            print("\u{001B}[?25h\u{001B}[0m\nCathedral collapsed into unmapped heap.")
            exit(0)
        }

        var tick = 0
        while true {
            mutateHeap(tick: tick)
            renderFrame(tick: tick)
            usleep(90_000) // ~11 FPS terminal refresh rate
            tick += 1
        }
    }

    // Simulates dynamic heap allocation, pointer lifetime, and garbage collection
    private func mutateHeap(tick: Int) {
        // Random allocations: Allocated pointers act as stones in the vaulted arches
        if Double.random(in: 0...1) < 0.75 || heap.count < 4 {
            let size = Int.random(in: 1...8)
            let isLeaked = Double.random(in: 0...1) < 0.28 // Leak probability
            let addr = String(format: "0x%04X", UInt16.random(in: 0x1000...0xFFFE))
            heap.append(HeapNode(id: nextID, address: addr, size: size, isLeaked: isLeaked))
            nextID += 1
        }

        // Progress rot phase on leaked memory
        for i in 0..<heap.count where heap[i].isLeaked {
            heap[i].rotPhase += 1
        }

        // Execute Garbage Collection cycle
        if tick > 0 && tick % 22 == 0 {
            gcCycleCount += 1
            let priorCount = heap.count
            // GC reclaims unreferenced pointers, leaving leaked memory intact to rot
            heap.removeAll { !$0.isLeaked }
            lastSweptCount = priorCount - heap.count
        }

        let leakedCount = heap.filter { $0.isLeaked }.count
        rotEntropy = heap.isEmpty ? 0 : Double(leakedCount) / Double(heap.count)
    }

    // Renders the ASCII Gothic Cathedral frame-by-frame
    private func renderFrame(tick: Int) {
        var buffer = clearScreen
        
        // Header metrics
        let totalLeaked = heap.filter { $0.isLeaked }.count
        buffer += "\(gold)† C A T H E D R A L  O F  T H E  G A R B A G E  C O L L E C T O R †\(reset)\n"
        buffer += "\(obsidian)Heap Pointers: \(marble)\(heap.count) \(obsidian)| Swept: \(gcCyan)\(lastSweptCount) \(obsidian)| Rot Corruption: \(rotPlum)\(totalLeaked) Leaks (\(Int(rotEntropy * 100))%)\(reset)\n"
        buffer += "\(obsidian)──────────────────────────────────────────────────────────────────────────\(reset)\n\n"

        // Gothic Spire & Cross
        buffer += "                           \(gold)†\(reset)\n"
        buffer += "                          \(marble)/|\\\(reset)\n"
        buffer += "                         \(marble)/ | \\\(reset)\n"
        buffer += "                        \(marble)/  |  \\\(reset)\n"
        buffer += "                       \(gold)/___|___\\\(reset)\n"

        // Dynamic Vaulted Arches (Built from live heap allocation pointers)
        let archCapacity = 10
        let visibleHeap = Array(heap.suffix(archCapacity))
        
        for level in 0..<max(visibleHeap.count, 3) {
            let padding = String(repeating: " ", count: max(0, 20 - level * 2))
            let archSpan = String(repeating: " ", count: level * 3 + 2)

            if level < visibleHeap.count {
                let node = visibleHeap[level]
                if node.isLeaked {
                    // Memory Leaks corrupt arches into stained-glass rot
                    let glyph = rotGlyphs[(node.rotPhase + level + tick) % rotGlyphs.count]
                    let rotColor = (level % 2 == 0) ? rotPlum : rotGreen
                    let corruptSegment = "\(rotColor)∩[\(glyph) \(node.address) \(glyph)]∩\(reset)"
                    buffer += "\(padding)\(marble)/\(reset)\(archSpan)\(corruptSegment)\(archSpan)\(marble)\\\(reset)\n"
                } else {
                    // Healthy allocated pointers grow soaring stone vaulted arches
                    let archSegment = "\(marble)∩(拱_\(node.address)_拱)∩\(reset)"
                    buffer += "\(padding)\(marble)/\(reset)\(archSpan)\(archSegment)\(archSpan)\(marble)\\\(reset)\n"
                }
            } else {
                // Empty arch frame waiting for heap allocation
                let emptySegment = "\(obsidian)⌢(________)⌢\(reset)"
                buffer += "\(padding)\(obsidian)/\(reset)\(archSpan)\(emptySegment)\(archSpan)\(obsidian)\\\(reset)\n"
            }
        }

        // Stained Glass Window Array (Visualizing Rot & Leak Progression)
        buffer += "                 \(gold)╔═══════════════════════════════════╗\(reset)\n"
        var windowRow = "                 \(gold)║\(reset)"
        let leakedNodes = heap.filter { $0.isLeaked }
        
        for idx in 0..<35 {
            if idx < leakedNodes.count {
                let rotNode = leakedNodes[idx % leakedNodes.count]
                let symbol = rotGlyphs[(rotNode.rotPhase + idx) % rotGlyphs.count]
                let color = (idx % 3 == 0) ? emberRed : ((idx % 2 == 0) ? rotPlum : rotGreen)
                windowRow += "\(color)\(symbol)\(reset)"
            } else {
                // Pristine stained glass window pane
                windowRow += "\(gcCyan)✧\(reset)"
            }
        }
        windowRow += "\(gold)║\(reset)\n"
        buffer += windowRow
        buffer += "                 \(gold)╚═══════════════════════════════════╝\(reset)\n"

        // Cathedral Pillars & Foundation
        let gargoyle = archGargoyles[tick % archGargoyles.count]
        buffer += "                  \(obsidian)\(gargoyle) |   |   |                 |   |   | \(gargoyle)\(reset)\n"
        buffer += "                 \(marble)▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓\(reset)\n"

        // Real-time GC Sweep Event Banner
        if tick % 22 < 6 && lastSweptCount > 0 {
            buffer += "\n\(gcCyan)  ✦✦ GARBAGE COLLECTION CYCLE \(gcCycleCount): CLEARED \(lastSweptCount) UNREFERENCED VAULTS ✦✦\(reset)\n"
        } else if totalLeaked > 5 {
            buffer += "\n\(rotPlum)  † WARNING: STAINED GLASS ROT SPREADING THROUGH UNCLAIMED LEAKS †\(reset)\n"
        } else {
            buffer += "\n\(obsidian)  [Heap mutator thread active... Allocating gothic geometry]\(reset)\n"
        }

        print(buffer)
    }
}

// Instantiate and start the generative renderer loop
let cathedral = GothicHeapCathedral()
cathedral.run()