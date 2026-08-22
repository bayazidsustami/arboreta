package main

import (
	"fmt"
	"math"
	"math/cmplx"
	"math/rand"
	"time"
)

const (
	Width     = 64
	Height    = 32
	FFTSize   = 64
	FrameRate = 15
)

// Cell represents a single node in the cellular automaton
type Cell struct {
	State int     // 0: dead, 1: alive
	Energy float64 // Brightness driven by webcam/audio synthesis
}

// VisualAutomaton manages state for the dynamic cellular automaton, simulated webcam feed, and FFT spectrum
type VisualAutomaton struct {
	grid       [][]Cell
	nextGrid   [][]Cell
	webcamFeed [][]float64
	audioFFT   []float64
	timeStep   float64
}

// NewVisualAutomaton initializes a grid with random visual seed values
func NewVisualAutomaton() *VisualAutomaton {
	grid := make([][]Cell, Height)
	nextGrid := make([][]Cell, Height)
	webcam := make([][]float64, Height)

	for y := 0; y < Height; y++ {
		grid[y] = make([]Cell, Width)
		nextGrid[y] = make([]Cell, Width)
		webcam[y] = make([]float64, Width)
		for x := 0; x < Width; x++ {
			if rand.Float64() > 0.65 {
				grid[y][x].State = 1
				grid[y][x].Energy = rand.Float64()
			}
		}
	}

	return &VisualAutomaton{
		grid:       grid,
		nextGrid:   nextGrid,
		webcamFeed: webcam,
		audioFFT:   make([]float64, FFTSize/2),
	}
}

// Cooley-Tukey Radix-2 Fast Fourier Transform
func fft(samples []complex128) []complex128 {
	n := len(samples)
	if n <= 1 {
		return samples
	}

	even := make([]complex128, n/2)
	odd := make([]complex128, n/2)
	for i := 0; i < n/2; i++ {
		even[i] = samples[2*i]
		odd[i] = samples[2*i+1]
	}

	fftEven := fft(even)
	fftOdd := fft(odd)

	res := make([]complex128, n)
	for k := 0; k < n/2; k++ {
		t := cmplx.Rect(1, -2*math.Pi*float64(k)/float64(n)) * fftOdd[k]
		res[k] = fftEven[k] + t
		res[k+n/2] = fftEven[k] - t
	}
	return res
}

// CaptureWebcamSim simulates a real-time moving video/webcam feed stream
func (va *VisualAutomaton) CaptureWebcamSim() {
	va.timeStep += 0.1
	for y := 0; y < Height; y++ {
		for x := 0; x < Width; x++ {
			nx := float64(x) / float64(Width)
			ny := float64(y) / float64(Height)
			// Generates moving dynamic wave patterns simulating video input brightness
			val := math.Sin(nx*10+va.timeStep)*0.5 + math.Cos(ny*10-va.timeStep)*0.5
			va.webcamFeed[y][x] = (val + 1.0) / 2.0
		}
	}
}

// CaptureAudioAndComputeFFT simulates streaming microphone audio and performs an FFT analysis
func (va *VisualAutomaton) CaptureAudioAndComputeFFT() {
	samples := make([]complex128, FFTSize)
	// Synthesize complex audio frequencies (bass, mid, treble)
	for i := 0; i < FFTSize; i++ {
		t := float64(i) / float64(FFTSize)
		bass := math.Sin(2 * math.Pi * 2 * t * (va.timeStep * 0.5))
		treble := math.Sin(2 * math.Pi * 12 * t * (va.timeStep * 1.5))
		samples[i] = complex(bass+treble, 0)
	}

	spectrum := fft(samples)
	for i := 0; i < FFTSize/2; i++ {
		va.audioFFT[i] = cmplx.Abs(spectrum[i]) / float64(FFTSize)
	}
}

// EvolveAutomaton applies cellular logic driven by audio FFT spectrum and webcam pixel data
func (va *VisualAutomaton) EvolveAutomaton() {
	// Average FFT magnitudes across low, mid, and high frequency bands
	var low, mid, high float64
	for i := 0; i < FFTSize/2; i++ {
		if i < 5 {
			low += va.audioFFT[i]
		} else if i < 16 {
			mid += va.audioFFT[i]
		} else {
			high += va.audioFFT[i]
		}
	}

	// Dynamically mutate Life survival parameters based on audio spectrum peaks
	survivalMin := 2 + int(math.Mod(low*4, 2))
	survivalMax := 3 + int(math.Mod(mid*4, 2))
	birthRule := 3 + int(math.Mod(high*4, 2))

	for y := 0; y < Height; y++ {
		for x := 0; x < Width; x++ {
			neighbors := va.countNeighbors(x, y)
			currentState := va.grid[y][x].State
			webcamLight := va.webcamFeed[y][x]

			newState := 0
			if currentState == 1 && (neighbors >= survivalMin && neighbors <= survivalMax) {
				newState = 1
			} else if currentState == 0 && (neighbors == birthRule || webcamLight > 0.8) {
				newState = 1
			}

			// Modulate energy/color intensity via dynamic audio energy & camera pixel data
			va.nextGrid[y][x].State = newState
			if newState == 1 {
				va.nextGrid[y][x].Energy = math.Min(1.0, webcamLight+low)
			} else {
				va.nextGrid[y][x].Energy = math.Max(0.0, va.grid[y][x].Energy*0.8) // Decay
			}
		}
	}

	// Double buffering swap
	va.grid, va.nextGrid = va.nextGrid, va.grid
}

func (va *VisualAutomaton) countNeighbors(x, y int) int {
	count := 0
	for dy := -1; dy <= 1; dy++ {
		for dx := -1; dx <= 1; dx++ {
			if dx == 0 && dy == 0 {
				continue
			}
			nx := (x + dx + Width) % Width
			ny := (y + dy + Height) % Height
			count += va.grid[ny][nx].State
		}
	}
	return count
}

// RenderKaleidoscope maps the 2D automaton grid symmetrically across 4 quadrants
func (va *VisualAutomaton) RenderKaleidoscope() {
	// Clear console screen using ANSI escape sequences
	fmt.Print("\033[H\033[2J")

	palette := []rune{' ', '░', '▒', '▓', '█'}
	halfW, halfH := Width/2, Height/2

	for y := 0; y < Height; y++ {
		for x := 0; x < Width; x++ {
			// Fold coordinates into a 4-way symmetrical kaleidoscope matrix
			kx := x
			if x >= halfW {
				kx = Width - 1 - x
			}
			ky := y
			if y >= halfH {
				ky = Height - 1 - y
			}

			cell := va.grid[ky][kx]
			if cell.State == 1 {
				idx := int(cell.Energy * float64(len(palette)-1))
				if idx >= len(palette) {
					idx = len(palette) - 1
				}
				fmt.Printf("\033[38;5;%dm%c\033[0m", 33+int(cell.Energy*198), palette[idx])
			} else {
				fmt.Print(" ")
			}
		}
		fmt.Println()
	}
	fmt.Printf("\n[Audio FFT Dynamically Mutating Cellular Automaton Rules] | Time: %.1fs\n", va.timeStep)
}

func main() {
	rand.Seed(time.Now().UnixNano())
	automaton := NewVisualAutomaton()

	ticker := time.NewTicker(time.Second / FrameRate)
	defer ticker.Stop()

	for range ticker.C {
		automaton.CaptureWebcamSim()
		automaton.CaptureAudioAndComputeFFT()
		automaton.EvolveAutomaton()
		automaton.RenderKaleidoscope()
	}
}