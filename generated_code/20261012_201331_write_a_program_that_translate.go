package main

import (
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"time"
)

// Organism represents a file living in the generative ecosystem
type Organism struct {
	Name     string
	Size     int64
	Lifespan int
	Age      int
	Energy   float64
	X, Y     int
	Alive    bool
}

func main() {
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))

	// Scan local directory to populate the ecosystem
	root := "."
	var organisms []*Organism

	_ = filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}

		// Calculate block allocation size approximation (4KB blocks)
		const blockSize = 4096
		size := info.Size()
		blocks := (size + blockSize - 1) / blockSize
		if blocks < 1 {
			blocks = 1
		}

		// Instantiate file as a sentient organism
		org := &Organism{
			Name:     info.Name(),
			Size:     size,
			Lifespan: int(blocks * 15), // Lifespan scales with block allocation
			Age:      0,
			Energy:   100.0,
			X:        rng.Intn(60),
			Y:        rng.Intn(18),
			Alive:    true,
		}
		organisms = append(organisms, org)
		if len(organisms) >= 25 {
			return filepath.SkipDir
		}
		return nil
	})

	if len(organisms) == 0 {
		fmt.Println("No files found in the directory to spawn organisms.")
		return
	}

	// Run the interactive generative simulation loop
	fmt.Print("\033[2J\033[H")
	for tick := 0; tick < 40; tick++ {
		fmt.Printf("\033[H\033[J=== Directory Ecosystem (Tick %d/40) ===\n", tick+1)

		// Create simulation grid
		grid := make([][]string, 18)
		for i := range grid {
			grid[i] = make([]string, 60)
			for j := range grid[i] {
				grid[i][j] = "·"
			}
		}

		activeCount := 0
		for _, org := range organisms {
			if !org.Alive {
				continue
			}
			activeCount++

			// Aging and energy decay based on size/lifespan
			org.Age++
			org.Energy -= float64(org.Age) * 0.15
			if org.Age >= org.Lifespan || org.Energy <= 0 {
				org.Alive = false
				continue
			}

			// Organic wandering movement
			org.X = (org.X + rng.Intn(3) - 1 + 60) % 60
			org.Y = (org.Y + rng.Intn(3) - 1 + 18) % 18

			// Render organism using the first letter of its filename
			char := string(org.Name[0])
			grid[org.Y][org.X] = char
		}

		// Draw ecosystem view
		for _, row := range grid {
			for _, cell := range row {
				fmt.Print(cell)
			}
			fmt.Println()
		}

		fmt.Printf("\nLiving Organisms: %d/%d\n", activeCount, len(organisms))
		fmt.Println("Rule: Lifespan is dictated by file block allocation size. Organisms wander and eventually decay.")

		if activeCount == 0 {
			fmt.Println("\nAll file organisms have completed their lifecycle. Ecosystem resting.")
			break
		}

		time.Sleep(350 * time.Millisecond)
	}
}