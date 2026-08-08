import AppKit
import Foundation

// Memory Allocation Tracker: Fetches current system VM stats (wired, active, free)
struct MemoryMetrics {
    var activeRatio: Float
    var wiredRatio: Float
    var churnFactor: Float
}

func fetchMemoryMetrics() -> MemoryMetrics {
    var stats = vm_statistics64()
    var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
    let kerr = withUnsafeMutablePointer(to: &stats) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
            host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
        }
    }
    
    if kerr == KERN_SUCCESS {
        let active = Float(stats.active_count)
        let wired = Float(stats.wire_count)
        let free = Float(stats.free_count)
        let total = max(1.0, active + wired + free)
        let churn = Float((stats.faults ^ stats.cow_faults) & 0xFF) / 255.0
        return MemoryMetrics(activeRatio: active / total, wiredRatio: wired / total, churnFactor: churn)
    }
    return MemoryMetrics(activeRatio: 0.5, wiredRatio: 0.3, churnFactor: 0.2)
}

// Game Theory Strategy Types for autonomous pixel agents
enum Strategy: CaseIterable {
    case cooperate    // Shared palette integration
    case defect       // Hue takeover / high contrast
    case titForTat    // Mirrors dynamic neighbor behavior
    case opportunistic // Adapts based on memory allocation shifts
}

// Pixel Agent: Maintains RGB values, dynamic score, and game strategy
struct PixelAgent {
    var r: Float
    var g: Float
    var b: Float
    var strategy: Strategy
    var score: Float = 0
    var lastCooperated: Bool = true
}

// Generative Art Canvas: Manages agent grid, evolutionary payoffs, and rendering
class GenerativeCanvasView: NSView {
    let gridCols = 100
    let gridRows = 100
    private var grid: [PixelAgent]
    private var renderTimer: Timer?

    override init(frame frameRect: NSRect) {
        // Initialize agents with randomized color palettes and strategies
        grid = (0..<(gridCols * gridRows)).map { _ in
            PixelAgent(
                r: Float.random(in: 0...1),
                g: Float.random(in: 0...1),
                b: Float.random(in: 0...1),
                strategy: Strategy.allCases.randomElement()!
            )
        }
        super.init(frame: frameRect)

        // Drive interactive negotiation cycle at ~30 FPS
        renderTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            self?.negotiateAndEvolve()
            self?.needsDisplay = true
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    private func negotiateAndEvolve() {
        let mem = fetchMemoryMetrics()
        var updatedGrid = grid

        // Dynamic Payoff Matrix derived from live system memory pressure
        let reward = 1.0 + mem.activeRatio
        let temptation = 1.6 + mem.wiredRatio
        let sucker = -0.5 - mem.churnFactor
        let punishment = 0.1

        for y in 0..<gridRows {
            for x in 0..<gridCols {
                let idx = y * gridCols + x
                var agent = grid[idx]

                // Identify 4-orthogonal neighboring agents
                let neighbors = [
                    ((x + 1) % gridCols, y),
                    ((x - 1 + gridCols) % gridCols, y),
                    (x, (y + 1) % gridRows),
                    (x, (y - 1 + gridRows) % gridRows)
                ]

                var roundScore: Float = 0

                for (nx, ny) in neighbors {
                    let nIdx = ny * gridCols + nx
                    let neighbor = grid[nIdx]

                    let agentAction = decideAction(agent: agent, neighbor: neighbor, mem: mem)
                    let neighborAction = decideAction(agent: neighbor, neighbor: agent, mem: mem)

                    // Evaluate Prisoner's Dilemma Game Matrix
                    let payoff: Float
                    switch (agentAction, neighborAction) {
                    case (true, true): payoff = reward
                    case (true, false): payoff = sucker
                    case (false, true): payoff = temptation
                    case (false, false): payoff = punishment
                    }
                    roundScore += payoff

                    // Negotiate Color Palette according to interaction results & memory state
                    if agentAction && neighborAction {
                        // Mutual cooperation -> smooth color blending reflecting active memory state
                        agent.r += (neighbor.r - agent.r) * 0.08 * mem.activeRatio
                        agent.g += (neighbor.g - agent.g) * 0.08 * (1.0 - mem.wiredRatio)
                        agent.b += (neighbor.b - agent.b) * 0.08 * mem.churnFactor
                    } else if !agentAction && neighborAction {
                        // Defected while neighbor cooperated -> siphon neighbor hue
                        agent.r = neighbor.r * 0.8 + agent.r * 0.2
                        agent.g = min(1.0, agent.g + 0.05 * mem.wiredRatio)
                    } else if agentAction && !neighborAction {
                        // Exploited by neighbor -> shift hue away to resist domination
                        agent.b = max(0.0, agent.b - 0.05 * mem.churnFactor)
                    } else {
                        // Mutual defection -> inject noise proportional to system memory volatility
                        agent.r = (agent.r + 0.03 * mem.wiredRatio).truncatingRemainder(dividingBy: 1.0)
                        agent.g = (agent.g + 0.03 * mem.churnFactor).truncatingRemainder(dividingBy: 1.0)
                    }
                    
                    agent.lastCooperated = agentAction
                }

                agent.score += roundScore
                agent.r = min(1.0, max(0.0, agent.r))
                agent.g = min(1.0, max(0.0, agent.g))
                agent.b = min(1.0, max(0.0, agent.b))

                // Evolutionary step: copy strategy from highest performing neighbor
                if let strongest = neighbors.map({ grid[$0.1 * gridCols + $0.0] }).max(by: { $0.score < $1.score }),
                   strongest.score > agent.score {
                    agent.strategy = strongest.strategy
                }

                updatedGrid[idx] = agent
            }
        }
        grid = updatedGrid
    }

    private func decideAction(agent: PixelAgent, neighbor: PixelAgent, mem: MemoryMetrics) -> Bool {
        switch agent.strategy {
        case .cooperate: return true
        case .defect: return false
        case .titForTat: return neighbor.lastCooperated
        case .opportunistic: return mem.activeRatio > 0.45 ? neighbor.lastCooperated : false
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cellW = bounds.width / CGFloat(gridCols)
        let cellH = bounds.height / CGFloat(gridRows)

        for y in 0..<gridRows {
            for x in 0..<gridCols {
                let agent = grid[y * gridCols + x]
                let rect = CGRect(x: CGFloat(x) * cellW, y: CGFloat(y) * cellH, width: cellW, height: cellH)
                ctx.setFillColor(CGColor(red: CGFloat(agent.r), green: CGFloat(agent.g), blue: CGFloat(agent.b), alpha: 1.0))
                ctx.fill(rect)
            }
        }
    }
}

// Application Startup & Window Assembly
let app = NSApplication.shared
app.setActivationPolicy(.regular)

let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 800, height: 800),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
)

window.center()
window.title = "Generative Art Engine: Autonomous Pixel Agents & System Memory Game Theory"
let canvas = GenerativeCanvasView(frame: window.contentView!.bounds)
canvas.autoresizingMask = [.width, .height]
window.contentView?.addSubview(canvas)
window.makeKeyAndOrderFront(nil)

app.activate(ignoringOtherApps: true)
app.run()