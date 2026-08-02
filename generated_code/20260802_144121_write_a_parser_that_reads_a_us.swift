import Cocoa
import Foundation

// MARK: - History Parser & Data Model
struct CommandNode {
    let command: String
    let wasSuccessful: Bool
}

class HistoryParser {
    static func loadHistory() -> [CommandNode] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let possiblePaths = [
            home.appendingPathComponent(".zsh_history"),
            home.appendingPathComponent(".bash_history")
        ]
        
        var rawLines: [String] = []
        for path in possiblePaths {
            if let content = try? String(contentsOf: path, encoding: .isoLatin1) {
                rawLines = content.components(separatedBy: .newlines)
                break
            }
        }
        
        if rawLines.isEmpty {
            // Fallback synthetic history if local shell history file is unavailable
            rawLines = [
                "git status", "git add .", "git commit -m 'feat'", "git push",
                "swift build", "swift test", "swift run", "make build",
                "sl", "gut status", "swift build --error", "npm run dev",
                "cd src", "ls -la", "cat README.md", "vim main.swift",
                "git status", "git diff", "git commit", "git push",
                "dockr run", "docker ps", "docker build -t app .",
                "curl localhost:8080", "grep -r 'fix' .", "python3 -m unittest"
            ]
        }
        
        return rawLines.compactMap { line -> CommandNode? in
            let cleaned = line.replacingOccurrences(of: "^:[0-9]+:[0-9]+;", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return nil }
            
            // Heuristic identifying syntax typos/errors vs clean command chains
            let knownTypos = ["sl", "gut", "dockr", "gerp", "co", "gti"]
            let firstWord = cleaned.components(separatedBy: .whitespaces).first?.lowercased() ?? ""
            let isError = knownTypos.contains(firstWord) || cleaned.contains("--error") || cleaned.contains("err")
            
            return CommandNode(command: cleaned, wasSuccessful: !isError)
        }
    }
}

// MARK: - Topographical Map Terrain Matrix
class MapTerrain {
    let width: Int = 80
    let height: Int = 80
    var grid: [[Float]] // Heightmap elevation matrix
    
    init() {
        self.grid = Array(repeating: Array(repeating: 0.0, count: width), count: height)
    }
    
    func generate(from history: [CommandNode]) {
        grid = Array(repeating: Array(repeating: 0.15, count: width), count: height)
        
        var x = width / 2
        var y = height / 2
        var chainLength = 0
        
        for (idx, node) in history.prefix(350).enumerated() {
            // Spiral walking algorithm across grid
            let angle = Double(idx) * 0.45
            x = max(2, min(width - 3, x + Int(cos(angle) * 3.2)))
            y = max(2, min(height - 3, y + Int(sin(angle) * 3.2)))
            
            if node.wasSuccessful {
                chainLength += 1
                let elevation = Float(chainLength) * 0.18 + 0.3
                applyVolcanicElevation(atX: x, y: y, radius: 4, heightIncrement: elevation)
            } else {
                chainLength = 0
                // Syntax errors erode deep river valleys into the heightmap
                applyErosionValley(atX: x, y: y, radius: 5, depth: 0.45)
            }
        }
    }
    
    private func applyVolcanicElevation(atX cx: Int, y cy: Int, radius: Int, heightIncrement: Float) {
        for dx in -radius...radius {
            for dy in -radius...radius {
                let rx = cx + dx
                let ry = cy + dy
                if rx >= 0 && rx < width && ry >= 0 && ry < height {
                    let dist = sqrt(Float(dx * dx + dy * dy))
                    if dist <= Float(radius) {
                        let factor = (1.0 - dist / Float(radius))
                        grid[ry][rx] += heightIncrement * factor * factor
                        grid[ry][rx] = min(grid[ry][rx], 2.5) // Peak height cap
                    }
                }
            }
        }
    }
    
    private func applyErosionValley(atX cx: Int, y cy: Int, radius: Int, depth: Float) {
        for dx in -radius...radius {
            for dy in -radius...radius {
                let rx = cx + dx
                let ry = cy + dy
                if rx >= 0 && rx < width && ry >= 0 && ry < height {
                    let dist = sqrt(Float(dx * dx + dy * dy))
                    if dist <= Float(radius) {
                        let factor = (1.0 - dist / Float(radius))
                        grid[ry][rx] -= depth * factor
                        grid[ry][rx] = max(grid[ry][rx], -0.8) // Deep valley basin
                    }
                }
            }
        }
    }
}

// MARK: - Interactive Isometric Topo Map Renderer
class TopoMapView: NSView {
    var terrain: MapTerrain?
    var rotationAngle: CGFloat = 0.0
    var timer: Timer?
    var animationTime: CGFloat = 0.0
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupAnimation()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAnimation()
    }
    
    private func setupAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.rotationAngle += 0.012
            self?.animationTime += 0.05
            self?.needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let terrain = terrain else { return }
        
        // Deep space/volcanic night background
        NSColor(red: 0.04, green: 0.06, blue: 0.1, alpha: 1.0).setFill()
        dirtyRect.fill()
        
        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()
        
        let centerX = bounds.midX
        let centerY = bounds.midY - 40
        
        let scaleX: CGFloat = 7.5
        let scaleY: CGFloat = 3.8
        let heightMultiplier: CGFloat = 32.0
        
        let cosA = cos(rotationAngle)
        let sinA = sin(rotationAngle)
        
        let w = terrain.width
        let h = terrain.height
        
        // Render 3D isometric terrain quad mesh
        for y in 0..<(h - 1) {
            for x in 0..<(w - 1) {
                let h0 = CGFloat(terrain.grid[y][x])
                let h1 = CGFloat(terrain.grid[y][x + 1])
                let h2 = CGFloat(terrain.grid[y + 1][x + 1])
                let h3 = CGFloat(terrain.grid[y + 1][x])
                
                let p0 = project(x: CGFloat(x) - CGFloat(w)/2, y: CGFloat(y) - CGFloat(h)/2, z: h0, cosA: cosA, sinA: sinA, scaleX: scaleX, scaleY: scaleY, hMult: heightMultiplier, center: CGPoint(x: centerX, y: centerY))
                let p1 = project(x: CGFloat(x + 1) - CGFloat(w)/2, y: CGFloat(y) - CGFloat(h)/2, z: h1, cosA: cosA, sinA: sinA, scaleX: scaleX, scaleY: scaleY, hMult: heightMultiplier, center: CGPoint(x: centerX, y: centerY))
                let p2 = project(x: CGFloat(x + 1) - CGFloat(w)/2, y: CGFloat(y + 1) - CGFloat(h)/2, z: h2, cosA: cosA, sinA: sinA, scaleX: scaleX, scaleY: scaleY, hMult: heightMultiplier, center: CGPoint(x: centerX, y: centerY))
                let p3 = project(x: CGFloat(x) - CGFloat(w)/2, y: CGFloat(y + 1) - CGFloat(h)/2, z: h3, cosA: cosA, sinA: sinA, scaleX: scaleX, scaleY: scaleY, hMult: heightMultiplier, center: CGPoint(x: centerX, y: centerY))
                
                let path = NSBezierPath()
                path.move(to: p0)
                path.line(to: p1)
                path.line(to: p2)
                path.line(to: p3)
                path.close()
                
                let avgHeight = (h0 + h1 + h2 + h3) / 4.0
                let color = colorForElevation(avgHeight, animationTime: animationTime)
                color.setFill()
                path.fill()
                
                // Topographic grid wireframe overlay
                NSColor(white: 1.0, alpha: 0.06).setStroke()
                path.lineWidth = 0.5
                path.stroke()
            }
        }
        
        context?.restoreGState()
        drawHUD()
    }
    
    private func project(x: CGFloat, y: CGFloat, z: CGFloat, cosA: CGFloat, sinA: CGFloat, scaleX: CGFloat, scaleY: CGFloat, hMult: CGFloat, center: CGPoint) -> CGPoint {
        let rx = x * cosA - y * sinA
        let ry = x * sinA + y * cosA
        let isoX = (rx - ry) * scaleX
        let isoY = (rx + ry) * scaleY / 2.0 + (z * hMult)
        return CGPoint(x: center.x + isoX, y: center.y + isoY)
    }
    
    private func colorForElevation(_ z: CGFloat, animationTime: CGFloat) -> NSColor {
        if z < 0 {
            // Deep river valley carved by syntax errors (Cyan/Blue animated water flow)
            let waterPulse = sin(animationTime * 2.5 + z * 4.0) * 0.08
            let depth = min(1.0, max(0.0, -z))
            return NSColor(red: 0.0, green: 0.35 + depth * 0.35 + waterPulse, blue: 0.75 + depth * 0.2, alpha: 0.95)
        } else if z < 0.35 {
            // Lowland plains (Lush green)
            return NSColor(red: 0.12, green: 0.45 + z * 0.3, blue: 0.22, alpha: 0.9)
        } else if z < 0.95 {
            // Mountainous terrain (Stone / Slate brown)
            return NSColor(red: 0.52 + z * 0.15, green: 0.42, blue: 0.32, alpha: 0.9)
        } else {
            // Volcanic mountain peaks built by command chains (Glowing Orange/Lava Red)
            let lavaPulse = (sin(animationTime * 4.0 + z * 5.0) + 1.0) * 0.12
            let magmaIntensity = min(1.0, (z - 0.95) / 1.0)
            return NSColor(red: 0.95 + lavaPulse, green: 0.25 + (1.0 - magmaIntensity) * 0.3, blue: 0.05, alpha: 0.98)
        }
    }
    
    private func drawHUD() {
        let title = "🌋 SHELL HISTORY TOPOGRAPHICAL MAP"
        let legend = """
        • Volcanic Mountain Ranges: Frequent Successful Command Chains
        • Deep River Valleys: Eroded by Syntax Errors & Typos
        • Animation: Rotating Isometric Mesh
        """
        
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .bold),
            .foregroundColor: NSColor.orange
        ]
        let legendAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.cyan
        ]
        
        title.draw(at: CGPoint(x: 20, y: bounds.height - 35), withAttributes: titleAttrs)
        legend.draw(at: CGPoint(x: 20, y: bounds.height - 85), withAttributes: legendAttrs)
    }
}

// MARK: - Application Lifecycle
class AppController: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let frame = NSRect(x: 0, y: 0, width: 950, height: 720)
        
        window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Shell History Topographical Map"
        window.isReleasedWhenClosed = false
        
        let topoView = TopoMapView(frame: frame)
        let history = HistoryParser.loadHistory()
        let terrain = MapTerrain()
        terrain.generate(from: history)
        
        topoView.terrain = terrain
        window.contentView = topoView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

let application = NSApplication.shared
let controller = AppController()
application.delegate = controller
application.run()