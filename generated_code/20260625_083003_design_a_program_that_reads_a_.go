package main

import (
	"image"
	"image/color"
	"log"
	"math"
	"math/rand"
	"time"

	"github.com/fogleman/gg"
	"gocv.io/x/gocv"
)

// Cell represents a Voronoi site.
type Cell struct {
	X, Y   float64
	Color  color.Color
	Pitch  float64 // simulated musical pitch
	Radius float64 // visual modulation
}

// generateSites creates random sites inside the canvas.
func generateSites(n int, w, h int) []Cell {
	cells := make([]Cell, n)
	for i := 0; i < n; i++ {
		cells[i] = Cell{
			X:     rand.Float64() * float64(w),
			Y:     rand.Float64() * float64(h),
			Color: randomColor(),
			Pitch: 200 + rand.Float64()*800, // 200‑1000 Hz range
		}
	}
	return cells
}

// randomColor returns a pastel colour.
func randomColor() color.Color {
	r := 150 + rand.Intn(106)
	g := 150 + rand.Intn(106)
	b := 150 + rand.Intn(106)
	return color.RGBA{uint8(r), uint8(g), uint8(b), 255}
}

// distance squared helper.
func dsq(a, b Cell) float64 {
	dx := a.X - b.X
	dy := a.Y - b.Y
	return dx*dx + dy*dy
}

// updateCells mutates cells based on a simulated tempo.
func updateCells(cells []Cell, tempo float64) {
	for i := range cells {
		// modulate radius with a sine wave driven by tempo
		cells[i].Radius = 20 + 15*math.Sin(tempo+float64(i))
		// shift colour hue slightly
		r, g, b, a := cells[i].Color.RGBA()
		h := float64(r%256) + tempo*10
		cells[i].Color = color.RGBA{
			uint8(math.Mod(h, 256)),
			uint8(g%256),
			uint8(b%256),
			uint8(a),
		}
	}
}

// drawVoronoi renders a simple Voronoi pattern by assigning each pixel
// to the nearest site. For performance we draw circles instead of a full pixel scan.
func drawVoronoi(dc *gg.Context, cells []Cell) {
	for _, c := range cells {
		dc.DrawCircle(c.X, c.Y, c.Radius)
		dc.SetColor(c.Color)
		dc.Fill()
	}
}

// simulateTempo produces a pseudo‑random tempo from 0.5 to 2.5 Hz.
func simulateTempo() float64 {
	return 0.5 + rand.Float64()*2.0
}

func main() {
	rand.Seed(time.Now().UnixNano())

	const (
		width  = 800
		height = 600
	)

	// Open webcam (video only, audio not captured).
	webcam, err := gocv.OpenVideoCapture(0)
	if err != nil {
		log.Fatalf("cannot open webcam: %v", err)
	}
	defer webcam.Close()

	window := gocv.NewWindow("Voronoi Soundscape")
	defer window.Close()

	img := gocv.NewMat()
	defer img.Close()

	// Initialise cells.
	cells := generateSites(30, width, height)

	// Main loop.
	for {
		if ok := webcam.Read(&img); !ok || img.Empty() {
			continue
		}
		// Convert frame to image.Image for drawing.
		frame, err := img.ToImage()
		if err != nil {
			continue
		}
		// Create a drawing context.
		dc := gg.NewContext(width, height)
		// Use the video frame as a faint background.
		dc.DrawImageAnchored(frame, width/2, height/2, 0.5, 0.5)
		dc.SetRGBA(0, 0, 0, 0.2)
		dc.DrawRectangle(0, 0, width, height)
		dc.Fill()

		// Simulate an audio tempo and update cells.
		tempo := simulateTempo() * 2 * math.Pi // angular speed
		updateCells(cells, tempo)

		// Render Voronoi‑like cells.
		drawVoronoi(dc, cells)

		// Convert back to Mat and show.
		output, err := gocv.ImageToMatRGBA(dc.Image())
		if err != nil {
			continue
		}
		window.IMShow(output)
		if window.WaitKey(1) >= 0 {
			break
		}
		output.Close()
	}
}