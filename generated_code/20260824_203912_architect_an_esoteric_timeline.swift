import Foundation

// MARK: - Core Domain Models

public struct GitCommit: Identifiable, Hashable {
    public let id: String
    public let author: String
    public let message: String
    public let timestamp: Date
    public let parentIDs: [String]
    
    public var isMergeCommit: Bool { parentIDs.count > 1 }
    
    public init(id: String, author: String, message: String, timestamp: Date = Date(), parentIDs: [String] = []) {
        self.id = id
        self.author = author
        self.message = message
        self.timestamp = timestamp
        self.parentIDs = parentIDs
    }
}

public struct MergeConflict {
    public let baseCommitID: String
    public let targetBranch: String
    public let conflictingFiles: [String]
    public let severity: Double // Controls collision magnitude (0.0 - 1.0)
}

// MARK: - Esoteric Astronomical Mechanics

public struct CelestialBody {
    public let id: String
    public let label: String
    public var mass: Double
    public var radius: Double
    public var orbitalRadius: Double
    public var orbitalAngle: Double
    public var orbitalVelocity: Double
    public var luminance: Double
    
    public mutating func step(deltaTime: Double) {
        orbitalAngle += orbitalVelocity * deltaTime
        if orbitalAngle >= 2 * .pi {
            orbitalAngle.formRemainder(dividingBy: 2 * .pi)
        }
    }
}

public struct PlanetaryRing {
    public let branchName: String
    public var distance: Double
    public var thickness: Double
    public var particleDensity: Int
    public var primaryColorHex: String
    public var celestialBodies: [CelestialBody] = []
    
    public mutating func assimilate(_ commit: GitCommit) {
        // Commits add mass and generate orbiting celestial bodies within the ring
        let massContribution = Double(commit.message.count) * 0.05 + 1.0
        thickness += 0.2
        particleDensity += 15
        
        let body = CelestialBody(
            id: commit.id,
            label: String(commit.id.prefix(7)),
            mass: massContribution,
            radius: max(1.0, log(massContribution + 1.0)),
            orbitalRadius: distance + Double.random(in: -thickness/2...thickness/2),
            orbitalAngle: Double.random(in: 0..<(2 * .pi)),
            orbitalVelocity: (2.0 / (distance + 1.0)).squareRoot() * Double.random(in: 0.8...1.2),
            luminance: commit.isMergeCommit ? 1.0 : 0.6
        )
        celestialBodies.append(body)
    }
}

public struct GravitationalShockwave {
    public let originRadius: Double
    public var currentRadius: Double
    public var amplitude: Double
    public var decayRate: Double
    
    public var isExtinct: Bool { amplitude <= 0.01 }
    
    public mutating func propagate(deltaTime: Double) {
        currentRadius += 15.0 * deltaTime
        amplitude *= exp(-decayRate * deltaTime)
    }
}

// MARK: - Stellar System Architect & Physics Engine

public final class StellarSystemEngine {
    public private(set) var starMass: Double
    public private(set) var planetaryRings: [String: PlanetaryRing] = [:]
    public private(set) var activeShockwaves: [GravitationalShockwave] = []
    
    private let queue = DispatchQueue(label: "com.stellar.git.engine", qos: .userInteractive)
    private var isRunning = false
    private var ringIndex: Double = 1.0
    
    public init(coreStarMass: Double = 1000.0) {
        self.starMass = coreStarMass
    }
    
    public func registerBranch(_ name: String, colorHex: String = "#3498db") {
        queue.async {
            guard self.planetaryRings[name] == nil else { return }
            let ringDistance = 10.0 + (self.ringIndex * 12.0)
            self.ringIndex += 1.0
            
            let ring = PlanetaryRing(
                branchName: name,
                distance: ringDistance,
                thickness: 1.5,
                particleDensity: 50,
                primaryColorHex: colorHex
            )
            self.planetaryRings[name] = ring
        }
    }
    
    public func ingestCommit(_ commit: GitCommit, on branch: String) {
        queue.async {
            if self.planetaryRings[branch] == nil {
                self.registerBranch(branch)
            }
            self.planetaryRings[branch]?.assimilate(commit)
            self.starMass += 0.5 // Star grows with git activity
        }
    }
    
    public func triggerConflictCollision(_ conflict: MergeConflict) {
        queue.async {
            guard let ring = self.planetaryRings[conflict.targetBranch] else { return }
            
            // Generate shockwave event
            let shockwave = GravitationalShockwave(
                originRadius: ring.distance,
                currentRadius: ring.distance,
                amplitude: conflict.severity * 50.0,
                decayRate: 0.8
            )
            self.activeShockwaves.append(shockwave)
            
            // Perturb bodies on the targeted ring
            if var ringToPerturb = self.planetaryRings[conflict.targetBranch] {
                for i in 0..<ringToPerturb.celestialBodies.count {
                    ringToPerturb.celestialBodies[i].orbitalVelocity *= Double.random(in: -1.5...2.5)
                    ringToPerturb.celestialBodies[i].luminance = 1.0
                }
                self.planetaryRings[conflict.targetBranch] = ringToPerturb
            }
        }
    }
    
    public func updateSystemSimulation(deltaTime: Double) {
        queue.sync {
            // Update orbital positions
            for (branch, var ring) in self.planetaryRings {
                for i in 0..<ring.celestialBodies.count {
                    ring.celestialBodies[i].step(deltaTime: deltaTime)
                }
                self.planetaryRings[branch] = ring
            }
            
            // Propagate shockwaves
            for i in (0..<self.activeShockwaves.count).reversed() {
                self.activeShockwaves[i].propagate(deltaTime: deltaTime)
                if self.activeShockwaves[i].isExtinct {
                    self.activeShockwaves.remove(at: i)
                }
            }
        }
    }
    
    public func renderAsciiFrame() {
        queue.sync {
            print("\u{001B}[2J\u{001B}[H") // Clear console screen
            print("=========================================================")
            print(" STELLAR GIT SYSTEM | Core Star Mass: \(String(format: "%.1f", starMass)) M☉")
            print(" Active Shockwaves: \(activeShockwaves.count)")
            print("=========================================================")
            
            for (branch, ring) in planetaryRings {
                let bodiesCount = ring.celestialBodies.count
                let ringVisual = String(repeating: "o", count: min(bodiesCount, 30))
                print(String(format: "Ring [%-12s] Dist: %4.1f AU | Particles: %4d | Bodies: [%-30s]",
                             branch, ring.distance, ring.particleDensity, ringVisual))
            }
            
            if !activeShockwaves.isEmpty {
                print("\n*** GRAVITATIONAL COLLISION EVENTS IN PROGRESS ***")
                for shock in activeShockwaves {
                    print(" Shockwave Radius: \(String(format: "%.2f", shock.currentRadius)) | Intensity: \(String(format: "%.2f", shock.amplitude))")
                }
            }
            print("---------------------------------------------------------")
        }
    }
}

// MARK: - Simulation Runner / Main Script

let engine = StellarSystemEngine()

// Initialize Branches
engine.registerBranch("main", colorHex: "#f1c40f")
engine.registerBranch("feature/astro-physics", colorHex: "#9b59b6")
engine.registerBranch("bugfix/gravity-leak", colorHex: "#e74c3c")

// Simulate Git Activity Stream
let branches = ["main", "feature/astro-physics", "bugfix/gravity-leak"]
var stepCount = 0

let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
    stepCount += 1
    
    // Random commit ingestion
    if Double.random(in: 0...1) > 0.3 {
        let randomBranch = branches.randomElement()!
        let mockCommit = GitCommit(
            id: UUID().uuidString.replacingOccurrences(of: "-", with: ""),
            author: "Developer Celestial",
            message: "Refactored orbital matrix \(stepCount)"
        )
        engine.ingestCommit(mockCommit, on: randomBranch)
    }
    
    // Occasional merge conflict collision event
    if stepCount % 15 == 0 {
        let conflict = MergeConflict(
            baseCommitID: UUID().uuidString,
            targetBranch: "main",
            conflictingFiles: ["Core/Gravity.swift", "Math/Vector.swift"],
            severity: Double.random(in: 0.5...1.0)
        )
        engine.triggerConflictCollision(conflict)
    }
    
    engine.updateSystemSimulation(deltaTime: 0.2)
    engine.renderAsciiFrame()
    
    if stepCount >= 60 {
        print("Simulation complete. Terminating stellar engine.")
        exit(0)
    }
}

RunLoop.main.run()