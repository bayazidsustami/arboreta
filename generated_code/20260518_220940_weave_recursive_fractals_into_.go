package main

import (
	"fmt"
	"math"
	"math/rand"
	"time"
)

// Fractal represents a point of existence within the recursive weave.
type Fractal struct {
	Depth    int
	Resonance float64
	Symmetry  float64
}

// Symphony represents the unfolding arrangement of recursive truths.
type Symphony struct {
	Notes []string
	Chaos float64
}

// Weave breathes life into the void by recursing through mathematical beauty.
// It uses the concept of a Mandelbrot-inspired drift to generate "poetic" data.
func Weave(f Fractal, depth int) Symphony {
	// The base case: when depth reaches zero, the ephemeral nature takes hold.
	if depth <= 0 {
		return Symphony{
			Notes: []string{"silence"},
			Chaos: f.Resonance,
		}
	}

	// Error as evolution: introducing stochastic entropy to prevent rigid stagnation.
	entropy := rand.Float64() * f.Resonance
	
	// Unraveling: the recursion branches, creating a fractal structure of complexity.
	leftBranch := Weave(Fractal{
		Depth:     depth - 1,
		Resonance: f.Resonance * 0.7,
		Symmetry:  f.Symmetry * 0.5,
	}, depth-1)

	rightBranch := Weave(Fractal{
		Depth:     depth - 1,
		Resonance: f.Resonance * 0.8,
		Symmetry:  f.Symmetry * 1.2,
	}, depth-1)

	// Syntax breathes: we combine the branches into a new, more complex movement.
	return Symphony{
		Notes: []string{
			leftBranch.Notes[0],
			fmt.Sprintf("✧ %s ✧", getCelestialWord(entropy)),
			rightBranch.Notes[0],
		},
		Chaos: (leftBranch.Chaos + rightBranch.Chaos) / 2 + entropy,
	}
}

// getCelestialWord translates numerical resonance into linguistic ephemeralism.
func getCelestialWord(v float64) string {
	words := []string{"echo", "drift", "pulse", "bloom", "void", "glimmer", "fracture", "aura"}
	idx := int(math.Mod(v*10, float64(len(words))))
	if idx < 0 {
		idx = 0
	}
	return words[idx]
}

func main() {
	// Seeding the universe with time.
	rand.Seed(time.Now().UnixNano())

	fmt.Println("--- INITIALIZING THE EPHEMERAL SYMPHONY ---")
	fmt.Println("Unraveling the recursive weave...\n")

	// The initial seed of existence.
	genesis := Fractal{
		Depth:     4,
		Resonance: 1.0,
		Symmetry:  1.0,
	}

	// Execute the algorithm.
	result := Weave(genesis, 4)

	// Rendering the symphony through the lens of the terminal.
	for i, note := range result.Notes {
		indent := math.Mod(float64(i), 2)
		if indent > 0.5 {
			fmt.Printf("  %s\n", note)
		} else {
			fmt.Printf("%s\n", note)
		}
	}

	fmt.Printf("\n[Final Resonance: %.4f | Entropy Level: %.4f]\n", result.Chaos, rand.Float64())
	fmt.Println("--- THE SYMPHONY DISSOLVES INTO THE VOID ---")
}