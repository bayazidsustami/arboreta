package main

import (
	"fmt"
	"math"
	"sort"
)

// Body represents a celestial object in our sorting simulation.
type Body struct {
	x, y   float64
	vx, vy float64
	mass   float64
	val    float64
}

// GravitationalSort translates an array of floating-point numbers into orbiting bodies,
// simulates gravitational physics with damping until equilibrium, and extracts the sorted order.
func GravitationalSort(arr []float64) []float64 {
	n := len(arr)
	if n <= 1 {
		return arr
	}

	bodies := make([]*Body, n)
	for i, v := range arr {
		// Distribute bodies initially in a circular configuration,
		// with initial radius influenced by their numerical value.
		angle := float64(i) * 2.0 * math.Pi / float64(n)
		r := 10.0 + math.Abs(v)
		bodies[i] = &Body{
			x:    r * math.Cos(angle),
			y:    r * math.Sin(angle),
			vx:   -math.Sin(angle) * math.Sqrt(20.0/r),
			vy:   math.Cos(angle) * math.Sqrt(20.0/r),
			mass: 1.0 + math.Abs(v)*0.1,
			val:  v,
		}
	}

	// Run N-body physics simulation using Verlet integration with energy damping
	G := 1.0
	dt := 0.02
	damping := 0.998

	for step := 0; step < 1500; step++ {
		fx := make([]float64, n)
		fy := make([]float64, n)

		// Central gravitational attractor
		for i := 0; i < n; i++ {
			b := bodies[i]
			r2 := b.x*b.x + b.y*b.y + 0.1
			r := math.Sqrt(r2)
			f := (200.0 * b.mass) / (r2 * r)
			fx[i] += -f * b.x
			fy[i] += -f * b.y
		}

		// Inter-body gravitational forces
		for i := 0; i < n; i++ {
			for j := i + 1; j < n; j++ {
				dx := bodies[j].x - bodies[i].x
				dy := bodies[j].y - bodies[i].y
				r2 := dx*dx + dy*dy + 0.2
				r := math.Sqrt(r2)
				f := (G * bodies[i].mass * bodies[j].mass) / (r2 * r)

				fx[i] += f * dx
				fy[i] += f * dy
				fx[j] -= f * dx
				fy[j] -= f * dy
			}
		}

		// Update kinematics and apply frictional damping to settle into equilibrium
		maxV := 0.0
		for i := 0; i < n; i++ {
			b := bodies[i]
			b.vx = (b.vx + fx[i]/b.mass*dt) * damping
			b.vy = (b.vy + fy[i]/b.mass*dt) * damping
			b.x += b.vx * dt
			b.y += b.vy * dt

			vMag := math.Hypot(b.vx, b.vy)
			if vMag > maxV {
				maxV = vMag
			}
		}

		// Stop early once stable orbital equilibrium is reached
		if step > 400 && maxV < 0.0005 {
			break
		}
	}

	// Sort bodies by their final equilibrium orbital radius to retrieve sorted values
	sort.Slice(bodies, func(i, j int) bool {
		return math.Hypot(bodies[i].x, bodies[i].y) < math.Hypot(bodies[j].x, bodies[j].y)
	})

	sorted := make([]float64, n)
	for i, b := range bodies {
		sorted[i] = b.val
	}
	return sorted
}

func main() {
	input := []float64{42.5, -3.14, 15.9, 0.0, 7.8, -12.4}
	fmt.Printf("Unsorted planetary inputs: %v\n", input)
	sorted := GravitationalSort(input)
	fmt.Printf("Sorted equilibrium state:  %v\n", sorted)
}