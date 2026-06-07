package main

import (
	"fmt"
	"math/rand"
	"strings"
	"time"
)

const (
	width        = 80 // cells per row
	bands        = 8  // frequency bands
	frames       = 200
	sleepMillis  = 80
	poemLines    = 8
	rhymePattern = "AABB"
)

// simple word pools for poem generation
var nouns = []string{"wind", "fire", "storm", "river", "night", "dawn", "cloud", "shade"}
var verbs = []string{"whispers", "shimmers", "dances", "sleeps", "glows", "burns", "rises", "falls"}
var rhymes = map[string][]string{
	"A": {"bright", "light", "flight", "night"},
	"B": {"deep", "sleep", "keep", "weep"},
}

// cellular automaton state
type automaton struct {
	rule  uint8
	row   []uint8
	next  []uint8
}

// create a new automaton with random rule and empty row
func newAutomaton(rule uint8) *automaton {
	row := make([]uint8, width)
	// seed with a single live cell in the middle
	row[width/2] = 1
	return &automaton{
		rule: rule,
		row:  row,
		next: make([]uint8, width),
	}
}

// evolve one generation using elementary CA rule
func (a *automaton) step() {
	for i := 0; i < width; i++ {
		// neighbourhood bits (left, center, right)
		left := a.row[(i-1+width)%width]
		center := a.row[i]
		right := a.row[(i+1)%width]
		index := (left << 2) | (center << 1) | right
		// rule bit determines next state
		a.next[i] = (a.rule >> index) & 1
	}
	a.row, a.next = a.next, a.row
}

// render the current row as ASCII
func (a *automaton) render() string {
	var sb strings.Builder
	for _, cell := range a.row {
		if cell == 1 {
			sb.WriteRune('#')
		} else {
			sb.WriteRune(' ')
		}
	}
	return sb.String()
}

// generate a line of poetry from current automaton state
func composeLine(a *automaton, lineIdx int) string {
	// count live cells
	live := 0
	for _, c := range a.row {
		if c == 1 {
			live++
		}
	}
	// pick words based on density
	var noun, verb string
	if live > width/2 {
		noun = nouns[rand.Intn(len(nouns))]
		verb = verbs[rand.Intn(len(verbs))]
	} else {
		noun = nouns[rand.Intn(len(nouns))]
		verb = verbs[rand.Intn(len(verbs))]
	}
	// choose rhyme word
	group := rhymePattern[lineIdx%len(rhymePattern):][0:1] // "A" or "B"
	rhymed := rhymes[group][rand.Intn(len(rhymes[group]))]
	return fmt.Sprintf("%s %s %s.", strings.Title(noun), verb, rhymed)
}

// simulate a fake frequency analysis producing a rule per band
func freqToRule() uint8 {
	// combine random band amplitudes into a rule byte
	var rule uint8
	for i := 0; i < bands; i++ {
		band := uint8(rand.Intn(2)) // treat each band as a bit
		rule |= band << i
	}
	return rule
}

func main() {
	rand.Seed(time.Now().UnixNano())
	// initialise automaton with rule derived from fake audio
	rule := freqToRule()
	ca := newAutomaton(rule)

	poem := make([]string, 0, poemLines)

	for f := 0; f < frames; f++ {
		// visual output
		fmt.Print("\033[H\033[2J") // clear screen
		fmt.Println(ca.render())

		// every few frames generate a poem line
		if f% (frames/poemLines) == 0 && len(poem) < poemLines {
			line := composeLine(ca, len(poem))
			poem = append(poem, line)
		}

		// advance automaton
		ca.step()

		// simulate new audio rule every 30 frames
		if f%30 == 0 {
			ca.rule = freqToRule()
		}

		time.Sleep(sleepMillis * time.Millisecond)
	}

	// final poem output
	fmt.Println("\n--- Poem ---")
	for _, l := range poem {
		fmt.Println(l)
	}
}