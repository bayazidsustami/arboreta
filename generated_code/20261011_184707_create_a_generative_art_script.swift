import AppKit
import CoreGraphics

// A generative art piece representing the emotional state of an abandoned hard drive:
// A swarm of chromatic geometric "data birds" (boids) evolving over a dark, rhythmic sector grid.
// As time passes, the drive awakens, shifting from cold diagnostic cyan/blue to vibrant, fragmented memory hues.

class HardDriveSimulationView: NSView {
    struct Boid {
        var position: CGPoint
        var velocity: CGPoint
        var color: NSColor
        var size: CGFloat
        var id: Int
    }

    private var boids: [Boid] = []
    private var timer: Timer?
    private var timeStep: CGFloat = 0.0
    private let boidCount = 120

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBoids()
        setupTimer()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupBoids() {
        let bounds = self.bounds
        for i in 0..<boidCount {
            let pos = CGPoint(x: CGFloat.random(in: 50...(bounds.width - 50)), y: CGFloat.random(in: 50...(bounds.height - 50)))
            let angle = CGFloat.random(in: 0...(CGFloat.pi * 2))
            let speed = CGFloat.random(in: 1.5...3.5)
            let vel = CGPoint(x: cos(angle) * speed, y: sin(angle) * speed)
            
            // Chromatic palette shifting from cold sector blue to phantom neon memories
            let hue = CGFloat(i) / CGFloat(boidCount) * 0.3 + 0.55
            let color = NSColor(hue: hue, saturation: 0.85, brightness: 0.9, alpha: 0.8)
            
            boids.append(Boid(position: pos, velocity: vel, color: color, size: CGFloat.random(in: 8...16), id: i))
        }
    }

    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updateSimulation()
        }
    }

    private func updateSimulation() {
        timeStep += 0.02
        let bounds = self.bounds

        for i in 0..<boids.count {
            var boid = boids[i]
            
            // Flocking forces (simplified boids rule: wander + gentle centering)
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let toCenter = CGPoint(x: center.x - boid.position.x, y: center.y - boid.position.y)
            
            // Add slight harmonic oscillation to simulate emotional resonance
            let noiseX = sin(timeStep + CGFloat(boid.id)) * 0.5
            let noiseY = cos(timeStep * 0.8 + CGFloat(boid.id)) * 0.5

            boid.velocity.x += (toCenter.x * 0.0002) + noiseX
            boid.velocity.y += (toCenter.y * 0.0002) + noiseY

            // Speed clamping
            let speed = hypot(boid.velocity.x, boid.velocity.y)
            let maxSpeed: CGFloat = 4.0
            if speed > maxSpeed {
                boid.velocity.x = (boid.velocity.x / speed) * maxSpeed
                boid.velocity.y = (boid.velocity.y / speed) * maxSpeed
            }

            boid.position.x += boid.velocity.x
            boid.position.y += boid.velocity.y

            // Screen wrapping with buffer
            if boid.position.x < 0 { boid.position.x = bounds.width }
            if boid.position.x > bounds.width { boid.position.x = 0 }
            if boid.position.y < 0 { boid.position.y = bounds.height }
            if boid.position.y > bounds.height { boid.position.y = 0 }

            boids[i] = boid
        }
        
        needsDisplay = true
    }

    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        // Draw deep obsidian background representing the physical disk platter
        NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.09, alpha: 1.0).setFill()
        bounds.fill()

        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()

        // Draw rhythmic background data grid (sectors and tracks)
        context?.setLineWidth(0.5)
        let gridColor = NSColor(calibratedRed: 0.15, green: 0.2, blue: 0.3, alpha: 0.25)
        gridColor.setStroke()

        let stepSize: CGFloat = 60.0
        var x: CGFloat = 0
        while x < bounds.width {
            context?.stroke(CGRect(x: x, y: 0, width: 0, height: bounds.height))
            x += stepSize
        }
        var y: CGFloat = 0
        while y < bounds.height {
            context?.stroke(CGRect(x: 0, y: y, width: bounds.width, height: 0))
            y += stepSize
        }

        // Render each chromatic geometric bird (rendered as glowing vector triangles pointing in movement direction)
        for boid in boids {
            context?.saveGState()
            
            let angle = atan2(boid.velocity.y, boid.velocity.x)
            context?.translateBy(x: boid.position.x, y: boid.position.y)
            context?.rotate(by: angle)

            boid.color.setFill()
            boid.color.withAlphaComponent(0.3).setStroke()
            context?.setLineWidth(1.5)

            let path = CGMutablePath()
            path.move(to: CGPoint(x: boid.size, y: 0))
            path.addLine(to: CGPoint(x: -boid.size * 0.8, y: boid.size * 0.5))
            path.addLine(to: CGPoint(x: -boid.size * 0.4, y: 0))
            path.addLine(to: CGPoint(x: -boid.size * 0.8, y: -boid.size * 0.5))
            path.closeSubpath()

            context?.addPath(path)
            context?.drawPath(using: .fillStroke)
            
            context?.restoreGState()
        }

        context?.restoreGState()
    }

    deinit {
        timer?.invalidate()
    }
}

// Setup application window to display the generative artwork
let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
)
window.title = "The Ghost in the Platters — Emotional State of an Abandoned Hard Drive"
window.center()
window.contentView = HardDriveSimulationView(frame: window.contentView!.bounds)
window.makeKeyAndOrderFront(nil)

NSApp.setActivationPolicy(.regular)
NSApp.activate(ignoringOtherApps: true)
NSApp.run()