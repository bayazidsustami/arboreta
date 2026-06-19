package main

import (
	"bytes"
	"encoding/binary"
	"image"
	"image/color"
	"image/png"
	"log"
	"math"
	"math/cmplx"
	"math/rand"
	"os"
	"os/exec"
	"sync"
	"time"

	"github.com/mjibson/go-dsp/fft"
)

// Settings
const (
	sampleRate   = 44100
	fftSize      = 1024
	gridWidth    = 128
	gridHeight   = 128
	cellSize     = 4               // pixels per cell
	frameRate    = 30
	durationSec  = 10
	poemWords    = 5
	videoWidth   = gridWidth * cellSize
	videoHeight  = gridHeight * cellSize
	audioChanBuf = 256
)

// simple audio generator – replace with real capture if desired
func audioGenerator(out chan []float64) {
	ticker := time.NewTicker(time.Duration(fftSize) * time.Second / sampleRate)
	for range ticker.C {
		buf := make([]float64, fftSize)
		for i := range buf {
			// pinkish noise
			buf[i] = rand.NormFloat64() * (1.0 / math.Sqrt(float64(i+1)))
		}
		out <- buf
	}
	close(out)
}

// map frequency magnitude to a cellular automaton rule (0..255)
func freqToRule(mag float64) uint8 {
	// simple scaling
	idx := int(mag*10) % 256
	return uint8(idx)
}

// one-dimensional CA applied to a row, toroidal wrap
func evolveRow(row []uint8, rule uint8) []uint8 {
	newRow := make([]uint8, len(row))
	for i := range row {
		// three‑cell neighbourhood
		left := row[(i-1+len(row))%len(row)]
		center := row[i]
		right := row[(i+1)%len(row)]
		neigh := (left << 2) | (center << 1) | right
		newRow[i] = (rule >> neigh) & 1
	}
	return newRow
}

// generate a tiny poem from amplitude envelope
func generatePoem(env float64) string {
	words := []string{"whisper", "storm", "silence", "echo", "dream", "pulse", "shadow", "light", "glass", "river"}
	n := poemWords
	var buf bytes.Buffer
	for i := 0; i < n; i++ {
		idx := int(env*float64(len(words))*float64(i+1)) % len(words)
		if i > 0 {
			buf.WriteByte(' ')
		}
		buf.WriteString(words[idx])
	}
	return buf.String()
}

// map poem characters to colors
func poemToColor(p string) color.RGBA {
	h := 0.0
	for _, r := range p {
		h += float64(r)
	}
	h = math.Mod(h, 360)
	// simple HSV→RGB conversion (full saturation, value)
	c := uint8(255)
	x := uint8(int(c) * int(1-math.Abs(math.Mod(h/60, 2)-1)))
	switch {
	case h < 60:
		return color.RGBA{c, x, 0, 255}
	case h < 120:
		return color.RGBA{x, c, 0, 255}
	case h < 180:
		return color.RGBA{0, c, x, 255}
	case h < 240:
		return color.RGBA{0, x, c, 255}
	case h < 300:
		return color.RGBA{x, 0, c, 255}
	default:
		return color.RGBA{c, 0, x, 255}
	}
}

// render the grid to an image using the poem‑derived color
func render(grid [][]uint8, poem string) *image.RGBA {
	img := image.NewRGBA(image.Rect(0, 0, videoWidth, videoHeight))
	col := poemToColor(poem)
	for y := 0; y < gridHeight; y++ {
		for x := 0; x < gridWidth; x++ {
			val := grid[y][x]
			var cellCol color.RGBA
			if val == 1 {
				cellCol = col
			} else {
				cellCol = color.RGBA{0, 0, 0, 255}
			}
			// fill cell pixels
			for dy := 0; dy < cellSize; dy++ {
				for dx := 0; dx < cellSize; dx++ {
					px := x*cellSize + dx
					py := y*cellSize + dy
					img.Set(px, py, cellCol)
				}
			}
		}
	}
	return img
}

// start ffmpeg process to encode raw PNG frames into a video
func startVideoEncoder() (*exec.Cmd, io.WriteCloser) {
	cmd := exec.Command("ffmpeg",
		"-y",
		"-f", "image2pipe",
		"-vcodec", "png",
		"-r", fmt.Sprintf("%d", frameRate),
		"-i", "-",
		"-c:v", "libx264",
		"-pix_fmt", "yuv420p",
		"output.mp4",
	)
	stdin, err := cmd.StdinPipe()
	if err != nil {
		log.Fatalf("ffmpeg stdin: %v", err)
	}
	if err := cmd.Start(); err != nil {
		log.Fatalf("ffmpeg start: %v", err)
	}
	return cmd, stdin
}

func main() {
	rand.Seed(time.Now().UnixNano())

	// audio channel
	audioCh := make(chan []float64, audioChanBuf)
	go audioGenerator(audioCh)

	// initialize grid with random states
	grid := make([][]uint8, gridHeight)
	for y := range grid {
		row := make([]uint8, gridWidth)
		for x := range row {
			row[x] = uint8(rand.Intn(2))
		}
		grid[y] = row
	}

	// video writer
	_, videoIn := startVideoEncoder()
	defer videoIn.Close()

	frameTicker := time.NewTicker(time.Second / time.Duration(frameRate))
	defer frameTicker.Stop()

	start := time.Now()
	for {
		select {
		case samples, ok := <-audioCh:
			if !ok {
				return
			}
			// FFT and magnitude
			cmplxVals := fft.FFTReal(samples)
			mags := make([]float64, len(cmplxVals))
			var envSum float64
			for i, c := range cmplxVals {
				m := cmplx.Abs(c)
				mags[i] = m
				envSum += m
			}
			env := envSum / float64(len(mags))

			// map mags to rules per column
			rules := make([]uint8, gridWidth)
			for i := 0; i < gridWidth; i++ {
				idx := i * len(mags) / gridWidth
				rules[i] = freqToRule(mags[idx])
			}

			// evolve each row concurrently
			var wg sync.WaitGroup
			for y := 0; y < gridHeight; y++ {
				wg.Add(1)
				go func(y int) {
					defer wg.Done()
					newRow := evolveRow(grid[y], rules[y%gridWidth])
					grid[y] = newRow
				}(y)
			}
			wg.Wait()

			// generate poem from envelope
			poem := generatePoem(env)

			// render and send frame
			img := render(grid, poem)
			var buf bytes.Buffer
			if err := png.Encode(&buf, img); err != nil {
				log.Fatalf("png encode: %v", err)
			}
			if _, err := videoIn.Write(buf.Bytes()); err != nil {
				log.Fatalf("write frame: %v", err)
			}

			// stop after desired duration
			if time.Since(start) > durationSec*time.Second {
				return
			}
		case <-frameTicker.C:
			// keep ticking even if no audio (no‑op)
		}
	}
}