package main

import (
	"fmt"
	"math"
	"math/rand"
	"os"
	"os/signal"
	"runtime"
	"syscall"
	"time"
)

// Audio Engine Configuration
const (
	SampleRate = 44100
	AudioDev   = "/dev/audio" // Standard Unix raw PCM output
)

// Musical Pitch Definitions (Frequency in Hz)
var (
	ScaleMajor = []float64{261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88, 523.25} // C Major
	ScaleMinor = []float64{220.00, 246.94, 261.63, 293.66, 329.63, 349.23, 392.00, 440.00} // A Minor
)

// Voice represents a single synthesis channel in our polyphonic engine
type Voice struct {
	Active    bool
	Freq      float64
	Phase     float64
	Amplitude float64
	Envelope  float64
	DecayRate float64
}

// MemoryState tracks system heap statistics and musical triggers
type MemoryState struct {
	HeapAlloc    uint64
	HeapObjects  uint64
	NumGC        uint32
	GCCycleDelta bool
}

var (
	voices      [8]Voice
	isFugueMode bool
	fugueTimer  int
)

func main() {
	// Attempt to open the UNIX audio device for raw PCM stream
	audioOut, err := os.OpenFile(AudioDev, os.O_WRONLY, 0666)
	if err != nil {
		// Fallback to stdout if /dev/audio isn't directly accessible (can pipe to a player like `aplay -f U8 -r 44100`)
		audioOut = os.Stdout
	}
	defer audioOut.Close()

	// Handle OS interrupt for clean shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGINT, syscall.SIGTERM)

	// Allocation simulator thread: constantly creates heap churn to drive the visualizer
	go simulateHeapActivity()

	// Memory monitoring goroutine
	memStatsChan := make(chan MemoryState, 10)
	go monitorMemory(memStatsChan)

	// Buffer setup for audio synthesis (8-bit Unsigned PCM, 44.1kHz)
	bufSize := 1024
	audioBuffer := make([]byte, bufSize)

	var lastState MemoryState
	sampleClock := 0.0

	for {
		select {
		case <-sigChan:
			return
		case state := <-memStatsChan:
			// Check if Garbage Collection occurred
			if state.NumGC > lastState.NumGC {
				state.GCCycleDelta = true
			}
			lastState = state

			// Process memory metrics into audio voice parameters
			updateSynthesis(state)

			// Print real-time visualization of Heap state and Musical mode
			renderConsoleVisualizer(state)
		default:
			// Generate digital audio samples
			for i := 0; i < bufSize; i++ {
				sampleClock += 1.0 / SampleRate
				audioBuffer[i] = generateSample()
			}

			// Stream raw audio bytes to output channel
			audioOut.Write(audioBuffer)
		}
	}
}

// simulateHeapActivity generates ongoing heap allocations and triggers periodic manual GC
func simulateHeapActivity() {
	var memorySink [][]byte
	for {
		// Dynamic allocations
		size := rand.Intn(1024*1024) + 1024
		chunk := make([]byte, size)
		memorySink = append(memorySink, chunk)

		// Randomly release memory or trigger GC to create musical dynamics
		if len(memorySink) > 30 || rand.Float32() < 0.05 {
			if len(memorySink) > 0 {
				memorySink = memorySink[:len(memorySink)/2] // Free references
			}
		}
		if rand.Float32() < 0.02 {
			runtime.GC() // Trigger GC Fugue manually on occasion
		}
		time.Sleep(time.Duration(rand.Intn(30)+10) * time.Millisecond)
	}
}

// monitorMemory reads Go runtime statistics and feeds them to the music synthesizer
func monitorMemory(out chan<- MemoryState) {
	var m runtime.MemStats
	for {
		runtime.ReadMemStats(&m)
		out <- MemoryState{
			HeapAlloc:   m.HeapAlloc,
			HeapObjects: m.HeapObjects,
			NumGC:       m.NumGC,
		}
		time.Sleep(20 * time.Millisecond)
	}
}

// updateSynthesis maps runtime system metrics directly into polyphonic sound generators
func updateSynthesis(m MemoryState) {
	// Trigger Polyphonic Fugue Mode on GC event
	if m.GCCycleDelta {
		isFugueMode = true
		fugueTimer = 100 // Duration of Fugue sequence
	}

	if isFugueMode {
		// Generate Polyphonic Counterpoint (Fugue) across all voices
		for i := 0; i < len(voices); i++ {
			scale := ScaleMinor
			noteIdx := (int(m.HeapObjects) + i*3) % len(scale)
			voices[i].Freq = scale[noteIdx] * math.Pow(2, float64(i%3-1)) // Harmonic canon intervals
			voices[i].Amplitude = 0.8 / float64(i+1)
			voices[i].Envelope = 1.0
			voices[i].DecayRate = 0.995
			voices[i].Active = true
		}
		fugueTimer--
		if fugueTimer <= 0 {
			isFugueMode = false
		}
	} else {
		// Continuous Generative Arpeggio transcribed from live Heap Allocation size
		scale := ScaleMajor
		baseNote := int(m.HeapAlloc / 1024 / 100)
		
		// Primary melody voice
		voices[0].Freq = scale[baseNote%len(scale)]
		voices[0].Amplitude = 0.5
		voices[0].Envelope = 0.8
		voices[0].DecayRate = 0.98
		voices[0].Active = true

		// Bass line voice tied to object counts
		voices[1].Freq = scale[int(m.HeapObjects/10)%len(scale)] / 2.0
		voices[1].Amplitude = 0.4
		voices[1].Envelope = 0.9
		voices[1].DecayRate = 0.99
		voices[1].Active = true

		// Mute high fugue voices when outside of GC
		for i := 2; i < len(voices); i++ {
			voices[i].Envelope *= 0.9 // Quick decay
		}
	}
}

// generateSample calculates the instantaneous PCM audio amplitude across active voices
func generateSample() byte {
	var mixedSignal float64

	for i := 0; i < len(voices); i++ {
		if !voices[i].Active {
			continue
		}

		// Phase accumulation for sine/saw wave generation
		voices[i].Phase += voices[i].Freq / SampleRate
		if voices[i].Phase >= 1.0 {
			voices[i].Phase -= 1.0
		}

		// Generative Waveform synthesis: Sine blended with mild Sawtooth harmonic
		sineWave := math.Sin(2.0 * math.Pi * voices[i].Phase)
		sawWave := 2.0*voices[i].Phase - 1.0
		sample := (0.7 * sineWave) + (0.3 * sawWave)

		// Apply envelope decay
		mixedSignal += sample * voices[i].Amplitude * voices[i].Envelope
		voices[i].Envelope *= voices[i].DecayRate
	}

	// Soft Clipping / Master Limiter to prevent 8-bit overflow
	mixedSignal = math.Max(-1.0, math.Min(1.0, mixedSignal))

	// Convert normalized float [-1.0, 1.0] to Unsigned 8-bit PCM [0, 255]
	return byte((mixedSignal + 1.0) * 127.5)
}

// renderConsoleVisualizer prints a real-time ASCII audio-reactive memory score to stderr
func renderConsoleVisualizer(m MemoryState) {
	mb := float64(m.HeapAlloc) / (1024 * 1024)
	barLen := int(mb * 4)
	if barLen > 40 {
		barLen = 40
	}

	heapBar := ""
	for i := 0; i < barLen; i++ {
		heapBar += "█"
	}

	modeStr := "\033[32m[ HARMONIC SCORE ]\033[0m"
	if isFugueMode {
		modeStr = "\033[31;1m[ POLYPHONIC GC FUGUE ]\033[0m"
	}

	fmt.Fprintf(os.Stderr, "\rHeap: [%-40s] %.2f MB | GC Count: %d | Status: %-30s", 
		heapBar, mb, m.NumGC, modeStr)
}