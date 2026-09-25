import AppKit
import Foundation
import CoreGraphics

class ThermalStormView: NSView {
    private var timer: Timer?
    private var cpuLoad: Double = 0.5
    private var lightningActive: Bool = false
    private var lightningPath: [NSPoint] = []
    private var corruptionBuffer: NSBitmapImageRep?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupBuffer()
        startSimulation()
    }
    
    required init?(coder: Decoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupBuffer() {
        corruptionBuffer = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(bounds.width),
            pixelsHigh: Int(bounds.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    }
    
    private func startSimulation() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updateSystemMetrics()
            self.needsDisplay = true
        }
    }
    
    private func updateSystemMetrics() {
        var loadavg = [Double](repeating: 0.0, count: 3)
        if getloadavg(&loadavg, 3) != -1 {
            // Map system load average to a simulated thermal intensity scale (0.0 to 1.0)
            self.cpuLoad = min(max(loadavg[0] / 4.0, 0.1), 1.0)
        } else {
            self.cpuLoad = 0.3
        }
        
        // Thermal spike trigger condition summoning lightning bolts
        if self.cpuLoad > 0.60 && !self.lightningActive && Double.random(in: 0...1) < 0.07 {
            triggerLightning()
        }
    }
    
    private func triggerLightning() {
        lightningActive = true
        let startX = CGFloat.random(in: 50...(bounds.width - 50))
        var currentPoint = NSPoint(x: startX, y: bounds.height)
        lightningPath = [currentPoint]
        
        while currentPoint.y > 0 {
            let nextX = currentPoint.x + CGFloat.random(in: -25...25)
            let nextY = currentPoint.y - CGFloat.random(in: 10...45)
            currentPoint = NSPoint(x: nextX, y: nextY)
            lightningPath.append(currentPoint)
        }
        
        corruptPixelsAlongPath()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.lightningActive = false
        }
    }
    
    private func corruptPixelsAlongPath() {
        guard let buffer = corruptionBuffer else { return }
        
        // Permanently corrupt specific pixels along the lightning strike path
        for point in lightningPath {
            let x = Int(point.x)
            let y = Int(bounds.height - point.y)
            
            for dx in -4...4 {
                for dy in -4...4 {
                    let px = x + dx
                    let py = y + dy
                    if px >= 0 && px < buffer.pixelsWide && py >= 0 && py < buffer.pixelsHigh {
                        let glitchColor = NSColor(calibratedHue: CGFloat.random(in: 0...1), saturation: 0.9, brightness: 1.0, alpha: 1.0)
                        buffer.setColor(glitchColor, atX: px, y: py)
                    }
                }
            }
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let ctx = NSGraphicsContext.current?.cgContext
        
        // Dynamic background shifting from cool atmospheric blue to fiery thermal red based on CPU load
        let thermalColor = NSColor(
            calibratedRed: CGFloat(0.05 + cpuLoad * 0.6),
            green: CGFloat(0.05 + (1.0 - cpuLoad) * 0.15),
            blue: CGFloat(0.25 * (1.0 - cpuLoad)),
            alpha: 1.0
        )
        thermalColor.setFill()
        bounds.fill()
        
        // Render the permanent pixel corruption buffer
        if let image = corruptionBuffer?.cgImage {
            ctx?.draw(image, in: bounds)
        }
        
        // Render active lightning flash effect
        if lightningActive {
            NSColor.white.setStroke()
            let path = NSBezierPath()
            if let first = lightningPath.first {
                path.move(to: first)
                for point in lightningPath.dropFirst() {
                    path.line(to: point)
                }
            }
            path.lineWidth = 3.5
            path.stroke()
            
            NSColor(white: 1.0, alpha: CGFloat(cpuLoad * 0.5)).setFill()
            bounds.fill()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Thermal Thunderstorm & Pixel Corruption Engine"
        window.contentView = ThermalStormView(frame: window.contentView!.bounds)
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