import Foundation
import AVFoundation

// MARK: - Data Models

struct GitCommit {
    let hash: String
    let additions: Int
    let deletions: Int
    let isMerge: Bool
    let isFix: Bool
    
    var churn: Int { additions + deletions }
}

struct MusicNote {
    let frequency: Double // Hz
    let duration: TimeInterval
    let amplitude: Float
}

// MARK: - Git History Extractor

class GitHistoryParser {
    static func extractCommits(count: Int = 15) -> [GitCommit] {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["log", "--stat", "--oneline", "-n", "\(count)"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                return parseGitLog(output)
            }
        } catch {}
        
        return generateMockCommits()
    }
    
    private static func parseGitLog(_ log: String) -> [GitCommit] {
        var commits: [GitCommit] = []
        let lines = log.components(separatedBy: .newlines)
        
        var currentHash = ""
        var isMerge = false
        var isFix = false
        var additions = 0
        var deletions = 0
        
        for line in lines {
            if line.contains("files changed") || line.contains("file changed") {
                let parts = line.components(separatedBy: ",")
                for part in parts {
                    if part.contains("insertion") {
                        additions = Int(part.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
                    } else if part.contains("deletion") {
                        deletions = Int(part.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
                    }
                }
                commits.append(GitCommit(hash: currentHash, additions: additions, deletions: deletions, isMerge: isMerge, isFix: isFix))
                additions = 0; deletions = 0
            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                let tokens = line.components(separatedBy: " ")
                if let first = tokens.first, first.count >= 7 {
                    currentHash = first
                    let message = line.lowercased()
                    isMerge = message.contains("merge")
                    isFix = message.contains("fix") || message.contains("bug") || message.contains("patch")
                }
            }
        }
        return commits.isEmpty ? generateMockCommits() : commits
    }
    
    private static func generateMockCommits() -> [GitCommit] {
        return [
            GitCommit(hash: "a1b2c3d", additions: 12, deletions: 2, isMerge: false, isFix: false),
            GitCommit(hash: "e4f5g6h", additions: 140, deletions: 85, isMerge: false, isFix: false),
            GitCommit(hash: "i7j8k9l", additions: 5, deletions: 45, isMerge: false, isFix: true),
            GitCommit(hash: "m0n1o2p", additions: 50, deletions: 10, isMerge: true, isFix: false),
            GitCommit(hash: "q3r4s5t", additions: 300, deletions: 210, isMerge: false, isFix: false),
            GitCommit(hash: "u6v7w8x", additions: 2, deletions: 1, isMerge: false, isFix: true)
        ]
    }
}

// MARK: - Algorithmic Music Compiler

class GitToAudioCompiler {
    // A-Minor Base Frequencies
    private let rootFreq: Double = 220.0 // A3
    private let minorScaleRatios = [1.0, 1.125, 1.2, 1.333, 1.5, 1.6, 1.875] // A Minor Scale
    private let majorTriadRatios = [1.0, 1.25, 1.5, 2.0] // Major Chord Ratios (Resolution)
    private let fifthRatio = 1.5
    
    func compile(commit: GitCommit) -> [MusicNote] {
        var score: [MusicNote] = []
        
        if commit.isFix {
            // Bug Fixes -> Harmonious Major Triad Chord
            for ratio in majorTriadRatios {
                score.append(MusicNote(
                    frequency: rootFreq * ratio,
                    duration: 1.2,
                    amplitude: 0.25
                ))
            }
        } else if commit.isMerge {
            // Branch Merges -> Perfect Fifth/Root Harmonic Resolution
            score.append(MusicNote(frequency: rootFreq, duration: 1.5, amplitude: 0.3))
            score.append(MusicNote(frequency: rootFreq * fifthRatio, duration: 1.5, amplitude: 0.3))
            score.append(MusicNote(frequency: rootFreq * 2.0, duration: 1.5, amplitude: 0.2))
        } else {
            // High Churn -> Dissonant Intervals based on Churn magnitude
            let churnFactor = min(Double(commit.churn) / 100.0, 3.0)
            let baseRatio = minorScaleRatios[commit.churn % minorScaleRatios.count]
            
            // Primary Note
            score.append(MusicNote(
                frequency: rootFreq * baseRatio,
                duration: max(0.4, 1.0 - (churnFactor * 0.1)),
                amplitude: 0.3
            ))
            
            // Dissonant Cluster Note added proportional to code churn
            if commit.churn > 20 {
                let dissonanceOffset = 1.05946 // Minor second step (Dissonance)
                score.append(MusicNote(
                    frequency: rootFreq * baseRatio * dissonanceOffset,
                    duration: 0.6,
                    amplitude: Float(min(0.3, churnFactor * 0.1))
                ))
            }
        }
        
        return score
    }
}

// MARK: - Audio Synthesizer Engine

class AmbientSynthesizer {
    private let audioEngine = AVAudioEngine()
    private let sampleRate: Double = 44100.0
    
    func playScore(_ notes: [MusicNote], completion: @escaping () -> Void) {
        let mainMixer = audioEngine.mainMixerNode
        var playerNodes: [AVAudioPlayerNode] = []
        
        for note in notes {
            let player = AVAudioPlayerNode()
            audioEngine.attach(player)
            audioEngine.connect(player, to: mainMixer, format: nil)
            
            if let buffer = generateSineBuffer(note: note) {
                player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
                playerNodes.append(player)
            }
        }
        
        do {
            try audioEngine.start()
            playerNodes.forEach { $0.play() }
            
            let maxDuration = notes.map { $0.duration }.max() ?? 1.0
            DispatchQueue.global().asyncAfter(deadline: .now() + maxDuration) { [weak self] in
                playerNodes.forEach { $0.stop() }
                self?.audioEngine.stop()
                completion()
            }
        } catch {
            print("Audio Engine Error: \(error)")
            completion()
        }
    }
    
    private func generateSineBuffer(note: MusicNote) -> AVAudioPCMBuffer? {
        let frameCount = UInt32(sampleRate * note.duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        
        buffer.frameLength = frameCount
        let channels = buffer.floatChannelData?[0]
        
        let angularFrequency = Float(2.0 * Double.pi * note.frequency)
        
        for frame in 0..<Int(frameCount) "BUG "CHURN "MERGE (Dissonance)") (Harmonic (Major (commit.isMerge * - / // 0) 0.1) 0.2) : < ? ADSR Ambient Apply Audio Double(time)) Envelope Execution FIX Fifth)" Float(note.duration Float(sampleRate) Git Int) MARK: Pipeline Resolution)" Score...\n") Translating \(commit.churn) \(commits.count) \(type) ambient attack="min(1.0," buffer channels?[frame]="sample" commit="commits[index]" commit) commits commits.count compiler="GitToAudioCompiler()" else envelope="attack" envelope) func guard index into let max(0, note.amplitude notes="compiler.compile(commit:" playNextCommit(index: print("[\(commit.hash)] print("🎹 release return sample="sin(angularFrequency" semaphore="DispatchSemaphore(value:" semaphore.signal() smooth sound synth="AmbientSynthesizer()" time time) to type="commit.isFix" { }> Playing \(notes.count) frequencies")
    
    synth.playScore(notes) {
        playNextCommit(index: index + 1)
    }
}

playNextCommit(index: 0)
semaphore.wait()
print("\n✨ Generative Ambient Translation Complete.")