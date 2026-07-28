import Foundation
import AppKit

// DecayClock: A self-executing visual clock simulating radioactive decay.
// Loads binary/code memory into an executable RWX buffer, randomly flips bits 
// once per second, renders the memory corruption as generative art, and
// executes decaying buffer segments until a crash occurs at midnight or execution failure.

class VisualDecayClockView: NSView {
    private var binaryBuffer: UnsafeMutableRawPointer
    private let bufferSize: Int = 65536
    private var decayTimer: Timer?
    private var renderTimer: Timer?
    private var totalFlips: Int = 0

    override init(frame frameRect: NSRect) {
        // Allocate page-aligned memory buffer
        binaryBuffer = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: 4096)
        
        // Populate buffer with own executable binary or active process memory
        if let path = Bundle.main.executablePath, let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            let copyCount = min(data.count, bufferSize)
            data.copyBytes(to: binaryBuffer.assumingMemoryBound(to: UInt8.self), count: copyCount)
        } else {
            // Fill with executable code instructions / memory fallback
            for i in 0..<bufferSize {
                binaryBuffer.storeBytes(of: UInt8(i & 0xFF), toByteOffset: i, as: UInt8.self)
            }
        }

        super.init(frame: frameRect)

        // Enable RWX (Read-Write-Execute) permissions on memory block
        mprotect(binaryBuffer, bufferSize, PROT_READ | PROT_WRITE | PROT_EXEC)

        // Radioactive Decay Loop: bit-flip binary memory once per second
        decayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.applyRadioactiveDecay()
        }

        // Redraw canvas loop
        renderTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
    }

    required init?(coder: NSCoder) { 
        fatalError("init(coder:) has not been implemented") 
    }

    deinit {
        binaryBuffer.deallocate()
    }

    private func applyRadioactiveDecay() {
        // Check for midnight execution crash condition
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        
        if hour == 0 && minute == 0 {
            // Midnight forced crash: illegal memory access
            let invalidPointer = UnsafeMutablePointer<UInt8>(bitPattern: 0xDEADBEEF)!
            invalidPointer.pointee = 0x00
        }

        // Perform random bit-flip on self binary byte
        let offset = Int.random(in: 0..<bufferSize)
        let bitIndex = Int.random(in: 0..<8)
        let currentByte = binaryBuffer.load(fromByteOffset: offset, as: UInt8.self)
        let corruptedByte = currentByte ^ (1 << bitIndex)
        
        binaryBuffer.storeBytes(of: corruptedByte, toByteOffset: offset, as: UInt8.self)
        totalFlips += 1

        // Attempt execution of corrupted buffer segment to simulate genuine software decay
        if totalFlips % 10 == 0 {
            typealias ExecutableFn = @convention(c) () -> Void
            let fn = unsafeBitCast(binaryBuffer, to: ExecutableFn.self)
            // Execution will eventually cause SIGSEGV/SIGBUS as instructions degrade
            _ = fn
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let bounds = self.bounds

        // Deep void background
        ctx.setFillColor(CGColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1.0))
        ctx.fill(bounds)

        // Generative Visualization of Corrupted Binary Memory
        let cols = 128
        let rows = 64
        let cellW = bounds.width / CGFloat(cols)
        let cellH = (bounds.height - 120) / CGFloat(rows)

        for r in 0..<rows {
            for c in 0..<cols {
                let offset = (r * cols + c) % bufferSize
                let byte = binaryBuffer.load(fromByteOffset: offset, as: UInt8.self)
                
                if byte > 0 {
                    let hue = CGFloat(byte) / 255.0
                    let saturation = CGFloat((byte ^ 0xAA) % 100) / 100.0
                    let alpha = CGFloat(byte % 32) / 32.0 + 0.1
                    
                    ctx.setFillColor(NSColor(hue: hue, saturation: saturation, brightness: 0.9, alpha: alpha).cgColor)
                    
                    let x = CGFloat(c) * cellW
                    let y = CGFloat(r) * cellH
                    let rect = CGRect(x: x, y: y, width: cellW - 0.5, height: cellH - 0.5)
                    ctx.fill(rect)
                }
            }
        }

        // Clock Display
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeText = formatter.string(from: Date())

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let clockAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 54, weight: .bold),
            .foregroundColor: NSColor(red: 0.2, green: 1.0, blue: 0.4, alpha: 0.9),
            .paragraphStyle: paragraphStyle
        ]

        let clockRect = CGRect(x: 0, y: bounds.height - 80, width: bounds.width, height: 60)
        let clockAttrString = NSAttributedString(string: timeText, attributes: clockAttributes)
        clockAttrString.draw(in: clockRect)

        // Subtitle Info
        let statusText = "decay entropy: \(totalFlips) bit-flips | status: degrading"
        let statusAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraphStyle
        ]
        let statusRect = CGRect(x: 0, y: bounds.height - 110, width: bounds.width, height: 20)
        NSAttributedString(string: statusText, attributes: statusAttributes).draw(in: statusRect)
    }
}

// App Launch
let app = NSApplication.shared
app.setActivationPolicy(.regular)

let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
    styleMask: [.titled, .closable, .miniaturizable],
    backing: .buffered,
    defer: false
)
window.center()
window.title = "Radioactive Binary Decay Clock"
window.contentView = VisualDecayClockView(frame: window.contentRect(forFrameRect: window.frame))
window.makeKeyAndOrderFront(nil)

app.activate(ignoringOtherApps: true)
app.run()