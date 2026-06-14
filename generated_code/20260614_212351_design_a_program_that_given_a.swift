import Foundation
import AVFoundation
import AppKit

// MARK: - Deterministic Seed
let seed: UInt64 = 0xDEADBEEF // change for reproducible sessions
var rng = SeededRandomNumberGenerator(seed: seed)

// Simple seeded RNG
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

// MARK: - Braille Helpers
let brailleOffset = 0x2800
func brailleChar(from bits: UInt8) -> String {
    let code = brailleOffset + Int(bits)
    return String(UnicodeScalar(code)!)
}

// MARK: - Langton's Ant CA
struct Ant {
    var x: Int
    var y: Int
    var dir: Int // 0=up,1=right,2=down,3=left
}
let dirs = [(0,-1),(1,0),(0,1),(-1,0)]

class Lattice {
    var width: Int
    var height: Int
    var cells: [[UInt8]] // 0 or 1 for ant rule
    var ant: Ant
    
    init(w:Int, h:Int) {
        width = w; height = h
        cells = Array(repeating: Array(repeating: 0, count: w), count: h)
        ant = Ant(x: w/2, y: h/2, dir: 0)
    }
    
    func step() {
        let cx = ant.x, cy = ant.y
        let state = cells[cy][cx]
        ant.dir = (ant.dir + (state == 0 ? 1 : -1) + 4) % 4
        cells[cy][cx] = state ^ 1
        let (dx,dy) = dirs[ant.dir]
        ant.x = (cx + dx + width) % width
        ant.y = (cy + dy + height) % height
    }
}

// MARK: - Audio Capture & FFT (simple magnitude)
class AudioAnalyzer: NSObject, AVAudioRecorderDelegate {
    var maxAmplitude: Float = 0.0
    private var engine = AVAudioEngine()
    private var fftSize: Int = 1024
    private var buffer = [Float](repeating: 0, count: 1024)
    
    override init() {
        super.init()
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: format) { [weak self] buf, _ in
            guard let strong = self else { return }
            let channelData = buf.floatChannelData![0]
            var maxVal: Float = 0
            for i in 0..<Int(buf.frameLength) {
                let v = abs(channelData[i])
                if v > maxVal { maxVal = v }
            }
            strong.maxAmplitude = maxVal
        }
        try? engine.start()
    }
}

// MARK: - Video Capture
class VideoCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var latestImage: NSImage?
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "video.queue")
    
    override init() {
        super.init()
        session.sessionPreset = .low
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: queue)
        session.addOutput(output)
        session.startRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let cv = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ci = CIImage(cvPixelBuffer: cv)
        let rep = NSCIImageRep(ciImage: ci)
        let img = NSImage(size: rep.size)
        img.addRepresentation(rep)
        latestImage = img
    }
}

// MARK: - Main Loop
let termWidth = 80
let termHeight = 24
let lattice = Lattice(w: termWidth, h: termHeight)
let audio = AudioAnalyzer()
let video = VideoCapture()

func render() {
    lattice.step()
    guard let img = video.latestImage else { return }
    let resized = img.resized(to: NSSize(width: termWidth, height: termHeight))
    guard let bitmap = resized.bitmapRepresentation() else { return }
    
    var lines: [String] = []
    for y in 0..<termHeight {
        var line = ""
        for x in 0..<termWidth {
            let idx = y * termWidth + x
            let pixel = bitmap[idx]
            // simple brightness from pixel (assuming RGBA)
            let r = Float((pixel >> 24) & 0xFF)
            let g = Float((pixel >> 16) & 0xFF)
            let b = Float((pixel >> 8) & 0xFF)
            let brightness = (r + g + b) / (3*255)
            // combine with audio amplitude
            let amp = audio.maxAmplitude
            var bits: UInt8 = 0
            if brightness > 0.5 { bits |= 0b0001 }
            if amp > 0.3 { bits |= 0b0010 }
            // include CA state
            let ca = lattice.cells[y][x]
            if ca == 1 { bits |= 0b0100 }
            line.append(brailleChar(from: bits))
        }
        lines.append(line)
    }
    // clear terminal and print
    print("\u{001B}[2J")
    for l in lines { print(l) }
}

// Helper extensions
extension NSImage {
    func resized(to size: NSSize) -> NSImage {
        let newImg = NSImage(size: size)
        newImg.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: size),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .copy,
                  fraction: 1.0)
        newImg.unlockFocus()
        return newImg
    }
    
    func bitmapRepresentation() -> [UInt32]? {
        guard let tiff = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        let w = Int(bitmap.pixelsWide)
        let h = Int(bitmap.pixelsHigh)
        var data = [UInt32](repeating: 0, count: w*h)
        for y in 0..<h {
            for x in 0..<w {
                let color = bitmap.colorAt(x: x, y: y) ?? NSColor.black
                let r = UInt32(color.redComponent * 255) << 24
                let g = UInt32(color.greenComponent * 255) << 16
                let b = UInt32(color.blueComponent * 255) << 8
                data[y*w + x] = r | g | b | 0xFF
            }
        }
        return data
    }
}

// Run loop
let timer = DispatchSource.makeTimerSource()
timer.schedule(deadline: .now(), repeating: .milliseconds(100))
timer.setEventHandler {
    render()
}
timer.resume()
RunLoop.main.run()