package main

import (
	"fmt"
	"math/rand"
	"time"
)

// elementary automaton with rule 30
const (
	width    = 79 // cells per line (odd for a centered seed)
	steps    = 30 // generations to display
	ruleMask = 0b00000111 // mask for extracting 3-bit neighbourhood
)

// rule30 maps a 3‑bit neighbourhood (left,center,right) to the next state.
var rule30 = [8]byte{
	0, // 111 -> 0
	0, // 110 -> 0
	0, // 101 -> 0
	1, // 100 -> 1
	1, // 011 -> 1
	1, // 010 -> 1
	1, // 001 -> 1
	0, // 000 -> 0
}

// generate the next generation from current line.
func nextGen(curr []byte) []byte {
	next := make([]byte, len(curr))
	for i := range curr {
		// wrap around edges (periodic boundary)
		left := curr[(i-1+len(curr))%len(curr)]
		center := curr[i]
		right := curr[(i+1)%len(curr)]
		neigh := (left << 2) | (center << 1) | right
		next[i] = rule30[neigh]
	}
	return next
}

// render a line using spaces and █ characters.
func render(line []byte) string {
	b := make([]byte, len(line))
	for i, v := range line {
		if v == 1 {
			b[i] = '█'
		} else {
			b[i] = ' '
		}
	}
	return string(b)
}

// Randomized seed for a more artistic touch.
func randomSeed() []byte {
	r := make([]byte, width)
	for i := range r {
		if rand.Intn(2) == 0 {
			r[i] = 0
		} else {
			r[i] = 1
		}
	}
	return r
}

func main() {
	rand.Seed(time.Now().UnixNano())

	// start with a single live cell in the middle
	curr := make([]byte, width)
	curr[width/2] = 1

	// optionally sprinkle a few random cells
	for i := 0; i < width/10; i++ {
		curr[rand.Intn(width)] = 1
	}

	for step := 0; step < steps; step++ {
		fmt.Println(render(curr))
		curr = nextGen(curr)

		// occasional random perturbation to keep patterns lively
		if step%7 == 0 && step != 0 {
			curr[rand.Intn(width)] ^= 1
		}
	}
}