package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"
	"time"
	"unicode"
)

type Cell struct {
	runeVal rune
	rule    int // 0-4 derived from Unicode block approximation
	state   int // 0 or 1
}

// approximate block rule: count of set bits in rune value mod 5
func deriveRule(r rune) int {
	bits := 0
	x := uint32(r)
	for x > 0 {
		bits += int(x & 1)
		x >>= 1
	}
	return bits % 5
}

// simple neighbor sum (Moore) with wrap‑around topology
func step(grid [][]Cell) [][]Cell {
	h, w := len(grid), len(grid[0])
	newGrid := make([][]Cell, h)
	for y := 0; y < h; y++ {
		newGrid[y] = make([]Cell, w)
		for x := 0; x < w; x++ {
			sum := 0
			for dy := -1; dy <= 1; dy++ {
				for dx := -1; dx <= 1; dx++ {
					if dy == 0 && dx == 0 {
						continue
					}
					ny := (y + dy + h) % h
					nx := (x + dx + w) % w
					sum += grid[ny][nx].state
				}
			}
			r := grid[y][x]
			// rule: become alive if sum equals rule, else die
			if sum == r.rule {
				r.state = 1
			} else {
				r.state = 0
			}
			newGrid[y][x] = r
		}
	}
	return newGrid
}

// map rune to a frequency (Hz) – simple linear scaling
func freqFromRune(r rune) float64 {
	base := 220.0 // A3
	return base * (1 + float64(r%88)/12.0) // stay within a few octaves
}

// render grid to terminal
func render(grid [][]Cell, stepNum int) {
	fmt.Print("\x1b[2J\x1b[H") // clear screen
	fmt.Printf("Step %d\n", stepNum)
	for _, row := range grid {
		var sb strings.Builder
		for _, c := range row {
			if c.state == 1 {
				sb.WriteRune('█')
			} else {
				sb.WriteRune(' ')
			}
		}
		fmt.Println(sb.String())
	}
	// show a crude "soundtrack"
	var freqSet = make(map[float64]struct{})
	for _, row := range grid {
		for _, c := range row {
			if c.state == 1 {
				freqSet[freqFromRune(c.runeVal)] = struct{}{}
			}
		}
	}
	var freqs []float64
	for f := range freqSet {
		freqs = append(freqs, f)
	}
	fmt.Print("Sound frequencies (Hz): ")
	for i, f := range freqs {
		if i > 0 {
			fmt.Print(", ")
		}
		fmt.Printf("%.1f", f)
	}
	fmt.Println()
}

// parse input poem into grid of Cells
func parsePoem(lines []string) [][]Cell {
	var grid [][]Cell
	for _, line := range lines {
		var row []Cell
		for _, r := range []rune(line) {
			if unicode.IsSpace(r) {
				continue
			}
			row = append(row, Cell{
				runeVal: r,
				rule:    deriveRule(r),
				state:   int(r % 2), // seed state from parity of code point
			})
		}
		if len(row) > 0 {
			grid = append(grid, row)
		}
	}
	return grid
}

func main() {
	// read poem from stdin; empty input falls back to a demo poem
	var lines []string
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}
	if len(lines) == 0 {
		lines = []string{
			"🌞🚀🌙",
			"💧🔥💨",
			"🌱🌸🌿",
		}
	}
	grid := parsePoem(lines)

	const steps = 200
	const delay = 100 * time.Millisecond

	for i := 0; i < steps; i++ {
		render(grid, i)
		grid = step(grid)
		time.Sleep(delay)
	}
}