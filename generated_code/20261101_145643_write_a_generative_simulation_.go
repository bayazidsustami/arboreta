package main

import (
	"fmt"
	"math"
	"math/rand"
	"time"
)

// Insect represents a typographic builder crawling across the architectural grid.
type Insect struct {
	x, y  int
	char  rune
	vx, vy float64
}

func main() {
	// Seed random number generator
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))

	// Fetch local timezone information to drive atmospheric anomaly simulation
	loc := time.Now().Location()
	_, offset := time.Now().Zone()
	hour := float64(time.Now().Hour())

	// Calculate baseline atmospheric pressure anomaly based on local timezone offset and time of day
	baseAnomaly := math.Sin(hour/24.0*2*math.Pi+float64(offset)/3600.0) * 18.5

	width, height := 64, 22
	grid := make([][]rune, height)
	for y := 0; y < height; y++ {
		grid[y] = make([]rune, width)
		for x := 0; x < width; x++ {
			grid[y][x] = ' '
		}
	}

	// Initialize typographic insects
	numInsects := 7
	insects := make([]*Insect, numInsects)
	insectChars := []rune{'@', '&', '%', '#', '§', '¶', 'Ω'}
	for i := 0; i < numInsects; i++ {
		insects[i] = &Insect{
			x:    rng.Intn(width),
			y:    rng.Intn(height),
			char: insectChars[i%len(insectChars)],
			vx:   (rng.Float64() - 0.5) * 2.5,
			vy:   (rng.Float64() - 0.5) * 2.5,
		}
	}

	// Run generative blueprint simulation for 45 frames
	totalSteps := 45
	for step := 0; step < totalSteps; step++ {
		// Dynamic atmospheric pressure fluctuation per step
		currentPressureAnomaly := baseAnomaly + math.Sin(float64(step)*0.25)*7.2

		// Blueprint materialization & decay
		for y := 0; y < height; y++ {
			for x := 0; x < width; x++ {
				if grid[y][x] != ' ' && rng.Float64() < 0.04 {
					grid[y][x] = '.'
				}
			}
		}

		// Update insect positions and structural deposits
		for _, ins := range insects {
			// Pressure anomalies alter insect velocity & construction density
			speedMod := 1.0 + (currentPressureAnomaly / 25.0)
			ins.x += int(math.Round(ins.vx * speedMod))
			ins.y += int(math.Round(ins.vy * speedMod))

			// Grid boundary checks and vector reflection
			if ins.x < 0 {
				ins.x = 0
				ins.vx *= -1
			} else if ins.x >= width {
				ins.x = width - 1
				ins.vx *= -1
			}
			if ins.y < 0 {
				ins.y = 0
				ins.vy *= -1
			} else if ins.y >= height {
				ins.y = height - 1
				ins.vy *= -1
			}

			// Deposit architectural glyphs
			blueprintGlyphs := []rune{'+', '-', '|', '#', 'O', 'x', '=', 'X'}
			grid[ins.y][ins.x] = blueprintGlyphs[rng.Intn(len(blueprintGlyphs))]
		}

		// Render simulation frame to terminal
		fmt.Printf("\033[H\033[2J")
		fmt.Println("╔══════════════════════════════════════════════════════════════════╗")
		fmt.Println("║       TYPOGRAPHIC INSECT ARCHITECTURAL BLUEPRINT GENERATOR       ║")
		fmt.Println("╚══════════════════════════════════════════════════════════════════╝")
		fmt.Printf(" Timezone: %s | Pressure Anomaly: %+5.2f hPa | Step: %d/%d\n", loc, currentPressureAnomaly, step+1, totalSteps)
		fmt.Printf(" ┌%s┐\n", string(repeatRune('─', width)))
		for y := 0; y < height; y++ {
			fmt.Printf(" │")
			for x := 0; x < width; x++ {
				hasInsect := false
				var activeChar rune
				for _, ins := range insects {
					if ins.x == x && ins.y == y {
						hasInsect = true
						activeChar = ins.char
						break
					}
				}
				if hasInsect {
					fmt.Printf("%c", activeChar)
				} else {
					fmt.Printf("%c", grid[y][x])
				}
			}
			fmt.Println("│")
		}
		fmt.Printf(" └%s┘\n", string(repeatRune('─', width)))

		time.Sleep(120 * time.Millisecond)
	}

	fmt.Println("\nBlueprint generation complete. Colony resting.")
}

func repeatRune(r rune, count int) []rune {
	buf := make([]rune, count)
	for i := range buf {
		buf[i] = r
	}
	return buf
}