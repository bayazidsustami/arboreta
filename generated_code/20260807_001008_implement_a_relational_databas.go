package main

import (
	"fmt"
	"math"
	"math/rand"
	"strings"
	"time"
)

// Record represents a database tuple.
type Record struct {
	ID    int
	Value string
}

// Table represents a relational database table.
type Table struct {
	Name    string
	Records []Record
}

// FluidParticle represents a potential join pair floating in a fluid field.
type FluidParticle struct {
	X, Y       float64
	VX, VY     float64
	Temp       float64
	RowA       Record
	RowB       Record
	MatchScore float64
	Frozen     bool
}

// Engine encapsulates the fluid-dynamics relational query optimizer.
type Engine struct {
	Width, Height int
	Particles     []*FluidParticle
	CoolingRate   float64
}

// NewEngine initializes the fluid simulation space with candidate join pairs.
func NewEngine(t1, t2 Table) *Engine {
	rand.Seed(time.Now().UnixNano())
	w, h := 60, 20
	var particles []*FluidParticle

	// Populate particles from Cartesian product (the initial fluid matrix)
	for _, r1 := range t1.Records {
		for _, r2 := range t2.Records {
			score := 0.0
			if r1.ID == r2.ID {
				score = 1.0 // High affinity for matching keys
			} else {
				score = 1.0 / (1.0 + math.Abs(float64(r1.ID-r2.ID)))
			}

			// Random initial positions and velocities in the fluid chamber
			p := &FluidParticle{
				X:          rand.Float64() * float64(w),
				Y:          rand.Float64() * float64(h),
				VX:         (rand.Float64() - 0.5) * 2.0,
				VY:         (rand.Float64() - 0.5) * 2.0,
				Temp:       100.0 * score, // Matches start at high thermal energy
				RowA:       r1,
				RowB:       r2,
				MatchScore: score,
			}
			particles = append(particles, p)
		}
	}

	return &Engine{
		Width:       w,
		Height:      h,
		Particles:   particles,
		CoolingRate: 0.90,
	}
}

// Step simulates Navier-Stokes style vorticity, thermal dissipation, and fractal attraction.
func (e *Engine) Step() {
	cx, cy := float64(e.Width)/2.0, float64(e.Height)/2.0

	for _, p := range e.Particles {
		if p.Frozen {
			continue
		}

		// Fluid forces: rotational vortex and attraction to equilibrium centers
		dx, dy := p.X-cx, p.Y-cy
		dist := math.Hypot(dx, dy) + 0.001

		vorticity := 0.6 * p.MatchScore
		p.VX += (-dy/dist)*vorticity + (rand.Float64()-0.5)*0.2
		p.VY += (dx/dist)*vorticity + (rand.Float64()-0.5)*0.2

		// Position updates
		p.X += p.VX
		p.Y += p.VY

		// Fluid boundary reflection
		if p.X < 0 || p.X >= float64(e.Width) {
			p.VX *= -0.8
			p.X = math.Max(0, math.Min(float64(e.Width-1), p.X))
		}
		if p.Y < 0 || p.Y >= float64(e.Height) {
			p.VY *= -0.8
			p.Y = math.Max(0, math.Min(float64(e.Height-1), p.Y))
		}

		// Thermal dissipation
		p.Temp *= e.CoolingRate
		p.VX *= e.CoolingRate
		p.VY *= e.CoolingRate

		// Crystallization phase transition: tuples snap into Julia fractal lattice coordinates
		if p.Temp < 1.5 && p.MatchScore == 1.0 {
			p.Frozen = true
			zx := (p.X/float64(e.Width))*3.0 - 1.5
			zy := (p.Y/float64(e.Height))*3.0 - 1.5
			for i := 0; i < 8; i++ {
				zx, zy = zx*zx-zy*zy+-0.7, 2*zx*zy+0.27015
			}
			p.X = math.Mod(math.Abs(zx*15), float64(e.Width))
			p.Y = math.Mod(math.Abs(zy*8), float64(e.Height))
		}
	}
}

// RenderFractal draws the crystallized query optimization state as an ASCII landscape.
func (e *Engine) RenderFractal() {
	grid := make([][]rune, e.Height)
	for i := range grid {
		grid[i] = make([]rune, e.Width)
		for j := range grid[i] {
			grid[i][j] = ' '
		}
	}

	for _, p := range e.Particles {
		x := int(p.X)
		y := int(p.Y)
		if x >= 0 && x < e.Width && y >= 0 && y < e.Height {
			if p.Frozen {
				grid[y][x] = '#' // Crystallized optimal join node
			} else if p.MatchScore > 0.5 {
				grid[y][x] = '*' // Semi-fluid warm match
			} else {
				grid[y][x] = '.' // Dissipated background noise
			}
		}
	}

	fmt.Println("\n=== PHYSICAL QUERY OPTIMIZATION LANDSCAPE (THERMAL EQUILIBRIUM) ===")
	for _, row := range grid {
		fmt.Println(string(row))
	}
	fmt.Println(strings.Repeat("=", e.Width))
}

// ExecuteJoin reads out the materialized joined tuples from the frozen lattice.
func (e *Engine) ExecuteJoin() {
	fmt.Println("\n=== MATERIALIZED RELATIONAL JOIN RESULTS ===")
	fmt.Printf("%-10s | %-12s | %-10s | %-12s | %-12s\n", "User_ID", "User_Name", "Order_ID", "Product", "State")
	fmt.Println(strings.Repeat("-", 65))

	joinedCount := 0
	for _, p := range e.Particles {
		if p.Frozen && p.MatchScore == 1.0 {
			fmt.Printf("%-10d | %-12s | %-10d | %-12s | %-12s\n",
				p.RowA.ID, p.RowA.Value, p.RowB.ID, p.RowB.Value, "CRYSTALLIZED")
			joinedCount++
		}
	}
	fmt.Printf("\nQuery finalized: %d tuples joined via fluid phase transition.\n", joinedCount)
}

func main() {
	users := Table{
		Name: "Users",
		Records: []Record{
			{ID: 101, Value: "Alice"},
			{ID: 102, Value: "Bob"},
			{ID: 103, Value: "Charlie"},
			{ID: 104, Value: "Diana"},
		},
	}

	orders := Table{
		Name: "Orders",
		Records: []Record{
			{ID: 101, Value: "Quantum CPU"},
			{ID: 102, Value: "Neural Deck"},
			{ID: 104, Value: "OLED Lens"},
			{ID: 105, Value: "Holocube"},
		},
	}

	fmt.Println("Injecting relation tuples into fluid dynamic chamber...")
	engine := NewEngine(users, orders)

	fmt.Println("Simulating vorticity, pressure, and thermal cooling...")
	for step := 0; step < 60; step++ {
		engine.Step()
	}

	// Render final crystallized fractal landscape
	engine.RenderFractal()

	// Output query result set
	engine.ExecuteJoin()
}