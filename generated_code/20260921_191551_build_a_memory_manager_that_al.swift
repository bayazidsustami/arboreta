import Foundation

// Virtual Bonsai Memory Manager in Swift
// Allocates heap space by growing a bonsai tree. Memory leaks manifest as dead branches
// that require manual trimming using scissor keystrokes ('x').

class BonsaiBranch {
    let id: UUID = UUID()
    var size: Int
    var isLeaking: Bool
    var health: Int = 100
    var left: BonsaiBranch?
    var right: BonsaiBranch?
    
    init(size: Int, isLeaking: Bool) {
        self.size = size
        self.isLeaking = isLeaking
    }
}

class BonsaiHeapManager {
    private var root: BonsaiBranch?
    private var totalAllocatedBytes: Int = 0
    private var leakCount: Int = 0
    
    // Allocate memory, growing the tree
    func allocate(size: Int, isLeaking: Bool) -> UUID {
        let newBranch = BonsaiBranch(size: size, isLeaking: isLeaking)
        totalAllocatedBytes += size
        if isLeaking { leakCount += 1 }
        
        if let currentRoot = root {
            insert(&root, branch: newBranch)
        } else {
            root = newBranch
        }
        return newBranch.id
    }
    
    private func insert(_ node: inout BonsaiBranch?, branch: BonsaiBranch) {
        guard let current = node else {
            node = branch
            return
        }
        // Alternate left/right growth
        if current.left == nil {
            insert(&current.left, branch: branch)
        } else if current.right == nil {
            insert(&current.right, branch: branch)
        } else {
            insert(&current.left, branch: branch)
        }
    }
    
    // Simulate aging and decay for leaking branches
    func tick() {
        traverseAndDecay(root)
    }
    
    private func traverseAndDecay(_ node: BonsaiBranch?) {
        guard let node = node else { return }
        if node.isLeaking {
            node.health = max(0, node.health - 15)
        }
        traverseAndDecay(node.left)
        traverseAndDecay(node.right)
    }
    
    // Trim dead/leaking branches with scissors
    func trim() -> Int {
        let freed = removeDeadBranches(&root)
        totalAllocatedBytes = max(0, totalAllocatedBytes - freed)
        return freed
    }
    
    private func removeDeadBranches(_ node: inout BonsaiBranch?) -> Int {
        guard let current = node else { return 0 }
        
        var freed = 0
        if current.isLeaking && current.health <= 0 {
            freed += current.size
            leakCount = max(0, leakCount - 1)
            node = nil
            return freed
        }
        
        freed += removeDeadBranches(&current.left)
        freed += removeDeadBranches(&current.right)
        return freed
    }
    
    // Render the bonsai tree to the terminal
    func renderAscii() {
        print("\n=== VIRTUAL BONSAI MEMORY MANAGER ===")
        print("Heap Allocated: \(totalAllocatedBytes) bytes | Active Leaks: \(leakCount)")
        print("Controls: Press 'x' + Enter to snip dead branches, or just Enter to let time pass.\n")
        print("          @ (Apex)")
        print("         / \\")
        renderNode(root, prefix: "        ", isTail: true)
        print("      =========\n")
    }
    
    private func renderNode(_ node: BonsaiBranch?, prefix: String, isTail: Bool) {
        guard let node = node else { return }
        let status: String
        if node.isLeaking {
            if node.health <= 0 {
                status = "💀 [DEAD LEAK]"
            } else {
                status = "🍂 [LEAKING: \(node.health)% HEALTH]"
            }
        } else {
            status = "🌿 [HEALTHY: \(node.size}b]"
        }
        
        print("\(prefix)\(isTail ? "└── " : "├── ")\(status)")
        
        let newPrefix = prefix + (isTail ? "    " : "│   ")
        if node.left != nil || node.right != nil {
            renderNode(node.left, prefix: newPrefix, isTail: false)
            renderNode(node.right, prefix: newPrefix, isTail: true)
        }
    }
    
    func getLeakCount() -> Int {
        return leakCount
    }
}

// Interactive Simulation Loop
let manager = BonsaiHeapManager()

// Seed initial memory structure
_ = manager.allocate(size: 64, isLeaking: false)
_ = manager.allocate(size: 128, isLeaking: true)
_ = manager.allocate(size: 256, isLeaking: false)

print("Starting Bonsai Memory Manager Simulation...")

// Configure terminal for line input
let queue = DispatchQueue(label: "bonsai.simulation")
var running = true

while running {
    manager.renderAscii()
    
    print("Action [x = use scissors, q = quit, enter = water/tick]: ", terminator: "")
    guard let input =readLine()?.lowercased() else { break }
    
    if input == "q" {
        running = false
        print("Exiting Bonsai Manager. Goodbye!")
    } else if input.contains("x") {
        let freed = manager.trim()
        print("✂️ SNIP! Trimmed \(freed) bytes of leaked memory.")
    } else {
        // Normal tick: age the tree and randomly introduce a new memory allocation/leak
        manager.tick()
        let randomSize = Int.random(in: 32...128)
        let isLeak = Bool.random()
        _ = manager.allocate(size: randomSize, isLeaking: isLeak)
        print("💧 Watered tree. New branch allocated (\(randomSize} bytes, leak: \(isLeak)).")
    }
    
    if manager.getLeakCount() > 5 {
        print("\n🔥 Out of Memory! The bonsai has withered completely due to unmanaged leaks.")
        break
    }
}