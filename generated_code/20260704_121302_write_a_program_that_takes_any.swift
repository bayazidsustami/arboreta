import Foundation
import SwiftUI
import Combine
import AVFoundation

// MARK: - Model

struct Commit: Decodable {
    let commit: Inner
    struct Inner: Decodable {
        let author: Author
        struct Author: Decodable {
            let date: String          // ISO‑8601
        }
    }
}

// MARK: - GitHub Service

final class GitHubFetcher: ObservableObject {
    @Published var notes: [Int] = []            // hour of day (0‑23)
    private var cancellable: AnyCancellable?
    private let repoURL: URL
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private var knownSHAs = Set<String>()
    
    init(githubURL: String) {
        // Transform "...github.com/owner/repo..." into API URL
        let comps = githubURL
            .replacingOccurrences(of: "https://github.com/", with: "")
            .split(separator: "/")
        guard comps.count >= 2 else {
            fatalError("Invalid GitHub repo URL")
        }
        let owner = comps[0], name = comps[1]
        self.repoURL = URL(string: "https://api.github.com/repos/\(owner)/\(name)/commits")!
        // initial fetch + periodic refresh
        cancellable = timer.sink { [weak self] _ in self?.fetch() }
        fetch()
    }
    
    private func fetch() {
        var request = URLRequest(url: repoURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let data = data,
                  let commits = try? JSONDecoder().decode([Commit].self, from: data) else { return }
            var newNotes: [Int] = []
            for (i, c) in commits.enumerated() {
                // Use SHA index as id (position in result) to avoid duplicates
                let id = "\(i)"
                if self?.knownSHAs.contains(id) == true { continue }
                self?.knownSHAs.insert(id)
                if let date = ISO8601DateFormatter().date(from: c.commit.author.date) {
                    let hour = Calendar.current.component(.hour, from: date)
                    newNotes.append(hour)
                }
            }
            DispatchQueue.main.async {
                self?.notes.append(contentsOf: newNotes)
            }
        }.resume()
    }
}

// MARK: - Audio Engine

final class Synthesizer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var timer: Timer?
    
    init() {
        let sampleRate: Double = 44100
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }
    
    func play(note: Int) {
        // Map hour (0‑23) to frequency between 220 Hz and 880 Hz
        let freq = 220.0 * pow(2.0, Double(note) / 12.0)
        let length = 0.2
        let frameCount = AVAudioFrameCount(format.sampleRate * length)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let theta = 2.0 * Double.pi * freq / format.sampleRate
        for i in 0..<Int(frameCount) {
            let sample = sin(theta * Double(i))
            buffer.floatChannelData!.pointee[i] = Float(sample) * 0.2
        }
        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }
}

// MARK: - Visualisation

struct MandalaView: View {
    @ObservedObject var fetcher: GitHubFetcher
    @StateObject private var synth = Synthesizer()
    @State private var angles: [Double] = Array(repeating: 0, count: 24)
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ForEach(0..<24, id: \.self) { hour in
                Circle()
                    .stroke(Color(hue: Double(hour)/24.0, saturation: 0.8, brightness: 0.9), lineWidth: 2)
                    .frame(width: 30 + CGFloat(angles[hour])*10,
                           height: 30 + CGFloat(angles[hour])*10)
                    .rotationEffect(.degrees(angles[hour]*Double(hour)))
                    .scaleEffect(1 + sin(angles[hour])*0.3)
                    .opacity(0.6)
            }
        }
        .onReceive(fetcher.$notes) { notes in
            guard let last = notes.last else { return }
            synth.play(note: last)
            // animate the corresponding hour slice
            withAnimation(.easeInOut(duration: 1.5)) {
                angles[last] += .pi / 4
                if angles[last] > .pi * 2 { angles[last] = 0 }
            }
        }
    }
}

// MARK: - App Entry

@main
struct SymphonyApp: App {
    // Replace with any public repo URL
    private let repo = "https://github.com/apple/swift"
    var body: some Scene {
        WindowGroup {
            MandalaView(fetcher: GitHubFetcher(githubURL: repo))
        }
    }
}