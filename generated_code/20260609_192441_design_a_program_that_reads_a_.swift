import SwiftUI
import Combine
import Foundation

// MARK: - Mock Tweet Stream (replace with real Twitter API)

struct Tweet {
    let text: String
    let timestamp: Date
}

// Simple sentiment analyzer (positive = 1, neutral = 0, negative = -1)
func sentiment(of text: String) -> Int {
    let lower = text.lowercased()
    let positives = ["good","great","awesome","happy","love","fantastic"]
    let negatives = ["bad","sad","terrible","hate","awful","worst"]
    let pos = positives.filter { lower.contains($0) }.count
    let neg = negatives.filter { lower.contains($0) }.count
    return pos > neg ? 1 : (neg > pos ? -1 : 0)
}

// MARK: - Voronoi Cell Model

struct Cell: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var hue: Double          // 0...1 derived from sentiment
    var saturation: Double   // word length influences saturation
    var brightness: Double   // age influences brightness
}

// MARK: - ViewModel handling stream & physics

class VoronoiViewModel: ObservableObject {
    @Published var cells: [Cell] = []
    private var cancellables = Set<AnyCancellable>()
    private let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    
    init() {
        // Simulated tweet generator
        Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { _ in self.receive(tweet: self.randomTweet()) }
            .store(in: &cancellables)
        
        // Animation step
        timer
            .sink { _ in self.updatePhysics() }
            .store(in: &cancellables)
    }
    
    private func randomTweet() -> Tweet {
        let sample = [
            "I love SwiftUI!",
            "This is terrible news.",
            "Just another day.",
            "Feeling awesome about the project.",
            "Worst bug ever.",
            "Happy coding!"
        ]
        return Tweet(text: sample.randomElement()!,
                     timestamp: Date())
    }
    
    private func receive(tweet: Tweet) {
        let words = tweet.text.split(separator: " ")
        let avgLen = words.map { $0.count }.reduce(0, +) / max(words.count,1)
        let sentimentScore = sentiment(of: tweet.text)   // -1,0,1
        
        // Map to visual parameters
        let hue = Double((sentimentScore + 1)) / 3.0           // 0..0.66
        let sat = Double(min(avgLen, 12)) / 12.0              // 0..1
        let pos = CGPoint(x: Double.random(in: 0...1),
                          y: Double.random(in: 0...1))
        let vel = CGVector(dx: Double.random(in: -0.001...0.001),
                           dy: Double.random(in: -0.001...0.001))
        
        let cell = Cell(position: pos,
                        velocity: vel,
                        hue: hue,
                        saturation: sat,
                        brightness: 1.0)
        cells.append(cell)
        // keep reasonable amount
        if cells.count > 200 { cells.removeFirst(cells.count - 200) }
    }
    
    private func updatePhysics() {
        let dt: CGFloat = 0.016
        for i in cells.indices {
            var c = cells[i]
            // simple motion
            c.position.x += c.velocity.dx * dt
            c.position.y += c.velocity.dy * dt
            // bounce
            if c.position.x < 0 || c.position.x > 1 { c.velocity.dx *= -1 }
            if c.position.y < 0 || c.position.y > 1 { c.velocity.dy *= -1 }
            // age dimming
            c.brightness = max(0.2, c.brightness - 0.001)
            cells[i] = c
        }
    }
}

// MARK: - Voronoi Rendering (approximation with circles)

struct VoronoiView: View {
    @ObservedObject var vm = VoronoiViewModel()
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(vm.cells) { cell in
                    Circle()
                        .fill(Color(hue: cell.hue,
                                    saturation: cell.saturation,
                                    brightness: cell.brightness))
                        .frame(width: 40, height: 40)
                        .position(x: cell.position.x * geo.size.width,
                                  y: cell.position.y * geo.size.height)
                }
            }
            .background(Color.black)
            .ignoresSafeArea()
        }
    }
}

// MARK: - App Entry

@main
struct VoronoiTwitterApp: App {
    var body: some Scene {
        WindowGroup {
            VoronoiView()
        }
    }
}