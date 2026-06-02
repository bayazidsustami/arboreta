import Foundation

// ---------- Mock Tweet Stream ----------
struct Tweet {
    let text: String
    let timestamp: Date
    let influence: Double   // 0..1
    let langConfidence: Double // 0..1
    let polarity: Double    // -1 (negative) .. 1 (positive)
}

// Simple generator producing random tweets every 0.8‑1.2 seconds
class TweetGenerator {
    private let timer: DispatchSourceTimer
    private let callback: (Tweet) -> Void
    init(callback: @escaping (Tweet) -> Void) {
        self.callback = callback
        timer = DispatchSource.makeTimerSource(queue: .global())
        schedule()
    }
    private func schedule() {
        let interval = Double.random(in: 0.8...1.2)
        timer.schedule(deadline: .now() + interval)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            let t = self.randomTweet()
            self.callback(t)
            self.schedule()
        }
        timer.activate()
    }
    private func randomTweet() -> Tweet {
        let words = ["happy", "sad", "excited", "angry", "peaceful", "tired"]
        let text = (0..<Int.random(in: 5...12)).map{ _ in words.randomElement()! }.joined(separator: " ")
        return Tweet(
            text: text,
            timestamp: Date(),
            influence: Double.random(in: 0...1),
            langConfidence: Double.random(in: 0.7...1.0),
            polarity: Double.random(in: -1...1)
        )
    }
}

// ---------- L‑System Core ----------
struct LSystem {
    var axiom: String
    var rules: [Character: String]
    var iterations: Int
    
    func evolve() -> String {
        var current = axiom
        for _ in 0..<iterations {
            var next = ""
            for ch in current {
                if let repl = rules[ch] {
                    next.append(contentsOf: repl)
                } else {
                    next.append(ch)
                }
            }
            current = next
        }
        return current
    }
}

// Create a rule set from tweet polarity
func ruleSet(from polarity: Double) -> [Character: String] {
    // map negative -> more branching, positive -> longer stems
    let branch = polarity < 0 ? "F[+F]F[-F]F" : "F+F-F"
    return ["F": branch]
}

// ---------- ASCII Renderer ----------
class ASCIIForest {
    private var trees: [(String, Tweet)] = []    // (L‑system string, tweet)
    private let width = 80
    private let height = 25
    
    func addTree(from tweet: Tweet) {
        let iterations = 3 + Int(abs(tweet.polarity) * 2)   // 3‑5
        let ls = LSystem(axiom: "F",
                         rules: ruleSet(from: tweet.polarity),
                         iterations: iterations)
        let result = ls.evolve()
        trees.append((result, tweet))
        if trees.count > 5 { trees.removeFirst() } // keep recent
    }
    
    func render() {
        var canvas = Array(repeating: Array(repeating: " ", count: width), count: height)
        let centerX = width / 2
        
        for (idx, (seq, tweet)) in trees.enumerated() {
            // vertical offset per tree
            var y = height - 1 - idx * 4
            var x = centerX
            var angle = 90.0
            var stack: [(Int, Int, Double)] = []
            let thickness = max(1, Int(tweet.influence * 3))
            let leafGlyph = tweet.langConfidence > 0.85 ? "*" : "+"
            let timeFactor = Int(tweet.timestamp.timeIntervalSince1970).truncatingRemainder(dividingBy: 10)
            
            for ch in seq {
                switch ch {
                case "F":
                    // draw forward
                    let rad = angle * .pi / 180
                    let dx = Int(round(cos(rad)))
                    let dy = Int(round(sin(rad)))
                    for _ in 0..<thickness {
                        let nx = x + dx * timeFactor
                        let ny = y - dy * timeFactor
                        if ny >= 0 && ny < height && nx >= 0 && nx < width {
                            canvas[ny][nx] = "|"
                        }
                        x = nx; y = ny
                    }
                case "+":
                    angle += 25
                case "-":
                    angle -= 25
                case "[":
                    stack.append((x, y, angle))
                case "]":
                    if let (sx, sy, a) = stack.popLast() {
                        x = sx; y = sy; angle = a
                    }
                default:
                    break
                }
            }
            // place leaf glyph at tip
            if y >= 0 && y < height && x >= 0 && x < width {
                canvas[y][x] = leafGlyph
            }
        }
        // clear screen
        print("\u{001B}[2J")
        // draw
        for line in canvas {
            print(String(line))
        }
    }
}

// ---------- Main Loop ----------
let forest = ASCIIForest()
let generator = TweetGenerator { tweet in
    forest.addTree(from: tweet)
    forest.render()
}

// Keep the script alive
RunLoop.main.run()