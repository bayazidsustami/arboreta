package main

import (
	"fmt"
	"math"
	"math/rand"
	"runtime"
	"sync"
	"sync/atomic"
	"time"
)

// Audio Engine Configuration
const (
	SampleRate = 44100
	BufferLen  = 2048
	MicroTones = 12 // 12-tone microtonal division offset base
)

// SystemMetrics holds real-time telemetry captured from Go's runtime memory & concurrency stats.
type SystemMetrics struct {
	HeapAllocBytes uint64  // Directly controls base frequency / pitch space
	HeapInUseBytes uint64  // Controls microtonal pitch modulation & phase offset
	GoroutineCount int     // Controls harmonic density and overtone count
	ContentionRate float64 // Controls ambient noise/dissonance and wave perturbation
}

// CymaticCanvas renders an ASCII fluid tapestry of resonant standing waves.
type CymaticCanvas struct {
	width, height int
	buffer        [][]rune
	chars         []rune
}

func NewCymaticCanvas(w, h int) *CymaticCanvas {
	b := make([][]rune, h)
	for i := range b {
		b[i] = make([]rune, w)
	}
	return &CymaticCanvas{
		width:  w,
		height: h,
		buffer: b,
		// Visual palette from low node density to high antinode amplitude
		chars: []rune(" .:-=+*#%@█"),
	}
}

// Render calculates multi-point Chladni pattern interference equations driven by audio frequencies.
func (c *CymaticCanvas) Render(f1, f2, contention float64, t float64) {
	mx := float64(c.width) / 2.0
	my := float64(c.height) / 2.0
	maxR := math.Hypot(mx, my)

	for y := 0; y < c.height; y++ {
		for x := 0; x < c.width; x++ {
			// Normalize coordinates
			nx := (float64(x) - mx) / mx
			ny := (float64(y) - my) / my
			r := math.Hypot(nx, ny)
			theta := math.Atan2(ny, nx)

			// 2D Cymatic Chladni standing wave pattern equation
			n := 3.0 + math.Sin(f1*0.01)
			m := 2.0 + math.Cos(f2*0.01)

			wave1 := math.Cos(n*math.Pi*nx) * math.Cos(m*math.Pi*ny)
			wave2 := math.Cos(m*math.Pi*nx) * math.Cos(n*math.Pi*ny)
			cymatic := wave1 - wave2

			// Add dynamic phase motion and contention jitter (acoustic chaos)
			phase := math.Sin(r*10.0 - t*2.0)
			jitter := (rand.Float64() - 0.5) * contention * 0.3
			amplitude := math.Abs(cymatic+phase+jitter) / 2.5

			// Radial attenuation
			amplitude *= math.Max(0, 1.0-(r/maxR))

			// Map amplitude to palette character index
			idx := int(amplitude * float64(len(c.chars)-1))
			if idx < 0 {
				idx = 0
			}
			if idx >= len(c.chars) {
				idx = len(c.chars) - 1
			}

			c.buffer[y][x] = c.chars[idx]
		}
	}

	// Output buffer to ANSI terminal using double buffering sweep
	fmt.Print("\033[H")
	for y := 0; y < c.height; y++ {
		fmt.Println(string(c.buffer[y]))
	}
}

// MicrotonalSynthesizer processes metric streams into real-time microtonal audio frames.
type MicrotonalSynthesizer struct {
	phase        float64
	phaseOffset  float64
	sampleRate   float64
	baseFreq     float64
	microInterval float64
}

func NewMicrotonalSynthesizer(sampleRate float64) *MicrotonalSynthesizer {
	return &MicrotonalSynthesizer{
		sampleRate: sampleRate,
		baseFreq:   110.0, // Low A tuning (110 Hz base)
	}
}

// GenerateSynthesizedFrame outputs a microtonal audio frame based on live runtime stats.
func (s *MicrotonalSynthesizer) GenerateFrame(metrics SystemMetrics, numSamples int) []float64 {
	buffer := make([]float64, numSamples)

	// Translate Heap Alloc to Just Intonation / Microtonal Base (432Hz - 864Hz range)
	allocMB := float64(metrics.HeapAllocBytes) / (1024 * 1024)
	targetFreq := 110.0 + math.Mod(allocMB*13.75, 352.0) // Microtonal scale shifting

	// Goroutines act as additive harmonic overtones
	overtones := metrics.GoroutineCount
	if overtones > 16 {
		overtones = 16
	}

	// Microtonal interval ratio (e.g., 19-TET microtonal steps mapped from memory ratios)
	microInterval := math.Pow(2.0, float64(metrics.HeapInUseBytes%19)/19.0)

	for i := 0; i < numSamples; i++ {
		// Smooth frequency interpolation
		s.baseFreq += (targetFreq - s.baseFreq) * 0.001
		freq := s.baseFreq * microInterval

		// Fundamental Sine wave
		sample := math.Sin(s.phase)

		// Add microtonal additive overtone soundscape
		for k := 1; k <= overtones; k++ {
			harmonicFreq := freq * float64(k) * (1.0 + 0.005*float64(k)) // Microtonal pitch detune
			sample += (1.0 / float64(k)) * math.Sin(s.phase*float64(k)+(s.phaseOffset*float64(k)))
		}

		// Inject contention-driven noise (acoustic friction / dissonance)
		if metrics.ContentionRate > 0 {
			whiteNoise := (rand.Float64()*2.0 - 1.0) * metrics.ContentionRate
			sample += whiteNoise * 0.15
		}

		// Normalize output
		buffer[i] = sample / float64(overtones+1)

		// Increment phase step
		step := (2.0 * math.Pi * freq) / s.sampleRate
		s.phase = math.Mod(s.phase+step, 2.0*math.Pi)
		s.phaseOffset = math.Mod(s.phaseOffset+(metrics.ContentionRate*0.01), 2.0*math.Pi)
	}

	return buffer
}

// Artificial Workload Simulator: Creates dynamic lock contention and memory allocation cycles.
func WorkloadEngine(done chan struct{}, contentionStat *uint64) {
	var mu sync.Mutex
	for {
		select {
		case <-done:
			return
		default:
			// Spawn transient goroutines and generate memory allocations
			go func() {
				alloc := make([]byte, rand.Intn(1024*1024*4)+1024)
				_ = alloc[rand.Intn(len(alloc))]

				// Induce mutex contention artificially
				if rand.Float64() < 0.6 {
					atomic.AddUint64(contentionStat, 1)
					mu.Lock()
					time.Sleep(time.Duration(rand.Intn(5)) * time.Millisecond)
					mu.Unlock()
				}
			}()
			time.Sleep(20 * time.Millisecond)
		}
	}
}

func main() {
	// Clear Terminal Screen
	fmt.Print("\033[2J\033[?25l")
	defer fmt.Print("\033[?25h") // Restore cursor on exit

	done := make(chan struct{})
	var contentionCount uint64

	// Start simulated load process
	go WorkloadEngine(done, &contentionCount)

	canvas := NewCymaticCanvas(70, 26)
	synth := NewMicrotonalSynthesizer(SampleRate)

	var memStats runtime.MemStats
	startTime := time.Now()
	var lastContention uint64

	ticker := time.NewTicker(40 * time.Millisecond) // ~25 FPS refresh
	defer ticker.Stop()

	for i := 0; i < 300; i++ { // Run simulation loop for 300 frames (~12 seconds)
		<-ticker.C

		// Capture live runtime memory & thread telemetry
		runtime.ReadMemStats(&memStats)
		currentGoroutines := runtime.NumGoroutine()

		// Compute instantaneous contention rate
		currentContention := atomic.LoadUint64(&contentionCount)
		contentionDelta := currentContention - lastContention
		lastContention = currentContention
		contentionRate := math.Min(1.0, float64(contentionDelta)/10.0)

		metrics := SystemMetrics{
			HeapAllocBytes: memStats.HeapAlloc,
			HeapInUseBytes: memStats.HeapInuse,
			GoroutineCount: currentGoroutines,
			ContentionRate: contentionRate,
		}

		// Synthesize audio frame buffer from process telemetry
		audioBuffer := synth.GenerateFrame(metrics, BufferLen)

		// Calculate dominant resonant frequencies from synthesized frame for visuals
		var frameEnergy float64
		for _, s := range audioBuffer {
			frameEnergy += math.Abs(s)
		}
		f1 := float64(metrics.HeapAllocBytes%1000) / 10.0
		f2 := float64(metrics.GoroutineCount * 12)

		t := time.Since(startTime).Seconds()

		// Render fluid cymatic pattern tapestry to ANSI canvas
		canvas.Render(f1, f2, metrics.ContentionRate, t)

		// Print Real-Time Process Telemetry Overlay
		fmt.Printf("\033[27;1H\033[2K")
		fmt.Printf("=== ACOUSTIC MAP | Heap: %d KB | Goroutines: %d | Contention Rate: %.2f | Resonant Freq: %.1f Hz ===",
			metrics.HeapAllocBytes/1024, metrics.GoroutineCount, metrics.ContentionRate, synth.baseFreq)
	}

	close(done)
	fmt.Println("\n\n[Process Map Complete. Dynamic soundscape & cymatic topology terminated.]")
}