import Foundation
import SwiftUI
import AVFoundation
import Combine

// MARK: - GitHub Commit Fetcher

struct Commit: Decodable {
    struct CommitInfo: Decodable {
        struct Author: Decodable {
            let date: String   // ISO8601
        }
        let author: Author
    }
    let commit: CommitInfo
}

class GitHubFetcher {
    private let session = URLSession(configuration: .default)
    func fetchCommits(owner: String, repo: String) async throws -> [Date] {
        var allDates: [Date] = []
        var page = 1
        let isoFormatter = ISO8601DateFormatter()
        while true {
            let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/commits?per_page=100&page=\(page)")!
            let (data, _) = try await session.data(from: url)
            let commits = try JSONDecoder().decode([Commit].self, from: data)
            guard !commits.isEmpty else { break }
            for c in commits {
                if let d = isoFormatter.date(from: c.commit.author.date) {
                    allDates.append(d)
                }
            }
            page += 1
        }
        return allDates
    }
}

// MARK: - Lunar‑Cycle → Note Mapper

struct Note {
    let frequency: Double   // Hz
    let duration: Double    // seconds
}

class LunarMapper {
    // Approximate lunar cycle = 29.53 days
    private let lunarPeriod: TimeInterval = 29.53 * 24 * 3600
    
    // Minor‑scale frequencies (C minor) for mapping
    private let scaleFrequencies = [130.81, 138.59, 146.83, 155.56, 164.81, 174.61, 185.00] // C3‑B♭3
    
    func notes(from dates: [Date]) -> [Note] {
        guard let first = dates.min() else { return [] }
        return dates.map { date in
            let elapsed = date.timeIntervalSince(first)
            let position = (elapsed.truncatingRemainder(dividingBy: lunarPeriod)) / lunarPeriod
            let index = Int(position * Double(scaleFrequencies.count)) % scaleFrequencies.count
            let freq = scaleFrequencies[index]
            // Duration proportional to how close the commit is to new moon (center of cycle)
            let distance = abs(position - 0.5) * 2.0   // 0 at new moon, 1 at full
            let dur = 0.2 + (0.8 * (1.0 - distance)) // 0.2‑1.0 s
            return Note(frequency: freq, duration: dur)
        }
    }
}

// MARK: - Audio Engine (Procedural Ambient Synth)

class Synthesizer: ObservableObject {
    private let engine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var bufferFormat: AVAudioFormat!
    private var cancellables = Set<AnyCancellable>()
    
    // Reactive amplitude for visualization
    @Published var currentAmplitude: Float = 0.0
    
    init() {
        let main = engine.mainMixerNode
        bufferFormat = main.outputFormat(forBus: 0)
        engine.attach(playerNode)
        engine.connect(playerNode, to: main, format: bufferFormat)
        try? engine.start()
        // Tap to read RMS amplitude
        main.installTap(onBus: 0, bufferSize: 1024, format: bufferFormat) { buf, _ in
            let channelData = buf.floatChannelData![0]
            let frameLength = Int(buf.frameLength)
            var sum: Float = 0
            vDSP_sve(channelData, 1, &sum, vDSP_Length(frameLength))
            let rms = sqrt(sum / Float(frameLength))
            DispatchQueue.main.async {
                self.currentAmplitude = rms
            }
        }
    }
    
    func play(_ notes: [Note]) {
        var idx = 0
        func scheduleNext() {
            guard idx < notes.count else { return }
            let note = notes[idx]
            let samples = Int(note.duration * bufferFormat.sampleRate)
            let buf = AVAudioPCMBuffer(pcmFormat: bufferFormat, frameCapacity: AVAudioFrameCount(samples))!
            buf.frameLength = AVAudioFrameCount(samples)
            let ptr = buf.floatChannelData![0]
            for n in 0..<samples {
                let phase = 2.0 * Double.pi * note.frequency * Double(n) / bufferFormat.sampleRate
                // Soft‑saw with gentle low‑pass shaping for ambience
                let value = sin(phase) * 0.5 + sin(phase * 0.5) * 0.3
                // Apply exponential decay envelope
                let env = pow(0.001, Double(n) / Double(samples))
                ptr[n] = Float(value * env * 0.3)
            }
            playerNode.scheduleBuffer(buf) {
                idx += 1
                scheduleNext()
            }
        }
        playerNode.play()
        scheduleNext()
    }
}

// MARK: - Living Mandala View

struct MandalaView: View {
    @ObservedObject var synth: Synthesizer
    @State private var phase: Double = 0.0
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<12) { i in
                    let angle = Double(i) * .pi / 6 + phase
                    let radius = min(geo.size.width, geo.size.height) * 0.4
                    let x = cos(angle) * radius
                    let y = sin(angle) * radius
                    Circle()
                        .stroke(lineWidth: 2)
                        .foregroundColor(Color(hue: (angle.truncatingRemainder(dividingBy: .pi*2))/(2*.pi), saturation: 0.6, brightness: 0.8))
                        .frame(width: 30, height: 30)
                        .position(x: geo.size.width/2 + x, y: geo.size.height/2 + y)
                }
            }
            .background(Color.black)
            .onReceive(synth.$currentAmplitude) { amp in
                // Amplitude drives mandala rotation speed and pulse
                withAnimation(.linear(duration: 0.1)) {
                    phase += Double(amp) * 0.5
                }
            }
        }
    }
}

// MARK: - SwiftUI App Entry

@main
struct LunarCommitsApp: App {
    @StateObject private var synth = Synthesizer()
    @State private var loading = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                MandalaView(synth: synth)
                    .ignoresSafeArea()
                if loading {
                    ProgressView("Fetching commits…")
                        .foregroundColor(.white)
                        .scaleEffect(1.5)
                }
            }
            .onAppear {
                Task {
                    do {
                        let fetcher = GitHubFetcher()
                        // Example repository – replace with any public repo
                        let dates = try await fetcher.fetchCommits(owner: "apple", repo: "swift")
                        let notes = LunarMapper().notes(from: dates)
                        synth.play(notes)
                    } catch {
                        print("Error: \(error)")
                    }
                    loading = false
                }
            }
        }
    }
}