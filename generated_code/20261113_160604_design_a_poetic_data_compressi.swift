import Foundation

// A poetic data compression tool that reduces text files into an evolving ASCII choreography
// of migrating birds (flocking behavior reflecting the entropy of the source data).

// MARK: - Entropy & Compression Analysis

/// Calculates the Shannon entropy of a given data stream (bytes).
func calculateEntropy(of data: Data) -> Double {
    guard !data.isEmpty else { return 0.0 }
    var frequency = [UInt8: Int]()
    for byte in data {
        frequency[byte, default: 0] += 1
    }
    
    let total = Double(data.count)
    var entropy = 0.0
    for count in frequency.values {
        let probability = Double(count) / total
        entropy -= probability * log2(probability)
    }
    return entropy // Scaled between 0.0 and 8.0 for a byte stream
}

/// Represents the "compressed" essence of the data file in a poetic format.
struct PoeticCompressedArchive {
    let originalSize: Int
    let entropy: Double
    let signature: String
    
    var description: String {
        return """
        --- POETIC COMPRESSION ARCHIVE ---
        Source Size: \(originalSize) bytes
        Data Entropy: \(String(format: "%.4f", entropy)) bits/byte
        Signature: \(signature)
        -----------------------------------
        """
    }
}

/// Compresses raw data into a poetic archive structure.
func compressToPoetry(data: Data) -> PoeticCompressedArchive {
    let entropy = calculateEntropy(of: data)
    
    // Create a compact cryptographic-like poetic signature using checksum and entropy
    let checksum = data.reduce(0, ^)
    let signature = String(format: "AERO-%02X-%02.2f", checksum, entropy * 10)
    
    return PoeticCompressedArchive(
        originalSize: data.count,
        entropy: entropy,
        signature: signature
    )
}

// MARK: - Flocking Simulation Model (Boids)

struct Vector2D {
    var x: Double
    var y: Double
    
    static func + (lhs: Vector2D, rhs: Vector2D) -> Vector2D {
        return Vector2D(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    static func - (lhs: Vector2D, rhs: Vector2D) -> Vector2D {
        return Vector2D(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    static func * (lhs: Vector2D, rhs: Double) -> Vector2D {
        return Vector2D(x: lhs.x * rhs, y: lhs.y * rhs)
    }
    
    mutating func add(_ other: Vector2D) {
        x += other.x
        y += other.y
    }
    
    var magnitude: Double {
        return sqrt(x*x + y*y)
    }
    
    func normalized() -> Vector2D {
        let mag = magnitude
        guard mag > 0 else { return Vector2D(x: 0, y: 0) }
        return Vector2D(x: x / mag, y: y / mag)
    }
    
    func limited(to max: Double) -> Vector2D {
        let mag = magnitude
        if mag > max {
            return normalized() * max
        }
        return self
    }
}

class Bird {
    var position: Vector2D
    var velocity: Vector2D
    var acceleration: Vector2D
    
    init(position: Vector2D, velocity: Vector2D) {
        self.position = position
        self.velocity = velocity
        self.acceleration = Vector2D(x: 0, y: 0)
    }
    
    func update(bounds: (width: Int, height: Int), maxSpeed: Double, maxForce: Double) {
        velocity = (velocity + acceleration).limited(to: maxSpeed)
        position = position + velocity
        acceleration = Vector2D(x: 0, y: 0) // Reset
        
        // Wrap around boundaries (migratory loop)
        if position.x < 0 { position.x = Double(bounds.width) }
        if position.x > Double(bounds.width) { position.x = 0 }
        if position.y < 0 { position.y = Double(bounds.height) }
        if position.y > Double(bounds.height) { position.y = 0 }
    }
    
    func applyForce(_ force: Vector2D) {
        acceleration.add(force)
    }
}

// MARK: - Choreography Engine

class FlockChoreographer {
    private var birds: [Bird] = []
    let width = 60
    let height = 20
    
    // Behaviors tuned by entropy
    var alignmentWeight: Double = 1.0
    var cohesionWeight: Double = 1.0
    var separationWeight: Double = 1.5
    var chaosFactor: Double = 0.0
    
    init(birdCount: Int, entropy: Double) {
        // High entropy = more chaotic, erratic flight paths (dense/unstructured data)
        // Low entropy = highly aligned, smooth flocking (structured/repetitive data)
        self.chaosFactor = entropy / 2.0
        self.alignmentWeight = max(0.2, 2.0 - (entropy * 0.2))
        self.cohesionWeight = max(0.2, 1.5 - (entropy * 0.1))
        
        for _ in 0..<birdCount {
            let pos = Vector2D(x: Double(arc4random_uniform(UInt32(width))),
                               y: Double(arc4random_uniform(UInt32(height))))
            let vel = Vector2D(x: Double(arc4random_uniform(3)) - 1.0,
                               y: Double(arc4random_uniform(3)) - 1.0).normalized() * 1.5
            birds.append(Bird(position: pos, velocity: vel))
        }
    }
    
    func step() {
        for bird in birds {
            // Apply boid rules simplified for CLI rendering
            let steer = Vector2D(
                x: (Double(arc4random_uniform(100)) / 50.0 - 1.0) * chaosFactor,
                y: (Double(arc4random_uniform(100)) / 50.0 - 1.0) * chaosFactor
            )
            bird.applyForce(steer)
            bird.update(bounds: (width, height), maxSpeed: 2.0, maxForce: 0.1)
        }
    }
    
    func renderFrame() -> String {
        // Initialize grid with spaces
        var grid = Array(repeating: Array(repeating: " ", count: width), count: height)
        
        for bird in birds {
            let x = min(max(Int(bird.position.x), 0), width - 1)
            let y = min(max(Int(bird.position.y), 0), height - 1)
            
            // Choose character based on velocity direction for wing-flapping effect
            let symbol = bird.velocity.x > 0 ? ">" : "<"
            grid[y][x] = symbol
        }
        
        return grid.map { $0.joined() }.joined(separator: "\n")
    }
}

// MARK: - Main Execution Script

func runPoeticCompressionCLI() {
    print("🕊️  Initializing Poetic Data Compression & Choreography Tool...")
    
    // Simulate reading a source text file (or accept sample text payload)
    let sampleText = """
    Swift is a general-purpose, multi-paradigm, compiled programming language developed by Apple Inc.
    Data compression reduces the number of bits needed to store or transmit data.
    Entropy measures the randomness or unpredictability of information within a stream.
    When text turns into birds, the code becomes alive, flying across the terminal sky.
    """
    
    guard let sourceData = sampleText.data(using: .utf8) else {
        print("Failed to encode source text.")
        return
    }
    
    // Compress data into poetic form
    let archive = compressToPoetry(data: sourceData)
    print("\n\(archive.description)\n")
    print("Translating entropy into avian choreography... (Press Ctrl+C to exit)\n")
    Thread.sleep(forTimeInterval: 2.0)
    
    // Initialize flock based on data entropy
    let choreographer = FlockChoreographer(birdCount: 35, entropy: archive.entropy)
    
    // Run an animated choreography sequence in the terminal
    for _ in 0..<50 {
        // Clear screen via ANSI escape codes
        print("\u{001B}[H\u{001B}[2J")
        print("Migrating Archive Signature: \(archive.signature) | Entropy-driven Flight Active\n")
        
        choreographer.step()
        print(choreographer.renderFrame())
        
        print("\n[ Flock state reflects source entropy: \(String(format: "%.2f", archive.entropy)) ]")
        Thread.sleep(forTimeInterval: 0.15)
    }
    
    print("\n✨ Compression choreography completed successfully.")
}

// Execute the script
runPoeticCompressionCLI()