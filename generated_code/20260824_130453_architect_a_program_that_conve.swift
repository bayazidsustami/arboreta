import Foundation
import AVFoundation

// MARK: - Audio Processing Engine
/// Reads an audio file, analyzes its frequency spectrum using FFT, and calculates stereo panning balance.
class SoundscapeAnalyzer {
    let fileURL: URL
    let frameSize = 1024
    
    init(fileURL: URL) {
        self.fileURL = fileURL
    }
    
    struct AudioFrame {
        let spectrum: [Float] // Frequency amplitudes driving landscape height
        let pan: Float       // -1.0 (left) to 1.0 (right) dictating light angle
    }
    
    func analyze() throws -> [AudioFrame] {
        let file = try AVAudioFile(forReading: fileURL)
        let format = file.processingFormat
        let channelCount = Int(format.channelCount)
        let totalFrames = AVAudioFrameCount(file.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else {
            return []
        }
        try file.read(into: buffer)
        
        var frames: [AudioFrame] = []
        let sampleCount = Int(buffer.frameLength)
        let numBands = frameSize / 2
        
        // Window setup for FFT (Hann window)
        var window = [Float](repeating: 0, count: frameSize)
        vDSP_hann_window(&window, vDSP_Length(frameSize), Int32(vDSP_HANN_NORM))
        
        var setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(frameSize), .FORWARD)
        defer { vDSP_DFT_DestroySetup(setup) }
        
        let leftChannel = buffer.floatChannelData?[0]
        let rightChannel = channelCount > 1 ? buffer.floatChannelData?[1] : leftChannel
        
        for step in stride(from: 0, to: sampleCount - frameSize, by: frameSize) {
            guard let left = leftChannel, let right = rightChannel else { break }
            
            // Calculate Stereo Panning Balance
            var leftRMS: Float = 0
            var rightRMS: Float = 0
            vDSP_rmsq(left.advanced(by: step), 1, &leftRMS, vDSP_Length(frameSize))
            vDSP_rmsq(right.advanced(by: step), 1, &rightRMS, vDSP_Length(frameSize))
            
            let totalEnergy = leftRMS + rightRMS
            let pan = totalEnergy > 0.0001 ? (rightRMS - leftRMS) / totalEnergy : 0.0
            
            // Perform Frequency Spectrum Analysis (FFT on Mono Mix)
            var mixedSamples = [Float](repeating: 0, count: frameSize)
            for i in 0..<frameSize {
                mixedSamples[i] = (left[step + i] + right[step + i]) * 0.5 * window[i]
            }
            
            var realIn = mixedSamples
            var imagIn = [Float](repeating: 0, count: frameSize)
            var realOut = [Float](repeating: 0, count: frameSize)
            var imagOut = [Float](repeating: 0, count: frameSize)
            
            vDSP_DFT_Execute(setup!, &realIn, &imagIn, &realOut, &imagOut)
            
            var magnitudes = [Float](repeating: 0, count: numBands)
            for i in 0..<numBands {
                magnitudes[i] = sqrt(realOut[i] * realOut[i] + imagOut[i] * imagOut[i])
            }
            
            frames.append(AudioFrame(spectrum: magnitudes, pan: pan))
        }
        
        return frames
    }
}

// MARK: - Generative ASCII Renderer
/// Translates audio metrics into topographically shaded line-art landscapes.
class ASCIIRenderer {
    let width: Int
    let height: Int
    // Shading gradient from lit (panned side) to shadow
    let lightPalette = Array(" .:-=+*#%@")
    
    init(width: Int = 80, height: Int = 24) {
        self.width = width
        self.height = height
    }
    
    func renderFrame(frame: SoundscapeAnalyzer.AudioFrame) -> String {
        var grid = Array(repeating: Array(repeating: Character(" "), count: width), count: height)
        let spectrum = frame.spectrum
        let lightAngle = Float(frame.pan) // Driven by stereo panning (-1 to 1)
        
        // Render terrain ridges across columns
        for x in 0..<width {
            let specIdx = min(Int(Float(x) / Float(width) * Float(spectrum.count)), spectrum.count - 1)
            let rawHeight = spectrum[specIdx]
            
            // Map magnitude to elevation height
            let elevation = Int(clamp(rawHeight * Float(height) * 0.5, min: 1, max: Float(height - 1)))
            let peakY = height - elevation
            
            for y in peakY..<height {
                // Calculate lighting intensity based on elevation and stereo light direction
                let depthFactor = Float(y - peakY) / Float(max(elevation, 1))
                let lightBias = ((Float(x) / Float(width)) - 0.5) * lightAngle
                let shadeIntensity = clamp((depthFactor + lightBias + 0.5) / 1.5, min: 0.0, max: 1.0)
                
                let paletteIdx = Int(shadeIntensity * Float(lightPalette.count - 1))
                
                if y == peakY {
                    // Topological ridge line outline
                    grid[y][x] = lightAngle > 0 ? "/" : "\\"
                } else {
                    grid[y][x] = lightPalette[paletteIdx]
                }
            }
        }
        
        return grid.map { String($0) }.joined(separator: "\n")
    }
    
    private func clamp(_ value: Float, min: Float, max: Float) -> Float {
        return Swift.max(min, Swift.min(max, value))
    }
}

// MARK: - Audio Synthesizer (Generates demo audio if no file is passed)
func generateSineWav(url: URL) {
    let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 44100.0,
        AVNumberOfChannelsKey: 2,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsFloatKey: false
    ]
    
    guard let writer = try? AVAudioRecorder(url: url, settings: settings) else { return }
    writer.record(forDuration: 3.0)
    writer.stop()
}

// MARK: - Main Script Execution
let tempAudioURL = FileManager.default.temporaryDirectory.appendingPathComponent("demo_landscape.wav")

if !FileManager.default.fileExists(atPath: tempAudioURL.path) {
    generateSineWav(url: tempAudioURL)
}

do {
    let analyzer = SoundscapeAnalyzer(fileURL: tempAudioURL)
    let frames = try analyzer.analyze()
    let renderer = ASCIIRenderer(width: 80, height: 20)
    
    print("\033[2J\033[H") // Clear terminal screen
    print("--- GENERATIVE ASCII SOUNDSCAPE ---")
    print("Frequencies -> Elevation | Stereo Panning -> Shading\n")
    
    // Animate soundscape frames
    for (index, frame) in frames.prefix(60).enumerated() {
        let asciiArt = renderer.renderFrame(frame: frame)
        print("\033[H") // Move cursor to top
        print("Frame: \(index + 1)/\(frames.count) | Pan: \(String(format: "%.2f", frame.pan))")
        print(asciiArt)
        Thread.sleep(forTimeInterval: 0.05)
    }
} catch {
    print("Error processing audio: \(error)")
}