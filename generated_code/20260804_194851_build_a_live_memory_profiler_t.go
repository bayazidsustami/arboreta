package main

import (
	"fmt"
	"math"
	"math/rand"
	"os"
	"os/signal"
	"runtime"
	"sync"
	"syscall"
	"time"
)

// Star represents an active heap object in 3D space
type Star struct {
	X, Y, Z    float64
	VX, VY, VZ float64
	Brightness float64
	Temperature int // Colors: 0=Blue, 1=Cyan, 2=White, 3=Yellow, 4=Red
	Lifetime   int
}

// BlackHole represents a memory leak location absorbing stars
type BlackHole struct {
	X, Y, Z float64
	Mass    float64
}

// Profiler Engine state
type Profiler struct {
	mu         sync.Mutex
	stars      []Star
	blackHoles []BlackHole
	angleX     float64
	angleY     float64
	leakBuffer [][]byte // Simulates memory leaks
	width      int
	height     int
	memStats   runtime.MemStats
}

func NewProfiler(w, h int) *Profiler {
	return &Profiler{
		width:      w,
		height:     h,
		stars:      make([]Star, 0),
		blackHoles: make([]BlackHole, 0),
	}
}

// Sample memory stats and update stellar nebula dynamics
func (p *Profiler) Update() {
	p.mu.Lock()
	defer p.mu.Unlock()

	runtime.ReadMemStats(&p.memStats)

	// Map HeapObjects count to Star population
	targetStars := int(p.memStats.HeapObjects / 100)
	if targetStars < 30 {
		targetStars = 30
	}
	if targetStars > 400 {
		targetStars = 400
	}

	// Spawn or prune stars to match active variables
	for len(p.stars) < targetStars {
		rad := 12.0 + rand.Float64()*15.0
		theta := rand.Float64() * 2 * math.Pi
		phi := math.Acos(2*rand.Float64() - 1)
		p.stars = append(p.stars, Star{
			X:           rad * math.Sin(phi) * math.Cos(theta),
			Y:           rad * math.Sin(phi) * math.Sin(theta),
			Z:           rad * math.Cos(phi),
			Brightness:  0.5 + rand.Float64()*0.5,
			Temperature: rand.Intn(5),
			Lifetime:    rand.Intn(100) + 50,
		})
	}
	if len(p.stars) > targetStars {
		p.stars = p.stars[:targetStars]
	}

	// Black hole density corresponds to leak growth / heap size relative to goal
	numBlackHoles := len(p.leakBuffer) / 20
	if numBlackHoles > 5 {
		numBlackHoles = 5
	}

	for len(p.blackHoles) < numBlackHoles {
		p.blackHoles = append(p.blackHoles, BlackHole{
			X:    (rand.Float64() - 0.5) * 20,
			Y:    (rand.Float64() - 0.5) * 20,
			Z:    (rand.Float64() - 0.5) * 20,
			Mass: 5.0,
		})
	}

	// Update Black Hole mass from leak buffer size
	for i := range p.blackHoles {
		p.blackHoles[i].Mass = 3.0 + float64(len(p.leakBuffer))*0.8
	}

	// Gravitational pull & rotation updates
	for i := range p.stars {
		s := &p.stars[i]
		// Twinkle main-sequence stars
		s.Brightness = 0.3 + 0.7*math.Abs(math.Sin(float64(time.Now().UnixNano())/1e8+float64(i)))

		// Pull towards closest black hole
		for _, bh := range p.blackHoles {
			dx, dy, dz := bh.X-s.X, bh.Y-s.Y, bh.Z-s.Z
			distSq := dx*dx + dy*dy + dz*dz + 1.0
			force := (bh.Mass * 0.1) / distSq

			s.VX += (dx / math.Sqrt(distSq)) * force
			s.VY += (dy / math.Sqrt(distSq)) * force
			s.VZ += (dz / math.Sqrt(distSq)) * force
		}

		s.X += s.VX
		s.Y += s.VY
		s.Z += s.VZ

		s.VX *= 0.95
		s.VY *= 0.95
		s.VZ *= 0.95
	}

	p.angleX += 0.02
	p.angleY += 0.03
}

// Render 3D Nebula onto ASCII terminal frame buffer with ANSI colors
func (p *Profiler) Render() {
	p.mu.Lock()
	defer p.mu.Unlock()

	// Initialize buffers
	buf := make([][]char, p.height)
	colorBuf := make([][]string, p.height)
	zBuf := make([][]float64, p.height)

	for y := 0; y < p.height; y++ {
		buf[y] = make([]char, p.width)
		colorBuf[y] = make([]string, p.width)
		zBuf[y] = make([]float64, p.width)
		for x := 0; x < p.width; x++ {
			buf[y][x] = ' '
			colorBuf[y][x] = "\033[0m"
			zBuf[y][x] = -1e9
		}
	}

	cosX, sinX := math.Cos(p.angleX), math.Sin(p.angleX)
	cosY, sinY := math.Cos(p.angleY), math.Sin(p.angleY)

	// 3D Projection Helper
	project := func(x, y, z float64) (int, int, float64) {
		// Rotate around Y and X axes
		x1 := x*cosY + z*sinY
		z1 := -x*sinY + z*cosY
		y2 := y*cosX - z1*sinX
		z2 := y*sinX + z1*cosX

		fov := 35.0
		distance := 40.0
		pz := z2 + distance
		screenX := int(float64(p.width)/2.0 + (x1*fov)/(pz*0.5))
		screenY := int(float64(p.height)/2.0 + (y2*fov)/pz)

		return screenX, screenY, z2
	}

	// Render Stars
	starGlyphs := []rune{'·', '•', '*', '✦', '★', '✸'}
	colors := []string{
		"\033[38;5;39m",  // Blue
		"\033[38;5;51m",  // Cyan
		"\033[38;5;231m", // White
		"\033[38;5;226m", // Yellow
		"\033[38;5;208m", // Orange
	}

	for _, s := range p.stars {
		sx, sy, sz := project(s.X, s.Y, s.Z)
		if sx >= 0 && sx < p.width && sy >= 0 && sy < p.height {
			if sz > zBuf[sy][sx] {
				zBuf[sy][sx] = sz
				idx := int(s.Brightness * float64(len(starGlyphs)-1))
				if idx >= len(starGlyphs) {
					idx = len(starGlyphs) - 1
				}
				buf[sy][sx] = char(starGlyphs[idx])
				colorBuf[sy][sx] = colors[s.Temperature]
			}
		}
	}

	// Render Black Holes (Event Horizon & Accretion Disk)
	for _, bh := range p.blackHoles {
		bx, by, bz := project(bh.X, bh.Y, bh.Z)
		radius := int(math.Min(bh.Mass/2.0, 6.0))

		for dy := -radius; dy <= radius; dy++ {
			for dx := -radius * 2; dx <= radius * 2; dx++ {
				px, py := bx+dx, by+dy
				if px >= 0 && px < p.width && py >= 0 && py < p.height {
					dist := math.Sqrt(float64(dx*dx)/4.0 + float64(dy*dy))
					if dist <= float64(radius) && bz+1.0 > zBuf[py][px] {
						zBuf[py][px] = bz + 1.0
						if dist < float64(radius)*0.5 {
							buf[py][px] = '@'
							colorBuf[py][px] = "\033[38;5;16m\033[48;5;196m" // Magenta/Red event horizon
						} else {
							buf[py][px] = 'o'
							colorBuf[py][px] = "\033[38;5;198m" // Accretion disk
						}
					}
				}
			}
		}
	}

	// Draw Canvas to Screen
	fmt.Print("\033[H") // Move cursor to top left
	fmt.Printf("\033[1;36m=== 🌌 GO HEAP NEBULA PROFILER 🌌 ===\033[0m\n")
	fmt.Printf("Allocated Heap: \033[1;32m%.2f MB\033[0m | Active Objects: \033[1;33m%d\033[0m | GC Cycles: \033[1;35m%d\033[0m | Leaks Coalesced: \033[1;31m%d\033[0m\n",
		float64(p.memStats.HeapAlloc)/1024/1024, p.memStats.HeapObjects, p.memStats.NumGC, len(p.blackHoles))
	fmt.Println("-------------------------------------------------------------------------------")

	for y := 0; y < p.height; y++ {
		line := ""
		for x := 0; x < p.width; x++ {
			line += colorBuf[y][x] + string(buf[y][x])
		}
		fmt.Println(line + "\033[0m")
	}
	fmt.Println("\033[1;30m[Press Ctrl+C to exit profiler] - Main-sequence stars = Active Heap, Black Holes = Leaks\033[0m")
}

type char rune

// Simulated Application workload with variable allocations and memory leaks
func simulateApplicationWorkload(p *Profiler) {
	ticker := time.NewTicker(400 * time.Millisecond)
	leakTicker := time.NewTicker(1500 * time.Millisecond)
	gcTicker := time.NewTicker(5 * time.Second)

	for {
		select {
		case <-ticker.C:
			// Normal memory allocation churn
			temp := make([][]byte, rand.Intn(15)+1)
			for i := range temp {
				temp[i] = make([]byte, rand.Intn(50000)+1000)
			}
		case <-leakTicker.C:
			// Intentional memory leak accumulation
			p.mu.Lock()
			leakBlock := make([]byte, 1024*1024*2) // 2MB leak block
			p.leakBuffer = append(p.leakBuffer, leakBlock)
			p.mu.Unlock()
		case <-gcTicker.C:
			// Force Garbage Collection periodically
			runtime.GC()
		}
	}
}

func main() {
	// Hide cursor & clear terminal screen
	fmt.Print("\033[?25l\033[2J")
	defer fmt.Print("\033[?25h\033[0m\n") // Restore cursor on exit

	profiler := NewProfiler(78, 22)

	// Intercept SIGINT/SIGTERM for clean shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go simulateApplicationWorkload(profiler)

	renderTicker := time.NewTicker(50 * time.Millisecond)
	defer renderTicker.Stop()

	for {
		select {
		case <-renderTicker.C:
			profiler.Update()
			profiler.Render()
		case <-sigChan:
			fmt.Println("\nExiting Nebula Profiler...")
			return
		}
	}
}