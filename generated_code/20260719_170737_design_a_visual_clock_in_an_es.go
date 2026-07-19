package main

import (
	"fmt"
	"math/rand"
	"strings"
	"time"
)

// The Grid dimensions for our esoteric visual clock
const (
	width  = 70
	height = 20
)

// Cell represents an element in our space-filling grid language
type Cell struct {
	symbol rune
	color  string
	energy int
}

func main() {
	// ANSI escape codes to clear screen and hide cursor
	fmt.Print("\033[2J\033[?25l")
	defer fmt.Print("\033[?25h") // Restore cursor on exit

	// Initialize the cellular universe
	grid := make([][]Cell, height)
	for i := range grid {
		grid[i] = make([]Cell, width)
		for j := range grid[i] {
			grid[i][j] = Cell{symbol: '.', color: "\033[38;5;236m", energy: 0}
		}
	}

	// Palette mapping time components to vibrant terminal colors
	colors := []string{
		"\033[38;5;45m",  // Cyan-blue (Seconds)
		"\033[38;5;99m",  // Deep Purple (Minutes)
		"\033[38;5;208m", // Cosmic Amber (Hours)
		"\033[38;5;197m", // Neon Rose (Flux)
	}

	for {
		now := time.Now()
		hr, min, sec := now.Hour(), now.Minute(), now.Second()

		// Dynamically mutate the cellular automata rules using time as quantum seeds
		ruleSum := hr + min + sec
		fluxRate := (sec % 5) + 1
		entropy := (min % 3) + 1

		// Inject modern temporal energy into the center of the grid
		midY, midX := height/2, width/2
		grid[midY][midX] = Cell{symbol: rune(48 + hr/10), color: colors[2], energy: hr}
		grid[midY][midX+1] = Cell{symbol: rune(48 + hr%10), color: colors[2], energy: hr}
		grid[midY][midX+3] = Cell{symbol: rune(48 + min/10), color: colors[1], energy: min}
		grid[midY][midX+4] = Cell{symbol: rune(48 + min%10), color: colors[1], energy: min}
		grid[midY][midX+6] = Cell{symbol: rune(48 + sec/10), color: colors[0], energy: sec}
		grid[midY][midX+7] = Cell{symbol: rune(48 + sec%10), color: colors[0], energy: sec}

		// Spark random quantum fluctuations based on the current second
		for k := 0; k < fluxRate; k++ {
			rx := rand.Intn(width)
			ry := rand.Intn(height)
			if grid[ry][rx].symbol == '.' || grid[ry][rx].symbol == ' ' {
				grid[ry][rx] = Cell{
					symbol: []rune("~*+¤§⚡" )[rand.Intn(6)],
					color:  colors[rand.Intn(len(colors))],
					energy: ruleSum % 10,
				}
			}
		}

		// Create the next generation buffer
		nextGrid := make([][]Cell, height)
		for i := range nextGrid {
			nextGrid[i] = make([]Cell, width)
			copy(nextGrid[i], grid[i])
		}

		// Evolve the space-filling grid based on time-mutated laws
		for y := 0; y < height; y++ {
			for x := 0; x < width; x++ {
				// Don't overwrite the core clock readout text
				if y == midY && x >= midX && x <= midX+7 {
					continue
				}

				// Count active neighbors and accumulate environmental energy
				neighbors := 0
				totalEnergy := 0
				for dy := -1; dy <= 1; dy++ {
					for dx := -1; dx <= 1; dx++ {
						if dy == 0 && dx == 0 {
							continue
						}
						ny, nx := (y+dy+height)%height, (x+dx+width)%width // Toroidal topology
						if grid[ny][nx].symbol != '.' && grid[ny][nx].symbol != ' ' {
							neighbors++
							totalEnergy += grid[ny][nx].energy
						}
					}
				}

				// The Esoteric Time-Mutation Rules
				current := grid[y][x]
				if current.symbol == '.' || current.symbol == ' ' {
					// Birth rule mutated by Minutes and Seconds
					if neighbors == entropy || (totalEnergy > hr && neighbors == 3) {
						nextGrid[y][x] = Cell{
							symbol: []rune("╱╲░▒▓┃" )[totalEnergy%6],
							color:  colors[(sec+totalEnergy)%4],
							energy: (totalEnergy + 1) % 60,
						}
					}
				} else {
					// Survival / Decay rule mutated by Hours and Total Energy
					if neighbors < 1 || neighbors > (ruleSum%4+2) {
						// Cell suffocates or expands into void space
						if rand.Float64() < 0.3 {
							nextGrid[y][x] = Cell{symbol: ' ', color: "\033[0m", energy: 0}
						}
					} else {
						// Cell shifts state, flowing through the digital landscape
						nextGrid[y][x].energy = (current.energy + fluxRate) % 100
						if nextGrid[y][x].energy%7 == 0 {
							nextGrid[y][x].color = colors[(min+y)%4]
						}
					}
				}
			}
		}
		grid = nextGrid

		// Render the frame to the terminal
		var out strings.Builder
		out.WriteString("\033[H") // Reset cursor to top-left
		out.WriteString(fmt.Sprintf("\033[1;36m「 COSMIC CHRONOMETER 」\033[0m  Rule Mutation Index: %03d\n", ruleSum))
		out.WriteString(strings.Repeat("─", width) + "\n")

		for y := 0; y < height; y++ {
			for x := 0; x < width; x++ {
				out.WriteString(grid[y][x].color + string(grid[y][x].symbol))
			}
			out.WriteString("\033[0m\n")
		}
		out.WriteString(strings.Repeat("─", width) + "\n")
		out.WriteString(fmt.Sprintf("\033[2mGrid State: Toroidal Flow | Entropy Vector: d(%d)/dt\033[0m", entropy))

		fmt.Print(out.String())

		// Synchronize clock tick rate (approx 8 frames per second for smooth fluid morphing)
		time.Sleep(125 * time.Millisecond)
	}
}