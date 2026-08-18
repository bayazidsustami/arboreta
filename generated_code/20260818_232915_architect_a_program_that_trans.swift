import SwiftUI
import Combine

// MARK: - Models & Shader Types
/// Captures timing metadata between keystrokes to compute dynamic cadence and acceleration.
struct KeyStrokeMetric {
    let timestamp: Date
    let interval: TimeInterval
    let speed: Double // normalized speed metric
}

// MARK: - Metal Shader Source
/// Metal Fragment Shader generating a dynamic Julia/Mandelbrot-hybrid fractal warped by keystroke dynamics.
let shaderSource = """
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float2 resolution;
    float time;
    float cadence;      // Warps fractal zoom & geometric morphing
    float acceleration; // Warps color spectrum shift & distortion frequency
    float colorShift;   // Cumulative phase offset from keypresses
};

fragment float4 fractalKernel(float2 fragCoord [[position]], constant Uniforms &u [[buffer(0)]]) {
    // Normalize coordinates to [-1.5, 1.5] centered on screen
    float2 st = (fragCoord - 0.5 * u.resolution) / min(u.resolution.x, u.resolution.y);
    
    // Dynamic geometry warp based on cadence and acceleration
    float zoom = 1.2 + sin(u.time * 0.5) * 0.2 + (u.cadence * 0.8);
    float2 c = float2(-0.7 + sin(u.time * 0.2) * 0.1, 0.27015 + u.acceleration * 0.15);
    float2 z = st * zoom;
    
    // Rotate domain based on cadence
    float angle = u.time * 0.1 + u.cadence * 2.0;
    float2x2 rot = float2x2(cos(angle), -sin(angle), sin(angle), cos(angle));
    z = rot * z;
    
    float iter = 0.0;
    const float maxIter = 64.0;
    
    // Fractal Iteration (Julia Set Base with dynamic warp)
    for (int i = 0; i < 64; i++) {
        if (dot(z, z) > 4.0) break;
        // z = z^2 + c with dynamic perturbance from typing acceleration
        z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c + float2(sin(z.y * u.acceleration), cos(z.x * u.acceleration)) * 0.05;
        iter += 1.0;
    }
    
    if (iter >= maxIter) return float4(0.0, 0.0, 0.0, 1.0);
    
    // Smooth coloring algorithm
    float dist = log(dot(z, z)) * 0.5;
    float smoothIter = iter - log2(max(1.0, dist));
    
    // Dynamic Spectrum Generation
    float paletteOffset = u.colorShift + smoothIter * 0.05 + u.time * 0.05;
    float3 col = 0.5 + 0.5 * cos(6.28318 * (float3(1.0, 1.0, 1.0) * paletteOffset + float3(0.0, 0.33, 0.67) + u.cadence));
    
    // Glow and contrast adjustments
    col *= pow(smoothIter / maxIter, 0.7);
    
    return float4(col, 1.0);
}
"""

// MARK: - Dynamic Tapestry Engine
class TapestryEngine: ObservableObject {
    @Published var inputText: String = "" {
        didSet {
            registerKeystroke()
        }
    }
    
    @Published var cadence: Float = 0.0
    @Published var acceleration: Float = 0.0
    @Published var colorShift: Float = 0.0
    
    private var lastKeyTime: Date?
    private var intervals: [TimeInterval] = []
    private var timer: AnyCancellable?
    
    init() {
        // Smoothly decay metrics over time when user stops typing
        timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.decayMetrics()
            }
    }
    
    private func registerKeystroke() {
        let now = Date()
        if let last = lastKeyTime {
            let interval = now.timeIntervalSince(last)
            intervals.append(interval)
            if intervals.count > 10 { intervals.removeFirst() }
            
            // Calculate average typing speed (cadence)
            let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
            let targetCadence = Float(max(0.0, min(1.0, (0.5 - avgInterval) * 2.0)))
            
            // Calculate acceleration (micro-variance in timing)
            let variance = abs(interval - avgInterval)
            let targetAccel = Float(max(0.0, min(1.0, variance * 5.0)))
            
            // Smoothly interpolate live metrics
            self.cadence = self.cadence * 0.7 + targetCadence * 0.3
            self.acceleration = self.acceleration * 0.7 + targetAccel * 0.3
            self.colorShift += Float(interval) * 0.2
        }
        lastKeyTime = now
    }
    
    private func decayMetrics() {
        if let last = lastKeyTime, Date().timeIntervalSince(last) > 0.5 {
            cadence *= 0.95
            acceleration *= 0.95
        }
    }
}

// MARK: - Metal View Render Bridge
struct FractalTapestryView: View {
    @ObservedObject var engine: TapestryEngine
    @State private var startTime = Date()
    
    var body: some View {
        TimelineView(.animation) { timelineContext in
            let elapsedTime = Float(timelineContext.date.timeIntervalSince(startTime))
            
            Rectangle()
                .colorEffect(
                    ShaderLibrary.fractalKernel(
                        .float2(800, 600), // Default canvas space
                        .float(elapsedTime),
                        .float(engine.cadence),
                        .float(engine.acceleration),
                        .float(engine.colorShift)
                    )
                )
        }
    }
}

// MARK: - Main Application Canvas
struct ContentView: View {
    @StateObject private var engine = TapestryEngine()
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ZStack {
            // Background Fractal Shader Canvas
            FractalTapestryView(engine: engine)
                .ignoresSafeArea()
            
            // Subtle Typing Layer
            VStack {
                Spacer()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Type to Warp the Tapestry")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                    
                    TextField("Type continuous text here...", text: $engine.inputText)
                        .font(.system(size: 16, design: .monospaced))
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .focused($isTextFieldFocused)
                    
                    // Live Micro-Timing Indicators
                    HStack(spacing: 20) {
                        MetricBadge(label: "Cadence", value: engine.cadence)
                        MetricBadge(label: "Variance", value: engine.acceleration)
                    }
                }
                .padding(24)
                .background(Color.black.opacity(0.4))
                .cornerRadius(16)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

struct MetricBadge: View {
    let label: String
    let value: Float
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.gray)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: geo.size.width * CGFloat(min(1.0, max(0.0, value))))
                }
            }
            .frame(width: 60, height: 4)
        }
    }
}

@main
struct FractalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}