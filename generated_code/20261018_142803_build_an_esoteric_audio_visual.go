package main

import (
	"fmt"
	"math"
	"runtime"
	"time"
)

// Esoteric A/V Synthesizer: Converts memory standard deviation anomalies into blooming neon mandalas.
func main() {
	windowSize := 20
	samples := make([]float64, windowSize)
	idx := 0

	// Hide terminal cursor for smooth rendering
	fmt.Print("\033[?25l")
	defer fmt.Print("\033[?25h")

	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()

	var m runtime.MemStats

	for range ticker.C {
		runtime.ReadMemStats(&m)
		alloc := float64(m.Alloc)

		samples[idx%windowSize] = alloc
		idx++

		// Calculate sliding window mean and standard deviation
		n := math.Min(float64(idx), float64(windowSize))
		sum := 0.0
		for i := 0; i < int(n); i++ {
			sum += samples[i]
		}
		mean := sum / n

		var variance float64
		for i := 0; i < int(n); i++ {
			diff := samples[i] - mean
			variance += diff * diff
		}
		stdDev := math.Sqrt(variance / n)

		// Synthesize visual frame
		renderMandala(stdDev, mean)
	}
}

// renderMandala draws an ASCII neon mandala modulated by system memory anomalies.
func renderMandala(stdDev, mean float64) {
	fmt.Print("\033[H") // Reset cursor to top-left
	width, height := 60, 24
	centerX, centerY := float64(width)/2.0, float64(height)/2.0

	// Neon ANSI color palette
	colors := []string{
		"\033[38;5;198m", // Neon Pink
		"\033[38;5;51m",  // Neon Cyan
		"\033[38;5;154m", // Neon Lime
		"\033[38;5;201m", // Bright Magenta
		"\033[38;5;214m", // Neon Orange
	}
	reset := "\033[0m"

	// Anomaly scale factors
	anomalyFactor := math.Min(4.0, stdDev/512.0+1.0)
	petalCount := 5 + int(math.Mod(mean/1024/1024, 5))

	fmt.Printf(" [NEON FLORA SYNTHESIZER] Alloc: %.2f MB | StdDev Anomaly: %.2f KB \n", mean/1024/1024, stdDev/1024)

	for y := 0; y < height; y++ {
		line := ""
		for x := 0; x < width; x++ {
			dx := float64(x) - centerX
			dy := (float64(y) - centerY) * 2.2 // Aspect ratio correction
			dist := math.Sqrt(dx*dx + dy*dy)
			angle := math.Atan2(dy, dx)

			// Mandala flower geometry modulated by memory variance
			val := math.Sin(angle*float64(petalCount)) * math.Cos(dist/2.5*anomalyFactor)
			
			// Weeping tendril distortion effect
			weep := math.Sin(dist*0.15-float64(time.Now().UnixNano())/2e8) * (stdDev / 8000.0)

			char := " "
			color := colors[0]

			if math.Abs(val+weep) < 0.22 && dist < 20 {
				char = "❀"
				color = colors[int(math.Abs(dx+dy))%len(colors)]
			} else if math.Abs(val) < 0.38 && dist < 24 {
				char = "·"
				color = colors[(int(dist)+int(time.Now().UnixMilli()/150))%len(colors)]
			} else if dist < 2.5 {
				char = "◉"
				color = colors[4]
			}

			if char != " " {
				line += color + char + reset
			} else {
				line += " "
			}
		}
		fmt.Println(line)
	}
}