package main

import (
	"image"
	"image/color"
	"image/png"
	"math"
	"math/rand"
	"os"
	"runtime"
	"sync"
)

const (
	width  = 1024
	height = 1024
)

// Main entry point: reads binary execution bytes, samples runtime memory statistics,
// and spawns thread workers to weave the canvas visual tapestry.
func main() {
	img := image.NewRGBA(image.Rect(0, 0, width, height))

	// Fill background with deep void indigo
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			img.Set(x, y, color.RGBA{12, 10, 24, 255})
		}
	}

	// Attempt to read raw binary payload of this running executable
	execPath, err := os.Executable()
	var rawBytes []byte
	if err == nil {
		rawBytes, _ = os.ReadFile(execPath)
	}
	if len(rawBytes) == 0 {
		// Fallback byte stream if executable binary is inaccessible
		rawBytes = make([]byte, 16384)
		rand.New(rand.NewSource(1337)).Read(rawBytes)
	}

	numThreads := 8
	var wg sync.WaitGroup

	// Palette driven by runtime heap memory allocation state
	palette := generateAllocPalette(numThreads)

	chunkSize := len(rawBytes) / numThreads
	for t := 0; t < numThreads; t++ {
		wg.Add(1)
		go func(threadID int) {
			defer wg.Done()

			// Allocation weave signature: dynamic heap allocations per thread
			_ = make([]byte, (threadID+1)*512*1024)

			start := threadID * chunkSize
			end := start + chunkSize
			if end > len(rawBytes) {
				end = len(rawBytes)
			}
			chunk := rawBytes[start:end]

			// Initial position around radial loom
			angleOffset := float64(threadID) * (2 * math.Pi / float64(numThreads))
			cx, cy := float64(width)/2, float64(height)/2
			radius := 180.0
			x := cx + math.Cos(angleOffset)*radius
			y := cy + math.Sin(angleOffset)*radius

			threadColor := palette[threadID%len(palette)]

			// Recursively weave binary byte signals and simulate stack unraveling
			weaveThread(img, chunk, threadID, threadColor, x, y, 0)
		}(t)
	}

	wg.Wait()

	// Export generated tapestry to PNG file
	outFile, err := os.Create("tapestry.png")
	if err != nil {
		panic(err)
	}
	defer outFile.Close()
	_ = png.Encode(outFile, img)
}

// Generates dynamic palette colors derived from Go runtime memory metrics
func generateAllocPalette(n int) []color.RGBA {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	palette := make([]color.RGBA, n)
	baseHue := float64(m.HeapAlloc % 360)

	for i := 0; i < n; i++ {
		hue := math.Mod(baseHue+float64(i)*(360.0/float64(n)), 360.0)
		r, g, b := hslToRGB(hue, 0.85, 0.6)
		palette[i] = color.RGBA{r, g, b, 210}
	}
	return palette
}

// weaveThread traverses binary bytes, weaving vector geometry until stack depth threshold causes unraveling
func weaveThread(img *image.RGBA, data []byte, threadID int, c color.RGBA, x, y float64, stackDepth int) {
	// Stack boundary condition representing stack overflow unraveling
	if stackDepth > 140 || len(data) == 0 {
		return
	}

	b := data[0]
	angle := float64(b) * (2.0 * math.Pi / 255.0)
	step := 2.5 + float64(b%9)

	// Stack unraveling effect: high recursive stack depth causes chaotic fraying & color decay
	if stackDepth > 100 {
		angle += (rand.Float64() - 0.5) * math.Pi * 0.8
		step *= 2.0
		// Unraveling visual shift: shift color to brilliant fraying crimson/amber
		c.R = uint8(math.Min(255, float64(c.R)+25.0))
		c.G = uint8(float64(c.G) * 0.7)
		c.A = uint8(math.Max(15, float64(c.A)*0.85))
	}

	nx := x + math.Cos(angle)*step
	ny := y + math.Sin(angle)*step

	// Toroidal screen wrap
	if nx < 0 {
		nx += width
	} else if nx >= width {
		nx -= width
	}
	if ny < 0 {
		ny += height
	} else if ny >= height {
		ny -= height
	}

	// Render woven line segment onto shared canvas
	drawLineAlpha(img, int(x), int(y), int(nx), int(ny), c)

	// Execution allocation ripple
	if b%32 == 0 {
		_ = make([]byte, 1024)
	}

	// Deepen stack frame
	weaveThread(img, data[1:], threadID, c, nx, ny, stackDepth+1)
}

// Alpha-blended line drawing routine
func drawLineAlpha(img *image.RGBA, x0, y0, x1, y1 int, c color.RGBA) {
	dx := abs(x1 - x0)
	dy := abs(y1 - y0)
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
			bg := img.RGBAAt(x0, y0)
			alpha := float64(c.A) / 255.0
			r := uint8(float64(c.R)*alpha + float64(bg.R)*(1.0-alpha))
			g := uint8(float64(c.G)*alpha + float64(bg.G)*(1.0-alpha))
			b := uint8(float64(c.B)*alpha + float64(bg.B)*(1.0-alpha))
			img.SetRGBA(x0, y0, color.RGBA{r, g, b, 255})
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

func abs(n int) int {
	if n < 0 {
		return -n
	}
	return n
}

// Converts HSL color values to RGB tuple
func hslToRGB(h, s, l float64) (uint8, uint8, uint8) {
	c := (1.0 - math.Abs(2.0*l-1.0)) * s
	x := c * (1.0 - math.Abs(math.Mod(h/60.0, 2.0)-1.0))
	m := l - c/2.0

	var r1, g1, b1 float64
	switch {
	case h < 60:
		r1, g1, b1 = c, x, 0
	case h < 120:
		r1, g1, b1 = x, c, 0
	case h < 180:
		r1, g1, b1 = 0, c, x
	case h < 240:
		r1, g1, b1 = 0, x, c
	case h < 300:
		r1, g1, b1 = x, 0, c
	default:
		r1, g1, b1 = c, 0, x
	}

	return uint8((r1 + m) * 255), uint8((g1 + m) * 255), uint8((b1 + m) * 255)
}