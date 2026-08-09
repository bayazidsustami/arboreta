import Foundation

// MARK: - Digital Terrarium & ASCII Plant Synthesizer
// Reads real-time system log output via `log stream` (or simulated fallback stream),
// computes entropy and frequency spectrums from the continuous log text bytes,
// and procedurally synthesizes growing fractal ASCII plants inside a terminal viewport.

struct Point {
    var x: Double
    var y: Double
}

class DigitalTerrarium {
    private let width = 80
    private let height = 24
    private var grid: [[Character]]
    private var colorGrid: [[String]]
    
    // Growth driver parameters derived from incoming system log frequency spectrum
    private var spectralEnergy: Double = 0.5
    private var branchAngleDelta: Double = .pi / 5.0
    private var maxDepth: Int = 4
    private var activePalette: Int = 32
    private let processQueue = DispatchQueue(label: "log.spectrum.queue")
    
    init() {
        grid = Array(repeating: Array(repeating: " ", count: width), count: height)
        colorGrid = Array(repeating: Array(repeating: "\u{001B}[0m", count: width), count: height)
    }

    func start() {
        setupTerminal()
        startLogStreamListener()
        
        // Main display loop updating procedural growth step
        while true {
            renderFrame()
            Thread.sleep(forTimeInterval: 0.12)
        }
    }

    private func setupTerminal() {
        print("\u{001B}[2J\u{001B}[H\u{001B}[?25l", terminator: "")
        signal(SIGINT) { _ in
            print("\u{001B}[?25h\u{001B}[0m\n[Terrarium Shutdown]")
            exit(0)
        }
    }

    // Listens to continuous system logs and analyzes ASCII frequency spectrums
    private func startLogStreamListener() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        task.arguments = ["stream", "--style", "compact"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let handle = pipe.fileHandleForReading
            handle.readabilityHandler = { [weak self] fileHandle in
                let data = fileHandle.availableData
                if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                    self?.analyzeLogSpectrum(str)
                }
            }
        } catch {
            // Fallback simulated spectrum reader if system process restricted
            simulateSystemLogStream()
        }
    }

    private func simulateSystemLogStream() {
        let logSamples = [
            "kernel: [cpu0] frequency shift step +1200MHz load 0.78",
            "CoreAudio: output spectrum sample rate 48000Hz buffer ok",
            "syslogd: message log packet burst decay factor 0.42",
            "network: interface en0 rx_bytes frame density high"
        ]
        processQueue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            let line = logSamples.randomElement()!
            self?.analyzeLogSpectrum(line)
            self?.simulateSystemLogStream()
        }
    }

    // Calculates byte entropy and spectral variance to adjust fractal characteristics
    private func analyzeLogSpectrum(_ logText: String) {
        let bytes = Array(logText.utf8)
        guard !bytes.isEmpty else { return }

        let sum = bytes.reduce(0) { $0 + Int($1) }
        let mean = Double(sum) / Double(bytes.count)
        let variance = bytes.reduce(0.0) { $0 + pow(Double($1) - mean, 2) } / Double(bytes.count)

        // Map logarithmic metrics to procedural plant growth traits
        spectralEnergy = min(1.0, max(0.2, variance / 1500.0))
        branchAngleDelta = (.pi / 8.0) + (mean.truncatingRemainder(dividingBy: 20.0) / 20.0) * (.pi / 4.0)
        maxDepth = 3 + Int(spectralEnergy * 3.0)
        activePalette = 31 + (sum % 6) // ANSI colors 31..36
    }

    private func renderFrame() {
        // Reset terrain grid
        grid = Array(repeating: Array(repeating: " ", count: width), count: height)
        colorGrid = Array(repeating: Array(repeating: "\u{001B}[0m", count: width), count: height)

        // Draw dynamic soil bedrock
        for x in 0..<width {
            grid[height - 1][x] = "="
            colorGrid[height - 1][x] = "\u{001B}[32m"
        }

        // Plant seeds growing from soil
        let roots = [15, 32, 50, 68]
        for (i, rootX) in roots.enumerated() {
            let color = "\u{001B}[\(31 + (activePalette + i) % 6);1m"
            growFractalBranch(
                origin: Point(x: Double(rootX), y: Double(height - 2)),
                angle: -.pi / 2.0,
                length: 4.0 + (spectralEnergy * 3.0),
                depth: maxDepth,
                color: color
            )
        }

        // Draw frame buffer output
        var buffer = "\u{001B}[H"
        buffer += "--- REAL-TIME LOG TERRARIUM | Spectral Energy: \(String(format: "%.2f", spectralEnergy)) ---\n"
        for y in 0..<height {
            for x in 0..<width {
                buffer += "\(colorGrid[y][x])\(grid[y][x])"
            }
            buffer += "\u{001B}[0m\n"
        }
        print(buffer, terminator: "")
    }

    // Procedural L-System style fractal recursive generator
    private func growFractalBranch(origin: Point, angle: Double, length: Double, depth: Int, color: String) {
        guard depth > 0 && length > 0.5 else { return }

        var curr = origin
        let dx = cos(angle)
        let dy = sin(angle)

        for _ in 0..<Int(round(length)) +="dy" curr.x curr.y if ix iy="Int(round(curr.y))" let {>= 0 && ix < width && iy >= 0 && iy < height - 1 {
                let glyph: Character = depth == 1 ? (spectralEnergy > 0.6 ? "*" : "%") : (abs(dx) > abs(dy) ? "~" : "|")
                grid[iy][ix] = glyph
                colorGrid[iy][ix] = color
            }
        }

        // Recursive branching driven by log spectrum angles
        let shrink = 0.72
        growFractalBranch(origin: curr, angle: angle - branchAngleDelta, length: length * shrink, depth: depth - 1, color: color)
        growFractalBranch(origin: curr, angle: angle + branchAngleDelta, length: length * shrink, depth: depth - 1, color: color)
    }
}

// Instantiate and execute digital terrarium engine
let terrarium = DigitalTerrarium()
terrarium.start()