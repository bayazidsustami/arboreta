import Foundation
import AudioToolbox
import SystemConfiguration

// MARK: - CPU Monitor
// Periodically polls host CPU metrics to compute normalized overall system load [0.0 - 1.0].

final class CPUMonitor {
    private var previousInfo: host_cpu_load_info?

    func fetchCurrentLoad() -> Float {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var cpuInfo = host_cpu_load_info()
        
        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0.1 }
        
        defer { previousInfo = cpuInfo }
        
        guard let prev = previousInfo else { return 0.1 }
        
        let userDiff = Double(cpuInfo.cpu_ticks.0 - prev.cpu_ticks.0)
        let systemDiff = Double(cpuInfo.cpu_ticks.1 - prev.cpu_ticks.1)
        let idleDiff = Double(cpuInfo.cpu_ticks.2 - prev.cpu_ticks.2)
        let niceDiff = Double(cpuInfo.cpu_ticks.3 - prev.cpu_ticks.3)
        
        let totalTicks = userDiff + systemDiff + idleDiff + niceDiff
        guard totalTicks > 0 else { return 0.1 }
        
        let activeTicks = userDiff + systemDiff + niceDiff
        return Float(clamping: activeTicks / totalTicks)
    }
}

// MARK: - Generative Ambient Synthesizer
// Uses Audio ToolBox Output Units (CoreAudio API) to synthesize FM/AM multi-oscillator ambient soundscapes.

final class GenerativeAudioEngine {
    private var audioUnit: AudioUnit?
    private var phase: Float = 0.0
    private var phaseLFO: Float = 0.0
    private var sampleRate: Float = 44100.0
    
    // Smoothed target parameters modulated by CPU load
    private var currentLoad: Float = 0.1
    private var targetLoad: Float = 0.1
    
    // Pentatonic scale frequency bases for harmonious ambient evolving tones
    private let baseFrequencies: [Float] = [130.81, 146.83, 164.81, 196.00, 220.00, 261.63, 293.66, 329.63] // C3-E4 Pentatonic

    func start() {
        setupAudioEngine()
    }

    func updateLoad(_ load: Float) {
        // Smooth transition to prevent jarring audio jumps
        self.targetLoad = max(0.05, min(1.0, load))
    }

    private func setupAudioEngine() {
        var cd = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_DefaultOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        guard let comp = AudioComponentFindNext(nil, &cd) else {
            fatalError("Could not find default output audio component.")
        }

        AudioComponentInstanceNew(comp, &audioUnit)

        guard let unit = audioUnit else { return }

        // Audio Stream Basic Description: 32-bit Float, Mono, 44.1kHz
        var streamFormat = AudioStreamBasicDescription(
            mSampleRate: Float64(sampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )

        AudioUnitSetProperty(
            unit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            0,
            &streamFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        )

        var renderCallback = AURenderCallbackStruct(
            inputProc: { (inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
                let engine = Unmanaged<GenerativeAudioEngine>.fromOpaque(inRefCon).takeUnretainedValue()
                return engine.renderAudio(inNumberFrames: inNumberFrames, ioData: ioData)
            },
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )

        AudioUnitSetProperty(
            unit,
            kAudioUnitProperty_SetRenderCallback,
            kAudioUnitScope_Input,
            0,
            &renderCallback,
            UInt32(MemoryLayout<AURenderCallbackStruct>.size)
        )

        AudioUnitInitialize(unit)
        AudioOutputUnitStart(unit)
    }

    private func renderAudio(inNumberFrames: UInt32, ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
        guard let buffers = ioData else { return noErr }
        let buffer = buffers.pointee.mBuffers
        guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { return noErr }

        for frame in 0..<Int(inNumberFrames) (0.6 (FM (LFO) (currentLoad (rootFreq (sine * +="phaseInc" - .pi / // 0.0001 0.15 0.2)) 0.25 0.4 0.5 1)) 1)] 1. 1.0) 2. 3. 50.0 Base Exponential FM Float="(0.15" Float(baseFrequencies.count Frequency Increment LFO Low-Frequency Master Oscillator Output Primary Slow Synthesizer accumulators ambient and architecture: audio baseFrequencies.count by carrier="sin(2.0" clipping complexity creating currentLoad currentLoad) data[frame]="max(-1.0," fmFreq fmIntensity fmSignal="sin(2.0" fmSignal) for frame gain gain: harmonic="sin(4.0" harmonic) if increases index intensity let lfo="(sin(2.0" lfo) load min(1.0, modulated modulation note on organic parameter phase phase) phaseInc="1.0" phaseLFO phaseLFO) rawSample="(carrier" rawSample)) root rootFreq="baseFrequencies[min(scaleIndex," safeguard sample sampleRate scaleIndex="Int(currentLoad" scaling slow smoothing subtle swelling swells synth) system wave wave-like waveform with workload write {> 1000.0 { phase -= 1000.0 }
            if phaseLFO > 1000.0 { phaseLFO -= 1000.0 }
        }

        return noErr
    }
}

// MARK: - CLI Visualizer & Controller
final class AmbientCPUApp {
    private let monitor = CPUMonitor()
    private let engine = GenerativeAudioEngine()
    private var isRunning = true

    func run() {
        print("\u{001B}[2J\u{001B}[H") // Clear screen
        print("=========================================================================")
        print("      GENERATIVE CPU AMBIENT SOUNDSCAPE SOUNDSYNTH (CoreAudio)          ")
        print("=========================================================================")
        print(" Listening to CPU load history and synthesizing real-time audio wave...")
        print(" Press Ctrl+C to exit.\n")

        engine.start()

        // Setup signal handling for clean terminal exit
        signal(SIGINT) { _ in
            print("\n\n [!] Shutting down ambient audio synthesis process. Goodbye!")
            exit(0)
        }

        let historySize = 30
        var history = Array(repeating: Float(0.0), count: historySize)

        while isRunning {
            let load = monitor.fetchCurrentLoad()
            engine.updateLoad(load)

            history.removeFirst()
            history.append(load)

            renderVisualizer(history: history, currentLoad: load)
            Thread.sleep(forTimeInterval: 0.15)
        }
    }

    private func renderVisualizer(history: [Float], currentLoad: Float) {
        let barHeight = 8
        var output = "\u{001B}[H\u{001B}[5;1H" // Move cursor below static header
        
        output += String(format: " Current System CPU Load: [%5.1f%%]  | Harmonic Energy Spectrum\n", currentLoad * 100.0)
        output += " -------------------------------------------------------------------------\n"

        // Render live ASCII waveform canvas based on load history
        for row in (0..<barHeight).reversed() {
            var line = " "
            let threshold = Float(row) / Float(barHeight)
            
            for value in history {
                if value >= threshold {
                    if row > 5 {
                        line += "█" // High load
                    } else if row > 2 {
                        line += "▓" // Medium load
                    } else {
                        line += "░" // Low load
                    }
                } else {
                    line += " "
                }
            }
            output += line + "\n"
        }
        
        output += " -------------------------------------------------------------------------\n"
        output += " Waveform Timeline → (Live Polling Interval: 150ms)\n"
        
        print(output, terminator: "")
        fflush(stdout)
    }
}

// Entry Point
let app = AmbientCPUApp()
app.run()