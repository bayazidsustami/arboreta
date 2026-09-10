import Foundation
import MachO

// MARK: - Telemetry Engine

struct SystemTelemetry {
    var cpuTemperature: Double // In Celsius
    var memoryFragmentation: Double // 0.0 (low) to 1.0 (high)

    static func sample() -> SystemTelemetry {
        // Reads Mach system load and memory info to estimate current performance metrics
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()
        
        var frag = 0.35
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let free = Double(stats.free_count)
            let active = Double(stats.active_count)
            let inactive = Double(stats.inactive_count)
            let total = free + active + inactive
            if total > 0 {
                frag = (inactive / total) * 1.5 // Proxy for dynamic fragmentation
            }
        }
        
        // Simulates thermal oscillation dynamic based on runtime activity
        let baseTemp = 42.0
        let jitter = Double.random(in: -3.0...15.0)
        let temp = min(max(baseTemp + jitter, 30.0), 95.0)
        
        return SystemTelemetry(cpuTemperature: temp, memoryFragmentation: min(max(frag, 0.0), 1.0))
    }
}

// MARK: - Generative Typographic Engine

enum FontStyle {
    case thin, regular, bold, fragmented

    func render(_ char: Character, weight: Double) -> String {
        switch self {
        case .thin:
            return String(char).lowercased()
        case .regular:
            return String(char)
        case .bold:
            return "[1m\(String(char).uppercased())[0m"
        case .fragmented:
            let glitched = ["#", "%", "*", "&", "@", "!"].randomElement() ?? "?"
            return weight > 0.7 ? "[5;31m\(glitched)[0m" : "[33m\(glitched)[0m"
        }
    }
}

struct Poet {
    static let stanzas = [
        "silicon pulses beneath the skin of glass",
        "heat rises like an unseen prayer",
        "memories shatter into scattered light",
        "the machine dreams in voltage and drift",
        "cycles dissolve into the infinite queue"
    ]

    static func compose(telemetry: SystemTelemetry) -> String {
        // Temperature dictates font weight/boldness intensity (0.0 to 1.0)
        let thermalWeight = min(max((telemetry.cpuTemperature - 30.0) / 65.0, 0.0), 1.0)
        let fragRate = telemetry.memoryFragmentation

        let line = stanzas.randomElement() ?? "0101010"
        var renderedPoem = ""

        for char in line {
            if char == " " {
                renderedPoem.append(" ")
                continue
            }

            // Determine font style per character based on dynamic system state
            let style: FontStyle
            let dice = Double.random(in: 0.0...1.0)

            if dice < fragRate * 0.6 {
                style = .fragmented
            } else if thermalWeight > 0.65 {
                style = .bold
            } else if thermalWeight < 0.25 {
                style = .thin
            } else {
                style = .regular
            }

            renderedPoem.append(style.render(char, weight: thermalWeight))
        }

        let tempFormatted = String(format: "%.1f°C", telemetry.cpuTemperature)
        let fragFormatted = String(format: "%.0f%%", telemetry.memoryFragmentation * 100)
        let status = " [TEMP: \(tempFormatted) | FRAG: \(fragFormatted)]"
        
        return renderedPoem + "[36m\(status)[0m"
    }
}

// MARK: - Terminal Rendering Loop

// Clear terminal canvas
print("[2J[H", terminator: "")
print("=== TELEMETRY ASCII POETRY ENGINE ===")
print("Modulating typography via CPU & Memory dynamics... (Press Ctrl+C to stop)\n")

for _ in 1...12 {
    let telemetry = SystemTelemetry.sample()
    let verse = Poet.compose(telemetry: telemetry)
    print("  \(verse)")
    fflush(stdout)
    Thread.sleep(forTimeInterval: 0.4)
}