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

// Ecosystem visualizer mapping Go runtime memory allocations to a simulated biome.
// - Active Heap & Leaks manifest as invasive flora (🌱, 🌿, ☘️, 🍀, 🌵, 🌴).
// - Garbage Collection (GC) triggers a clearing wildfire (🔥, 💥) that sweeps away memory plants into ash.

const (
	width  = 40
	height = 15
)

var (
	floraSymbols = []string{"🌱", "🌿", "☘️", "🍀", "🌵", "🌴"}
	fireSymbols  = []string{"🔥", "💥", "⚡", "♨️"}
	ashSymbols   = []string{"░░", "▒▒", "··", "  "}
)

type Cell struct {
	Symbol string
	Color  string
	State  string // "empty", "flora", "fire", "ash"
}

func main() {
	// Intercept terminate signals for clean cursor restoration
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	// Background routine to periodically simulate variable allocations and memory leaks
	var memoryLeakHolder [][]byte
	go func() {
		for {
			time.Sleep(150 * time.Millisecond)
			// Allocate dynamic memory block
			block := make([]byte, rand.Intn(100000)+20000)
			
			// 40% chance to simulate memory leak (hold reference)
			if rand.Float32() < 0.40 {
				memoryLeakHolder = append(memoryLeakHolder, block)
			}

			// When heap leaks reach critical mass, release references and trigger forced GC
			if len(memoryLeakHolder) > 100 {
				memoryLeakHolder = nil
				runtime.GC()
			}
		}
	}()

	grid := make([][]Cell, height)
	for i := range grid {
		grid[i] = make([]Cell, width)
		for j := range grid[i] {
			grid[i][j] = Cell{Symbol: "  ", Color: "\033[0m", State: "empty"}
		}
	}

	fmt.Print("\033[?25l\033[2J") // Hide cursor & clear screen
	defer fmt.Print("\033[?25h\033[0m\033[2J")

	ticker := time.NewTicker(120 * time.Millisecond)
	defer ticker.Stop()

	var memStats runtime.MemStats
	var lastNumGC uint32

	for {
		select {
		case <-sigChan:
			return
		case <-ticker.C:
			runtime.ReadMemStats(&memStats)
			gcOccurred := memStats.NumGC > lastNumGC
			lastNumGC = memStats.NumGC

			updateEcosystem(grid, &memStats, gcOccurred)
			renderEcosystem(grid, &memStats)
		}
	}
}

func updateEcosystem(grid [][]Cell, stats *runtime.MemStats, gcOccurred bool) {
	// If Garbage Collection occurred, engulf existing flora in a wildfire sweep
	if gcOccurred {
		for i := 0; i < height; i++ {
			for j := 0; j < width; j++ {
				if grid[i][j].State == "flora" {
					grid[i][j].State = "fire"
					grid[i][j].Symbol = fireSymbols[rand.Intn(len(fireSymbols))]
					grid[i][j].Color = "\033[91m" // Red
				}
			}
		}
		return
	}

	// Calculate target flora count based on current heap in-use memory
	heapKB := stats.HeapInuse / 1024
	targetFlora := int(heapKB % uint64(width*height))

	currentFlora := 0
	for i := 0; i < height; i++ {
		for j := 0; j < width; j++ {
			cell := &grid[i][j]
			switch cell.State {
			case "fire":
				cell.State = "ash"
				cell.Symbol = ashSymbols[rand.Intn(len(ashSymbols))]
				cell.Color = "\033[90m" // Gray
			case "ash":
				if rand.Float32() < 0.5 {
					cell.State = "empty"
					cell.Symbol = "  "
					cell.Color = "\033[0m"
				}
			case "flora":
				currentFlora++
				if rand.Float32() < 0.05 { // Evolve plant symbol over time
					cell.Symbol = floraSymbols[rand.Intn(len(floraSymbols))]
				}
			}
		}
	}

	// Sprout invasive flora to reflect memory growth/leaks
	sproutsToGen := targetFlora - currentFlora
	for k := 0; k < sproutsToGen && k < 15; k++ {
		rx, ry := rand.Intn(height), rand.Intn(width)
		if grid[rx][ry].State == "empty" || grid[rx][ry].State == "ash" {
			grid[rx][ry].State = "flora"
			grid[rx][ry].Symbol = floraSymbols[rand.Intn(len(floraSymbols))]
			grid[rx][ry].Color = "\033[32m" // Green
		}
	}
}

func renderEcosystem(grid [][]Cell, stats *runtime.MemStats) {
	fmt.Print("\033[H") // Reset cursor position
	fmt.Println("\033[1;36m=== VIRTUAL MEMORY ECOSYSTEM VISUALIZER ===\033[0m")
	fmt.Printf("\033[1;33mHeap Alloc:\033[0m %7d KB | \033[1;35mHeap Objects:\033[0m %7d | \033[1;31mGC Wildfires:\033[0m %3d\n",
		stats.HeapAlloc/1024, stats.HeapObjects, stats.NumGC)
	fmt.Println("┌────────────────────────────────────────────────────────────────────────────────┐")

	for i := 0; i < height; i++ {
		fmt.Print("│")
		for j := 0; j < width; j++ {
			cell := grid[i][j]
			fmt.Printf("%s%s\033[0m", cell.Color, cell.Symbol)
		}
		fmt.Println("│")
	}
	fmt.Println("└────────────────────────────────────────────────────────────────────────────────┘")
	fmt.Println("🌱/🌿 = Active Heap/Leaks | 🔥/⚡ = Garbage Collection | ░░/▒▒ = Purged Memory Ash")
}