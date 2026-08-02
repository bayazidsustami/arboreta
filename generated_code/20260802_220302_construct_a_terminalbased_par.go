package main

import (
	"fmt"
	"math/rand"
	"os"
	"os/signal"
	"runtime"
	"syscall"
	"time"
)

// Particle represents an allocated memory block decaying into star dust.
type Particle struct {
	x, y   int
	energy float64 // 1.0 (bright newborn allocation) to 0.0 (reclaimed dust)
}

const (
	width  = 80
	height = 22
)

func clearScreen()        { fmt.Print("\033[2J\033[H") }
func hideCursor()         { fmt.Print("\033[?25l") }
func showCursor()         { fmt.Print("\033[?25h") }
func moveCursor(x, y int) { fmt.Printf("\033[%d;%dH", y+1, x+1) }

// Map particle energy levels to flickering ASCII chars and ANSI color gradients.
func renderParticle(energy float64) string {
	switch {
	case energy > 0.85:
		chars := []rune{'★', '✦', '✹', '#', '@'}
		char := chars[rand.Intn(len(chars))]
		return fmt.Sprintf("\033[38;2;255;255;255m\033[1m%c\033[0m", char) // Radiant White
	case energy > 0.65:
		chars := []rune{'*', '✶', '+'}
		char := chars[rand.Intn(len(chars))]
		return fmt.Sprintf("\033[38;2;100;220;255m%c\033[0m", char) // Cyan Glow
	case energy > 0.45:
		chars := []rune{'o', '°', 'x'}
		char := chars[rand.Intn(len(chars))]
		return fmt.Sprintf("\033[38;2;80;200;120m%c\033[0m", char) // Decay Green
	case energy > 0.25:
		chars := []rune{'.', '·', ':'}
		char := chars[rand.Intn(len(chars))]
		return fmt.Sprintf("\033[38;2;220;140;60m%c\033[0m", char) // Amber Dust
	default:
		return "\033[38;2;80;40;50m·\033[0m" // Fading Ember
	}
}

func main() {
	// Restore terminal state on signal interrupt
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-sigChan
		showCursor()
		clearScreen()
		fmt.Println("Memory visualizer terminated. All allocations reclaimed.")
		os.Exit(0)
	}()

	hideCursor()
	clearScreen()

	var particles []Particle
	var activeHeap [][]byte

	tick := 0
	for {
		tick++

		// 1. Dynamically allocate memory blocks to simulate workload
		if tick%3 == 0 {
			allocBytes := rand.Intn(1_200_000) + 300_000
			buf := make([]byte, allocBytes)
			for i := range buf {
				buf[i] = byte(i)
			}
			activeHeap = append(activeHeap, buf)

			// Spawn ASCII star particles representing allocated bytes
			spawnCount := allocBytes / 35_000
			for i := 0; i < spawnCount; i++ {
				particles = append(particles, Particle{
					x:      rand.Intn(width),
					y:      rand.Intn(height),
					energy: 1.0,
				})
			}
		}

		// 2. Periodically drop memory handles and trigger explicit Garbage Collection
		if tick%12 == 0 && len(activeHeap) > 0 {
			dropCount := (len(activeHeap) / 2) + 1
			if dropCount > len(activeHeap) {
				dropCount = len(activeHeap)
			}
			activeHeap = activeHeap[dropCount:]
			runtime.GC() // Garbage collector reclaims orphaned heap blocks
		}

		// 3. Read real runtime stats
		var m runtime.MemStats
		runtime.ReadMemStats(&m)

		// 4. Update particles; decay rate accelerates during active GC sweeps
		decayRate := 0.035
		if m.NumGC > 0 && tick%12 < 4 {
			decayRate = 0.095 // Rapid burnout when GC is actively sweeping
		}

		var liveParticles []Particle
		for _, p := range particles {
			p.energy -= decayRate + (rand.Float64() * 0.02)
			if p.energy > 0 {
				liveParticles = append(liveParticles, p)
			}
		}
		particles = liveParticles

		// 5. Construct and render screen buffer
		screen := make([][]string, height)
		for r := range screen {
			screen[r] = make([]string, width)
			for c := range screen[r] {
				screen[r][c] = " "
			}
		}

		for _, p := range particles {
			if p.x >= 0 && p.x < width && p.y >= 0 && p.y < height {
				screen[p.y][p.x] = renderParticle(p.energy)
			}
		}

		// Output header metrics and frame
		moveCursor(0, 0)
		fmt.Printf("\033[1;36m⚡ REAL-TIME MEMORY DECAY & GC PARTICLE SYSTEM ⚡\033[0m\n")
		fmt.Printf("\033[90mHeap Alloc: %5.2f MB | Heap Objects: %6d | Total GC Cycles: %3d | Active Stars: %4d\033[0m\n",
			float64(m.HeapAlloc)/1024/1024, m.HeapObjects, m.NumGC, len(particles))
		fmt.Println("--------------------------------------------------------------------------------")

		for _, row := range screen {
			for _, cell := range row {
				fmt.Print(cell)
			}
			fmt.Println()
		}

		time.Sleep(50 * time.Millisecond)
	}
}