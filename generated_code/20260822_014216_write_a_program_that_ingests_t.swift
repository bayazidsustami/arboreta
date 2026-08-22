import AVFoundation
import MetalKit
import AppKit
import Accelerate

// MARK: - Audio Processing & Audio-to-Emotion Vector Pipeline

final class AudioAnalysisPipeline: NSObject {
    private let audioEngine = AVAudioEngine()
    private let fftSize = 1024
    private var fftSetup: FFTSetup?
    
    // Audio Features
    @UnsafeAtomic var rmsEnergy: Float = 0.0
    @UnsafeAtomic var spectralCentroid: Float = 0.0
    @UnsafeAtomic var spectralEntropy: Float = 0.0
    
    // Derived Emotional & Physical Vectors
    var valence: Float = 0.5   // Emotional positivity/negativity
    var arousal: Float = 0.0   // Emotional intensity/activation
    var entropy: Float = 0.0   // Room noise entropy / decay driver
    
    override init() {
        fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(fftSize))), FFTRadix(kFFTRadix2))
        super.init()
        setupAudioEngine()
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }
    
    private func setupAudioEngine() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: format) { [weak self] buffer, _ in
            self?.processAudio(buffer: buffer)
        }
        
        do {
            try audioEngine.start()
        } catch {
            print("Audio Engine Initialization Error: \(error)")
        }
    }
    
    private func processAudio(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength >= fftSize, let fftSetup = fftSetup else { return }
        
        // 1. Calculate RMS Energy (Arousal baseline)
        var rms: Float = 0.0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(fftSize))
        self.rmsEnergy = rms
        
        // 2. Perform FFT via Accelerate
        var realParts = [Float](repeating: 0.0, count: fftSize / 2)
        var imagParts = [Float](repeating: 0.0, count: fftSize / 2)
        var splitComplex = DSPSplitComplex(realp: &realParts, imagp: &imagParts)
        
        channelData.withMemoryRebound(to: DSPComplex.self, capacity: fftSize) { ptr in
            vDSP_ctoz(ptr, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
        }
        
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, vDSP_Length(log2(Float(fftSize))), FFTDirection(FFT_FORWARD))
        
        var magnitudes = [Float](repeating: 0.0, count: fftSize / 2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
        
        // 3. Spectral Centroid (Timbre brightness -> Valence component)
        var sumMag: Float = 0.0
        var weightedSum: Float = 0.0
        for i in 0..<(fftSize / 2) {
            let mag = sqrt(magnitudes[i])
            sumMag += mag
            weightedSum += mag * Float(i)
        }
        let centroid = sumMag > 0 ? (weightedSum / sumMag) / Float(fftSize / 2) : 0.0
        self.spectralCentroid = centroid
        
        // 4. Spectral Entropy (Chaos/Decay factor)
        var entropyVal: Float = 0.0
        if sumMag > 0 {
            for i in 0..<(fftSize / 2) {
                let p = sqrt(magnitudes[i]) / sumMag
                if p > 0 {
                    entropyVal -= p * log2(p)
                }
            }
            entropyVal /= log2(Float(fftSize / 2))
        }
        self.spectralEntropy = entropyVal
        
        // Update Emotional State Vectors (Smooth low-pass filtered continuous mapping)
        self.arousal = self.arousal * 0.85 + (min(rms * 8.0, 1.0)) * 0.15
        self.valence = self.valence * 0.90 + (centroid * 1.5) * 0.10
        self.entropy = self.entropy * 0.80 + (entropyVal) * 0.20
    }
}

// Simple property wrapper helper for atomic floating values across audio/render threads
@propertyWrapper
struct UnsafeAtomic<Value> {
    private var storage: Value
    private let lock = NSLock()
    
    init(wrappedValue: Value) {
        self.storage = wrappedValue
    }
    
    var wrappedValue: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
        set {
            lock.lock()
            storage = newValue
            lock.unlock()
        }
    }
}

// MARK: - Metal Shaders (Embedded MSL Source)

let metalShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float time;
    float arousal;
    float valence;
    float entropy;
    float2 resolution;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut vertexMain(uint vertexID [[vertex_id]]) {
    // Screen-filling quad triangle trick
    float2 grid[6] = {
        float2(-1.0, -1.0), float2( 1.0, -1.0), float2(-1.0,  1.0),
        float2(-1.0,  1.0), float2( 1.0, -1.0), float2( 1.0,  1.0)
    };
    VertexOut out;
    out.position = float4(grid[vertexID], 0.0, 1.0);
    out.uv = grid[vertexID] * 0.5 + 0.5;
    return out;
}

// 3D Generative Raymarching Scene
float mapTapestry(float3 p, float time, float arousal, float valence, float entropy) {
    // Warp space based on dynamic acoustic entropy
    float twist = mix(0.2, 2.5, entropy);
    float c = cos(twist * p.y + time * (0.5 + arousal));
    float s = sin(twist * p.y + time * (0.5 + arousal));
    float2x2 m = float2x2(c, -s, s, c);
    p.xz = m * p.xz;

    // Generative weave geometry deformation
    float scale = 3.0 + arousal * 4.0;
    float weave = sin(p.x * scale + time) * cos(p.y * scale + time) * sin(p.z * scale);
    
    // Geometry shape deforms from soft organic waves (high valence) to sharp noise (low valence)
    float baseDist = length(p.xz) - (0.8 + 0.3 * sin(p.y * 3.0 + time));
    float roughness = mix(sin(p.x * 10.0) * cos(p.z * 10.0) * 0.1, 
                          fract(sin(dot(p, float3(12.9898, 78.233, 45.164))) * 43758.5453) * 0.2, 
                          entropy);

    return baseDist + weave * (0.15 + arousal * 0.2) + roughness;
}

fragment float4 fragmentMain(VertexOut in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 uv = (in.uv - 0.5) * float2(u.resolution.x / u.resolution.y, 1.0);
    
    // Raymarch Camera Setup
    float3 ro = float3(0.0, 0.0, -2.5);
    float3 rd = normalize(float3(uv, 1.2));
    
    float t = 0.0;
    float maxDist = 10.0;
    float d = 0.0;
    
    for (int i = 0; i < 64; ++i) {
        float3 p = ro + rd * t;
        d = mapTapestry(p, u.time, u.arousal, u.valence, u.entropy);
        if (d < 0.001 || t > maxDist) break;
        t += d * 0.6; // Soft step size for volumetric decay feel
    }

    // Color Palette mapping derived from Emotional Vectors (Valence & Arousal)
    float3 calmColor = float3(0.1, 0.4, 0.8);      // Deep serene blues/teals
    float3 passionateColor = float3(0.9, 0.2, 0.3); // High arousal reds/magentas
    float3 joyfulColor = float3(1.0, 0.8, 0.2);     // High valence warm golds
    
    float3 baseColor = mix(calmColor, joyfulColor, clamp(u.valence, 0.0, 1.0));
    baseColor = mix(baseColor, passionateColor, clamp(u.arousal, 0.0, 1.0));

    // Dynamic Entropy Texture Decay & Lighting
    float3 col = float3(0.0);
    if (t < maxDist) {
        float3 p = ro + rd * t;
        
        // Calculate Normal
        float2 e = float2(0.005, 0.0);
        float3 n = normalize(float3(
            mapTapestry(p + e.xyy, u.time, u.arousal, u.valence, u.entropy) - mapTapestry(p - e.xyy, u.time, u.arousal, u.valence, u.entropy),
            mapTapestry(p + e.yxy, u.time, u.arousal, u.valence, u.entropy) - mapTapestry(p - e.yxy, u.time, u.arousal, u.valence, u.entropy),
            mapTapestry(p + e.yyx, u.time, u.arousal, u.valence, u.entropy) - mapTapestry(p - e.yyx, u.time, u.arousal, u.valence, u.entropy)
        ));

        // Dynamic Lighting affected by Entropy
        float3 lightDir = normalize(float3(sin(u.time), 1.0, -1.0));
        float diff = max(dot(n, lightDir), 0.0);
        float rim = pow(1.0 - max(dot(-rd, n), 0.0), 3.0);
        
        // Dynamic Entropy Decay: Ambient Occlusion & Texture Dissolution
        float decayFactor = exp(-t * (0.1 + u.entropy * 0.5));
        
        col = baseColor * (diff + 0.2) + rim * float3(1.0, 0.9, 0.8) * u.arousal;
        col *= decayFactor; // Decay texture density based on dynamic room noise
    } else {
        // Background Ambient Glow affected by emotional state
        col = baseColor * 0.05 * (1.0 - length(uv));
    }

    return float4(col, 1.0);
}
"""

// MARK: - Metal Renderer & MTKView Delegate

struct MetalUniforms {
    var time: Float = 0
    var arousal: Float = 0
    var valence: Float = 0
    var entropy: Float = 0
    var resolution: SIMD2<Float> = .zero
}

final class TapestryRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private let audioPipeline: AudioAnalysisPipeline
    private var startTime: CFTimeInterval
    
    init(metalView: MTKView, audioPipeline: AudioAnalysisPipeline) {
        guard let defaultDevice = MTLCreateSystemDefaultDevice(),
              let queue = defaultDevice.makeCommandQueue() else {
            fatalError("Metal initialisation failed.")
        }
        self.device = defaultDevice
        self.commandQueue = queue
        self.audioPipeline = audioPipeline
        self.startTime = CACurrentMediaTime()
        
        metalView.device = defaultDevice
        super.init()
        metalView.delegate = self
        
        setupPipeline()
    }
    
    private func setupPipeline() {
        do {
            let library = try device.makeLibrary(source: metalShaderSource, options: nil)
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexMain")
            pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragmentMain")
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to compile Metal shaders: \(error)")
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let pipelineState = pipelineState,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        
        let currentTime = Float(CACurrentMediaTime() - startTime)
        var uniforms = MetalUniforms(
            time: currentTime,
            arousal: audioPipeline.arousal,
            valence: audioPipeline.valence,
            entropy: audioPipeline.entropy,
            resolution: SIMD2<Float>(Float(view.bounds.width), Float(view.bounds.height))
        )
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setBytes(&uniforms, length: MemoryLayout<MetalUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - App Architecture & UI Entry Point

final class TapestryApplicationDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var audioPipeline: AudioAnalysisPipeline!
    var renderer: TapestryRenderer!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prompt for Microphone Permissions
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                if granted {
                    self.startVisualizer()
                } else {
                    print("Microphone access denied. Exiting.")
                    NSApp.terminate(nil)
                }
            }
        }
    }
    
    private func startVisualizer() {
        let windowMask: NSWindow.StyleMask = [.titled, .closable, .resizable, .miniaturizable]
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1024, height: 768),
                          styleMask: windowMask,
                          backing: .buffered,
                          defer: false)
        window.center()
        window.title = "Emotional Tapestry - Generative Audio-Spatial Raymarcher"
        
        let mtkView = MTKView(frame: window.contentView!.bounds)
        window.contentView?.addSubview(mtkView)
        mtkView.autoresizingMask = [.width, .height]
        
        // Initialize Audio Analysis & Renderer Engine
        audioPipeline = AudioAnalysisPipeline()
        renderer = TapestryRenderer(metalView: mtkView, audioPipeline: audioPipeline)
        
        window.makeKeyAndOrderFront(nil)
    }
}

// Executable Script Entrypoint
let app = NSApplication.shared
let delegate = TapestryApplicationDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()