package main

import (
	"fmt"
	"strings"
	"time"
)

// Engine manages the state, self-modifying rule set, and execution history of a 2D cellular automaton.
type Engine struct {
	width, height int
	grid          [][]bool
	ruleB         uint16 // Bitmask for birth rules
	ruleS         uint16 // Bitmask for survival rules
	history       []string
}

// NewEngine constructs the engine with a deterministic seed pattern and standard Conway rules.
func NewEngine(w, h int) *Engine {
	grid := make([][]bool, h)
	for i := range grid {
		grid[i] = make([]bool, w)
	}

	e := &Engine{
		width:   w,
		height:  h,
		grid:    grid,
		ruleB:   1 << 3,              // Born on 3 neighbors
		ruleS:   (1 << 2) | (1 << 3), // Survive on 2 or 3 neighbors
		history: make([]string, 0),
	}

	// Deterministic initial seed pattern
	seed := [][2]int{
		{1, 2}, {2, 3}, {3, 1}, {3, 2}, {3, 3},
		{5, 10}, {5, 11}, {5, 12},
		{7, 5}, {8, 5}, {9, 5},
	}
	for _, p := range seed {
		if p[0] < h && p[1] < w {
			e.grid[p[0]][p[1]] = true
		}
	}
	return e
}

// Render displays the current ASCII frame and appends it to the execution history.
func (e *Engine) Render() string {
	var sb strings.Builder
	for y := 0; y < e.height; y++ {
		for x := 0; x < e.width; x++ {
			if e.grid[y][x] {
				sb.WriteString("#")
			} else {
				sb.WriteString(".")
			}
		}
		if y < e.height-1 {
			sb.WriteString("\n")
		}
	}
	frame := sb.String()
	e.history = append(e.history, frame)
	return frame
}

// Step advances the automaton one tick and mutates its transition rules based on state entropy.
func (e *Engine) Step() {
	next := make([][]bool, e.height)
	for i := range next {
		next[i] = make([]bool, e.width)
	}

	activeCount := 0
	for y := 0; y < e.height; y++ {
		for x := 0; x < e.width; x++ {
			neighbors := e.countNeighbors(y, x)
			if e.grid[y][x] {
				next[y][x] = (e.ruleS & (1 << neighbors)) != 0
			} else {
				next[y][x] = (e.ruleB & (1 << neighbors)) != 0
			}
			if next[y][x] {
				activeCount++
			}
		}
	}

	e.grid = next

	// Self-modification: deterministically flip rule bitmasks according to active cell parity
	if activeCount%2 == 0 {
		e.ruleB ^= (1 << (activeCount % 8))
	} else {
		e.ruleS ^= (1 << (activeCount % 8))
	}
	// Guarantee minimum vitality
	e.ruleB |= (1 << 3)
}

func (e *Engine) countNeighbors(y, x int) int {
	count := 0
	for dy := -1; dy <= 1; dy++ {
		for dx := -1; dx <= 1; dx++ {
			if dy == 0 && dx == 0 {
				continue
			}
			ny := (y + dy + e.height) % e.height
			nx := (x + dx + e.width) % e.width
			if e.grid[ny][nx] {
				count++
			}
		}
	}
	return count
}

// SerializeToPythonQuine outputs a valid, self-replicating Python Quine string containing the execution history.
func (e *Engine) SerializeToPythonQuine() string {
	var sb strings.Builder
	sb.WriteString("[")
	for i, frame := range e.history {
		if i > 0 {
			sb.WriteString(", ")
		}
		sb.WriteString(fmt.Sprintf("%q", frame))
	}
	sb.WriteString("]")
	pyHistory := sb.String()

	// Quine template that prints its exact Python source code alongside the embedded history payload
	template := "h = %s\ns = 'h = %%s\\ns = %%r\\nprint(s %%%% (h, s))'\nprint(s %% (h, s))"
	return fmt.Sprintf(template, pyHistory)
}

func main() {
	engine := NewEngine(20, 8)
	totalSteps := 10

	fmt.Println("=== ASCII CELLULAR AUTOMATON TRANSITIONS ===")
	for i := 0; i < totalSteps; i++ {
		fmt.Printf("\n--- Frame %d ---\n", i+1)
		frame := engine.Render()
		fmt.Println(frame)
		engine.Step()
		time.Sleep(50 * time.Millisecond)
	}

	fmt.Println("\n=== SERIALIZED SECONDARY LANGUAGE QUINE (PYTHON) ===")
	pythonQuine := engine.SerializeToPythonQuine()
	fmt.Println(pythonQuine)
}