import (
	"fmt"
	"math"
	"math/cmplx"
	"math/rand"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"[github.com/godonut/audio](https://github.com/godonut/audio)"
)

// Terminal & ASCII settings
const (
	width     = 80
	height    = 30
	sampleRate = 44100
	frameSize  = 1024
)

// Spectral Classifications (O, B, A, F, G, K, M) mapping to ANSI colors and symbols
type StarClass struct {
	Name   string
	Color  string // ANSI escape code
	Symbol rune
}

var starClasses = []StarClass{
	{Name: "O", Color: "\033[38;5;39m", Symbol: '★'},  // Deep Blue
	{Name: "B", Color: "\033[38;5;51m", Symbol: '✦'},  // Light Blue/Cyan
	{Name: "A", Color: "\033[38;5;255m", Symbol: '✧'}, // White
	{Name: "F", Color: "\033[38;5;229m", Symbol: '✯'}, // Yellow-White
	{Name: "G", Color: "\033[38;5;220m", Symbol: '✶'}, // Yellow (Sun-like)
	{Name: "K", Color: "\033[38;5;208m", Symbol: '✷'}, // Orange
	{Name: "M", Color: "\033[38;5;196m", Symbol: '•'}, // Red
}

type Star struct {
	x, y       int
	freqBand   int
	brightness float64
	classIdx   int
}

type ConstellationMap struct {
	stars []*Star
}

func NewConstellationMap(numStars int) *ConstellationMap {
	rand.Seed(time.Now().UnixNano())
	cm := &ConstellationMap{
		stars: make([]*Star, numStars),
	}
	for i := 0; i < numStars; i++ {
		cm.stars[i] = &Star{
			x:        rand.Intn(width),
			y:        rand.Intn(height),
			freqBand: i,
		}
	}
	return cm
}

// FFT performs Cooley-Tukey Radix-2 Fast Fourier Transform
func fft(buffer []complex128) []complex128 {
	n := len(buffer)
	if n <= 1 {
		return buffer
	}

	even := make([]complex128, n/2)
	odd := make([]complex128, n/2)
	for i := 0; i < n/2; i++ {
		even[i] = buffer[2*i]
		odd[i] = buffer[2*i+1]
	}

	fftEven := fft(even)
	fftOdd := fft(odd)

	combined := make([]complex128, n)
	for k := 0; k < n/2; k++ {
		t := cmplx.Rect(1, -2*math.Pi*float64(k)/float64(n)) * fftOdd[k]
		combined[k] = fftEven[k] + t
		combined[k+n/2] = fftEven[k] - t
	}
	return combined
}

// Calculate Spectral Centroid to determine Timbre (Audio Brightness/Sharpness)
func calculateSpectralCentroid(magnitudes []float64) float64 {
	var totalMag float64
	var weightedSum float64
	for i, mag := range magnitudes {
		weightedSum += float64(i) * mag
		totalMag += mag
	}
	if totalMag == 0 {
		return 0
	}
	return weightedSum / totalMag
}

func main() {
	// Initialize Audio Input Stream
	stream, err := audio.OpenDefaultInputStream(1, sampleRate, frameSize)
	if err != nil {
		// Fallback to simulated audio input if no hardware/driver is present
		runSimulatedMode()
		return
	}
	defer stream.Close()
	stream.Start()

	// Setup terminal environment
	fmt.Print("\033[?25l\033[2J") // Hide cursor & clear screen
	defer fmt.Print("\033[?25h\033[0m\033[2J") // Restore terminal on exit

	// Handle Graceful Shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	numStars := 60
	cmap := NewConstellationMap(numStars)
	pcmBuffer := make([]float32, frameSize)

	for {
		select {
		case <-sigChan:
			return
		default:
			// Read audio buffer
			stream.Read(pcmBuffer)

			// Prepare FFT input
			complexBuf := make([]complex128, frameSize)
			for i, v := range pcmBuffer {
				// Apply Hann Window to smooth audio frame transitions
				window := 0.5 * (1 - math.Cos(2*math.Pi*float64(i)/float64(frameSize-1)))
				complexBuf[i] = complex(float64(v)*window, 0)
			}

			// Perform FFT
			fftOut := fft(complexBuf)
			magnitudes := make([]float64, frameSize/2)
			for i := 0; i < frameSize/2; i++ {
				magnitudes[i] = cmplx.Abs(fftOut[i])
			}

			// Timbre calculation (Spectral Centroid)
			centroid := calculateSpectralCentroid(magnitudes)
			// Map centroid to stellar classification (0 to len(starClasses)-1)
			normCentroid := math.Min(1.0, centroid/(float64(frameSize)/8.0))
			classIndex := int(normCentroid * float64(len(starClasses)-1))

			// Update star states based on frequency bands and overall timbre
			step := (frameSize / 2) / numStars
			for i, star := range cmap.stars {
				bandIdx := i * step
				if bandIdx < len(magnitudes) {
					// Audio magnitude -> Star brightness (logarithmic response)
					rawMag := magnitudes[bandIdx]
					star.brightness = math.Min(1.0, math.Log1p(rawMag)/3.0)
					// Tweak spectral classification per star slightly using local band energy
					star.classIdx = (classIndex + (i % 2)) % len(starClasses)
				}
			}

			// Render ASCII Constellation Frame
			renderFrame(cmap)
			time.Sleep(30 * time.Millisecond)
		}
	}
}

func renderFrame(cmap *ConstellationMap) {
	// Create canvas buffer
	grid := make([][]string, height)
	for y := 0; y < height; y++ {
		grid[y] = make([]string, width)
		for x := 0; x < width; x++ {
			grid[y][x] = " "
		}
	}

	// Plot Stars
	activeStars := []*Star{}
	for _, star := range cmap.stars {
		if star.brightness > 0.15 {
			sClass := starClasses[star.classIdx]
			var sym string
			if star.brightness > 0.7 {
				sym = fmt.Sprintf("%s%c\033[0m", sClass.Color, sClass.Symbol)
			} else if star.brightness > 0.4 {
				sym = fmt.Sprintf("%s*\033[0m", sClass.Color)
			} else {
				sym = "\033[38;5;238m.\033[0m" // Dim background star
			}
			grid[star.y][star.x] = sym
			activeStars = append(activeStars, star)
		}
	}

	// Draw Constellation Lines between nearby bright stars
	for i := 0; i < len(activeStars); i++ {
		for j := i + 1; j < len(activeStars); j++ {
			s1, s2 := activeStars[i], activeStars[j]
			dist := math.Hypot(float64(s1.x-s2.x), float64(s1.y-s2.y))
			if dist < 12.0 && s1.brightness > 0.5 && s2.brightness > 0.5 {
				drawLine(grid, s1.x, s1.y, s2.x, s2.y)
			}
		}
	}

	// Output buffer to screen (Reset cursor position)
	var output strings.Builder
	output.WriteString("\033[H")
	output.WriteString("--- REAL-TIME AUDIO ASCII CONSTELLATION MAP ---\n")
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			output.WriteString(grid[y][x])
		}
		output.WriteString("\n")
	}
	output.WriteString("\033[38;5;244mO/B/A/F/G/K/M Classes mapped by Timbre & Spectral Centroid\033[0m")
	fmt.Print(output.String())
}

// Bresenham's line algorithm for drawing constellation bounds
func drawLine(grid [][]string, x0, y0, x1, y1 int) {
	dx := int(math.Abs(float64(x1 - x0)))
	dy := int(math.Abs(float64(y1 - y0)))
	sx, sy := -1, -1
	if x0 < x1 {
		sx = 1
	}
	if y0 < y1 {
		sy = 1
	}
	err := dx - dy

	for {
		if x0 >= 0 && x0 < width && y0 >= 0 && y0 < height {
			if grid[y0][x0] == " " {
				grid[y0][x0] = "\033[38;5;236m·\033[0m" // Subtle constellation line
			}
		}
		if x0 == x1 && y0 == y1 {
			break
		}
		e2 := 2 * err
		if e2 > -dy {
			err -= dy
			x0 += sx
		}
		if e2 < dx {
			err += dx
			y0 += sy
		}
	}
}

// Fallback visualizer if live microphone device isn't available
func runSimulatedMode() {
	fmt.Print("\033[?25l\033[2J")
	defer fmt.Print("\033[?25h\033[0m\033[2J")

	numStars := 60
	cmap := NewConstellationMap(numStars)
	t := 0.0

	for {
		t += 0.05
		for i, star := range cmap.stars {
			// Synthesize imaginary harmonic signal
			freq := float64(i+1) * 0.2
			star.brightness = math.Abs(math.Sin(t*freq)+math.Cos(t*0.5)) / 2.0
			star.classIdx = int(math.Abs(math.Sin(t+float64(i)))) % len(starClasses)
		}
		renderFrame(cmap)
		time.Sleep(40 * time.Millisecond)
	}
}