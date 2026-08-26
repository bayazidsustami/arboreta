import Foundation
import AppKit

// MARK: - Domain Models & Data Structures

enum MemoryKey: String, CaseIterable {
    case cMajor = "C Major (Nominal)"
    case gMajor = "G Major (Light Pressure)"
    case dMinor = "D Minor (Moderate Pressure)"
    case cMinor = "C Minor (High Pressure)"
    case fSharpMinor = "F# Minor (Critical Pressure)"

    var midiBaseNotes: [Int] {
        switch self {
        case .cMajor: return [60, 62, 64, 65, 67, 69, 71, 72]      // C4 Scale
        case .gMajor: return [67, 69, 71, 72, 74, 76, 78, 79]      // G4 Scale
        case .dMinor: return [62, 64, 65, 67, 69, 70, 72, 74]      // D4 Minor
        case .cMinor: return [60, 62, 63, 65, 67, 68, 70, 72]      // C4 Minor
        case .fSharpMinor: return [66, 68, 69, 71, 73, 74, 76, 78] // F#4 Minor
        }
    }
}

struct HeapAllocation {
    let id: UUID
    let classTypeName: String
    let byteSize: Int
    let timestamp: Date
    var isLeaked: Bool
}

struct MusicNote {
    let pitchMIDI: Int
    let durationBeats: Double
    let measureIndex: Int
    let isDissonant: Bool
    let isResolution: Bool
}

// MARK: - Core Profiler Engine

final class MemoryLeakProfilerEngine {
    private(set) var activeAllocations: [UUID: HeapAllocation] = [:]
    private(set) var leakedAllocations: [HeapAllocation] = []
    
    var currentMemoryPressure: Double {
        let totalBytes = activeAllocations.values.reduce(0) { $0 + $1.byteSize } +
                         leakedAllocations.reduce(0) { $0 + $1.byteSize }
        return min(1.0, Double(totalBytes) / 10_000_000.0) // 10MB threshold for max pressure
    }
    
    var currentMusicalKey: MemoryKey {
        let pressure = currentMemoryPressure
        switch pressure {
        case 0.0..<0.2: return .cMajor
        case 0.2..<0.4: return .gMajor
        case 0.4..<0.6: return .dMinor
        case 0.6..<0.8: return .cMinor
        default: return .fSharpMinor
        }
    }

    func allocate(type: String, size: Int, forceLeak: Bool = false) {
        let alloc = HeapAllocation(id: UUID(), classTypeName: type, byteSize: size, timestamp: Date(), isLeaked: forceLeak)
        if forceLeak {
            leakedAllocations.append(alloc)
        } else {
            activeAllocations[alloc.id] = alloc
        }
    }

    func triggerGarbageCollectionSweep() -> Int {
        let freedCount = activeAllocations.count
        activeAllocations.removeAll()
        return freedCount
    }
}

// MARK: - Music Generation Service

final class MusicScoreGenerator {
    static func generateScore(from engine: MemoryLeakProfilerEngine, totalMeasures: Int = 8) -> [MusicNote] {
        var score: [MusicNote] = []
        let key = engine.currentMusicalKey
        let pitches = key.midiBaseNotes
        
        for measure in 0..<totalMeasures {
            let isGCMeasure = (measure == totalMeasures - 1)
            
            if isGCMeasure {
                // Full harmonic resolution cascade (Consonant Arpeggio Sweep)
                for (idx, pitch) in pitches.enumerated() {
                    score.append(MusicNote(
                        pitchMIDI: pitch,
                        durationBeats: 0.5,
                        measureIndex: measure,
                        isDissonant: false,
                        isResolution: true
                    ))
                }
            } else {
                // Standard measure generation based on heap state
                let notesInMeasure = 4
                for beat in 0..<notesInMeasure {
                    let hasLeakInBeat = !engine.leakedAllocations.isEmpty && (beat % 2 == 1)
                    var pitch = pitches[beat % pitches.count]
                    
                    if hasLeakInBeat {
                        // Lingering dissonance: Shift pitch by a tritone (+6 semitones)
                        pitch += 6
                    }
                    
                    score.append(MusicNote(
                        pitchMIDI: pitch,
                        durationBeats: 1.0,
                        measureIndex: measure,
                        isDissonant: hasLeakInBeat,
                        isResolution: false
                    ))
                }
            }
        }
        return score
    }
}

// MARK: - Sheet Music PDF Renderer

final class SheetMusicPDFRenderer {
    static func renderToPDF(score: [MusicNote], key: MemoryKey, fileURL: URL) {
        let pdfBounds = CGRect(x: 0, y: 0, width: 612, height: 792) // Letter Size
        guard let consumer = CGDataConsumer(url: fileURL as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            print("Failed to create PDF Context")
            return
        }

        context.beginPDFPage(nil)
        
        // Background
        context.setFillColor(NSColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1.0).cgColor)
        context.fill(pdfBounds)

        // Draw Title & Key
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 20),
            .foregroundColor: NSColor.black
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.darkGray
        ]
        
        ("Heap Allocation Harmonic Profile" as NSString).draw(at: NSPoint(x: 50, y: 720), withAttributes: titleAttributes)
        ("Key State: \(key.rawValue)" as NSString).draw(at: NSPoint(x: 50, y: 698), withAttributes: subtitleAttributes)

        // Draw Staves
        let staffStartY: CGFloat = 580
        let lineSpacing: CGFloat = 10
        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineWidth(1.0)

        for i in 0..<5 {
            let y = staffStartY - (CGFloat(i) * lineSpacing)
            context.move(to: CGPoint(x: 50, y: y))
            context.addLine(to: CGPoint(x: 562, y: y))
        }
        context.strokePath()

        // Render Notes
        let measureWidth: CGFloat = 60
        let noteStartX: CGFloat = 70
        
        for note in score {
            let measureOffset = CGFloat(note.measureIndex) * measureWidth
            let x = noteStartX + measureOffset + (CGFloat(note.pitchMIDI % 4) * 12)
            
            // Map pitch to vertical staff position
            let pitchOffset = CGFloat(note.pitchMIDI - 60) * 3.5
            let y = staffStartY - 40 + pitchOffset

            // Set Note Color (Dissonance = Red/Orange, Resolution = Green, Normal = Black)
            if note.isDissonant {
                context.setFillColor(NSColor.systemRed.cgColor)
            } else if note.isResolution {
                context.setFillColor(NSColor.systemGreen.cgColor)
            } else {
                context.setFillColor(NSColor.black.cgColor)
            }

            // Draw Note Head
            let noteRect = CGRect(x: x, y: y, width: 9, height: 7)
            context.fillEllipse(in: noteRect)

            // Draw Note Stem
            context.setLineWidth(1.2)
            context.setStrokeColor(context.fillColor ?? NSColor.black.cgColor)
            context.move(to: CGPoint(x: x + 8, y: y + 3))
            context.addLine(to: CGPoint(x: x + 8, y: y + 25))
            context.strokePath()
        }

        context.endPDFPage()
        context.closePDF()
        print("Successfully generated Sheet Music PDF at: \(fileURL.path)")
    }
}

// MARK: - Script Execution Pipeline

func executeVisualMemoryProfilerPipeline() {
    print("--- Initializing Visual Memory-Leak Musical Profiler ---")
    let profiler = MemoryLeakProfilerEngine()

    // 1. Simulate Heap Allocations
    print("Simulating Heap Allocations and Memory Leaks...")
    profiler.allocate(type: "TextureBuffer", size: 2_500_000, forceLeak: false)
    profiler.allocate(type: "LeakedViewController", size: 4_000_000, forceLeak: true) // Orphaned object
    profiler.allocate(type: "AudioStreamCache", size: 2_000_000, forceLeak: true)     // Orphaned object

    print("Current Memory Pressure: \(String(format: "%.2f", profiler.currentMemoryPressure * 100))%")
    print("Determined Musical Key: \(profiler.currentMusicalKey.rawValue)")

    // 2. Generate Musical Score from Heap Profile
    print("Translating Allocation Patterns into Sheet Music...")
    let score = MusicScoreGenerator.generateScore(from: profiler)

    // 3. Trigger GC Harmonic Sweep
    let freedCount = profiler.triggerGarbageCollectionSweep()
    print("Garbage Collection Swept \(freedCount) active objects -> Cascading Full-Harmonic Resolution.")

    // 4. Render to Sheet Music File (PDF)
    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("MemoryProfileScore.pdf")
    SheetMusicPDFRenderer.renderToPDF(score: score, key: profiler.currentMusicalKey, fileURL: outputURL)
}

executeVisualMemoryProfilerPipeline()