package main

import (
	"fmt"
	"math"
	"math/rand"
	"runtime"
	"sync"
	"time"

	"[github.com/tfriedel6/canvas/sdlcanvas](https://github.com/tfriedel6/canvas/sdlcanvas)"
)

// Entity represents a parasitic organism born from a system thread.
type Entity struct {
	x, y          float64
	vx, vy        float64
	energy        float64
	size          float64
	hue           float64
	threadID      int
	history       [][2]float64
	mutationRate  float64
}

// ThermalEcosystem manages the digital ecosystem driven by system dynamics.
type ThermalEcosystem struct {
	width, height float64
	entities      []*Entity
	cpuTemp       float64
	audioFreq     float64
	entropyPool   float64
	mu            sync.RWMutex
}

func NewThermalEcosystem(w, h float64) *ThermalEcosystem {
	eco := &ThermalEcosystem{
		width:       w,
		height:      h,
		entropyPool: 100.0,
	}

	// Spawn initial thread-based parasitic organisms
	numThreads := runtime.NumCPU() * 2
	for i := 0; i < numThreads; i++ {
		eco.entities = append(eco.entities, &Entity{
			x:            rand.Float64() * w,
			y:            rand.Float64() * h,
			vx:           (rand.Float64() - 0.5) * 2,
			vy:           (rand.Float64() - 0.5) * 2,
			energy:       50 + rand.Float64()*50,
			size:         3 + rand.Float64()*4,
			hue:          float64(i*360 / numThreads),
			threadID:     i,
			history:      make([][2]float64, 0),
			mutationRate: 0.05 + rand.Float64()*0.1,
		})
	}
	return eco
}

// Read thermal fluctuations (simulated dynamic system thermal load)
func (e *ThermalEcosystem) pollThermalSensors() {
	ticker := time.NewTicker(100 * time.Millisecond)
	for range ticker.C {
		e.mu.Lock()
		// Simulate dynamic CPU thermal curves and thread workload stress
		var totalMem runtime.MemStats
		runtime.ReadMemStats(&totalMem)
		
		// Temperature oscillates between 40C and 85C based on system state
		baseTemp := 45.0 + math.Sin(float64(time.Now().UnixNano())/1e9)*15.0
		workload := float64(totalMem.Alloc%1000) / 1000.0 * 25.0
		e.cpuTemp = baseTemp + workload

		// Synthesize audio reactivity frequency (simulated audio FFT resonance peak)
		e.audioFreq = 200.0 + math.Cos(float64(time.Now().UnixNano())/5e8)*800.0 + (e.cpuTemp * 5.0)

		// Replenish system entropy from thermal heat
		e.entropyPool += (e.cpuTemp - 35.0) * 0.1
		if e.entropyPool > 500 {
			e.entropyPool = 500
		}
		e.mu.Unlock()
	}
}

// Update organism physics, feeding logic, and reproduction
func (e *ThermalEcosystem) Update() {
	e.mu.Lock()
	defer e.mu.Unlock()

	tempFactor := e.cpuTemp / 50.0
	audioImpact := math.Sin(e.audioFreq/100.0) * 2.0

	var nextGeneration []*Entity

	for _, organism := range e.entities {
		// Feed on system entropy pool
		feedAmount := math.Min(e.entropyPool, 0.5*tempFactor)
		organism.energy += feedAmount
		e.entropyPool -= feedAmount

		// Parasitic decay based on thermal load
		organism.energy -= 0.2 * (1.0 + tempFactor*0.5)

		// Audio-reactive jitter and velocity updates
		organism.vx += (rand.Float64() - 0.5) * (audioImpact + 0.5)
		organism.vy += (rand.Float64() - 0.5) * (audioImpact + 0.5)

		// Max speed limit based on temperature
		maxSpeed := 2.0 * tempFactor
		speed := math.Hypot(organism.vx, organism.vy)
		if speed > maxSpeed {
			organism.vx = (organism.vx / speed) * maxSpeed
			organism.vy = (organism.vy / speed) * maxSpeed
		}

		organism.x += organism.vx
		organism.y += organism.vy

		// Boundary wrapping
		if organism.x < 0 { organism.x = e.width }
		if organism.x > e.width { organism.x = 0 }
		if organism.y < 0 { organism.y = e.height }
		if organism.y > e.height { organism.y = 0 }

		// Track historical trail
		organism.history = append(organism.history, [2]float64{organism.x, organism.y})
		if len(organism.history) > 15 {
			organism.history = organism.history[1:]
		}

		// Organism reproduction if sufficient entropy energy absorbed
		if organism.energy > 120 {
			organism.energy /= 2
			child := &Entity{
				x:            organism.x + (rand.Float64()-0.5)*10,
				y:            organism.y + (rand.Float64()-0.5)*10,
				vx:           -organism.vx,
				vy:           -organism.vy,
				energy:       organism.energy,
				size:         math.Max(2, organism.size+(rand.Float64()-0.5)),
				hue:          math.Mod(organism.hue+organism.mutationRate*360, 360),
				threadID:     organism.threadID,
				history:      make([][2]float64, 0),
				mutationRate: organism.mutationRate,
			}
			nextGeneration = append(nextGeneration, child)
		}

		// Keep alive if energy > 0
		if organism.energy > 0 {
			nextGeneration = append(nextGeneration, organism)
		}
	}

	e.entities = nextGeneration
}

func main() {
	const width, height = 1024, 768

	// Initialize window and hardware-accelerated canvas
	wnd, cv, err := sdlcanvas.CreateWindow(width, height, "Generative Thermal Organism Ecosystem")
	if err != nil {
		fmt.Printf("Failed to create canvas window: %v\n", err)
		return
	}
	defer wnd.Destroy()

	ecosystem := NewThermalEcosystem(float64(width), float64(height))
	go ecosystem.pollThermalSensors()

	wnd.MainLoop(func() {
		ecosystem.Update()

		ecosystem.mu.RLock()
		temp := ecosystem.cpuTemp
		entropy := ecosystem.entropyPool
		entities := make([]*Entity, len(ecosystem.entities))
		copy(entities, ecosystem.entities)
		ecosystem.mu.RUnlock()

		// Semi-transparent background for motion trails
		cv.SetFillStyle("#0a0a12025")
		cv.FillRect(0, 0, float64(width), float64(height))

		// Render parasitic organisms and tendrils
		for _, org := range entities {
			// Render trail
			if len(org.history) > 1 {
				cv.SetLineWidth(1.0)
				for i := 0; i < len(org.history)-1; i++ {
					alpha := float64(i) / float64(len(org.history))
					cv.SetStrokeStyle(fmt.Sprintf("hsla(%.0f, 80%%, 50%%, %.2f)", org.hue, alpha))
					cv.BeginPath()
					cv.MoveTo(org.history[i][0], org.history[i][1])
					cv.LineTo(org.history[i+1][0], org.history[i+1][1])
					cv.Stroke()
				}
			}

			// Render organism nucleus
			cv.SetFillStyle(fmt.Sprintf("hsl(%.0f, 100%%, 60%%)", org.hue))
			cv.BeginPath()
			cv.Arc(org.x, org.y, org.size*(1.0+org.energy/100.0), 0, math.Pi*2, false)
			cv.Fill()
		}

		// Render system status HUD overlay
		cv.SetFillStyle("#ffffff")
		cv.SetFont("sans-serif", 14)
		cv.FillText(fmt.Sprintf("CPU Thermal Load: %.1f°C", temp), 20, 30)
		cv.FillText(fmt.Sprintf("System Entropy Pool: %.1f J", entropy), 20, 50)
		cv.FillText(fmt.Sprintf("Active Thread Parasites: %d", len(entities)), 20, 70)
	})
}