package main

import (
	"fmt"
	"math"
	"math/rand"
	"strings"
	"time"
)

const (
	Width     = 80
	Height    = 35
	Terrain   = " .:-=+*#%@"
)

type Particle struct {
	Word     string
	X, Y     float64
	VX, VY   float64
	Mass     float64
	Sentence int
}

func main() {
	rawProse := `
		In the depth of digital space, words swirl like dynamic fluids in a silent void. 
		Frequency exerts a heavy gravitational pull, drawing frequent concepts into deep valley centers. 
		Sentence structures curve and flow, forming ridge boundaries across the topography. 
		Particles drift along gradients of density, seeking equilibrium in an ever shifting matrix. 
		As text condenses, chaotic language resolves into structured terrain.
	`

	words := strings.Fields(strings.ToLower(strings.Map(func(r rune) rune {
		if strings.ContainsRune(".!?,;-", r) {
			return ' '
		}
		return r
	}, rawProse)))

	freq := make(map[string]int)
	for _, w := range words {
		freq[w]++
	}

	sentences := strings.FieldsFunc(rawProse, func(r rune) bool {
		return r == '.' || r == '!' || r == '?'
	})

	rand.Seed(time.Now().UnixNano())
	var particles []Particle

	for sIdx, sentence := range sentences {
		sWords := strings.Fields(strings.ToLower(sentence))
		for _, w := range sWords {
			cleanW := strings.Trim(w, ".!?,;-")
			if cleanW == "" {
				continue
			}
			p := Particle{
				Word:     cleanW,
				X:        rand.Float64() * float64(Width-1),
				Y:        rand.Float64() * float64(Height-1),
				Mass:     float64(freq[cleanW]),
				Sentence: sIdx,
			}
			particles = append(particles, p)
		}
	}

	// Simulation Loop
	steps := 120
	for step := 0; step < steps; step++ {
		// Calculate gravitational forces and structural springs
		for i := 0; i < len(particles); i++ {
			p1 := &particles[i]
			var fx, fy float64

			// Center gravity pull based on mass
			centerX, centerY := float64(Width)/2.0, float64(Height)/2.0
			dxC, dyC := centerX-p1.X, centerY-p1.Y
			distC := math.Hypot(dxC, dyC) + 0.1
			fx += (dxC / distC) * p1.Mass * 0.05
			fy += (dyC / distC) * p1.Mass * 0.05

			for j := 0; j < len(particles); j++ {
				if i == j {
					continue
				}
				p2 := particles[j]
				dx, dy := p2.X-p1.X, p2.Y-p1.Y
				dist := math.Hypot(dx, dy) + 0.1

				// Word frequency gravitational pull
				gravity := (p1.Mass * p2.Mass) / (dist * dist)
				
				// Sentence structure spring repulsion/attraction
				var sentenceFactor float64
				if p1.Sentence == p2.Sentence {
					// Cohesion along sentence boundary
					sentenceFactor = 0.1 / dist
				} else {
					// Separation between distinct sentences
					sentenceFactor = -0.05 / (dist * dist)
				}

				force := gravity + sentenceFactor
				fx += (dx / dist) * force
				fy += (dy / dist) * force
			}

			// Dampening and velocity integration
			p1.VX = (p1.VX + fx*0.1) * 0.85
			p1.VY = (p1.VY + fy*0.1) * 0.85

			p1.X += p1.VX
			p1.Y += p1.VY

			// Boundary constraints
			if p1.X < 0 { p1.X = 0 }
			if p1.X >= Width { p1.X = Width - 1 }
			if p1.Y < 0 { p1.Y = 0 }
			if p1.Y >= Height { p1.Y = Height - 1 }
		}
	}

	// Generate Topological ASCII Grid
	densityGrid := make([][]float64, Height)
	for y := 0; y < Height; y++ {
		densityGrid[y] = make([]float64, Width)
	}

	// Rasterize particle density fields into terrain elevation
	for _, p := range particles {
		radius := int(p.Mass * 3)
		for dy := -radius; dy <= radius; dy++ {
			for dx := -radius; dx <= radius; dx++ {
				gx, gy := int(p.X)+dx, int(p.Y)+dy
				if gx >= 0 && gx < Width && gy >= 0 && gy < Height {
					dist := math.Hypot(float64(dx), float64(dy))
					if dist < float64(radius) {
						densityGrid[gy][gx] += (1.0 - (dist / float64(radius))) * p.Mass
					}
				}
			}
		}
	}

	// Render Matrix with Text Overlay
	textMap := make(map[string]rune)
	for _, p := range particles {
		px, py := int(p.X), int(p.Y)
		for idx, ch := range p.Word {
			if px+idx < Width {
				key := fmt.Sprintf("%d,%d", px+idx, py)
				textMap[key] = ch
			}
		}
	}

	// Print Topological ASCII Visualization
	for y := 0; y < Height; y++ {
		for x := 0; x < Width; x++ {
			key := fmt.Sprintf("%d,%d", x, y)
			if ch, exists := textMap[key]; exists {
				fmt.Printf("%c", ch)
			} else {
				val := densityGrid[y][x]
				idx := int(val)
				if idx >= len(Terrain) {
					idx = len(Terrain) - 1
				}
				fmt.Printf("%c", Terrain[idx])
			}
		}
		fmt.Println()
	}
}