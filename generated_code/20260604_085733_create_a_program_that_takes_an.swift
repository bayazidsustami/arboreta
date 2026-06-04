import Foundation
import AVFoundation
import CoreMIDI

// MARK: - MIDI Utilities -------------------------------------------------------

/// Load a MIDI file and return an array of note events (pitch, velocity, start, duration)
func loadMIDI(at url: URL) throws -> [(pitch: UInt8, velocity: UInt8, start: Double, duration: Double)] {
    let data = try Data(contentsOf: url)
    var sequence: MusicSequence?
    NewMusicSequence(&sequence)
    data.withUnsafeBytes { ptr in
        let bytes = ptr.baseAddress!.assumingMemoryBound(to: UInt8.self)
        MusicSequenceFileLoadData(sequence!, bytes, data.count, .midiType, MusicSequenceLoadFlags())
    }
    var track: MusicTrack?
    MusicSequenceGetIndTrack(sequence!, 0, &track)
    var iterator: MusicEventIterator?
    NewMusicEventIterator(track!, &iterator)

    var events: [(UInt8, UInt8, Double, Double)] = []
    var hasEvent: DarwinBoolean = false
    MusicEventIteratorHasCurrentEvent(iterator!, &hasEvent)
    while hasEvent.boolValue {
        var timeStamp: MusicTimeStamp = 0
        var eventType: MusicEventType = 0
        var eventData: UnsafeRawPointer?
        var eventDataSize: UInt32 = 0
        MusicEventIteratorGetEventInfo(iterator!, &timeStamp, &eventType, &eventData, &eventDataSize)

        if eventType == kMusicEventType_MIDINoteMessage,
           let data = eventData?.assumingMemoryBound(to: MIDINoteMessage.self) {
            let note = data.pointee
            events.append((note.note, note.velocity, timeStamp, note.duration))
        }

        MusicEventIteratorNextEvent(iterator!)
        MusicEventIteratorHasCurrentEvent(iterator!, &hasEvent)
    }
    DisposeMusicEventIterator(iterator!)
    return events
}

/// Save a new MIDI file from note events
func saveMIDI(events: [(pitch: UInt8, velocity: UInt8, start: Double, duration: Double)], to url: URL) throws {
    var sequence: MusicSequence?
    NewMusicSequence(&sequence)
    var track: MusicTrack?
    MusicSequenceNewTrack(sequence!, &track)

    for ev in events {
        var msg = MIDINoteMessage(channel: 0,
                                  note: ev.pitch,
                                  velocity: ev.velocity,
                                  releaseVelocity: 0,
                                  duration: Float32(ev.duration))
        MusicTrackNewMIDINoteEvent(track!, ev.start, &msg)
    }

    MusicSequenceFileCreate(sequence!,
                            url as CFURL,
                            .midiType,
                            .eraseFile,
                            480) // 480 ppq
}

// MARK: - Contour Extraction ---------------------------------------------------

/// Convert note events to a melodic contour (relative pitch steps)
func extractContour(from events: [(pitch: UInt8, velocity: UInt8, start: Double, duration: Double)]) -> [Int] {
    // Sort by start time, keep only the highest voice (simple heuristic)
    let sorted = events.sorted { $0.start < $1.start }
    var contour: [Int] = []
    var lastPitch: Int? = nil
    for ev in sorted {
        let p = Int(ev.pitch)
        if let lp = lastPitch {
            contour.append(p - lp)
        }
        lastPitch = p
    }
    return contour
}

// MARK: - Cellular Automaton ---------------------------------------------------

// Simple 1‑dimensional CA with radius 1 (elementary)
struct CellularAutomaton {
    var rule: UInt8               // 8‑bit rule number (e.g., 30, 90, 110)
    var size: Int                 // number of cells
    var state: [UInt8]            // current generation (0 or 1)

    init(rule: UInt8, size: Int) {
        self.rule = rule
        self.size = size
        // Random initial state
        self.state = (0..<size).map { _ in UInt8.random(in: 0...1) }
    }

    /// Produce next generation
    mutating func step() {
        var next = [UInt8](repeating: 0, count: size)
        for i in 0..<size {
            let left = state[(i - 1 + size) % size]
            let center = state[i]
            let right = state[(i + 1) % size]
            let pattern = (left << 2) | (center << 1) | right
            let bit = (rule >> pattern) & 1
            next[i] = bit
        }
        state = next
    }
}

// Map contour values to CA rule numbers (mod 256)
func contourToRule(_ contour: [Int]) -> UInt8 {
    let sum = contour.reduce(0) { $0 + abs($1) }
    return UInt8(sum % 256)
}

// MARK: - ASCII Art Renderer ---------------------------------------------------

struct ASCIIRenderer {
    let width: Int
    let height: Int
    var buffer: [[Character]]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.buffer = Array(repeating: Array(repeating: " ", count: width), count: height)
    }

    mutating func drawLine(_ line: [UInt8]) {
        // Shift buffer up
        buffer.removeFirst()
        buffer.append(Array(repeating: " ", count: width))

        // Map line onto the bottom row
        for (i, cell) in line.enumerated() where i < width {
            buffer[height - 1][i] = cell == 1 ? "#" : " "
        }
    }

    func snapshot() -> String {
        buffer.map { String($0) }.joined(separator: "\n")
    }
}

// MARK: - Video Generation (FFmpeg wrapper) -----------------------------------

/// Write a sequence of ASCII frames to a temporary folder and invoke ffmpeg to turn them into a video.
/// Returns URL of the generated mp4.
func makeVideo(from frames: [String], fps: Int) throws -> URL {
    let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true, attributes: nil)

    for (i, txt) in frames.enumerated() {
        let path = tmpDir.appendingPathComponent(String(format: "%05d.txt", i))
        try txt.write(to: path, atomically: true, encoding: .utf8)
    }

    let outURL = tmpDir.appendingPathComponent("output.mp4")
    let ffmpeg = Process()
    ffmpeg.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffmpeg") // Homebrew location; adjust if needed
    ffmpeg.arguments = [
        "-y",
        "-framerate", "\(fps)",
        "-i", "\(tmpDir.path)/%05d.txt",
        "-vf", "format=yuv420p",
        outURL.path
    ]
    try ffmpeg.run()
    ffmpeg.waitUntilExit()
    return outURL
}

// MARK: - Main -----------------------------------------------------------------

do {
    // 1. Load source MIDI
    let inputURL = URL(fileURLWithPath: CommandLine.arguments[1]) // e.g., "input.mid"
    let notes = try loadMIDI(at: inputURL)

    // 2. Extract melodic contour
    let contour = extractContour(from: notes)

    // 3. Derive CA rule from contour
    let rule = contourToRule(contour)

    // 4. Setup automaton
    let caSize = 80
    var ca = CellularAutomaton(rule: rule, size: caSize)

    // 5. Prepare renderer
    var renderer = ASCIIRenderer(width: caSize, height: 24)

    // 6. Determine tempo (use first tempo meta‑event if present, else 120 BPM)
    var tempoBPM: Double = 120
    // Simple extraction: assume 120 if not implemented

    let fps = Int(tempoBPM / 60.0 * Double(renderer.width)) // sync speed with tempo
    var frames: [String] = []

    // 7. Run for a fixed duration (e.g., 8 bars)
    let generations = 200
    for _ in 0..<generations {
        ca.step()
        renderer.drawLine(ca.state)
        frames.append(renderer.snapshot())
    }

    // 8. Export video
    let videoURL = try makeVideo(from: frames, fps: fps)
    print("Video written to \(videoURL.path)")

    // 9. Generate new MIDI from state transitions
    var newEvents: [(pitch: UInt8, velocity: UInt8, start: Double, duration: Double)] = []
    var time: Double = 0
    let tick = 0.5 // half‑beat per generation
    for gen in 0..<generations {
        let active = ca.state.filter { $0 == 1 }.count
        // Map density to pitch within original key (use first note as tonic)
        let basePitch = notes.first?.pitch ?? 60
        let pitch = UInt8(min(127, Int(basePitch) + active % 12))
        newEvents.append((pitch, 80, time, tick))
        time += tick
    }
    let outputMIDI = URL(fileURLWithPath: "generated.mid")
    try saveMIDI(events: newEvents, to: outputMIDI)
    print("MIDI written to \(outputMIDI.path)")

} catch {
    print("Error: \(error)")
}