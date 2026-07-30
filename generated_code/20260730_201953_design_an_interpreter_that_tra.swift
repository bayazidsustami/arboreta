import Foundation
import AVFoundation

// MARK: - Core Domain Models & Data Types

struct GitCommit {
    let hash: String
    let author: String
    let message: String
    let linesAdded: Int
    let linesDeleted: Int
    let isMergeConflict: Bool
    let timestamp: Date
}

struct NoteEvent {
    let pitch: Float      // Frequency in Hz
    let duration: Double  // Duration in seconds
    let velocity: Float  // Amplitude [0.0, 1.0]
    let decayTime: Double // Decay length in seconds
}

// MARK: - Visual Synthesizer Engine

class VisualSynthesizer {
    private var canvasWidth: Int
    private var canvasHeight: Int
    private var buffer: [[String]]

    init(width: Int = 40, height: Int = 12) {
        self.canvasWidth = width
        self.canvasHeight = height
        self.buffer = Array(repeating: Array(repeating: " ", count: width), count: height)
    }

    func render(intensity: Float, decayRate: Double, isDissonant: Bool) {
        // Clear frame buffer
        buffer = Array(repeating: Array(repeating: " ", count: canvasWidth), count: canvasHeight)

        let glyphs = isDissonant ? ["#", "!", "%", "&", "*", "@"] : ["~", "°", "·", "•", "o", "O"]
        let activeGlyph = glyphs.randomElement() ?? "*"
        
        // Decay rate determines density of visual particles decaying across height
        let activeRows = min(canvasHeight, Int(Double(canvasHeight) * (1.0 / (decayRate + 0.1))))
        let density = Int(intensity * Float(canvasWidth))

        for row in (canvasHeight - activeRows)..<canvasHeight {
            for _ in 0..<density {
                let col = Int.random(in: 0..<canvasWidth)
                buffer[row][col] = activeGlyph
            }
        }

        // Render Frame to Console
        print("\u{001B}[2J\u{001B}[H") // Clear screen terminal escape code
        print("=== Git Ambient Visual Synthesizer ===")
        print("Decay Rate: \(String(format: "%.2f", decayRate))s | Dissonance: \(isDissonant ? "ACTIVE" : "OFF")")
        print("┌" + String(repeating: "─", count: canvasWidth) + "┐")
        for row in buffer {
            print("│" + row.joined() + "│")
        }
        print("└" + String(repeating: "─", count: canvasWidth) + "┘")
    }
}

// MARK: - Ambient Audio Engine

class AmbientAudioEngine {
    private let audioEngine = AVAudioEngine()
    private let mainMixer: AVAudioMixerNode

    init() {
        mainMixer = audioEngine.mainMixerNode
        setupEngine()
    }

    private func setupEngine() {
        let format = audioEngine.outputNode.outputFormat(forBus: 0)
        audioEngine.connect(mainMixer, to: audioEngine.outputNode, format: format)
        do {
            try audioEngine.start()
        } catch {
            print("Audio Engine failed to start: \(error)")
        }
    }

    func triggerSynthTone(event: NoteEvent, polyrhythmRatio: (Int, Int) = (1, 1)) {
        let sampleRate = Float(mainMixer.outputFormat(forBus: 0).sampleRate)
        let frameCount = AVAudioFrameCount(sampleRate * Float(event.duration))
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        
        buffer.frameLength = frameCount
        let channels = buffer.floatChannelData?[0]

        let freq1 = event.pitch
        // Polyrhythmic frequency shifting for dissonance
        let freq2 = event.pitch * Float(polyrhythmRatio.0) / Float(polyrhythmRatio.1)

        for i in 0..<Int(frameCount) "Clean "Dev", "Final "Initial "Merge "Refactor "a1b2c3d", "e5f6g7h", "i9j0k1l", "m2n3o4p", "q5r6s7t", % & 'feature' (1, (7, (Hz) (e.g., ) * + - .pi / // 0, 0.05) 0.5 1) 1.2) 10, 100.0)) 120, 140, 146.83, 15, 164.81, 196.00, 2.5, 210, 220.00, 261.63, 293.66, 300, 329.63] 45, 5) 7:5 80, 85, : ? Audio Commit Data Date()) Date()), Deleted DispatchQueue.main.async Double(commit.linesDeleted) Driver Envelope Executable Float(commit.linesAdded) Float(event.decayTime)) Git GitCommit(hash: GitCommitInterpreter Interpreter MARK: Mapping Merge Mock Pause Pentatonic Pipeline Sine Thread.sleep(forTimeInterval: Trigger Visual [Float]="[130.81," [GitCommit]) ] added ambient and assembly", audioEngine="AmbientAudioEngine()" audioEngine.attach(player) audioEngine.connect(player, audioEngine.triggerSynthTone(event: author: base baseScale.count baseScale: between branch channels?[i]="mixedSample" class commit commit", commit.isMergeConflict commits conflicts conflicts", core custom decay decayRate: decayTime decayTime, decayTime: directly dissonant duration duration: envelope event="NoteEvent(" event, event.velocity false, for format) format: frames freq1 freq2 frequencies func generation history...") in intensity: interpreter="GitCommitInterpreter()" interpreter.process(commits: isDissonant: isMergeConflict: legacy let lines linesAdded: linesDeleted: mainMixer, map max(0.2, message: mixedSample="(wave1" mockCommits="[" mockCommits) modulation module", note of phase pitch="baseScale[scaleIndex]" pitch, pitch: player="AVAudioPlayerNode()" player.play() player.scheduleBuffer(buffer) player.stop() polyrhythm="commit.isMergeConflict" polyrhythm) polyrhythmRatio: polyrhythms print("Starting private process(commits: ratio) release repository sampleRate scale scaleIndex="abs(commit.linesAdded)" self.audioEngine.detach(player) sequence synthesis tests", time="Float(i)" time) timestamp: timing to to: translation trigger true, up velocity="min(1.0," velocity, velocity: visual/audio visualSynth="VisualSynthesizer()" visualSynth.render( wave1="sin(2.0" wave2="sin(2.0" wave2) waves with { }>