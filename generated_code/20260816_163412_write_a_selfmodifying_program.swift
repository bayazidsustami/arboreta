import Foundation

// MARK: - AST & Digital Bonsai Architecture

enum SyntaxKind: String, CaseIterable {
    case importDecl = "Import"
    case classDecl  = "Class"
    case funcDecl   = "Function"
    case varDecl    = "Variable"
    case statement  = "Statement"
}

class ASTNode {
    let kind: SyntaxKind
    let name: String
    var children: [ASTNode] = []
    var isWithered: Bool = false
    
    init(kind: SyntaxKind, name: String) {
        self.kind = kind
        self.name = name
    }
}

// MARK: - Memory Leak Tracker & Simulator

class LeakingLeaf {
    var reference: LeakingLeaf? // Retain cycle causing memory leak
}

class MemoryLeakDetector {
    static var leaks: [LeakingLeaf] = []
    
    static func generateLeak() {
        let nodeA = LeakingLeaf()
        let nodeB = LeakingLeaf()
        nodeA.reference = nodeB
        nodeB.reference = nodeA
        leaks.append(nodeA) // Retained unreferenced object graph
    }
}

// MARK: - Self-Parsing AST Engine

class SwiftASTParser {
    static func parse(source: String) -> ASTNode {
        let root = ASTNode(kind: .classDecl, name: "BonsaiSource")
        let lines = source.components(separatedBy: .newlines)
        
        var currentParent = root
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("import") {
                root.children.append(ASTNode(kind: .importDecl, name: String(trimmed.prefix(15))))
            } else if trimmed.hasPrefix("class") || trimmed.hasPrefix("struct") {
                let node = ASTNode(kind: .classDecl, name: String(trimmed.prefix(20)))
                root.children.append(node)
                currentParent = node
            } else if trimmed.hasPrefix("func") {
                let node = ASTNode(kind: .funcDecl, name: String(trimmed.prefix(20)))
                currentParent.children.append(node)
            } else if trimmed.hasPrefix("var") || trimmed.hasPrefix("let") {
                currentParent.children.append(ASTNode(kind: .varDecl, name: String(trimmed.prefix(15))))
            } else if !trimmed.isEmpty && !trimmed.hasPrefix("//") {
                currentParent.children.append(ASTNode(kind: .statement, name: String(trimmed.prefix(12))))
            }
        }
        return root
    }
}

// MARK: - Bonsai Tree Renderer

class BonsaiRenderer {
    static func render(root: ASTNode, leakCount: Int) {
        print("\n🌱 --- DIGITAL BONSAI TREE (AST VISUALIZATION) --- 🌱\n")
        
        // Flatten nodes to simulate branch withered effects from leaks
        var allNodes: [ASTNode] = []
        func collect(_ node: ASTNode) {
            allNodes.append(node)
            node.children.forEach { collect($0) }
        }
        collect(root)
        
        for i in 0..<min(leakCount * 2, allNodes.count) {
            allNodes[i].isWithered = true
        }
        
        print("               .---.                 ")
        print("             (  🌿  )                ")
        print("            (  🌿🌿  )               ")
        
        for (idx, child) in root.children.enumerated() {
            let isLast = idx == root.children.count - 1
            let branchConnector = isLast ? "└── " : "├── "
            let leafSymbol = child.isWithered ? "🥀 [WITHERED LEAK]" : "🍃 [ALIVE]"
            let woodBranch = child.isWithered ? "~~x~~" : "====="
            
            print("        \(branchConnector)\(woodBranch) \(leafSymbol) \(child.kind.rawValue): \(child.name)")
            
            for subChild in child.children.prefix(3) {
                let subLeaf = subChild.isWithered ? "🍂" : "🌿"
                print("        │   ├── \(subLeaf) \(subChild.kind.rawValue): \(subChild.name)")
            }
        }
        
        print("             |||||||                 ")
        print("             |||||||   (AST Trunk)   ")
        print("           ===========               ")
        print("          [===========] (Memory Pot) \n")
    }
}

// MARK: - Lightning Exception & Self-Mutation Engine

enum BonsaiException: Error {
    case unhandledRuntimeGlitch(String)
}

class MutationEngine {
    static func triggerLightningStrikeAndMutate(filePath: String, source: String) {
        print("⚡⚡⚡ UNHANDLED RUNTIME EXCEPTION ENCOUNTERED! ⚡⚡⚡")
        print("⚡ Lightning strikes the Bonsai Tree! ⚡")
        print("                     /\\                     ")
        print("                    /  \\                    ")
        print("                   / /\\ \\                   ")
        print("                  / /  \\ \\                  ")
        print("                 / /____\\ \\                 ")
        print("                /________  \\                ")
        print("                         \\ \\                ")
        print("                          \\/                ")
        
        var mutatedSource = source
        
        // Mutation rules: Flip operators, alter constants, or substitute foliage
        let mutations: [(String, String)] = [
            ("==" , "!="),
            ("+" , "-"),
            ("true" , "false"),
            ("🌿" , "🔥"),
            ("🍃" , "⚡")
        ]
        
        if let target = mutations.randomElement(), mutatedSource.contains(target.0) {
            if let range = mutatedSource.range(of: target.0) {
                mutatedSource.replaceSubrange(range, with: target.1)
                print("\n⚡ MUTATION SUCCESSFUL: Replaced '\(target.0)' with '\(target.1)' in source code! ⚡")
            }
        } else {
            mutatedSource += "\n// Mutated by Lightning Strike at \(Date())\n"
            print("\n⚡ MUTATION SUCCESSFUL: Injected energy surge comment into source code! ⚡")
        }
        
        // Write mutated source back to file if possible
        if FileManager.default.isWritableFile(atPath: filePath) {
            try? mutatedSource.write(toFile: filePath, atomically: true, encoding: .utf8)
            print("⚡ Source file '\(filePath)' successfully rewritten with mutated state. ⚡\n")
        } else {
            print("⚡ Mutated Source Code Preview (Memory-Only): ⚡")
            print(mutatedSource.suffix(300))
        }
    }
}

// MARK: - Execution Lifecycle

func runDigitalBonsai() {
    let filePath = #file
    let sourceCode = (try? String(contentsOfFile: filePath, encoding: .utf8)) ?? """
    import Foundation
    class BonsaiSource {
        func grow() { let status = "Alive" }
        func bloom() { var leaf = "🌿" }
    }
    """
    
    // 1. Parse AST from self source
    let ast = SwiftASTParser.parse(source: sourceCode)
    
    // 2. Cause memory leaks (simulated unreleased retain cycles)
    MemoryLeakDetector.generateLeak()
    MemoryLeakDetector.generateLeak()
    
    // 3. Render Digital Bonsai Tree
    BonsaiRenderer.render(root: ast, leakCount: MemoryLeakDetector.leaks.count)
    
    // 4. Trigger unhandled runtime exception -> Lightning strike self-mutation
    do {
        print("Executing runtime pipeline...")
        throw BonsaiException.unhandledRuntimeGlitch("Uncaught Null Pointer Exception on Branch #3")
    } catch {
        MutationEngine.triggerLightningStrikeAndMutate(filePath: filePath, source: sourceCode)
    }
}

runDigitalBonsai()