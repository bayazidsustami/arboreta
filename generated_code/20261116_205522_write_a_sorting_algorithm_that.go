// Package main implements a creative sorting visualization where a data set
// is rendered as a flock of digital starlings. Out-of-order elements become
// chaotic predators/glitches until the swarm achieves complete harmony (sorted order).
package main

import (
	"fmt"
	"time"
)

// Starling represents an element in our dataset with positional and state attributes.
type Starling struct {
	value    int
	index    int
	isGlitch bool
}

func main() {
	// Initial chaotic data set representing unharmonized flock positions
	data := []int{42, 12, 89, 3, 55, 23, 77, 1, 34, 60}
	starlings := make([]Starling, len(data))
	for i, v := range data {
		starlings[i] = Starling{value: v, index: i}
	}

	fmt.Println("Initializing Starling Swarm Sort...")
	time.Sleep(500 * time.Millisecond)

	sorted := false
	step := 0

	for !sorted {
		sorted = true
		step++

		// Clear screen and display current generation
		fmt.Printf("\033[H\033[2J")
		fmt.Printf("--- Swarm Generation %d ---\n", step)

		// Evaluate aerodynamic friction (inversion check)
		for i := 0; i < len(starlings); i++ {
			if i < len(starlings)-1 && starlings[i].value > starlings[i+1].value {
				starlings[i].isGlitch = true
				starlings[i+1].isGlitch = true
				sorted = false
			} else {
				starlings[i].isGlitch = false
			}
		}

		// Render the flock; misaligned starlings manifest as chaotic predators/glitches
		for _, s := range starlings {
			if s.isGlitch {
				fmt.Printf("[X:%2d (PREDATOR)] ", s.value)
			} else {
				fmt.Printf(".·:*¨¨*:·.(%2d) ", s.value)
			}
		}
		fmt.Println("\n")

		// Apply flock alignment rules (bubble sort step) to resolve turbulence
		for i := 0; i < len(starlings)-1; i++ {
			if starlings[i].value > starlings[i+1].value {
				starlings[i], starlings[i+1] = starlings[i+1], starlings[i]
			}
		}

		time.Sleep(350 * time.Millisecond)

		if step > 50 {
			break
		}
	}

	fmt.Println("Aerodynamic and numerical harmony achieved!")
	fmt.Println("Final Sorted Swarm:")
	for _, s := range starlings {
		fmt.Printf("%d ", s.value)
	}
	fmt.Println()
}