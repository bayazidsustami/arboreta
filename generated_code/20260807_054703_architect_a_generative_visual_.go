package main

import (
	"fmt"
	"image"
	"image/color"
	"image/draw"
	"image/png"
	"math"
	"math/rand"
	"net/http"
	"runtime"
	"sync"
	"time"
)

// Canvas dimensions
const (
	width  = 1000
	height = 800
)

// CallFrame captures a state in the recursive call stack.
type CallFrame struct {
	Depth       int
	Angle       float64
	Length      float64
	X1, Y1      float64
	X2, Y2      float64
	Decaying    bool
	DecayFactor float64
}

// VisualCanvas manages the tree state and memory decay triggers.
type VisualCanvas struct {
	mu         sync.RWMutex
	frames     []CallFrame
	allocLimit uint64
}

func NewVisualCanvas(limitMB uint64) *VisualCanvas {
	return &VisualCanvas{
		allocLimit: limitMB * 1024 * 1024,
	}
}

// GrowBranch recursively simulates stack execution and translates frames into botanical geometry.
func (vc *VisualCanvas) GrowBranch(depth int, maxDepth int, x, y, angle, length float64) {
	// Sample runtime memory stats to trigger leaf decay upon stack memory pressure
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	isDecaying := false
	if m.Alloc > vc.allocLimit || rand.Float64() < 0.08 { // Simulated allocation stress trigger
		isDecaying = true
	}

	x2 := x + length*math.Cos(angle)
	y2 := y + length*math.Sin(angle)

	frame := CallFrame{
		Depth:       depth,
		Angle:       angle,
		Length:      length,
		X1:          x,
		Y1:          y,
		X2:          x2,
		Y2:          y2,
		Decaying:    isDecaying,
		DecayFactor: rand.Float64(),
	}

	vc.mu.Lock()
	vc.frames = append(vc.frames, frame)
	vc.mu.Unlock()

	// Micro-delay to simulate stack frame lifetime
	time.Sleep(3 * time.Millisecond)

	if depth < maxDepth {
		// Recursive call stack branching
		spread := 0.32 + rand.Float64()*0.12
		shrink := 0.73 + rand.Float64()*0.04

		vc.GrowBranch(depth+1, maxDepth, x2, y2, angle-spread, length*shrink)
		vc.GrowBranch(depth+1, maxDepth, x2, y2, angle+spread, length*shrink)
	}
}

// RenderGenerativeCanvas draws the live fractal tree with vibrant bloom or autumn leaf decay.
func (vc *VisualCanvas) RenderGenerativeCanvas() *image.RGBA {
	vc.mu.RLock()
	defer vc.mu.RUnlock()

	img := image.NewRGBA(image.Rect(0, 0, width, height))
	// Deep midnight background canvas
	bgColor := color.RGBA{R: 12, G: 16, B: 24, A: 255}
	draw.Draw(img, img.Bounds(), &image.Uniform{bgColor}, image.Point{}, draw.Src)

	for _, frame := range vc.frames {
		var strokeColor color.RGBA
		if frame.Decaying {
			// Autumn decay hues: Withered Amber & Crimson
			strokeColor = color.RGBA{
				R: uint8(190 + rand.Intn(60)),
				G: uint8(70 + rand.Intn(50)),
				B: uint8(20 + rand.Intn(30)),
				A: 220,
			}
		} else {
			// Radiant spring flora hues: Emerald transition to Sakura Pink
			t := float64(frame.Depth) / 12.0
			strokeColor = color.RGBA{
				R: uint8(40 + t*190),
				G: uint8(180 - t*70),
				B: uint8(110 + t*90),
				A: 240,
			}
		}

		thickness := int(math.Max(1, float64(11-frame.Depth)*0.85))
		drawLine(img, int(frame.X1), int(frame.Y1), int(frame.X2), int(frame.Y2), strokeColor, thickness)

		// Draw blossoms or decaying leaf clusters at higher stack depths
		if frame.Depth >= 7 {
			drawBotanicalLeaf(img, int(frame.X2), int(frame.Y2), frame.Decaying)
		}
	}

	return img
}

func drawLine(img *image.RGBA, x0, y0, x1, y1 int, col color.RGBA, thickness int) {
	dx := math.Abs(float64(x1 - x0))
	dy := math.Abs(float64(y1 - y0))
	sx, sy := 1, 1
	if x0 >= x1 {
		sx = -1
	}
	if y0 >= y1 {
		sy = -1
	}
	err := dx - dy

	for {
		for tx := -thickness / 2; tx <= thickness/2; tx++ {
			for ty := -thickness / 2; ty <= thickness/2; ty++ {
				px, py := x0+tx, y0+ty
				if px >= 0 && px < width && py >= 0 && py < height {
					img.Set(px, py, col)
				}
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

func drawBotanicalLeaf(img *image.RGBA, x, y int, decaying bool) {
	radius := 4
	if decaying {
		radius = 3
	}
	for dx := -radius; dx <= radius; dx++ {
		for dy := -radius; dy <= radius; dy++ {
			if dx*dx+dy*dy <= radius*radius {
				px, py := x+dx, y+dy
				if px >= 0 && px < width && py >= 0 && py < height {
					var leafCol color.RGBA
					if decaying {
						leafCol = color.RGBA{R: 215, G: 95, B: 25, A: 210} // Decaying autumn leaf
					} else {
						leafCol = color.RGBA{R: 255, G: 180, B: 200, A: 230} // Blooming sakura blossom
					}
					img.Set(px, py, leafCol)
				}
			}
		}
	}
}

func main() {
	rand.Seed(time.Now().UnixNano())
	canvas := NewVisualCanvas(15) // Soft memory threshold in MB

	// Background worker continually triggering recursive call stacks
	go func() {
		for {
			canvas.mu.Lock()
			canvas.frames = nil
			canvas.mu.Unlock()

			// Initiate recursive stack growth from base trunk
			canvas.GrowBranch(0, 10, width/2, height-40, -math.Pi/2, 125)
			time.Sleep(2 * time.Second)
		}
	}()

	// HTTP web server serving real-time auto-refreshing generative visual canvas
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		fmt.Fprint(w, `<!DOCTYPE html>
<html>
<head>
    <title>Call Stack Fractal Botanical Canvas</title>
    <style>
        body { background: #07090e; margin: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; color: #eceff4; font-family: sans-serif; }
        h3 { margin-bottom: 12px; font-weight: 300; letter-spacing: 1px; }
        img { border-radius: 12px; box-shadow: 0 12px 40px rgba(0,0,0,0.85); border: 1px solid #1e2330; }
    </style>
</head>
<body>
    <h3>Live Call Stack Botanical Canvas</h3>
    <img id="canvas" src="/render" width="1000" height="800"/>
    <script>
        setInterval(() => {
            document.getElementById('canvas').src = '/render?' + new Date().getTime();
        }, 200);
    </script>
</body>
</html>`)
	})

	http.HandleFunc("/render", func(w http.ResponseWriter, r *http.Request) {
		img := canvas.RenderGenerativeCanvas()
		w.Header().Set("Content-Type", "image/png")
		png.Encode(w, img)
	})

	fmt.Println("Visual Canvas running at http://localhost:8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		fmt.Println("Server error:", err)
	}
}