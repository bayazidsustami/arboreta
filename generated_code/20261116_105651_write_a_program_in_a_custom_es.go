// Package main implements a creative interpreter for "Boreas", an esoteric 
// weather-driven typographic poetry language where verses decay as midnight nears.
package main

import (
	"fmt"
	"math/rand"
	"time"
)

// Boreas VM holds the state of the evolving typographic poem.
type VM struct {
	poem []string
}

func main() {
	// Seed source for atmospheric fluctuations
	rand.Seed(time.Now().UnixNano())

	fmt.Println("Initializing Boreas Esoteric Engine: Weather-to-Poetry Decay...")

	vm := &VM{
		poem: []string{
			"The frost whispers secrets to the glass,",
			"Barometer falling like an old man's sigh,",
			"Cumulus drift in silver-gray mass,",
			"While midnight pulls the velvet curtain high.",
		},
	}

	vm.run()
}

// run executes the esoteric instruction loop, translating weather shifts into text and decay.
func (vm *VM) run() {
	ticker := time.NewTicker(600 * time.Millisecond)
	defer ticker.Stop()

	steps := 0
	for range ticker.C {
		steps++

		// Simulate local weather fluctuation (temperature and barometric pressure)
		temp := 12.5 + rand.Float64()*8.0 - 4.0
		pressure := 1010.0 + rand.Float64()*15.0 - 7.5

		fmt.Printf("\n[🌡️ %.1f°C | 🌀 %.1fhPa] ─── Epoch %d\n", temp, pressure, steps)

		// Render current poem typography
		for _, line := range vm.poem {
			fmt.Println("    ✦", line)
		}

		// As midnight approaches, entropy increases and lines dissolve from the top
		if steps%2 == 0 && len(vm.poem) > 0 {
			fmt.Println("    [⌛ The clock ticks closer to midnight... line dissolves]")
			vm.poem = vm.poem[1:]
		}

		// Termination when the poem has completely consumed itself
		if len(vm.poem) == 0 {
			fmt.Println("\nMidnight reached. Complete silence claims the parchment.")
			break
		}

		if steps >= 8 {
			break
		}
	}
}