package main

import (
	"fmt"
	"math"
	"math/rand"
	"strings"
	"sync"
	"time"
)

const (
	mapWidth   = 40
	mapHeight  = 20
	ringBuffer = 100
)

// Weather state determined by typing rhythm variance
type Weather int

const (
	Clear Weather = iota
	LightBreeze
	Rainstorm
	Blizzard
)

func (w Weather) String() string {
	switch w {
	case Clear:
		return "Clear Skies (Steady Rhythm)"
	case LightBreeze:
		return "Gentle Wind (Mild Variation)"
	case Rainstorm:
		return "Thunderstorm (Erratic Staccato)"
	case Blizzard:
		return "Blizzard (Chaotic Bursts)"
	default:
		return "Unknown"
	}
}

// Biome defined by base topology and weather
type Biome struct {
	Name    string
	Weather Weather
	Symbols []rune
}

// KeyEvent simulates an audio/keystroke stream packet
type KeyEvent struct {
	Timestamp time.Time
	Key       rune
}

// Engine processes stream data into topographic representations
type Engine struct {
	mu           sync.Mutex
	events       []KeyEvent
	speed        float64 // Keystrokes per second (KPS)
	rhythmVar    float64 // Variance in inter-keystroke timing
	heightMap    [][]float64
	currentBiome Biome
}

func NewEngine() *Engine {
	hMap := make([][]float64, mapHeight)
	for i := range hMap {
		hMap[i] = make([]float64, mapWidth)
	}
	return &Engine{
		events:    make([]KeyEvent, 0, ringBuffer),
		heightMap: hMap,
		currentBiome: Biome{
			Name:    "Temperate Lowlands",
			Weather: Clear,
			Symbols: []rune{' ', '░', '▒', '▓', '█'},
		},
	}
}

// PushEvent adds a new keystroke event from the real-time audio/input stream
func (e *Engine) PushEvent(k rune) {
	e.mu.Lock()
	defer e.mu.Unlock()

	now := time.Now()
	e.events = append(e.events, KeyEvent{Timestamp: now, Key: k})
	if len(e.events) > ringBuffer {
		e.events = e.events[1:]
	}

	e.calculateMetrics()
	e.updateTopography()
}

// Calculate typing speed (elevation driver) and rhythm variance (weather driver)
func (e *Engine) calculateMetrics() {
	if len(e.events) < 2 {
		return
	}

	// 1. Calculate Typing Speed (KPS) based on recent window
	window := 3.0 // seconds
	now := time.Now()
	recentCount := 0
	var intervals []float64

	for i := len(e.events) - 1; i >= 0; i-- {
		dt := now.Sub(e.events[i].Timestamp).Seconds()
		if dt > window {
			break
		}
		recentCount++

		if i > 0 {
			prevDt := e.events[i].Timestamp.Sub(e.events[i-1].Timestamp).Seconds()
			intervals = append(intervals, prevDt)
		}
	}

	e.speed = float64(recentCount) / window

	// 2. Calculate Rhythm Variance (Standard Deviation of Inter-keystroke Intervals)
	if len(intervals) < 2 {
		e.rhythmVar = 0
		return
	}

	var sum float64
	for _, v := range intervals {
		sum += v
	}
	mean := sum / float64(len(intervals))

	var varianceSum float64
	for _, v := range intervals {
		varianceSum += (v - mean) * (v - mean)
	}
	e.rhythmVar = math.Sqrt(varianceSum / float64(len(intervals)))

	// Update Weather Pattern based on Rhythm Variance
	switch {
	case e.rhythmVar < 0.1:
		e.currentBiome.Weather = Clear
	case e.rhythmVar < 0.25:
		e.currentBiome.Weather = LightBreeze
	case e.rhythmVar < 0.45:
		e.currentBiome.Weather = Rainstorm
	default:
		e.currentBiome.Weather = Blizzard
	}
}

// Generate a 3D procedural topological map modulated by speed and rhythm
func (e *Engine) updateTopography() {
	t := float64(time.Now().UnixNano()) / 1e9

	for y := 0; y < mapHeight; y++ {
		for x := 0; x < mapWidth; x++ {
			// Base Perlin-like mathematical terrain combining sine waves
			nx := float64(x) / float64(mapWidth)
			ny := float64(y) / float64(mapHeight)

			baseElevation := math.Sin(nx*math.Pi*2+t) * math.Cos(ny*math.Pi*2+t)

			// Modulation: Speed expands terrain peak height
			elevationFactor := 1.0 + (e.speed * 1.5)
			
			// Modulation: Rhythm variance distorts landscape frequency
			distortion := math.Sin((nx+ny)*10.0*e.rhythmVar + t*2.0)

			finalHeight := (baseElevation + distortion*0.3) * elevationFactor
			e.heightMap[y][x] = math.Max(0, math.Min(float64(len(e.currentBiome.Symbols)-1), finalHeight+2.0))
		}
	}
}

// Render the 3D topology and weather state to standard output
func (e *Engine) Render() {
	e.mu.Lock()
	defer e.mu.Unlock()

	var sb strings.Builder
	sb.WriteString("\033[H\033[2J") // Clear terminal screen
	sb.WriteString("=== REAL-TIME KEYSTROKE 3D TOPOLOGY MAP ===\n")
	sb.WriteString(fmt.Sprintf("Typing Speed (Elevation): %.2f KPS | Rhythm Variance (Weather): %.3f\n", e.speed, e.rhythmVar))
	sb.WriteString(fmt.Sprintf("Current Weather: %s\n", e.currentBiome.Weather.String()))
	sb.WriteString("┌" + strings.Repeat("─", mapWidth) + "┐\n")

	// Render Terrain Grid
	for y := 0; y < mapHeight; y++ {
		sb.WriteString("│")
		for x := 0; x < mapWidth; x++ {
			hIdx := int(e.heightMap[y][x])
			if hIdx >= len(e.currentBiome.Symbols) {
				hIdx = len(e.currentBiome.Symbols) - 1
			}

			// Render active weather overlay on top of terrain
			char := e.currentBiome.Symbols[hIdx]
			if rand.Float64() < e.weatherOverlayDensity() {
				char = e.getWeatherParticle()
			}

			sb.WriteRune(char)
		}
		sb.WriteString("│\n")
	}
	sb.WriteString("└" + strings.Repeat("─", mapWidth) + "┘\n")
	sb.WriteString("Simulating keystroke audio stream... Press Ctrl+C to exit.\n")

	fmt.Print(sb.String())
}

func (e *Engine) weatherOverlayDensity() float64 {
	switch e.currentBiome.Weather {
	case LightBreeze:
		return 0.03
	case Rainstorm:
		return 0.12
	case Blizzard:
		return 0.25
	default:
		return 0.0
	}
}

func (e *Engine) getWeatherParticle() rune {
	switch e.currentBiome.Weather {
	case LightBreeze:
		return '~'
	case Rainstorm:
		return '/'
	case Blizzard:
		return '*'
	default:
		return ' '
	}
}

// Simulate stream of live incoming audio-synthesized keystrokes
func simulateAudioKeystrokeStream(engine *Engine) {
	phrases := []string{
		"golang real time stream synthesis",
		"fast typing creates high mountain peaks",
		"uneven rhythm induces turbulent weather patterns",
		"topological mapping in terminal space",
	}

	for {
		for _, phrase := range phrases {
			for _, char := range phrase {
				engine.PushEvent(char)

				// Randomize delay to simulate typing rhythm variations
				delay := time.Duration(50+rand.Intn(300)) * time.Millisecond
				time.Sleep(delay)
			}
			// Pauses between phrases cause elevation decay
			time.Sleep(1 * time.Second)
		}
	}
}

func main() {
	rand.Seed(time.Now().UnixNano())
	engine := NewEngine()

	// Start receiving simulated audio stream events asynchronously
	go simulateAudioKeystrokeStream(engine)

	// Render loop running at ~30 FPS
	ticker := time.NewTicker(33 * time.Millisecond)
	for range ticker.C {
		engine.Render()
	}
}