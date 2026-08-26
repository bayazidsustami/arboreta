import Foundation

// Quine payload: The exact Swift source string representing the self-replicating logic.
let sourceTemplate = """
import Foundation

let sourceTemplate = %C%@%C

struct QuineAutomaton {
    var state: [Int]
    
    init(size: Int) {
        self.state = (0..<size).map { _ in Int.random(in: 0...1) }
    }
    
    mutating func step() -> [Int] {
        var next = state
        let n = state.count
        for i in 0..<n {
            let left = state[(i - 1 + n) %% n]
            let center = state[i]
            let right = state[(i + 1) %% n]
            let rule30 = left ^ (center | right)
            next[i] = rule30
        }
        self.state = next
        return next
    }
}

func microtonalFrequency(cellIndex: Int, totalCells: Int, stateValue: Int) -> Double {
    let baseFreq = 110.0 // A2
    let centsStep = 1200.0 / Double(totalCells) * 1.5 // Microtonal scale division
    let Cents = Double(cellIndex) * centsStep + (stateValue == 1 ? 14.0 : -14.0)
    return baseFreq * pow(2.0, Cents / 1200.0)
}

var automaton = QuineAutomaton(size: 16)
var audioNodes: [String] = []

for stepIndex in 0..<8 {
    let trace = automaton.step()
    let activeNodes = trace.enumerated().compactMap { (index, val) -> String? in
        guard val == 1 else { return nil }
        let freq = microtonalFrequency(cellIndex: index, totalCells: trace.count, stateValue: val)
        let pan = (Double(index) / Double(trace.count - 1)) * 2.0 - 1.0
        return \"\"\"
        {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();
          const panner = ctx.createStereoPanner();
          osc.type = 'sine';
          osc.frequency.setValueAtTime(\\(freq), ctx.currentTime + \\(Double(stepIndex) * 0.4));
          gain.gain.setValueAtTime(0.0, ctx.currentTime + \\(Double(stepIndex) * 0.4));
          gain.gain.linearRampToValueAtTime(0.08, ctx.currentTime + \\(Double(stepIndex) * 0.4) + 0.1);
          gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + \\(Double(stepIndex) * 0.4) + 0.8);
          panner.pan.value = \\(pan);
          osc.connect(gain); gain.connect(panner); panner.connect(ctx.destination);
          osc.start(ctx.currentTime + \\(Double(stepIndex) * 0.4));
          osc.stop(ctx.currentTime + \\(Double(stepIndex) * 0.4) + 0.95);
        }
        \"\"\"
    }
    audioNodes.append(contentsOf: activeNodes)
}

let htmlContent = \"\"\"
<!DOCTYPE html>
<html>
<head><title>Quine Automaton Soundscape</title></head>
<body style="background:#0d0d11;color:#8a99ad;font-family:monospace;padding:2em;">
  <h2>Quine-Driven Cellular Automaton Soundscape</h2>
  <button id="play" style="background:#1e2530;color:#00ffcc;border:1px solid #00ffcc;padding:10px 20px;cursor:pointer;">Synthesize Trace</button>
  <pre style="margin-top:2em;background:#050508;padding:1em;border-radius:4px;overflow-x:auto;">\\(String(format: sourceTemplate, 34, sourceTemplate, 34))</pre>
  <script>
    document.getElementById('play').onclick = () => {
      const ctx = new (window.AudioContext || window.webkitAudioContext)();
      \\(audioNodes.joined(separator: "\\n"))
    };
  </script>
</body>
</html>
\"\"\"

let outputURL = URL(fileURLWithPath: "soundscape.html")
try? htmlContent.write(to: outputURL, atomically: true, encoding: .utf8)
print("Quine execution complete. Soundscape HTML written to soundscape.html")
"""

struct QuineAutomaton {
    var state: [Int]
    
    init(size: Int) {
        self.state = (0..<size).map { _ in Int.random(in: 0...1) }
    }
    
    mutating func step() -> [Int] {
        var next = state
        let n = state.count
        for i in 0..<n {
            let left = state[(i - 1 + n) % n]
            let center = state[i]
            let right = state[(i + 1) % n]
            let rule30 = left ^ (center | right)
            next[i] = rule30
        }
        self.state = next
        return next
    }
}

// Maps discrete automaton execution state into microtonal frequencies (using cents offsets)
func microtonalFrequency(cellIndex: Int, totalCells: Int, stateValue: Int) -> Double {
    let baseFreq = 110.0 // A2
    let centsStep = 1200.0 / Double(totalCells) * 1.5 // Microtonal scale division
    let cents = Double(cellIndex) * centsStep + (stateValue == 1 ? 14.0 : -14.0)
    return baseFreq * pow(2.0, cents / 1200.0)
}

var automaton = QuineAutomaton(size: 16)
var audioNodes: [String] = []

// Generate execution trace steps and map active cells directly into Web Audio API synthesis graph instructions
for stepIndex in 0..<8 {
    let trace = automaton.step()
    let activeNodes = trace.enumerated().compactMap { (index, val) -> String? in
        guard val == 1 else { return nil }
        let freq = microtonalFrequency(cellIndex: index, totalCells: trace.count, stateValue: val)
        let pan = (Double(index) / Double(trace.count - 1)) * 2.0 - 1.0
        return """
        {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();
          const panner = ctx.createStereoPanner();
          osc.type = 'sine';
          osc.frequency.setValueAtTime(\(freq), ctx.currentTime + \(Double(stepIndex) * 0.4));
          gain.gain.setValueAtTime(0.0, ctx.currentTime + \(Double(stepIndex) * 0.4));
          gain.gain.linearRampToValueAtTime(0.08, ctx.currentTime + \(Double(stepIndex) * 0.4) + 0.1);
          gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + \(Double(stepIndex) * 0.4) + 0.8);
          panner.pan.value = \(pan);
          osc.connect(gain); gain.connect(panner); panner.connect(ctx.destination);
          osc.start(ctx.currentTime + \(Double(stepIndex) * 0.4));
          osc.stop(ctx.currentTime + \(Double(stepIndex) * 0.4) + 0.95);
        }
        """
    }
    audioNodes.append(contentsOf: activeNodes)
}

// Self-reproduction: Formats source code using sourceTemplate and Embeds generated Web Audio graph into HTML output
let quineSource = String(format: sourceTemplate, 34, sourceTemplate, 34)
let htmlContent = """
<!DOCTYPE html>
<html>
<head><title>Quine Automaton Soundscape</title></head>
<body style="background:#0d0d11;color:#8a99ad;font-family:monospace;padding:2em;">
  <h2>Quine-Driven Cellular Automaton Soundscape</h2>
  <button id="play" style="background:#1e2530;color:#00ffcc;border:1px solid #00ffcc;padding:10px 20px;cursor:pointer;">Synthesize Trace</button>
  <pre style="margin-top:2em;background:#050508;padding:1em;border-radius:4px;overflow-x:auto;">\(quineSource)</pre>
  <script>
    document.getElementById('play').onclick = () => {
      const ctx = new (window.AudioContext || window.webkitAudioContext)();
      \(audioNodes.joined(separator: "\n"))
    };
  </script>
</body>
</html>
"""

let outputURL = URL(fileURLWithPath: "soundscape.html")
try? htmlContent.write(to: outputURL, atomically: true, encoding: .utf8)
print("Quine execution complete. Soundscape HTML written to soundscape.html")