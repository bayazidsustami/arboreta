import SwiftUI
import AppKit

// MARK: - Git & Bonsai Models

/// Represents a single Git commit in history.
struct Commit: Identifiable, Equatable {
    let id = UUID()
    let hash: String
    let message: String
    let branchName: String
    let isMergeConflict: Bool
    let timestamp: Date
    
    static func randomHash() -> String {
        String((0..<7).map { _ in "0123456789abcdef".randomElement()! })
    }
}

/// Represents a leaf sprouted by a commit on the Bonsai tree.
struct BonsaiLeaf: Identifiable {
    let id = UUID()
    var offset: CGPoint
    var size: CGFloat
    var color: Color
    var rotation: Double
    var isFalling: Bool = false
    var opacity: Double = 1.0
}

/// Represents a branch in the Git repository and on the Bonsai tree.
class BonsaiBranch: Identifiable, ObservableObject {
    let id = UUID()
    let name: String
    let color: Color
    @Published var commits: [Commit] = []
    @Published var length: CGFloat
    @Published var angle: Double // Angle relative to parent (in degrees)
    @Published var thickness: CGFloat
    @Published var leaves: [BonsaiLeaf] = []
    @Published var childBranches: [BonsaiBranch] = []
    
    init(name: String, color: Color, length: CGFloat = 60, angle: Double = 0, thickness: CGFloat = 12) {
        self.name = name
        self.color = color
        self.length = length
        self.angle = angle
        self.thickness = thickness
    }
    
    func addCommit(_ commit: Commit) {
        commits.append(commit)
        length += 8.0
        thickness += 0.4
        
        // Sprout 2-4 leaves per commit
        let leafCount = Int.random(in: 2...4)
        for _ in 0..<leafCount {
            let progress = CGFloat.random(in: 0.2...1.0)
            let sideOffset = CGFloat.random(in: -18...18)
            let leaf = BonsaiLeaf(
                offset: CGPoint(x: sideOffset, y: -progress * length),
                size: CGFloat.random(in: 8...14),
                color: [.green, Color(red: 0.2, green: 0.7, blue: 0.3), Color(red: 0.4, green: 0.8, blue: 0.2)].randomElement()!,
                rotation: Double.random(in: -45...45)
            )
            leaves.append(leaf)
        }
    }
    
    /// Seasonal Pruning: Triggered by merge conflicts. Sheds half the leaves and trims back branch length.
    func pruneSeasonally() {
        // Retain only 30% of leaves, rest fall off
        leaves = leaves.enumerated().compactMap { index, leaf in
            if index % 3 == 0 {
                var pruned = leaf
                pruned.color = Color(red: 0.85, green: 0.4, blue: 0.2) // Autumn amber
                return pruned
            }
            return nil
        }
        length = max(40, length * 0.7)
        thickness = max(4, thickness * 0.8)
        
        for child in childBranches {
            child.pruneSeasonally()
        }
    }
}

// MARK: - Git Bonsai Simulator Engine

class GitBonsaiEngine: ObservableObject {
    @Published var rootBranch: BonsaiBranch
    @Published var allBranches: [BonsaiBranch] = []
    @Published var commitHistory: [Commit] = []
    @Published var activeBranch: BonsaiBranch
    @Published var pruningNotice: String? = nil
    @Published var seasonName: String = "Spring Growth"
    @Published var isAutoPlaying: Bool = false
    
    private var timer: Timer?
    
    let branchColors: [Color] = [.pink, .cyan, .orange, .purple, .yellow, .mint]
    
    init() {
        let main = BonsaiBranch(name: "main", color: Color(red: 0.35, green: 0.22, blue: 0.15), length: 90, angle: 0, thickness: 18)
        self.rootBranch = main
        self.activeBranch = main
        self.allBranches = [main]
        
        // Initial commits
        pushCommit(message: "Initial commit", isConflict: false)
        pushCommit(message: "Add README & setup project", isConflict: false)
    }
    
    func pushCommit(message: String? = nil, isConflict: Bool = false) {
        let msg = message ?? defaultCommitMessages.randomElement()!
        let commit = Commit(
            hash: Commit.randomHash(),
            message: msg,
            branchName: activeBranch.name,
            isMergeConflict: isConflict,
            timestamp: Date()
        )
        
        commitHistory.insert(commit, at: 0)
        activeBranch.addCommit(commit)
        
        if isConflict {
            triggerMergeConflictPruning()
        }
    }
    
    func createBranch(name: String) {
        guard !allBranches.contains(where: { $0.name == name }) else { return }
        
        let newAngle = Double.random(in: 25...50) * (allBranches.count % 2 == 0 ? 1 : -1)
        let color = branchColors[allBranches.count % branchColors.count]
        let newBranch = BonsaiBranch(name: name, color: color, length: 50, angle: newAngle, thickness: activeBranch.thickness * 0.65)
        
        activeBranch.childBranches.append(newBranch)
        allBranches.append(newBranch)
        activeBranch = newBranch
        
        pushCommit(message: "Branch '\(name)' created", isConflict: false)
    }
    
    func triggerMergeConflictPruning() {
        pruningNotice = "⚡ MERGE CONFLICT DETECTED! Dramatic Seasonal Pruning Initiated..."
        seasonName = "Autumn Conflict Pruning"
        
        withAnimation(.easeInOut(duration: 1.2)) {
            rootBranch.pruneSeasonally()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.pruningNotice = nil
            self.seasonName = "Spring Renewal"
        }
    }
    
    func toggleAutoPlay() {
        isAutoPlaying.toggle()
        if isAutoPlaying {
            timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                let shouldConflict = Double.random(in: 0...1) < 0.15
                let shouldBranch = Double.random(in: 0...1) < 0.2 && self.allBranches.count < 6
                
                if shouldBranch {
                    let branchNames = ["feature/auth", "fix/css-layout", "refactor/core", "release/v2", "experimental/ai"]
                    if let available = branchNames.first(where: { name in !self.allBranches.contains(where: { $0.name == name }) }) {
                        self.createBranch(name: available)
                        return
                    }
                }
                
                self.pushCommit(isConflict: shouldConflict)
            }
        } else {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private let defaultCommitMessages = [
        "Fix memory leak in render loop",
        "Implement dark mode support",
        "Update dependencies and build tools",
        "Refactor tree rendering pipeline",
        "Add unit tests for commit parser",
        "Optimize branch layout algorithm",
        "Fix edge case in merge resolution",
        "Update API documentation"
    ]
}

// MARK: - SwiftUI Views & Renderer

struct BonsaiBranchView: View {
    @ObservedObject var branch: BonsaiBranch
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Branch Trunk Path
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addQuadCurve(
                    to: CGPoint(x: 0, y: -branch.length),
                    control: CGPoint(x: branch.angle * 0.3, y: -branch.length * 0.5)
                )
            }
            .stroke(
                LinearGradient(
                    colors: [branch.color, branch.color.opacity(0.8)],
                    startPoint: .bottom,
                    endPoint: .top
                ),
                style: StrokeStyle(lineWidth: branch.thickness, lineCap: .round, lineJoin: .round)
            )
            
            // Leaves
            ForEach(branch.leaves) { leaf in
                Circle()
                    .fill(leaf.color)
                    .frame(width: leaf.size, height: leaf.size * 1.4)
                    .rotationEffect(.degrees(leaf.rotation))
                    .offset(x: leaf.offset.x, y: leaf.offset.y)
                    .shadow(color: leaf.color.opacity(0.4), radius: 2)
            }
            
            // Sub-branches recursively rendered
            ForEach(branch.childBranches) { subBranch in
                BonsaiBranchView(branch: subBranch)
                    .offset(y: -branch.length * 0.7)
                    .rotationEffect(.degrees(subBranch.angle), anchor: .bottom)
            }
        }
    }
}

struct BonsaiSimulatorView: View {
    @StateObject private var engine = GitBonsaiEngine()
    @State private var newBranchName: String = ""
    
    var body: some View {
        HSplitView {
            // Left Panel: Interactive Tree Canvas
            ZStack {
                // Zen Garden Background
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.12, blue: 0.15), Color(red: 0.05, green: 0.06, blue: 0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Sun / Moon Glow
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: 180, y: -180)
                
                // Pot / Base
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Bonsai Tree Root
                    BonsaiBranchView(branch: engine.rootBranch)
                        .padding(.bottom, -10)
                    
                    // Pot Graphics
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.25, green: 0.2, blue: 0.18))
                            .frame(width: 220, height: 35)
                            .shadow(radius: 8)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.18, green: 0.14, blue: 0.12))
                            .frame(width: 240, height: 12)
                            .offset(y: -12)
                    }
                    .padding(.bottom, 40)
                }
                
                // Overlay Season Badge & Pruning Notice
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bonsai Git Status")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text(engine.seasonName)
                                .font(.title2)
                                .bold()
                                .foregroundColor(.pink)
                        }
                        Spacer()
                    }
                    .padding()
                    
                    if let notice = engine.pruningNotice {
                        Text(notice)
                            .font(.callout)
                            .bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.red.opacity(0.85)))
                            .shadow(color: .red, radius: 10)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Spacer()
                }
            }
            .frame(minWidth: 550, minHeight: 600)
            
            // Right Panel: Control Dashboard & Git Log
            VStack(alignment: .leading, spacing: 16) {
                Text("Git Bonsai Control Center")
                    .font(.title)
                    .bold()
                
                Divider()
                
                // Actions & Controls
                VStack(alignment: .leading, spacing: 12) {
                    Text("Simulate Git Events").font(.headline)
                    
                    HStack(spacing: 10) {
                        Button(action: { engine.pushCommit() }) {
                            Label("New Commit (+Leaves)", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        
                        Button(action: { engine.pushCommit(isConflict: true) }) {
                            Label("Merge Conflict (Prune)", systemImage: "scissors")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                    
                    HStack {
                        Button(action: { engine.toggleAutoPlay() }) {
                            Label(engine.isAutoPlaying ? "Pause Simulator" : "Auto Growth Mode", systemImage: engine.isAutoPlaying ? "pause.fill" : "play.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Divider()
                
                // Branch Management
                VStack(alignment: .leading, spacing: 10) {
                    Text("Branch Switcher & Sprouter").font(.headline)
                    
                    Picker("Active Branch:", selection: $engine.activeBranch) {
                        ForEach(engine.allBranches) { branch in
                            Text(branch.name).tag(branch)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    HStack {
                        TextField("New branch name...", text: $newBranchName)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Sprout Branch") {
                            if !newBranchName.isEmpty {
                                engine.createBranch(name: newBranchName)
                                newBranchName = ""
                            }
                        }
                        .disabled(newBranchName.isEmpty)
                    }
                }
                
                Divider()
                
                // Git Log Inspector
                Text("Commit History Log").font(.headline)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(engine.commitHistory) { commit in
                            HStack(alignment: .top, spacing: 8) {
                                Text(commit.hash)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(4)
                                    .background(Color.secondary.opacity(0.2))
                                    .cornerRadius(4)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(commit.message)
                                        .font(.body)
                                        .bold(commit.isMergeConflict)
                                        .foregroundColor(commit.isMergeConflict ? .red : .primary)
                                    
                                    Text("Branch: \(commit.branchName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
                        }
                    }
                }
            }
            .padding()
            .frame(minWidth: 320, maxWidth: 400)
        }
    }
}

// MARK: - App Script Launch Setup

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = BonsaiSimulatorView()
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1050, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Git Repository Bonsai Simulator 🪴"
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// Entrypoint runner
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()