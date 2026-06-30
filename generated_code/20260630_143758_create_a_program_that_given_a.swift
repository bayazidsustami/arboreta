import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// ---------- Simple MIDI Parser ----------
struct MidiNote {
    let pitch: UInt8       // 0‑127
    let velocity: UInt8    // 0‑127
    let startTime: Double  // seconds
    let duration: Double   // seconds
    let channel: UInt8
}

func loadMidiNotes(from url: URL) throws -> [MidiNote] {
    var musicSequence: MusicSequence? = nil
    var status = NewMusicSequence(&musicSequence)
    if status != noErr { throw NSError(domain: "MIDI", code: Int(status), userInfo: nil) }
    status = MusicSequenceFileLoad(musicSequence!, url as CFURL, .midiType, MusicSequenceLoadFlags())
    if status != noErr { throw NSError(domain: "MIDI", code: Int(status), userInfo: nil) }

    var notes = [MidiNote]()
    var trackCount: UInt32 = 0
    MusicSequenceGetTrackCount(musicSequence!, &trackCount)

    for i in 0..<trackCount {
        var track: MusicTrack? = nil
        MusicSequenceGetIndTrack(musicSequence!, i, &track)
        var iterator: MusicEventIterator? = nil
        NewMusicEventIterator(track!, &iterator)

        var hasEvent: DarwinBoolean = false
        MusicEventIteratorHasCurrentEvent(iterator!, &hasEvent)
        while hasEvent.boolValue {
            var timeStamp: MusicTimeStamp = 0
            var eventType: MusicEventType = 0
            var eventData: UnsafeRawPointer? = nil
            var eventDataSize: UInt32 = 0
            MusicEventIteratorGetEventInfo(iterator!, &timeStamp, &eventType, &eventData, &eventDataSize)

            if eventType == kMusicEventType_MIDINoteMessage {
                let msg = eventData!.assumingMemoryBound(to: MIDINoteMessage.self).pointee
                let start = MusicSequenceGetSecondsForBeats(musicSequence!, timeStamp)
                let dur   = MusicSequenceGetSecondsForBeats(musicSequence!, Double(msg.duration))
                notes.append(MidiNote(pitch: msg.note,
                                      velocity: msg.velocity,
                                      startTime: start,
                                      duration: dur,
                                      channel: msg.channel))
            }

            MusicEventIteratorNextEvent(iterator!)
            MusicEventIteratorHasCurrentEvent(iterator!, &hasEvent)
        }
        DisposeMusicEventIterator(iterator!)
    }
    DisposeMusicSequence(musicSequence!)
    return notes.sorted { $0.startTime < $1.startTime }
}

// ---------- Fractal ASCII Generator ----------
func fractalString(for note: MidiNote, size: Int) -> String {
    // Simple deterministic L‑system whose parameters derive from pitch/velocity
    let angle = Double(note.pitch % 12) / 12.0 * .pi * 2.0
    let depth = Int(note.velocity / 16) + 2
    var result = ""
    for y in 0..<size {
        for x in 0..<size {
            // Map coordinates into complex plane
            let cx = (Double(x) / Double(size) - 0.5) * 3.0
            let cy = (Double(y) / Double(size) - 0.5) * 3.0
            var zx = 0.0, zy = 0.0
            var iter = 0
            while zx*zx + zy*zy < 4.0 && iter < depth {
                // Rotate based on pitch angle
                let nx = zx * cos(angle) - zy * sin(angle) + cx
                let ny = zx * sin(angle) + zy * cos(angle) + cy
                zx = nx; zy = ny
                iter += 1
            }
            // Choose character based on iteration count
            let chars = " .:-=+*#%@"
            let idx = min(iter, chars.count-1)
            let ch = chars[chars.index(chars.startIndex, offsetBy: idx)]
            result.append(ch)
        }
        result.append("\n")
    }
    return result
}

// ---------- Render ASCII to CGImage ----------
func imageFromAscii(_ ascii: String, fontSize: CGFloat, fg: CGColor, bg: CGColor) -> CGImage? {
    let lines = ascii.split(separator: "\n")
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                                                .foregroundColor: NSColor(cgColor: fg)!]
    let lineHeight = fontSize * 1.2
    let width = CGFloat(lines.map { $0.count }.max() ?? 0) * fontSize * 0.6
    let height = CGFloat(lines.count) * lineHeight

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil,
                              width: Int(width),
                              height: Int(height),
                              bitsPerComponent: 8,
                              bytesPerRow: 0,
                              space: colorSpace,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }

    ctx.setFillColor(bg)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

    for (i, line) in lines.enumerated() {
        let attrStr = NSAttributedString(string: String(line), attributes: attrs)
        let y = CGFloat(i) * lineHeight
        attrStr.draw(at: CGPoint(x: 0, y: height - y - lineHeight))
    }
    return ctx.makeImage()
}

// ---------- GIF Encoder ----------
func writeGif(frames: [CGImage], delay: Double, to url: URL) throws {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
        throw NSError(domain: "GIF", code: -1, userInfo: nil)
    }

    let props: [CFString: Any] = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]]
    CGImageDestinationSetProperties(dest, props as CFDictionary)

    let frameProps: [CFString: Any] = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]]
    for img in frames {
        CGImageDestinationAddImage(dest, img, frameProps as CFDictionary)
    }

    if !CGImageDestinationFinalize(dest) {
        throw NSError(domain: "GIF", code: -2, userInfo: nil)
    }
}

// ---------- Main Execution ----------
let args = CommandLine.arguments
guard args.count > 2 else {
    print("Usage: \(args[0]) <input.mid> <output.gif>")
    exit(1)
}
let midiURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])

do {
    let notes = try loadMidiNotes(from: midiURL)

    // Determine total duration to compute frame delay (e.g., 30 FPS)
    let totalTime = notes.map { $0.startTime + $0.duration }.max() ?? 0.0
    let fps = 30.0
    let frameCount = Int(totalTime * fps) + 1
    let frameDelay = 1.0 / fps

    // Build a timeline mapping each frame to the active note (simple nearest)
    var frames = [CGImage]()
    for f in 0..<frameCount {
        let t = Double(f) / fps
        // Find note playing at this moment; fallback to last note
        let active = notes.last { $0.startTime <= t && t <= $0.startTime + $0.duration } ?? notes.last!
        let ascii = fractalString(for: active, size: 40)
        if let img = imageFromAscii(ascii, fontSize: 12, fg: CGColor(gray: 1, alpha: 1), bg: CGColor(gray: 0, alpha: 1)) {
            frames.append(img)
        }
    }

    try writeGif(frames: frames, delay: frameDelay, to: outURL)
    print("GIF written to \(outURL.path)")
} catch {
    print("Error: \(error)")
    exit(1)
}