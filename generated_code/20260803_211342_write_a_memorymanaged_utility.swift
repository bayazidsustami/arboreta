import AppKit
import Foundation
import CoreGraphics

// MARK: - Kernel Log Processing Engine

enum LogEvent {
    case memoryLeak(address: String, size: Int)
    case deadlock(threadA: Int, threadB: Int)
    case normalActivity(subsystem: String)
}

// Simulates real-time kernel debug log streams (e.g. system logs / vm events)
class LogStreamSimulator {
    private let subsystems = ["kernel.vm", "kernel.sched", "kernel.io", "kernel.ipc", "kernel.net"]
    
    func fetchNextLog() -> LogEvent {
        let roll = Int.random(in: 0...100)
        if roll < 18 {
            let addr = String(format: "0x%08X", UInt32.random(in: 0x10000000...0x7FFFFFFF))
            return .memoryLeak(address: addr, size: Int.random(in: 64...4096))
        } else if roll < 30 {
            let t1 = Int.random(in: 100...999)
            let t2 = Int.random(in: 100...999)
            return .deadlock(threadA: t1, threadB: t2)
        } else {
            return .normalActivity(subsystem: subsystems.randomElement()!)
        }
    }
}

// MARK: - Visual Generative Entities

class GardenEntity {
    var position: CGPoint
    var age: CGFloat = 0.0
    var maxAge: CGFloat = 100.0
    var isDead: Bool { age >= maxAge }
    
    init(position: CGPoint) {
        self.position = position
    }
    
    func update() {
        age += 0.2
    }
    
    func draw(in context: CGContext) {}
}

// Normal system events bloom organic flowering flora
class FlowerEntity: GardenEntity {
    var petalColor: NSColor
    var stemHeight: CGFloat = 0
    var targetHeight: CGFloat
    var petalCount: Int
    
    override init(position: CGPoint) {
        self.targetHeight = CGFloat.random(in: 30...80)
        self.petalCount = Int.random(in: 5...8)
        let colors: [NSColor] = [.systemPink, .systemTeal, .systemGreen, .systemYellow, .systemPurple]
        self.petalColor = colors.randomElement()!
        super.init(position: position)
    }
    
    override func update() {
        super.update()
        if stemHeight < targetHeight {
            stemHeight += 0.5
        }
    }
    
    override func draw(in context: CGContext) {
        context.saveGState()
        
        // Organic swaying stem
        context.setStrokeColor(NSColor.systemGreen.cgColor)
        context.setLineWidth(2.0)
        context.move(to: position)
        let top = CGPoint(x: position.x + sin(age * 0.05) * 5, y: position.y + stemHeight)
        context.addLine(to: top)
        context.strokePath()
        
        // Blooming Petals
        let scale = min(1.0, age / 20.0)
        let radius: CGFloat = 12.0 * scale
        context.setFillColor(petalColor.cgColor)
        
        for i in 0..<petalCount {
            let angle = (CGFloat(i) / CGFloat(petalCount)) * .pi * 2 + (age * 0.01)
            let petalCenter = CGPoint(
                x: top.x + cos(angle) * (radius * 0.8),
                y: top.y + sin(angle) * (radius * 0.8)
            )
            context.fillEllipse(in: CGRect(x: petalCenter.x - radius/2, y: petalCenter.y - radius/2, width: radius, height: radius))
        }
        
        // Flower Center
        context.setFillColor(NSColor.systemYellow.cgColor)
        context.fillEllipse(in: CGRect(x: top.x - radius/3, y: top.y - radius/3, width: radius*0.66, height: radius*0.66))
        
        context.restoreGState()
    }
}

// Memory Leaks sprout invasive bioluminescent fungi and spores
class FungusEntity: GardenEntity {
    var capRadius: CGFloat = 5.0
    var maxRadius: CGFloat
    var address: String
    var spores: [CGPoint] = []
    
    init(position: CGPoint, address: String, size: Int) {
        self.address = address
        self.maxRadius = min(50.0, CGFloat(size) / 50.0 + 15.0)
        super.init(position: position)
        self.maxAge = 220.0
    }
    
    override func update() {
        super.update()
        if capRadius < maxRadius {
            capRadius += 0.25
        }
        // Emit invasive spores as memory leaks accumulate
        if Int(age) % 12 == 0 && spores.count < 15 {
            let offset = CGPoint(x: CGFloat.random(in: -35...35), y: CGFloat.random(in: 10...50))
            spores.append(CGPoint(x: position.x + offset.x, y: position.y + offset.y))
        }
    }
    
    override func draw(in context: CGContext) {
        context.saveGState()
        
        // Fungal Stalk
        context.setStrokeColor(NSColor(red: 0.85, green: 0.2, blue: 0.55, alpha: 0.8).cgColor)
        context.setLineWidth(3.5)
        context.move(to: position)
        let capCenter = CGPoint(x: position.x, y: position.y + capRadius * 1.3)
        context.addLine(to: capCenter)
        context.strokePath()
        
        // Invasive Mushroom Cap
        let capRect = CGRect(x: capCenter.x - capRadius, y: capCenter.y - capRadius * 0.6, width: capRadius * 2, height: capRadius * 1.2)
        context.setFillColor(NSColor(red: 0.95, green: 0.15, blue: 0.45, alpha: 0.9).cgColor)
        context.fillEllipse(in: capRect)
        
        // Spore cloud particles
        context.setFillColor(NSColor(red: 1.0, green: 0.4, blue: 0.7, alpha: 0.6).cgColor)
        for spore in spores {
            context.fillEllipse(in: CGRect(x: spore.x - 2, y: spore.y - 2, width: 4, height: 4))
        }
        
        context.restoreGState()
    }
}

// Thread Deadlocks crystallize into rigid, refraction-like glass structures
class GlassCrystalEntity: GardenEntity {
    var height: CGFloat = 0
    var maxHeight: CGFloat
    var facets: Int
    var threadPair: (Int, Int)
    
    init(position: CGPoint, threadA: Int, threadB: Int) {
        self.threadPair = (threadA, threadB)
        self.maxHeight = CGFloat.random(in: 50...110)
        self.facets = Int.random(in: 4...7)
        super.init(position: position)
        self.maxAge = 260.0
    }
    
    override func update() {
        super.update()
        if height < maxHeight {
            height += 0.9
        }
    }
    
    override func draw(in context: CGContext) {
        context.saveGState()
        
        let width: CGFloat = 18.0
        let apex = CGPoint(x: position.x, y: position.y + height)
        
        // Render crystalline glass facets with specular highlights
        for i in 0..<facets {
            let offset = (CGFloat(i) - CGFloat(facets)/2.0) * (width / CGFloat(facets))
            let path = CGMutablePath()
            path.move(to: position)
            path.addLine(to: CGPoint(x: position.x + offset, y: position.y + height * 0.75))
            path.addLine(to: apex)
            path.closeSubpath()
            
            let alpha = 0.25 + 0.5 * (CGFloat(i) / CGFloat(facets))
            context.setFillColor(NSColor(red: 0.75, green: 0.92, blue: 1.0, alpha: alpha).cgColor)
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.8).cgColor)
            context.setLineWidth(0.8)
            
            context.addPath(path)
            context.drawPath(using: .fillStroke)
        }
        
        context.restoreGState()
    }
}

// MARK: - Generative Canvas View & Memory Management Loop

class GenerativeGardenView: NSView {
    private var entities: [GardenEntity] = []
    private let logEngine = LogStreamSimulator()
    private var timer: Timer?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        startSimulation()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        startSimulation()
    }
    
    private func startSimulation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    private func tick() {
        // Parse incoming log activity periodically
        if Int.random(in: 0...10) < 4 {
            parseAndSpawnEntity()
        }
        
        // Automatic memory management: update entities and clean up expired objects
        entities.forEach { $0.update() }
        entities.removeAll { $0.isDead }
        
        needsDisplay = true
    }
    
    private func parseAndSpawnEntity() {
        let log = logEngine.fetchNextLog()
        let spawnX = CGFloat.random(in: 60...(bounds.width - 60))
        let spawnPos = CGPoint(x: spawnX, y: 50)
        
        switch log {
        case .normalActivity:
            entities.append(FlowerEntity(position: spawnPos))
        case .memoryLeak(let address, let size):
            entities.append(FungusEntity(position: spawnPos, address: address, size: size))
        case .deadlock(let threadA, let threadB):
            entities.append(GlassCrystalEntity(position: spawnPos, threadA: threadA, threadB: threadB))
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Midnight cybernetic landscape gradient
        let bgGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor(red: 0.04, green: 0.04, blue: 0.09, alpha: 1.0).cgColor,
                NSColor(red: 0.01, green: 0.01, blue: 0.03, alpha: 1.0).cgColor
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        context.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: bounds.height), end: CGPoint(x: 0, y: 0), options: [])
        
        // Ground line anchor
        context.setStrokeColor(NSColor(red: 0.2, green: 0.35, blue: 0.25, alpha: 0.6).cgColor)
        context.setLineWidth(2.0)
        context.move(to: CGPoint(x: 0, y: 50))
        context.addLine(to: CGPoint(x: bounds.width, y: 50))
        context.strokePath()
        
        // Draw evolving generative objects
        for entity in entities {
            entity.draw(in: context)
        }
        
        // Active Dashboard HUD
        let statusText = "🌿 Kernel Log Visual Garden | Managed Entities: \(entities.count)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold),
            .foregroundColor: NSColor.cyan
        ]
        statusText.draw(at: CGPoint(x: 20, y: bounds.height - 35), withAttributes: attributes)
    }
}

// MARK: - Runnable macOS App Setup

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let windowSize = NSSize(width: 960, height: 600)
        let screenSize = NSScreen.main?.frame.size ?? windowSize
        let rect = NSRect(
            x: (screenSize.width - windowSize.width) / 2,
            y: (screenSize.height - windowSize.height) / 2,
            width: windowSize.width,
            height: windowSize.height
        )
        
        window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Kernel Debug Log Generative Garden"
        
        let gardenView = GenerativeGardenView(frame: rect)
        window.contentView = gardenView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()