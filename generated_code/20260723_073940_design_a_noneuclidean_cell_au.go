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

// Hyperbolic disk parameters (Poincaré Disk Model)
const (
	Width     = 800
	Height    = 800
	Center    = 400.0
	Radius    = 380.0
	NumRings  = 6
	Slices    = 12
	TotalCells = NumRings * Slices
)

type Cell struct {
	Ring, Slice int
	State       float64 // 0.0 (dead) to 1.0 (alive)
	Decay       float64 // Generational decay history
	Age         int
}

type HyperbolicGrid struct {
	Cells []*Cell
}

func NewGrid() *HyperbolicGrid {
	g := &HyperbolicGrid{Cells: make([]*Cell, 0, TotalCells)}
	for r := 0; r < NumRings; r++ {
		for s := 0; s < Slices; s++ {
			g.Cells = append(g.Cells, &Cell{
				Ring:  r,
				Slice: s,
				State: rand.Float64(),
			})
		}
	}
	return g
}

// Non-Euclidean hyperbolic neighbor lookup with periodic boundary wrapping
func (g *HyperbolicGrid) Neighbors(c *Cell) []*Cell {
	var neighbors []*Cell
	for _, other := range g.Cells {
		// Radial adjacency
		if math.Abs(float64(other.Ring-c.Ring)) == 1 && other.Slice == c.Slice {
			neighbors = append(neighbors, other)
		}
		// Angular adjacency (hyperbolic wrapping on the hyperbolic tiling)
		if other.Ring == c.Ring {
			diff := math.Abs(float64(other.Slice - c.Slice))
			if diff == 1 || diff == float64(Slices-1) {
				neighbors = append(neighbors, other)
			}
		}
	}
	return neighbors
}

// Measure real-time CPU usage over a brief interval
func getCPUUsage() float64 {
	var m1, m2 runtime.MemStats
	runtime.ReadMemStats(&m1)
	start := time.Now()
	// Short busy loop to sample CPU/system activity
	for time.Since(start) < 10*time.Millisecond {
		_ = math.Sin(rand.Float64())
	}
	runtime.ReadMemStats(&m2)

	// Derive sentiment load (0.0 = calm/peaceful, 1.0 = stressed/chaotic)
	allocDiff := float64(m2.Alloc - m1.Alloc)
	sentiment := math.Min(1.0, allocDiff/100000.0)
	return sentiment
}

// Step cellular automata rules modified by system emotional state (CPU sentiment)
func (g *HyperbolicGrid) Step(sentiment float64) {
	nextStates := make([]float64, len(g.Cells))

	for i, c := range g.Cells {
		neighbors := g.Neighbors(c)
		sum := 0.0
		for _, n := range neighbors {
			sum += n.State
		}
		avg := sum / float64(len(neighbors))

		// Non-linear decay function influenced by CPU sentiment load
		decayRate := 0.05 + (sentiment * 0.15)
		c.Decay = math.Max(0.0, c.Decay*0.95+(1.0-c.State)*decayRate)

		// Self-modifying transition rules: Calm = stable maze, Chaotic = rapid decay/mutation
		if avg > 0.3 && avg < (0.6+sentiment*0.3) {
			nextStates[i] = math.Min(1.0, c.State+0.1)
		} else {
			nextStates[i] = math.Max(0.0, c.State-decayRate)
		}

		if c.State > 0.1 {
			c.Age++
		} else {
			c.Age = 0
		}
	}

	for i, c := range g.Cells {
		c.State = nextStates[i]
	}
}

// Convert hyperbolic grid coordinate to Poincaré Disk 2D projection
func getCoordinates(ring, slice int) (float64, float64) {
	// Hyperbolic radial scaling r_p = tanh(r_h / 2)
	rh := float64(ring+1) / float64(NumRings) * 2.5
	r := Radius * math.Tanh(rh/2.0)
	theta := (float64(slice) / float64(Slices)) * 2.0 * math.Pi

	x := Center + r*math.Cos(theta)
	y := Center + r*math.Sin(theta)
	return x, y
}

// Render self-modifying SVG representation of the non-Euclidean decay labyrinth
func (g *HyperbolicGrid) RenderSVG(frame int, sentiment float64) string {
	svg := fmt.Sprintf(`<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="0 0 %d %d" style="background:#0a0a12;">`, Width, Height)
	
	// Draw Poincaré disk boundary
	svg += fmt.Sprintf(`<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="#1a1a3a" stroke-width="2"/>`, Center, Center, Radius)

	// Render non-Euclidean geometry and decay arcs
	for _, c := range g.Cells {
		x1, y1 := getCoordinates(c.Ring, c.Slice)
		x2, y2 := getCoordinates(c.Ring, (c.Slice+1)%Slices)
		
		// Arc curves towards center simulating hyperbolic geodesic curvature
		midX, midY := getCoordinates(c.Ring, c.Slice)
		ctrlX := Center + (midX-Center)*0.7
		ctrlY := Center + (midY-Center)*0.7

		// Color mapping based on state, generational decay, and CPU emotional sentiment
		r := int(255 * (1.0 - c.State) * sentiment)
		gCol := int(180 * c.State)
		b := int(200 * (1.0 - c.Decay))
		strokeWidth := math.Max(0.5, (c.State*4.0)+(sentiment*2.0))

		svg += fmt.Sprintf(`<path d="M %.2f %.2f Q %.2f %.2f %.2f %.2f" fill="none" stroke="rgb(%d,%d,%d)" stroke-width="%.2f" opacity="%.2f"/>`,
			x1, y1, ctrlX, ctrlY, x2, y2, r, gCol, b, 0.3+c.State*0.7)

		// Draw decaying nodal junctions
		if c.State > 0.2 {
			nodeSize := (1.0 - c.Decay) * 5.0 * (1.0 + sentiment)
			svg += fmt.Sprintf(`<circle cx="%.2f" cy="%.2f" r="%.2f" fill="rgba(%d,%d,%d,%.2f)"/>`,
				x1, y1, nodeSize, 255-r, gCol, b, c.State)
		}
	}

	// Sentiment overlay watermark
	svg += fmt.Sprintf(`<text x="20" y="40" fill="#ffffff" font-family="sans-serif" font-size="14" opacity="0.6">CPU Sentiment Load: %.2f | Decay Frame: %d</text>`, sentiment, frame)
	svg += `</svg>`
	return svg
}

func main() {
	rand.Seed(time.Now().UnixNano())
	grid := NewGrid()

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, os.Interrupt, syscall.SIGTERM)

	frame := 0
	ticker := time.NewTicker(200 * time.Millisecond)
	defer ticker.Stop()

	// Output live dynamic SVG output stream to stdout/file
	filename := "hyperbolic_decay_labyrinth.svg"
	fmt.Printf("Generating self-modifying SVG hyperbolic decay labyrinth into %s...\n", filename)

	for {
		select {
		case <-sig:
			fmt.Println("\nProcess terminated.")
			return
		case <-ticker.C:
			frame++
			sentiment := getCPUUsage()
			grid.Step(sentiment)

			svgContent := grid.RenderSVG(frame, sentiment)
			_ = os.WriteFile(filename, []byte(svgContent), 0644)

			if frame%5 == 0 {
				fmt.Printf("Frame %d rendered | Sentiment Index: %.4f\n", frame, sentiment)
			}
			if frame >= 100 { // Auto finish after 100 iterations if uninterrupted
				fmt.Printf("Completed 100 generations. Output saved to %s\n", filename)
				return
			}
		}
	}
}