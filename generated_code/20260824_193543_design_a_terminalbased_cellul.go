package main

import (
	"fmt"
	"math/rand"
	"strings"
	"time"
)

// Phoneme represents a cellular unit of sound and visual weight.
type Phoneme struct {
	Symbol string
	Stress int // 0: Unstressed, 1: Secondary, 2: Primary
}

// Concrete poetry lexicon organized by stress patterns.
var phonemePool = map[int][]string{
	0: {"ah", "eh", "ih", "oh", "uh", "m", "n", "s", "l"},
	1: {"KRA", "TZE", "VOX", "LUM", "PHO", "RHO", "STR"},
	2: {"DARK", "SOUL", "FLOW", "Breathe", "SING", "Pulse", "WAVE"},
}

const (
	Width  = 30
	Height = 15
)

// Grid holds the cellular automaton state.
type Grid [Height][Width]Phoneme

func main() {
	rand.Seed(time.Now().UnixNano())
	grid := initGrid()

	// Hide cursor and clear screen using ANSI escape sequences
	fmt.Print("\033[?25l\033[2J")

	for {
		render(grid)
		grid = step(grid)
		time.Sleep(150 * time.Millisecond)
	}
}

// Randomly populates the initial grid with phonemes.
func initGrid() Grid {
	var g Grid
	for y := 0; y < Height; y++ {
		for x := 0; x < Width; x++ {
			if rand.Float32() < 0.35 {
				g[y][x] = randomPhoneme()
			}
		}
	}
	return g
}

// Creates a phoneme based on a random stress level.
func randomPhoneme() Phoneme {
	stress := rand.Intn(3)
	symbols := phonemePool[stress]
	return Phoneme{
		Symbol: symbols[rand.Intn(len(symbols))],
		Stress: stress,
	}
}

// Steps the cellular automaton state based on linguistic stress neighbors.
func step(current Grid) Grid {
	var next Grid
	for y := 0; y < Height; y++ {
		for x := 0; x < Width; x++ {
			neighbors, totalStress := analyzeNeighbors(current, x, y)
			cell := current[y][x]

			if cell.Symbol != "" {
				// Survival rules based on stress harmony:
				// Overcrowding of heavy stress leads to death; balanced rhythm sustains life.
				if neighbors >= 2 && neighbors <= 4 && totalStress <= 6 {
					next[y][x] = cell
				} else if totalStress > 6 {
					// High stress causes phonetic mutation into lighter sound
					next[y][x] = Phoneme{Symbol: phonemePool[0][rand.Intn(len(phonemePool[0]))], Stress: 0}
				}
			} else {
				// Birth rule: Rhythmic resonance creates a new phoneme
				if neighbors == 3 {
					avgStress := totalStress / 3
					if avgStress > 2 {
						avgStress = 2
					}
					symbols := phonemePool[avgStress]
					next[y][x] = Phoneme{
						Symbol: symbols[rand.Intn(len(symbols))],
						Stress: avgStress,
					}
				}
			}
		}
	}
	return next
}

// Counts alive neighbors and sums their linguistic stress levels.
func analyzeNeighbors(g Grid, x, y int) (count int, totalStress int) {
	for dy := -1; dy <= 1; dy++ {
		for dx := -1; dx <= 1; dx++ {
			if dx == 0 && dy == 0 {
				continue
			}
			nx, ny := (x+dx+Width)%Width, (y+dy+Height)%Height
			neighbor := g[ny][nx]
			if neighbor.Symbol != "" {
				count++
				totalStress += neighbor.Stress
			}
		}
	}
	return
}

// Renders the poetry grid to the terminal using ANSI colors.
func render(g Grid) {
	var sb strings.Builder
	sb.WriteString("\033[H") // Move cursor to top-left

	for y := 0; y < Height; y++ {
		for x := 0; x < Width; x++ {
			cell := g[y][x]
			if cell.Symbol == "" {
				sb.WriteString("    ")
			} else {
				// Color mapping based on stress: 0=cyan, 1=magenta, 2=bold yellow
				var colorCode string
				switch cell.Stress {
				case 0:
					colorCode = "\033[36m"
				case 1:
					colorCode = "\033[35m"
				case 2:
					colorCode = "\033[1;33m"
				}
				sb.WriteString(fmt.Sprintf("%s%-4s\033[0m", colorCode, cell.Symbol))
			}
		}
		sb.WriteString("\n")
	}
	fmt.Print(sb.String())
}