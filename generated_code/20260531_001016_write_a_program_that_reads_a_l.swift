import SwiftUI
import AVFoundation
import Accelerate

// MARK: - Audio Engine (mic + synth)

final class AudioEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let mic = AVAudioInputNode()
    private let format: AVAudioFormat
    private let fftSize = 1024
    private var fftSetup: FFTSetup!
    private var window: [Float]!
    
    @Published var spectrum: [Float] = []          // magnitude per bin
    @Published var synthFrequency: Float = 440.0   // A4, mutable by gestures
    
    init() {
        format = engine.inputNode.inputFormat(forBus: 0)
        fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(fftSize))), FFTRadix(kFFTRadix2))
        window = vDSP.window(ofType: Float.self,
                             usingSequence: .hanningDenormalized,
                             count: fftSize,
                             isHalfWindow: false)
        setupChain()
        start()
    }
    
    private func setupChain() {
        // mic → analyser
        engine.attach(mic)
        engine.connect(engine.inputNode, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }
        
        // synth → output
        engine.attach(player)
        let synthFormat = AVAudioFormat(standardFormatWithSampleRate: format.sampleRate, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: synthFormat)
        scheduleSynth()
    }
    
    private func scheduleSynth() {
        let sampleRate = format.sampleRate
        let length = AVAudioFrameCount(sampleRate * 0.1) // 100 ms buffer
        let buffer = AVAudioPCMBuffer(pcmFormat: player.outputFormat(forBus: 0), frameCapacity: length)!
        buffer.frameLength = length
        let thetaInc = 2.0 * Float.pi * synthFrequency / Float(sampleRate)
        var theta: Float = 0
        let ptr = buffer.floatChannelData![0]
        for i in 0..<Int(length) {
            ptr[i] = sin(theta)
            theta += thetaInc
            if theta > 2.0 * Float.pi { theta -= 2.0 * Float.pi }
        }
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        player.play()
    }
    
    private func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP.multiply(channelData, window, result: &windowed)
        
        var real = [Float](repeating: 0, count: fftSize/2)
        var imag = [Float](repeating: 0, count: fftSize/2)
        real.withUnsafeMutableBufferPointer { rp in
            imag.withUnsafeMutableBufferPointer { ip in
                windowed.withUnsafeBufferPointer { wp in
                    var splitComplex = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                    wp.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize) { typePtr in
                        vDSP_ctoz(typePtr, 2, &splitComplex, 1, vDSP_Length(fftSize/2))
                    }
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, vDSP_Length(log2(Float(fftSize))), FFTDirection(FFT_FORWARD))
                    var magnitudes = [Float](repeating: 0, count: fftSize/2)
                    vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize/2))
                    var normalized = [Float](repeating: 0, count: fftSize/2)
                    var scale: Float = 1.0 / Float(fftSize)
                    vDSP_vsrm(&magnitudes, 1, &scale, &normalized, 1, vDSP_Length(fftSize/2))
                    DispatchQueue.main.async { self.spectrum = normalized }
                }
            }
        }
    }
    
    func updateSynthFrequency(by delta: Float) {
        synthFrequency = max(30, min(2000, synthFrequency + delta))
        player.stop()
        scheduleSynth()
    }
}

// MARK: - Glyph Mapping

func glyphForBin(_ magnitude: Float, index: Int) -> String {
    // Simple harmonic‑relationship mapping: pick a Unicode block per octave
    let baseCode: UInt32 = 0x2600 // miscellaneous symbols
    let octave = index / 12
    let offset = UInt32((magnitude * 10).rounded()) % 12
    return String(UnicodeScalar(baseCode + octave * 12 + offset) ?? "?")
}

// MARK: - SwiftUI View

struct ContentView: View {
    @StateObject private var audio = AudioEngine()
    @State private var offset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 0) {
                    ForEach(Array(audio.spectrum.enumerated()), id: \.0) { i, mag in
                        Text(glyphForBin(mag, index: i))
                            .font(.system(size: 24 + CGFloat(mag * 50)))
                            .frame(width: 30, height: geo.size.height)
                    }
                }
            }
            .content.offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { v in
                        offset = v.translation.width
                        let deltaFreq = Float(v.translation.width / 10)
                        audio.updateSynthFrequency(by: deltaFreq)
                    }
                    .onEnded { _ in offset = 0 }
            )
        }
        .frame(minWidth: 400, minHeight: 200)
    }
}

// MARK: - App Entry

@main
struct GlyphSpectrumApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}