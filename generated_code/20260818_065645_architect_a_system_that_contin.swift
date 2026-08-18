import Foundation
import AudioToolbox
import CoreAudio

// MARK: - Models & Data Structs

struct Earthquake {
    let id: String
    let magnitude: Double   // Modulates Amplitude and Harmonic Density
    let depth: Double       // Modulates Pitch Base (Deeper = Low frequency, Shallow = High frequency)
    let latitude: Double    // Modulates Spatial Stereo Panning
    let longitude: Double   // Modulates Timbre / Distortion Filter
    let place: String
    let timestamp: Date
}

// USGS GeoJSON Data Models
struct USGSResponse: Decodable {
    struct Feature: Decodable {
        struct Properties: Decodable {
            let mag: Double?
            let place: String?
            let time: Int64
        }
        struct Geometry: Decodable {
            let coordinates: [Double] // [longitude, latitude, depth]
        }
        let id: String
        let properties: Properties
        let geometry: Geometry
    }
    let features: [Feature]
}

// MARK: - Generative Musical Engine

final class SeismicAudioEngine {
    private var audioUnit: AudioComponentInstance?
    private var phase: Double = 0.0
    private var harmonicPhases: [Double] = Array(repeating: 0.0, count: 5)
    
    // Generative Parameters (Modulated by Seismic Activity)
    private var baseFrequency: Double = 110.0   // Root Pitch (Hz)
    private var targetFrequency: Double = 110.0
    private var modulationDepth: Double = 0.0  // Harmonics
    private var panPosition: Double = 0.0      // -1.0 (Left) to +1.0 (Right)
    private var distortionAmount: Double = 0.1 // Timbre grit
    private var targetGain: Double = 0.2
    private var currentGain: Double = 0.0
    private var tempoBPM: Double = 60.0        // Pulsing tempo driven by frequency of earthquakes
    private var pulsePhase: Double = 0.0
    
    private let sampleRate: Double = 44100.0
    private let lock = NSLock()

    init() {
        setupAudioUnit()
    }

    private func setupAudioUnit() {
        var cd = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_DefaultOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        guard let component = AudioComponentFindNext(nil, &cd) else {
            print("Failed to find audio component")
            return
        }

        AudioComponentInstanceNew(component, &audioUnit)

        guard let unit = audioUnit else { return }

        var callbackStruct = AURenderCallbackStruct(
            inputProc: { (inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
                let engine = Unmanaged<SeismicAudioEngine>.fromOpaque(inRefCon).takeUnretainedValue()
                return engine.renderAudio(ioActionFlags: ioActionFlags, timeStamp: inTimeStamp, busNumber: inBusNumber, numberFrames: inNumberFrames, ioData: ioData)
            },
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )

        AudioUnitSetProperty(
            unit,
            kAudioUnitProperty_SetRenderCallback,
            kAudioUnitScope_Input,
            0,
            &callbackStruct,
            UInt32(MemoryLayout<AURenderCallbackStruct>.size)
        )

        var streamFormat = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 8,
            mFramesPerPacket: 1,
            mBytesPerFrame: 8,
            mChannelsPerFrame: 2,
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

        AudioUnitInitialize(unit)
    }

    func start() {
        guard let unit = audioUnit else { return }
        AudioOutputUnitStart(unit)
    }

    func stop() {
        guard let unit = audioUnit else { return }
        AudioOutputUnitStop(unit)
    }

    // Modulate audio synthesis parameters based on incoming seismic event
    func modulate(with event: Earthquake) {
        lock.lock()
        defer { lock.unlock() }

        // Depth modulates target base pitch (Inverted depth mapping: deeper = lower frequency bass)
        let normalizedDepth = max(0.0, min(1.0, event.depth / 600.0))
        self.targetFrequency = 55.0 + (1.0 - normalizedDepth) * 220.0

        // Magnitude modulates harmonic complexity & target gain amplitude
        let magNormalized = max(0.1, min(1.0, event.magnitude / 8.0))
        self.modulationDepth = magNormalized * 4.0
        self.targetGain = min(0.6, 0.1 + magNormalized * 0.4)

        // Latitude controls stereo spatial panning (-90 to +90 mapped to -1.0 to 1.0)
        self.panPosition = max(-1.0, min(1.0, event.latitude / 90.0))

        // Longitude modulates timbral richness/distortion saturation (-180 to +180)
        self.distortionAmount = 0.05 + (abs(event.longitude) / 180.0) * 0.85
        
        // Magnitude accelerates rhythmic pulse speed
        self.tempoBPM = 40.0 + (magNormalized * 160.0)

        print("\n--- [AUDIO SYNTHESIS MODULATED] ---")
        print("Root Freq: \(String(format: "%.2f", targetFrequency)) Hz | Gain: \(String(format: "%.2f", targetGain))")
        print("Harmonics: \(String(format: "%.2f", modulationDepth)) | Distortion: \(String(format: "%.2f", distortionAmount))")
        print("Pan: \(String(format: "%.2f", panPosition)) | Rhythm Tempo: \(String(format: "%.0f", tempoBPM)) BPM\n")
    }

    // Real-time PCM DSP Synthesis Engine (Additive Synth with FM Overtones, Waveshaping, and Panning)
    private func renderAudio(
        ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        timeStamp: UnsafePointer<AudioTimeStamp>,
        busNumber: UInt32,
        numberFrames: UInt32,
        ioData: UnsafeMutablePointer<AudioBufferList>?
    ) -> OSStatus {
        guard let buffers = ioData else { return noErr }
        
        let leftBuffer = buffers.pointee.mBuffers.mData?.assumingMemoryBound(to: Float.self)
        let bufferListPtr = UnsafeMutableAudioBufferListPointer(buffers)
        
        // Extract stereo channels
        let leftChannel = bufferListPtr[0].mData?.assumingMemoryBound(to: Float.self)
        let rightChannel = bufferListPtr.count > 1 ? bufferListPtr[1].mData?.assumingMemoryBound(to: Float.self) : nil

        lock.lock()
        let freq = baseFrequency
        let targetFreq = targetFrequency
        let harmDepth = modulationDepth
        let pan = panPosition
        let distortion = distortionAmount
        let gainTarget = targetGain
        let bpm = tempoBPM
        
        // Smooth parameter transitions
        baseFrequency += (targetFreq - freq) * 0.001
        currentGain += (gainTarget - currentGain) * 0.001
        let gain = currentGain
        lock.unlock()

        let deltaPhase = (2.0 * .pi * freq) / sampleRate
        let pulseIncrement = (bpm / 60.0) / sampleRate

        for frame in 0..<Int(numberFrames) +="deltaPhase" if phase {> 2.0 * .pi { phase -= 2.0 * .pi }

            // Dynamic Rhythm Envelope Generator
            pulsePhase += pulseIncrement
            if pulsePhase > 1.0 { pulsePhase -= 1.0 }
            let envelope = pow(sin(pulsePhase * .pi), 4.0)

            // Fundamental Sine Synth
            var sample = sin(phase)

            // Dynamic Harmonics generation based on seismic magnitude modulation
            for i in 1...4 {
                let harmonicCoeff = Double(i + 1)
                harmonicPhases[i - 1] += deltaPhase * harmonicCoeff
                if harmonicPhases[i - 1] > 2.0 * .pi { harmonicPhases[i - 1] -= 2.0 * .pi }
                
                let harmonicAmp = (harmDepth / Double(i)) * 0.2
                sample += sin(harmonicPhases[i - 1]) * harmonicAmp
            }

            // Timbre modulation: Non-linear soft-clipping saturation (earthquake friction distortion)
            sample = tanh(sample * (1.0 + distortion * 3.0))

            // Apply Rhythmic Envelope and Global Gain
            let finalSample = Float(sample * gain * envelope)

            // Equal Power Stereo Panning Calculation based on Latitude
            let angle = (pan + 1.0) * (.pi / 4.0) // 0 to pi/2
            let leftGain = Float(cos(angle))
            let rightGain = Float(sin(angle))

            leftChannel?[frame] = finalSample * leftGain
            if let right = rightChannel {
                right[frame] = finalSample * rightGain
            } else if bufferListPtr[0].mNumberChannels == 2 {
                // Interleaved stereo fallback
                leftBuffer?[frame * 2] = finalSample * leftGain
                leftBuffer?[frame * 2 + 1] = finalSample * rightGain
            }
        }

        return noErr
    }
}

// MARK: - Live Global Seismic Network Feed Listener

final class SeismicStreamMonitor {
    // USGS Endpoint for live past-hour globally recorded earthquakes
    private let usgsAPIURL = URL(string: "[https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson](https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson)")!
    private var processedIDs: Set<String> = []
    private var timer: Timer?
    
    var onSeismicEventDetected: ((Earthquake) -> Void)?

    func startMonitoring(pollingInterval: TimeInterval = 10.0) {
        print("🌍 Initializing live global seismic stream listener...")
        fetchLatestEarthquakes()
        
        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            self?.fetchLatestEarthquakes()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func fetchLatestEarthquakes() {
        let task = URLSession.shared.dataTask(with: usgsAPIURL) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                return
            }

            do {
                let decoded = try JSONDecoder().decode(USGSResponse.self, from: data)
                let sortedFeatures = decoded.features.sorted { $0.properties.time < $1.properties.time }

                for feature in sortedFeatures {
                    let id = feature.id
                    if !self.processedIDs.contains(id) {
                        self.processedIDs.insert(id)
                        
                        guard let mag = feature.properties.mag,
                              feature.geometry.coordinates.count >= 3 else { continue }
                        
                        let event = Earthquake(
                            id: id,
                            magnitude: mag,
                            depth: feature.geometry.coordinates[2],
                            latitude: feature.geometry.coordinates[1],
                            longitude: feature.geometry.coordinates[0],
                            place: feature.properties.place ?? "Unknown Location",
                            timestamp: Date(timeIntervalSince1970: TimeInterval(feature.properties.time) / 1000.0)
                        )
                        
                        DispatchQueue.main.async {
                            self.onSeismicEventDetected?(event)
                        }
                    }
                }
            } catch {
                // Parsing safeguard
            }
        }
        task.resume()
    }
}

// MARK: - Main Execution Loop

let audioEngine = SeismicAudioEngine()
let seismicMonitor = SeismicStreamMonitor()

print("""
====================================================================
 🌋 SEISMIC HARMONICS: Continuous Live Earthquake Audio Synthesizer
 Modulation Matrix:
   - Magnitude  -> Harmonization Intensity & Rhythm Speed
   - Depth      -> Fundamental Base Pitch Frequency (Hz)
   - Latitude   -> Dynamic Stereo Panning (-90° to +90°)
   - Longitude  -> Timbre Saturation & Harmonics Distortion
====================================================================
""")

audioEngine.start()

seismicMonitor.onSeismicEventDetected = { quake in
    print("⚡ NEW SEISMIC EVENT DETECTED [\(quake.timestamp.formatted())]")
    print("📍 Location: \(quake.place)")
    print("📊 Magnitude: \(quake.magnitude) Mw | Depth: \(quake.depth) km")
    print("🌐 Coordinates: (\(quake.latitude)°, \(quake.longitude)°)")
    
    audioEngine.modulate(with: quake)
}

seismicMonitor.startMonitoring(pollingInterval: 8.0)

// Keep executable alive
RunLoop.main.run()