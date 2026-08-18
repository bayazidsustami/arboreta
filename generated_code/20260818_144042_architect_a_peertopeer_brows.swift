import Foundation
import Network

// MARK: - Node Telemetry Data
struct NodeState: Codable {
    let id: UUID
    let latencyMs: Double
    let batteryLevel: Float
    let activeTabCount: Int
    var position: (x: Double, y: Double)
    
    enum CodingKeys: String, CodingKey {
        case id, latencyMs, batteryLevel, activeTabCount, posX, posY
    }
    
    init(id: UUID = UUID(), latencyMs: Double, batteryLevel: Float, activeTabCount: Int, position: (x: Double, y: Double)) {
        self.id = id
        self.latencyMs = latencyMs
        self.batteryLevel = batteryLevel
        self.activeTabCount = activeTabCount
        self.position = position
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        latencyMs = try container.decode(Double.self, forKey: .latencyMs)
        batteryLevel = try container.decode(Float.self, forKey: .batteryLevel)
        activeTabCount = try container.decode(Int.self, forKey: .activeTabCount)
        let x = try container.decode(Double.self, forKey: .posX)
        let y = try container.decode(Double.self, forKey: .posY)
        position = (x, y)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(latencyMs, forKey: .latencyMs)
        try container.encode(batteryLevel, forKey: .batteryLevel)
        try container.encode(activeTabCount, forKey: .activeTabCount)
        try container.encode(position.x, forKey: .posX)
        try container.encode(position.y, forKey: .posY)
    }
}

// MARK: - Distributed Fluid Field Grid
final class FluidCanvas {
    let width: Int
    let height: Int
    private(set) var density: [Double]
    private(set) var velocityX: [Double]
    private(set) var velocityY: [Double]
    
    init(width: Int = 32, height: Int = 16) {
        self.width = width
        self.height = height
        self.density = Array(repeating: 0.0, count: width * height)
        self.velocityX = Array(repeating: 0.0, count: width * height)
        self.velocityY = Array(repeating: 0.0, count: width * height)
    }
    
    func applyNodeInfluence(_ node: NodeState) {
        let gridX = min(max(Int(node.position.x * Double(width)), 0), width - 1)
        let gridY = min(max(Int(node.position.y * Double(height)), 0), height - 1)
        let index = gridY * width + gridX
        
        // Active tabs add fluid density/mass into the grid
        let addedDensity = Double(node.activeTabCount) * 15.0
        density[index] += addedDensity
        
        // Battery level governs fluid energy / velocity vector magnitude
        let energy = Double(node.batteryLevel) * 5.0
        
        // Latency determines force turbulence and directional vector angle
        let angle = (node.latencyMs.truncatingRemainder(dividingBy: 360.0)) * (.pi / 180.0)
        velocityX[index] += cos(angle) * energy
        velocityY[index] += sin(angle) * energy
    }
    
    func stepSimulation(viscosity: Double = 0.02, decay: Double = 0.95) {
        var nextDensity = density
        var nextVX = velocityX
        var nextVY = velocityY
        
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let idx = y * width + x
                let neighbors = [
                    (y - 1) * width + x,
                    (y + 1) * width + x,
                    y * width + (x - 1),
                    y * width + (x + 1)
                ]
                
                // Diffuse fluid density and velocity across neighbors
                var avgDensity = 0.0
                var avgVX = 0.0
                var avgVY = 0.0
                for nIdx in neighbors {
                    avgDensity += density[nIdx]
                    avgVX += velocityX[nIdx]
                    avgVY += velocityY[nIdx]
                }
                
                nextDensity[idx] = (density[idx] + viscosity * (avgDensity / 4.0)) * decay
                nextVX[idx] = (velocityX[idx] + viscosity * (avgVX / 4.0)) * decay
                nextVY[idx] = (velocityY[idx] + viscosity * (avgVY / 4.0)) * decay
            }
        }
        
        density = nextDensity
        velocityX = nextVX
        velocityY = nextVY
    }
    
    func renderASCII() -> String {
        let glyphs = [" ", "░", "▒", "▓", "█"]
        var output = "\u{1B}[H\u{1B}[2J" // Clear terminal
        output += "=== P2P Browser Node Fluid Dynamic Canvas ===\n"
        
        for y in 0..<height {
            var line = ""
            for x in 0..<width {
                let val = density[y * width + x]
                let intensity = min(max(Int(val / 10.0), 0), glyphs.count - 1)
                line += glyphs[intensity]
            }
            output += line + "\n"
        }
        return output
    }
}

// MARK: - Peer-to-Peer Browser Node Engine
final class PeerNode {
    let localNodeId = UUID()
    private let listener: NWListener
    private var peerConnections: [NWConnection] = []
    private var networkNodes: [UUID: NodeState] = [:]
    let canvas = FluidCanvas()
    private let queue = DispatchQueue(label: "p2p.fluid.network")
    
    init(port: UInt16 = 8080) throws {
        let params = NWParameters.tcp
        self.listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
    }
    
    func start() {
        listener.newConnectionHandler = { [weak self] newConnection in
            self?.acceptConnection(newConnection)
        }
        listener.start(queue: queue)
        
        // Continuously update local telemetry & simulate fluid dynamics
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    func connectToPeer(host: String, port: UInt16) {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!)
        let connection = NWConnection(to: endpoint, using: .tcp)
        connection.start(queue: queue)
        peerConnections.append(connection)
        receiveData(from: connection)
    }
    
    private func acceptConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        peerConnections.append(connection)
        receiveData(from: connection)
    }
    
    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            if let data = data, let nodeState = try? JSONDecoder().decode(NodeState.self, from: data) {
                self?.networkNodes[nodeState.id] = nodeState
            }
            if error == nil {
                self?.receiveData(from: connection)
            }
        }
    }
    
    private func broadcastLocalState(_ state: NodeState) {
        guard let encoded = try? JSONEncoder().encode(state) else { return }
        for conn in peerConnections {
            conn.send(content: encoded, completion: .contentProcessed({ _ in }))
        }
    }
    
    private func tick() {
        // Collect simulated local node browser telemetry
        let localState = NodeState(
            id: localNodeId,
            latencyMs: Double.random(in: 12.0...180.0),
            batteryLevel: Float.random(in: 0.25...1.0),
            activeTabCount: Int.random(in: 2...18),
            position: (
                x: 0.5 + 0.3 * cos(Date().timeIntervalSince1970 * 0.8),
                y: 0.5 + 0.3 * sin(Date().timeIntervalSince1970 * 0.8)
            )
        )
        
        networkNodes[localNodeId] = localState
        broadcastLocalState(localState)
        
        // Inject peer forces into fluid field & run physical step
        for node in networkNodes.values {
            canvas.applyNodeInfluence(node)
        }
        canvas.stepSimulation()
        
        // Render updated canvas frame
        print(canvas.renderASCII())
        print("Active Peer Nodes: \(networkNodes.count)")
    }
}

// MARK: - Main Execution Flow
let nodePort: UInt16 = 8080
if let p2pNode = try? PeerNode(port: nodePort) {
    p2pNode.start()
    
    // Connect to local peer mesh standard port if available
    p2pNode.connectToPeer(host: "127.0.0.1", port: 8081)
    
    RunLoop.main.run(until: Date().addingTimeInterval(5.0))
}