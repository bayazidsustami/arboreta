import AVFoundation
import CoreImage
import CoreGraphics
import AppKit
import AudioToolbox

// ---------- Helper Extensions ----------
extension NSImage {
    var cgImage: CGImage? {
        var rect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
extension CGImage {
    func dominantColors(count: Int = 5) -> [NSColor] {
        let ci = CIImage(cgImage: self)
        let extent = ci.extent
        let params: [String: Any] = [
            kCIInputImageKey: ci,
            kCIInputExtentKey: CIVector(cgRect: extent),
            kCIInputCountKey: count
        ]
        guard let filter = CIFilter(name: "CIAreaMaximum", parameters: params),
              let output = filter.outputImage,
              let bitmap = CIContext().createCGImage(output, from: extent) else { return [] }
        var colors: [NSColor] = []
        let data = CFDataCreateMutable(nil, 0)!
        let dest = CGImageDestinationCreateWithData(data, kUTTypePNG, 1, nil)!
        CGImageDestinationAddImage(dest, bitmap, nil)
        CGImageDestinationFinalize(dest)
        let nsImg = NSImage(data: data as Data)!
        nsImg.representations.forEach {
            if let rep = $0 as? NSBitmapImageRep {
                for x in 0..<rep.pixelsWide {
                    for y in 0..<rep.pixelsHigh {
                        let c = rep.colorAt(x: x, y: y) ?? .black
                        colors.append(c)
                    }
                }
            }
        }
        return Array(colors.prefix(count))
    }
}

// ---------- Audio ----------
class SimpleSynth {
    private var audioUnit: AudioComponentInstance?
    init() {
        var desc = AudioComponentDescription(componentType: kAudioUnitType_MusicDevice,
                                             componentSubType: kAudioUnitSubType_MIDISynth,
                                             componentManufacturer: kAudioUnitManufacturer_Apple,
                                             componentFlags: 0,
                                             componentFlagsMask: 0)
        let comp = AudioComponentFindNext(nil, &desc)!
        AudioComponentInstanceNew(comp, &audioUnit)
        AudioUnitInitialize(audioUnit!)
    }
    func play(note: UInt8, velocity: UInt8 = 64) {
        var midiEvent = MIDIChannelMessage(status: 0x90, data1: note, data2: velocity, reserved: 0)
        MIDIPacketList(midiEvent).withUnsafeBytes {
            AudioUnitSendMIDIEventList(audioUnit!, 0, 0, $0.baseAddress!.assumingMemoryBound(to: MIDIPacketList.self))
        }
    }
    deinit {
        AudioUnitUninitialize(audioUnit!)
        AudioComponentInstanceDispose(audioUnit!)
    }
}

// ---------- SVG Generator ----------
struct KaleidoSVG {
    var size: CGFloat
    var paths: [String] = []
    mutating func addPattern(color: NSColor, angle: CGFloat) {
        let rad = angle * .pi / 180
        let x = size/2 + cos(rad) * size/3
        let y = size/2 + sin(rad) * size/3
        let hex = "<polygon points='\(size/2),\(size/2) \(x),\(y)' fill='\(color.hexString)'/>"
        paths.append(hex)
    }
    func render() -> String {
        let header = "<svg xmlns='http://www.w3.org/2000/svg' width='\(size)' height='\(size)'>"
        let body = paths.joined(separator:"")
        return header + body + "</svg>"
    }
}
extension NSColor {
    var hexString: String {
        let rgb = usingColorSpace(.deviceRGB)!
        return String(format:"#%02X%02X%02X",
                      Int(rgb.redComponent*255),
                      Int(rgb.greenComponent*255),
                      Int(rgb.blueComponent*255))
    }
}

// ---------- Main ----------
let capture = AVCaptureSession()
capture.sessionPreset = .low

guard let videoDevice = AVCaptureDevice.default(for: .video),
      let input = try? AVCaptureDeviceInput(device: videoDevice) else {
    fatalError("No camera")
}
capture.addInput(input)

let output = AVCaptureVideoDataOutput()
output.alwaysDiscardsLateVideoFrames = true
let queue = DispatchQueue(label: "videoQueue")
output.setSampleBufferDelegate(nil, queue: queue) // placeholder, we'll use manual capture

capture.addOutput(output)
capture.startRunning()

let synth = SimpleSynth()
let svgSize: CGFloat = 400
var angle: CGFloat = 0
let outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("kaleido.svg")

while true {
    guard let connection = output.connection(with: .video),
          let sample = output.copyNextSampleBuffer(),
          let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else { continue }
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let context = CIContext()
    guard let cg = context.createCGImage(ciImage, from: ciImage.extent) else { continue }

    // dominant colors
    let colors = cg.dominantColors(count: 3)

    // map colors to notes (C4=60, step per hue)
    for (i, col) in colors.enumerated() {
        let hue = col.hueComponent
        let note = UInt8(60 + Int(hue * 12)) // one octave
        synth.play(note: note + UInt8(i*2))
    }

    // generate SVG
    var svg = KaleidoSVG(size: svgSize)
    for col in colors {
        svg.addPattern(color: col, angle: angle)
        angle += 30
    }
    try? svg.render().write(to: outputURL, atomically: true, encoding: .utf8)

    // simple throttle
    Thread.sleep(forTimeInterval: 0.1)
}