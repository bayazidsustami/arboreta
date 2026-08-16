import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Models & Data Structures

struct Star {
    let x: Int
    let y: Int
    let symbol: String
    let magnitude: Double // 0.0 (dim) to 1.0 (bright)
    let word: String
}

struct Article {
    let title: String
    let sentiment: Double // -1.0 (negative) to 1.0 (positive)
}

// MARK: - Sentiment Analysis

class SentimentAnalyzer {
    // Lexicons for basic rule-based sentiment scoring
    private static let positiveWords: Set<String> = [
        "good", "great", "positive", "growth", "win", "gain", "success", "hope",
        "love", "peace", "bright", "rise", "hero", "discovery", "breakthrough",
        "future", "boost", "advance", "thrive", "heal", "solution", "upgrade"
    ]
    
    private static let negativeWords: Set<String> = [
        "bad", "worst", "fail", "loss", "crisis", "war", "death", "threat",
        "fear", "drop", "crash", "dark", "danger", "attack", "storm", "gloom",
        "conflict", "risk", "damage", "hurt", "concern", "decline", "error"
    ]
    
    static func score(text: String) -> Double {
        let tokens = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        
        guard !tokens.isEmpty else { return 0.5 }
        
        var score = 0.0
        for token in tokens {
            if positiveWords.contains(token) { score += 1.0 }
            if negativeWords.contains(token) { score -= 1.0 }
        }
        
        // Normalize between 0.0 and 1.0
        let normalized = (score / Double(max(tokens.count, 1))) * 5.0
        return max(0.0, min(1.0, (normalized + 1.0) / 2.0))
    }
}

// MARK: - RSS XML Parser

class RSSParser: NSObject, XMLParserDelegate {
    private var articles: [Article] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var isInItem = false
    
    func parse(data: Data) -> [Article] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return articles
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName.lowercased()
        if currentElement == "item" || currentElement == "entry" {
            isInItem = true
            currentTitle = ""
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInItem && currentElement == "title" {
            currentTitle += string
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let elem = elementName.lowercased()
        if elem == "item" || elem == "entry" {
            let trimmed = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let sentiment = SentimentAnalyzer.score(text: trimmed)
                articles.append(Article(title: trimmed, sentiment: sentiment))
            }
            isInItem = false
        }
    }
}

// MARK: - Terminal Canvas & Constellation Renderer

class CelestialCanvas {
    let width: Int
    let height: Int
    private var grid: [[String]]
    private var colorGrid: [[String]]
    
    init(width: Int = 80, height: Int = 30) {
        self.width = width
        self.height = height
        self.grid = Array(repeating: Array(repeating: " ", count: width), count: height)
        self.colorGrid = Array(repeating: Array(repeating: "\u{001B}[0m", count: width), count: height)
    }
    
    func clear() {
        grid = Array(repeating: Array(repeating: " ", count: width), count: height)
        colorGrid = Array(repeating: Array(repeating: "\u{001B}[0m", count: width), count: height)
    }
    
    // Select star symbol and ANSI color based on headline sentiment (magnitude)
    private func starAppearance(for magnitude: Double) -> (symbol: String, color: String) {
        switch magnitude {
        case 0.8...1.0:
            return ("★", "\u{001B}[1;33m") // Bright Yellow Bold
        case 0.6..<0.8:
            return ("✦", "\u{001B}[1;36m") // Cyan Bold
        case 0.4..<0.6:
            return ("✶", "\u{001B}[35m")   // Magenta
        case 0.2..<0.4:
            return ("·", "\u{001B}[34m")   // Blue
        default:
            return (".", "\u{001B}[2;37m") // Dim White
        }
    }
    
    // Draw celestial background noise (faint field stars)
    func drawCosmicDust() {
        for y in 0..<height {
            for x in 0..<width {
                if Double.random(in: 0...1) < 0.04 {
                    grid[y][x] = "."
                    colorGrid[y][x] = "\u{001B}[2;30m" // Dark gray
                }
            }
        }
    }
    
    // Trace elliptical orbital trajectories using headline word frequencies
    func plotOrbitalTrajectory(article: Article, index: Int, total: Int) {
        let words = article.title.components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 }
        let frequencyWeight = Double(words.count)
        
        let centerX = Double(width) / 2.0
        let centerY = Double(height) / 2.0
        
        // Ellipse parameters derived from word frequencies and article index
        let radiusX = min(centerX - 2, 10.0 + (Double(index) * 3.5) + frequencyWeight)
        let radiusY = min(centerY - 2, 5.0 + (Double(index) * 1.8) + (frequencyWeight / 2.0))
        let tilt = Double(index) * (Double.pi / 4.0)
        
        let steps = 60
        for i in 0..<steps {
            let theta = (Double(i) / Double(steps)) * 2.0 * Double.pi
            
            // Parametric ellipse with tilt rotation
            let rawX = radiusX * cos(theta)
            let rawY = radiusY * sin(theta)
            
            let rotX = rawX * cos(tilt) - rawY * sin(tilt)
            let rotY = rawX * sin(tilt) + rawY * cos(tilt)
            
            let canvasX = Int(centerX + rotX)
            let canvasY = Int(centerY + rotY)
            
            if canvasX >= 0 && canvasX < width && canvasY >= 0 && canvasY < height {
                // Only place orbit trace if space is empty
                if grid[canvasY][canvasX] == " " || grid[canvasY][canvasX] == "." {
                    grid[canvasY][canvasX] = "°"
                    colorGrid[canvasY][canvasX] = "\u{001B}[30;1m" // Faint gray trail
                }
            }
            
            // Place major stars at key cardinal angles along orbit
            if i % (steps / max(1, min(words.count, 6))) == 0 {
                let starMag = article.sentiment
                let (symbol, color) = starAppearance(for: starMag)
                
                if canvasX >= 0 && canvasX < width && canvasY >= 0 && canvasY < height {
                    grid[canvasY][canvasX] = symbol
                    colorGrid[canvasY][canvasX] = color
                }
            }
        }
    }
    
    func render(feedTitle: String) {
        print("\u{001B}[2J\u{001B}[H") // Clear screen
        print("\u{001B}[1;35m═══ REAL-TIME NEWS CONSTELLATION MAP ═══\u{001B}[0m")
        print("\u{001B}[36mSource Feed: \(feedTitle)\u{001B}[0m\n")
        
        // Top border
        print("┌" + String(repeating: "─", count: width) + "┐")
        
        for y in 0..<height {
            var line = "│"
            for x in 0..<width {
                line += colorGrid[y][x] + grid[y][x] + "\u{001B}[0m"
            }
            line += "│"
            print(line)
        }
        
        // Bottom border
        print("└" + String(repeating: "─", count: width) + "┘")
        
        // Legend
        print("\n\u{001B}[1mMagnitude (Sentiment):\u{001B}[0m \u{001B}[1;33m★ Positive\u{001B}[0m  \u{001B}[1;36m✦ Neutral-High\u{001B}[0m  \u{001B}[35m✶ Neutral\u{001B}[0m  \u{001B}[34m· Dim\u{001B}[0m  \u{001B}[2;37m. Negative\u{001B}[0m")
        print("\u{001B}[1mOrbits:\u{001B}[0m \u{001B}[30;1m° Traced by Word Frequencies\u{001B}[0m\n")
    }
}

// MARK: - Main Execution Flow

let feedURLString = "[https://news.google.com/rss](https://news.google.com/rss)"
guard let feedURL = URL(string: feedURLString) else {
    print("Invalid RSS URL")
    exit(1)
}

print("Observing celestial signals from RSS feed...")

let semaphore = DispatchSemaphore(value: 0)
var fetchedData: Data?

let task = URLSession.shared.dataTask(with: feedURL) { data, response, error in
    fetchedData = data
    semaphore.signal()
}
task.resume()
semaphore.wait()

guard let data = fetchedData else {
    print("Failed to fetch RSS data from sky.")
    exit(1)
}

let parser = RSSParser()
let articles = parser.parse(data: data)

guard !articles.isEmpty else {
    print("No celestial events (articles) found.")
    exit(0)
}

// Render canvas
let canvas = CelestialCanvas(width: 80, height: 26)
canvas.drawCosmicDust()

// Decode first 5 articles into celestial constellations
let maxConstellations = min(articles.count, 5)
for i in 0..<maxConstellations {
    canvas.plotOrbitalTrajectory(article: articles[i], index: i, total: maxConstellations)
}

canvas.render(feedTitle: feedURLString)

// Print Decoded Constellation Transcripts
print("\u{001B}[1;32m[ Decoded Headline Signals ]\u{001B}[0m")
for i in 0..<maxConstellations {
    let a = articles[i]
    let magStr = String(format: "%.2f", a.sentiment)
    print(" \u{001B}[33mOrbit \(i + 1):\u{001B}[0m (Mag: \(magStr)) \(a.title)")
}
print("\n\u{001B}[32m✦ Star map generation complete.\u{001B}[0m")