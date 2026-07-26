import AppKit
import AVFoundation
import MetalKit

// MARK: - Metal Shader Source
let metalShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct Particle {
    float2 position;
    float2 velocity;
    float4 color;
    float size;
    float life;
    float maxLife;
    float viscosity;
};

struct Uniforms {
    float2 resolution;
    float time;
    float pitch;
    float timbre;
    float amplitude;
};

vertex float4 vertexShader(uint vertexID [[vertex_id]]) {
    float2 positions[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0)
    };
    return float4(positions[vertexID], 0.0, 1.0);
}

fragment float4 fragmentShader(
    float4 fragCoord [[position]],
    constant Uniforms& uniforms [[buffer(0)]],
    device const Particle* particles [[buffer(1)]],
    constant uint& particleCount [[buffer(2)]]
) {
    float2 uv = fragCoord.xy / uniforms.resolution;
    uv.y = 1.0 - uv.y; // Flip Y for Metal coordinate system
    
    float3 color = float3(0.02, 0.01, 0.04); // Deep ambient background background
    
    // Accumulate light-emitting ink particles with fluid glow
    for (uint i = 0; i < particleCount; i++) {
        Particle p = particles[i];
        if (p.life <= 0.0) continue;
        
        float2 pNorm = p.position / uniforms.resolution;
        float dist = distance(uv, pNorm);
        
        float radius = (p.size / uniforms.resolution.x) * (p.life / p.maxLife);
        
        // Inverse distance field for smooth fluid-like light emission
        if (dist < radius * 4.0) {
            float alpha = smoothstep(radius * 4.0, 0.0, dist);
            float core = smoothstep(radius, 0.0, dist);
            
            float3 inkColor = p.color.rgb;
            color += inkColor * (core * 1.5 + alpha * 0.3) * (p.life / p.maxLife);
        }
    }
    
    // Add subtle procedural fluid swirl noise background
    float swirl = sin(uv.x * 10.0 + uniforms.time) * cos(uv.y * 10.0 + uniforms.time);
    color += float3(0.05 * swirl * uniforms.amplitude);
    
    return float4(saturate(color), 1.0);
}
"""

// MARK: - Particle Structure
struct Particle {
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var color: SIMD4<Float>
    var size: Float
    var life: Float
    var maxLife: Float
    var viscosity: Float
}

struct Uniforms {
    var resolution: SIMD2<Float>
    var time: Float
    var pitch: Float
    var timbre: Float
    var amplitude: Float
}

// MARK: - Audio Processor
class AudioProcessor: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private let captureSession = AVCaptureSession()
    
    var currentPitch: Float = 440.0
    var currentTimbre: Float = 0.5
    var currentAmplitude: Float = 0.0
    
    func start() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            guard granted else { return }
            self.setupAudioInput()
        }
    }
    
    private func setupAudioInput() {
        guard let device = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        captureSession.beginConfiguration()
        if captureSession.canAddInput(input) { captureSession.addInput(input) }
        
        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "audioProcessingQueue"))
        if captureSession.canAddOutput(output) { captureSession.addOutput(output) }
        
        captureSession.commitConfiguration()
        captureSession.startRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        
        CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)
        
        guard let samples = dataPointer else { return }
        let numSamples = length / MemoryLayout<Float>.size
        let floatBuffer = samples.withMemoryRebound(to: Float.self, capacity: numSamples) { UnsafeBufferPointer(start: $0, count: numSamples) }
        
        if floatBuffer.isEmpty { return }
        
        // Calculate Amplitude (RMS)
        var sumSquares: Float = 0
        for sample in floatBuffer { sumSquares += sample * sample }
        let rms = sqrt(sumSquares / Float(floatBuffer.count))
        
        // Zero-crossing rate calculation for Pitch estimation
        var zeroCrossings = 0
        for i in 1..<floatBuffer.count {
            if (floatBuffer[i - 1] >= 0 && floatBuffer[i] < 0) || (floatBuffer[i - 1] < 0 && floatBuffer[i] >= 0) {
                zeroCrossings += 1
            }
        }
        let estimatedFreq = Float(zeroCrossings) * (44100.0 / Float(floatBuffer.count)) / 2.0
        
        // Timbre proxy using Spectral Brightness (high-frequency energy ratio)
        var highFreqEnergy: Float = 0
        for i in 1..<floatBuffer.count {
            let diff = floatBuffer[i] - floatBuffer[i - 1]
            highFreqEnergy += diff * diff
        }
        let timbreMetric = min(1.0, highFreqEnergy / max(0.0001, Float(floatBuffer.count)))
        
        DispatchQueue.main.async {
            self.currentAmplitude = min(1.0, rms * 5.0)
            self.currentPitch = max(100.0, min(2000.0, estimatedFreq))
            self.currentTimbre = timbreMetric
        }
    }
}

// MARK: - Generative Metal View
class GenerativeCanvasView: MTKView {
    private var pipelineState: MTLRenderPipelineState!
    private var commandQueue: MTLCommandQueue!
    
    private var particles: [Particle] = []
    private let maxParticles = 300
    private var particleBuffer: MTLBuffer!
    private var uniformsBuffer: MTLBuffer!
    
    private let audioProcessor = AudioProcessor()
    private var startTime = CFAbsoluteTimeGetCurrent()
    
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device ?? MTLCreateSystemDefaultDevice())
        setupMetal()
        setupBuffers()
        audioProcessor.start()
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupMetal() {
        guard let dev = self.device else { return }
        self.commandQueue = dev.makeCommandQueue()
        
        do {
            let library = try dev.makeLibrary(source: metalShaderSource, options: nil)
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexShader")
            pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            pipelineState = try dev.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Metal compilation error: \(error)")
        }
    }
    
    private func setupBuffers() {
        guard let dev = self.device else { return }
        
        // Initialize fluid particles
        for _ in 0..<maxParticles {
            particles.append(Particle(
                position: SIMD2<Float>(0, 0),
                velocity: SIMD2<Float>(0, 0),
                color: SIMD4<Float>(0, 0, 0, 0),
                size: 0,
                life: 0,
                maxLife: 1.0,
                viscosity: 0.95
            ))
        }
        
        particleBuffer = dev.makeBuffer(length: MemoryLayout<Particle>.stride * maxParticles, options: .storageModeShared)
        uniformsBuffer = dev.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: .storageModeShared)
    }
    
    private func spawnInkDrop() {
        let pitch = audioProcessor.currentPitch
        let timbre = audioProcessor.currentTimbre
        let amp = audioProcessor.currentAmplitude
        
        guard amp > 0.05 else { return }
        
        // Find inactive particle to emit
        if let index = particles.firstIndex(where: { $0.life <= 0 }) {
            let size = bounds.size
            let normalizedPitch = (pitch - 100.0) / 1900.0
            
            // Pitch dictates spawn position, initial force, and dynamic color
            let spawnX = Float(size.width) * (0.2 + 0.6 * normalizedPitch)
            let spawnY = Float(size.height) * 0.2
            
            // Timbre modulates viscosity and initial upward buoyancy velocity
            let buoyancy = 50.0 + timbre * 150.0
            let initialVelocity = SIMD2<Float>(
                Float.random(in: -20...20) * amp,
                buoyancy * amp
            )
            
            // Pitch -> Color Mapping (HSL-like rainbow ink palette)
            let hue = normalizedPitch * 360.0
            let rgb = hslToRGB(h: hue, s: 0.8 + timbre * 0.2, l: 0.5 + amp * 0.3)
            
            particles[index] = Particle(
                position: SIMD2<Float>(spawnX, spawnY),
                velocity: initialVelocity,
                color: SIMD4<Float>(rgb.x, rgb.y, rgb.z, 1.0),
                size: Float.random(in: 15...35) * (1.0 + amp),
                life: 3.0 + Float.random(in: 0...2),
                maxLife: 5.0,
                viscosity: max(0.85, 0.99 - (timbre * 0.1)) // High timbre = sleek fluid; low = viscous ink
            )
        }
    }
    
    private func updatePhysics(deltaTime: Float) {
        let amp = audioProcessor.currentAmplitude
        let timbre = audioProcessor.currentTimbre
        
        spawnInkDrop()
        
        for i in 0..<particles.count {
            if particles[i].life > 0 {
                particles[i].life -= deltaTime
                
                // Buoyancy force upward
                let buoyancyForce = SIMD2<Float>(0, 15.0 * (1.0 + amp))
                
                // Swirl force derived from audio timbre and position
                let angle = (particles[i].position.x * 0.01) + (particles[i].position.y * 0.01) + Float(CFAbsoluteTimeGetCurrent())
                let swirlForce = SIMD2<Float>(cos(angle), sin(angle)) * (20.0 + timbre * 80.0)
                
                // Integrate velocity and viscosity drag
                particles[i].velocity = (particles[i].velocity + (buoyancyForce + swirlForce) * deltaTime) * particles[i].viscosity
                particles[i].position += particles[i].velocity * deltaTime
            }
        }
        
        // Update GPU memory
        let pPointer = particleBuffer.contents().bindMemory(to: Particle.self, capacity: maxParticles)
        for i in 0..<maxParticles {
            pPointer[i] = particles[i]
        }
        
        var uniforms = Uniforms(
            resolution: SIMD2<Float>(Float(bounds.width), Float(bounds.height)),
            time: Float(CFAbsoluteTimeGetCurrent() - startTime),
            pitch: audioProcessor.currentPitch,
            timbre: audioProcessor.currentTimbre,
            amplitude: audioProcessor.currentAmplitude
        )
        memcpy(uniformsBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.stride)
    }
    
    override func draw(_ rect: CGRect) {
        let currentTime = CFAbsoluteTimeGetCurrent()
        let deltaTime = Float(1.0 / 60.0)
        
        updatePhysics(deltaTime: deltaTime)
        
        guard let drawable = currentDrawable,
              let descriptor = currentRenderPassDescriptor,
              let commandQueue = commandQueue,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(nil, offset: 0, index: 0)
        renderEncoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentBuffer(particleBuffer, offset: 0, index: 1)
        
        var count = UInt32(maxParticles)
        renderEncoder.setFragmentBytes(&count, length: MemoryLayout<UInt32>.size, index: 2)
        
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func hslToRGB(h: Float, s: Float, l: Float) -> SIMD3<Float> {
        let c = (1.0 - abs(2.0 * l - 1.0)) * s
        let x = c * (1.0 - abs(fmod(h / 60.0, 2.0) - 1.0))
        let m = l - c / 2.0
        
        var rgb = SIMD3<Float>(0, 0, 0)
        if h < 60 { rgb = SIMD3(c, x, 0) }
        else if h < 120 { rgb = SIMD3(x, c, 0) }
        else if h < 180 { rgb = SIMD3(0, c, x) }
        else if h < 240 { rgb = SIMD3(0, x, c) }
        else if h < 300 { rgb = SIMD3(x, 0, c) }
        else { rgb = SIMD3(c, 0, x) }
        
        return rgb + SIMD3(m, m, m)
    }
}

// MARK: - Application Entry Point
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let windowMask: NSWindow.StyleMask = [.titled, .closable, .resizable, .miniaturizable]
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1024, height: 768),
            styleMask: windowMask,
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Generative Audio Fluid Canvas"
        window.contentView = GenerativeCanvasView(frame: window.contentView!.bounds, device: nil)
        window.makeKeyAndOrderFront(nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()