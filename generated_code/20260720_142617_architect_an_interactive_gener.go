package main

import (
	"crypto/rand"
	"fmt"
	"math"
	"math/big"
	"os"
	"os/signal"
	"runtime"
	"syscall"
	"time"
)

const (
	width  = 80
	height = 40
)

// Particle represents a glowing node in our stack constellation
type Particle struct {
	x, y     float64
	vx, vy   float64
	char     rune
	color    string
	life     float64
	maxLife  float64
	isBranch bool
}

// StackConstellation manages the self-consuming ASCII universe
type StackConstellation struct {
	particles []*Particle
	matrix    [][]rune
	colorMap  [][]string
}

func NewConstellation() *StackConstellation {
	matrix := make([][]rune, height)
	colorMap := make([][]string, height)
	for i := range matrix {
		matrix[i] = make([]rune, width)
		colorMap[i] = make([]string, width)
	}
	return &StackConstellation{
		particles: make([]*Particle, 0),
		matrix:    matrix,
		colorMap:  colorMap,
	}
}

// Random float generator for organic movement
func randFloat(min, max float64) float64 {
	n, _ := rand.Int(rand.Reader, big.NewInt(10000))
	return min + (float64(n.Int64())/10000.0)*(max-min)
}

// Capture current execution stack and mutate it into the particle field
func (sc *StackConstellation) ingestStack() {
	buf := make([]byte, 4096)
	n := runtime.Stack(buf, false)
	stackStr := string(buf[:n])

	// Parse runes and inject them as cosmic seeds at the center
	for _, r := range stackStr {
		if r == ' ' || r == '\n' || r == '\t' {
			continue
		}
		if randFloat(0, 1) > 0.15 { // Throttle ingestion density
			continue
		}

		// Higher functions/calls get deeper colors
		colors := []string{"\033[38;5;45m", "\033[38;5;99m", "\033[38;5;198m", "\033[38;5;220m", "\033[38;5;81m"}
		cIdx, _ := rand.Int(rand.Reader, big.NewInt(int64(len(colors))))
		
		angle := randFloat(0, 2*math.Pi)
		speed := randFloat(0.2, 0.9)
		life := randFloat(20, 50)

		p := &Particle{
			x:        float64(width) / 2.0,
			y:        float64(height) / 2.0,
			vx:       math.Cos(angle) * speed,
			vy:       math.Sin(angle) * speed * 0.5, // Account for terminal font aspect ratio
			char:     r,
			color:    colors[cIdx.Int64()],
			life:     life,
			maxLife:  life,
			isBranch: randFloat(0, 1) > 0.85,
		}
		sc.particles = append(sc.particles, p)
	}
}

// Update particle physics, applying self-consuming gravity and decay
func (sc *StackConstellation) update() {
	var living []*Particle
	
	// Black hole gravity center (the execution context point)
	cx, cy := float64(width)/2.0, float64(height)/2.0

	for _, p := range sc.particles {
		p.life--
		if p.life <= 0 {
			continue // Consumed by the ether
		}

		// Gravitational pull towards the center of compilation
		dx := cx - p.x
		dy := cy - p.y
		dist := math.Sqrt(dx*dx + dy*dy) + 0.1
		
		// Orbital/Swirling force
		p.vx += (dx/dist)*0.01 - (dy/dist)*0.02
		p.vy += (dy/dist)*0.005 + (dx/dist)*0.01

		// Move
		p.x += p.vx
		p.y += p.vy

		living = append(living, p)
	}
	sc.particles = living
}

// Render the field to the screen matrix with glowing gradients
func (sc *StackConstellation) render() {
	// Clear frame buffers
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			sc.matrix[y][x] = ' '
			sc.colorMap[y][x] = ""
		}
	}

	// Draw connections (constellation lines) between nearby execution nodes
	for i, p1 := range sc.particles {
		if !p1.isBranch {
			continue
		}
		for j := i + 1; j < len(sc.particles); j++ {
			p2 := sc.particles[j]
			dx := p1.x - p2.x
			dy := p1.y - p2.y
			if math.Sqrt(dx*dx+dy*dy) < 3.5 {
				ix, iy := int(p2.x), int(p2.y)
				if ix >= 0 && ix < width && iy >= 0 && iy < height {
					sc.matrix[iy][ix] = '.'
					sc.colorMap[iy][ix] = "\033[38;5;239m" // Dim link color
				}
			}
		}
	}

	// Draw active stack particles
	for _, p := range sc.particles {
		ix, iy := int(p.x), int(p.y)
		if ix >= 0 && ix < width && iy >= 0 && iy < height {
			sc.matrix[iy][ix] = p.char
			
			// Dynamic fade color calculation
			lifeRatio := p.life / p.maxLife
			if lifeRatio < 0.3 {
				sc.colorMap[iy][ix] = "\033[38;5;236m" // Dying embers
			} else if lifeRatio < 0.6 {
				sc.colorMap[iy][ix] = "\033[38;5;242m" // Fading node
			} else {
				sc.colorMap[iy][ix] = p.color // Living stack element
			}
		}
	}

	// Print frame to terminal safely
	fmt.Print("\033[H") // Move cursor to top-left
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			if sc.colorMap[y][x] != "" {
				fmt.Print(sc.colorMap[y][x] + string(sc.matrix[y][x]) + "\033[0m")
			} else {
				fmt.Print(" ")
			}
		}
		fmt.Println()
	}
}

// Deeper recursion loop to generate dynamic runtime stacks organically
func recursiveStardust(depth int, sc *StackConstellation) {
	if depth > 8 {
		sc.ingestStack()
		return
	}
	// Create uneven processing chains to oscillate stack traces
	if depth%2 == 0 {
		recursiveStardust(depth+1, sc)
	} else {
		sc.ingestStack()
		recursiveStardust(depth+2, sc)
	}
}

func main() {
	// Hide cursor and clear terminal
	fmt.Print("\033[?25l\033[2J")

	sc := NewConstellation()

	// Clean exit handling
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		fmt.Print("\033[?25h\033[2J\033[H") // Restore cursor and clean up
		os.Exit(0)
	}()

	ticker := time.NewTicker(40 * time.Millisecond)
	defer ticker.Stop()

	frame := 0
	for range ticker.C {
		frame++
		
		// Periodically dive into runtime recursion to extract new stack geometry
		if frame%3 == 0 {
			recursiveStardust(0, sc)
		}

		sc.update()
		sc.render()
	}
}