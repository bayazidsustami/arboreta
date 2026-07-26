import Foundation
import Darwin

// MARK: - System Memory Monitor
struct MemoryStats {
    var freeMB: Double = 0.0
    var activeMB: Double = 0.0
    var inactiveMB: Double = 0.0
    var wiredMB: Double = 0.0
    var fragmentationRatio: Double = 0.0 // 0.0 (pristine) to 1.0 (highly fragmented/leaking)
    
    static func current() -> MemoryStats {
        var stats = MemoryStats()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStat = vm_statistics64_data_t()
        
        let result = withUnsafeMutablePointer(to: &vmStat) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let pageSize = Double(vm_kernel_page_size) / (1024.0 * 1024.0) // MB
            stats.freeMB = Double(vmStat.free_count) * pageSize
            stats.activeMB = Double(vmStat.active_count) * pageSize
            stats.inactiveMB = Double(vmStat.inactive_count) * pageSize
            stats.wiredMB = Double(vmStat.wire_count) * pageSize
            
            let total = stats.freeMB + stats.activeMB + stats.inactiveMB + stats.wiredMB
            if total > 0 {
                // High inactive/wired ratio relative to free memory indicates memory pressure / fragmentation
                let unalignedRatio = (stats.inactiveMB + (stats.wiredMB * 0.5)) / total
                stats.fragmentationRatio = min(max(unalignedRatio * 1.5, 0.0), 1.0)
            }
        } else {
            // Fallback simulation value if Mach host stats fail
            stats.fragmentationRatio = Double.random(in: 0.15...0.85)
        }
        return stats
    }
}

// MARK: - Terminal Canvas & ANSI Styling
struct Terminal {
    static func hideCursor() { print("\u{001B}[?25l", terminator: "") }
    static func showCursor() { print("\u{001B}[?25h", terminator: "") }
    static func clearScreen() { print("\u{001B}[2J\u{001B}[H", terminator: "") }
    
    enum Color: String {
        case reset     = "\u{001B}[0m"
        case stone     = "\u{001B}[38;5;245m"
        case shadow    = "\u{001B}[38;5;238m"
        case spire     = "\u{001B}[38;5;250m"
        case stained   = "\u{001B}[38;5;141m"
        case stainedGlow = "\u{001B}[38;5;207m"
        case gargoyle  = "\u{001B}[38;5;130m"
        case crumbling = "\u{001B}[38;5;196m"
        case dust      = "\u{001B}[38;5;240m"
        case statsText = "\u{001B}[38;5;51m"
    }
}

// MARK: - Procedural Cathedral Generator
class CathedralRenderer {
    private var scrollOffset: Int = 0
    private var simulatedLeakMemory: [UnsafeMutableRawPointer] = []
    
    // Generates a single line of the infinite Gothic Cathedral facade at row `y`
    func generateLine(y: Int, width: Int, fragmentation: Double) -> String {
        var charBuffer = Array(repeating: " ", count: width)
        var colorBuffer = Array(repeating: Terminal.Color.reset.rawValue, count: width)
        
        let center = width / 2
        let cycle = y % 40
        
        // Render Spires, Rose Windows, Arches, and Buttresses
        for x in 0..<width {
            let dx = abs(x - center)
            
            // Central Spires & Pinnacles
            if cycle < 8 {
                if dx == 0 {
                    setChar(&charBuffer, &colorBuffer, x, "┼", .spire)
                } else if dx == cycle {
                    setChar(&charBuffer, &colorBuffer, x, "/", .stone)
                } else if dx == -cycle {
                    setChar(&charBuffer, &colorBuffer, x, "\\", .stone)
                }
            } 
            // Rose Window & Triforium Section
            else if cycle >= 8 && cycle < 22 {
                let winRadius = 6
                let winY = cycle - 15
                let distSq = dx * dx + winY * winY
                
                if abs(dx) == 18 || abs(dx) == 30 {
                    setChar(&charBuffer, &colorBuffer, x, "║", .shadow)
                } else if distSq >= (winRadius - 1) * (winRadius - 1) && distSq <= (winRadius + 1) * (winRadius + 1) {
                    setChar(&charBuffer, &colorBuffer, x, "☸", .stainedGlow)
                } else if distSq < winRadius * winRadius {
                    let patterns = ["✧", "✦", "✢", "✶"]
                    let symbol = patterns[(dx + y) % patterns.count]
                    setChar(&charBuffer, &colorBuffer, x, symbol, .stained)
                } else if dx == 12 || dx == -12 {
                    setChar(&charBuffer, &colorBuffer, x, "│", .shadow)
                }
            } 
            // Great Gothic Nave & Pointed Arches
            else {
                if dx == 8 || dx == 24 || dx == 36 {
                    setChar(&charBuffer, &colorBuffer, x, "▓", .stone)
                } else if dx == 16 {
                    setChar(&charBuffer, &colorBuffer, x, "║", .shadow)
                } else if cycle == 39 {
                    setChar(&charBuffer, &colorBuffer, x, "═", .stone)
                } else if (dx > 8 && dx < 16) && cycle == 23 {
                    setChar(&charBuffer, &colorBuffer, x, "∩", .stone)
                }
            }
            
            // Flying Buttresses on outer flanks
            if dx > 26 && dx < 36 && (y + dx) % 4 == 0 {
                setChar(&charBuffer, &colorBuffer, x, "╱", .shadow)
            }
        }
        
        // Manifest Memory Leaks / Fragmentation as Crumbling Gargoyles
        let gargoylePositions = [center - 25, center + 25, center - 14, center + 14]
        for pos in gargoylePositions where pos >= 0 && pos < width {
            if (y + pos) % 18 == 0 {
                let isCrumbling = fragmentation > 0.35 && Double.random(in: 0...1) < (fragmentation * 1.2)
                
                if isCrumbling {
                    // Crumbling gargoyle debris particles falling
                    let debris = ["░", "▒", "▓", "∴", "∵", "∷", "*", "."]
                    let particle = debris.randomElement()!
                    setChar(&charBuffer, &colorBuffer, pos, particle, .crumbling)
                    
                    // Dust dispersion adjacent
                    if pos + 1 < width { setChar(&charBuffer, &colorBuffer, pos + 1, "░", .dust) }
                    if pos - 1 >= 0 { setChar(&charBuffer, &colorBuffer, pos - 1, ".", .dust) }
                } else {
                    // Intact Gothic Gargoyle
                    setChar(&charBuffer, &colorBuffer, pos, "🦇", .gargoyle)
                }
            }
        }
        
        // Assembly of colored line string
        var lineResult = ""
        for i in 0..<width {
            lineResult += colorBuffer[i] + charBuffer[i]
        }
        return lineResult + Terminal.Color.reset.rawValue
    }
    
    private func setChar(_ chars: inout [String], _ colors: inout [String], _ index: Int, _ char: String, _ color: Terminal.Color) {
        chars[index] = char
        colors[index] = color.rawValue
    }
    
    // Simulate real-time memory pressure changes
    func simulateLeakPulse() {
        if Double.random(in: 0...1) < 0.25 {
            let size = 1024 * 1024 * Int.random(in: 4...16) // Allocate block
            if let ptr = malloc(size) {
                memset(ptr, 0xAF, size)
                simulatedLeakMemory.append(ptr)
            }
        }
        // Retain maximum of 30 blocks to avoid crashing system while driving up stats
        if simulatedLeakMemory.count > 30 {
            let oldPtr = simulatedLeakMemory.removeFirst()
            free(oldPtr)
        }
    }
    
    deinit {
        for ptr in simulatedLeakMemory { free(ptr) }
    }
}

// MARK: - Main Real-Time Execution Loop
Terminal.hideCursor()
Terminal.clearScreen()

let renderer = CathedralRenderer()
var currentY = 0
let screenWidth = 80
let screenHeight = 24

// Cleanup ANSI state on interrupt
signal(SIGINT) { _ in
    Terminal.showCursor()
    print("\u{001B}[0m\nCathedral collapsed into memory void.")
    exit(0)
}

print("\(Terminal.Color.statsText.rawValue)--- GOTHIC CATHEDRAL MEMORY MONITOR (Ctrl+C to Exit) ---\(Terminal.Color.reset.rawValue)")

while true {
    // 1. Fetch system memory metrics
    let stats = MemoryStats.current()
    
    // 2. Occasionally induce slight synthetic allocation to simulate live leaks
    renderer.simulateLeakPulse()
    
    // 3. Render cathedral frame buffer
    var frameLines: [String] = []
    for row in 0..<screenHeight {
        let line = renderer.generateLine(y: currentY + row, width: screenWidth, fragmentation: stats.fragmentationRatio)
        frameLines.append(line)
    }
    
    // 4. Draw HUD Overlay with System Memory Metrics
    let fragPercent = Int(stats.fragmentationRatio * 100)
    let hudColor = stats.fragmentationRatio > 0.5 ? Terminal.Color.crumbling.rawValue : Terminal.Color.statsText.rawValue
    let hud = "\(hudColor)║ RAM Free: \(Int(stats.freeMB))MB | Active: \(Int(stats.activeMB))MB | Fragmentation/Leak Severity: [\(String(repeating: "█", count: fragPercent / 5))\(String(repeating: "░", count: 20 - fragPercent / 5))] \(fragPercent)% ║\(Terminal.Color.reset.rawValue)"
    
    // Output screen frame
    print("\u{001B}[H") // Reposition cursor to top-left
    print(hud)
    for line in frameLines {
        print(line)
    }
    
    currentY += 1
    usleep(80_000) // ~12 FPS endless gothic scroll
}