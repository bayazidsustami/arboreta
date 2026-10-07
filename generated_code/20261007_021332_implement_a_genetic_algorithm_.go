package main

import (
	"fmt"
	"math/rand"
	"strings"
	"time"
)

// CoffeeFlavor represents an instruction in our esoteric coffee-bytecode language.
type CoffeeFlavor string

const (
	Espresso  CoffeeFlavor = "Espresso"  // Adds a radiant stellar spark (*)
	Latte     CoffeeFlavor = "Latte"     // Adds a soothing cosmic wave (~)
	Mocha     CoffeeFlavor = "Mocha"     // Adds a deep interstellar void (.)
	Macchiato CoffeeFlavor = "Macchiato" // Adds a pulsing energy node (+)
	ColdBrew  CoffeeFlavor = "ColdBrew"  // Shifts canvas coordinates
)

var availableFlavors = []CoffeeFlavor{Espresso, Latte, Mocha, Macchiato, ColdBrew}

// SatelliteTelemetry simulates real-time orbital data affecting our aesthetic target.
type SatelliteTelemetry struct {
	SolarActivity float64 // 0.0 to 1.0 energy index
	OrbitalSpeed  float64 // km/s
}

// Program represents an individual genome made of coffee instructions.
type Program struct {
	Instructions []CoffeeFlavor
	Fitness      float64
	VisualPoem   string
}

// Execute runs the coffee bytecode to brew a visual poem on a text grid.
func (p *Program) Execute(width, height int) {
	var sb strings.Builder
	grid := make([][]string, height)
	for i := range grid {
		grid[i] = make([]string, width)
		for j := range grid[i] {
			grid[i][j] = "."
		}
	}

	x, y := 0, 0
	for _, inst := range p.Instructions {
		switch inst {
		case Espresso:
			grid[y][x] = "*"
		case Latte:
			grid[y][x] = "~"
		case Mocha:
			grid[y][x] = "."
		case Macchiato:
			grid[y][x] = "+"
		case ColdBrew:
			x = (x + 2) % width
		}
		x = (x + 1) % width
		if x == 0 {
			y = (y + 1) % height
		}
	}

	for _, row := range grid {
		sb.WriteString(strings.Join(row, "") + "\n")
	}
	p.VisualPoem = sb.String()
}

// Evaluate calculates fitness based on how well the poem reflects satellite telemetry.
func (p *Program) Evaluate(tel SatelliteTelemetry) {
	targetEnergy := tel.SolarActivity
	energyCount := 0.0
	total := float64(len(p.Instructions))
	if total == 0 {
		p.Fitness = 0
		return
	}

	for _, inst := range p.Instructions {
		if inst == Espresso || inst == Macchiato {
			energyCount++
		}
	}

	actualEnergy := energyCount / total
	diff := actualEnergy - targetEnergy
	if diff < 0 {
		diff = -diff
	}
	// Fitness rewards matching the desired energetic mood of the telemetry
	p.Fitness = 1.0 / (1.0 + diff)
}

func main() {
	rand.Seed(time.Now().UnixNano())

	// Simulate local satellite telemetry stream
	telemetry := SatelliteTelemetry{
		SolarActivity: 0.58, // Moderate solar storm mood
		OrbitalSpeed:  7.78, // Low-Earth Orbit velocity (km/s)
	}

	fmt.Println("--- SATELLITE TELEMETRY INITIALIZED ---")
	fmt.Printf("Solar Activity Index: %.2f | Orbital Speed: %.2f km/s\n\n", telemetry.SolarActivity, telemetry.OrbitalSpeed)

	// Genetic Algorithm Parameters
	popSize := 60
	genomeLen := 140
	generations := 40
	width, height := 24, 6

	// Initialize population with random coffee recipes
	population := make([]Program, popSize)
	for i := range population {
		insts := make([]CoffeeFlavor, genomeLen)
		for j := range insts {
			insts[j] = availableFlavors[rand.Intn(len(availableFlavors))]
		}
		population[i] = Program{Instructions: insts}
	}

	// Evolution loop
	for gen := 0; gen < generations; gen++ {
		for i := range population {
			population[i].Execute(width, height)
			population[i].Evaluate(telemetry)
		}

		// Sort population by fitness descending (simple bubble sort for clarity)
		for i := 0; i < len(population); i++ {
			for j := i + 1; j < len(population); j++ {
				if population[j].Fitness > population[i].Fitness {
					population[i], population[j] = population[j], population[i]
				}
			}
		}

		// Elite preservation & reproduction
		newPop := make([]Program, popSize)
		copy(newPop[:6], population[:6]) // Top 6 elites

		for i := 6; i < popSize; i++ {
			parent1 := population[rand.Intn(12)]
			parent2 := population[rand.Intn(12)]
			childInsts := make([]CoffeeFlavor, genomeLen)

			// Crossover
			split := rand.Intn(genomeLen)
			copy(childInsts[:split], parent1.Instructions[:split])
			copy(childInsts[split:], parent2.Instructions[split:])

			// Mutation (rate: 6%)
			for j := range childInsts {
				if rand.Float64() < 0.06 {
					childInsts[j] = availableFlavors[rand.Intn(len(availableFlavors))]
				}
			}
			newPop[i] = Program{Instructions: childInsts}
		}
		population = newPop
	}

	// Final execution of the fittest coffee program
	population[0].Execute(width, height)
	fmt.Printf("--- BREWED VISUAL POEM (Fitness: %.4f) ---\n", population[0].Fitness)
	fmt.Println(population[0].VisualPoem)
}