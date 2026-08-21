package main

import (
	"fmt"
	"math"
	"math/rand"
	"os"
	"os/exec"
	"runtime"
	"time"
)

const (
	width  = 80
	height = 24
)

// Clock digits layout template (5x3 per digit)
var digitFont = map[rune][]string{
	'0': {"███", "█ █", "█ █", "█ █", "███"},
	'1': {"  █", "  █", "  █", "  █", "  █"},
	'2': {"███", "  █", "███", "█  ", "███"},
	'3': {"███", "  █", "███", "  █", "███"},
	'4': {"█ █", "█ █", "███", "  █", "  █"},
	'5': {"███", "█  ", "███", "  █", "███"},
	'6': {"███", "█  ", "███", "█ █", "███"},
	'7': {"███", "  █", "  █", "  █", "  █"},
	'8': {"███", "█ █", "███", "█ █", "███"},
	'9': {"███", "█ █", "███", "  █", "███"},
	':': {"   ", " █ ", "   ", " █ ", "   "},
}

// Density ramp for rendering fluid intensity
var densityRamp = []rune{' ', '.', ':', '-', '=', '+', '*', '%', '@', '#'}

func clearTerminal() {
	var cmd *exec.Cmd
	if runtime.GOOS == "windows" {
		cmd = exec.Command("cmd", "/c", "cls")
	} else {
		cmd = exec.Command("clear")
	}
	cmd.Stdout = os.Stdout
	cmd.Run()
}

func main() {
	// Screen buffers: density holds fluid mass, velocity fields drive movement
	density := make([][]float64, height)
	vx := make([][]float64, height)
	vy := make([][]float64, height)
	for y := 0; y < height; y++ {
		density[y] = make([]float64, width)
		vx[y] = make([]float64, width)
		vy[y] = make([]float64, width)
	}

	// Interface integrity map: 1.0 = pristine UI, 0.0 = completely eroded into fluid
	uiMask := make([][]float64, height)
	for y := 0; y < height; y++ {
		uiMask[y] = make([]float64, width)
	}

	// Hide cursor on exit
	fmt.Print("\033[?25l")
	defer fmt.Print("\033[?25h")

	ticker := time.NewTicker(40 * time.Millisecond) // ~25 FPS
	defer ticker.Stop()

	lastTime := time.Now()

	for range ticker.C {
		// Measure system micro-latency (jitter relative to expected tick rate)
		now := time.Now()
		elapsed := now.Sub(lastTime)
		lastTime = now

		expected := 40 * time.Millisecond
		latencyJitter := float64(elapsed-expected) / float64(time.Millisecond)
		if latencyJitter < 0 {
			latencyJitter = -latencyJitter
		}

		// Convert time string into current UI target mask
		timeStr := now.Format("15:04:05")
		targetUI := make([][]bool, height)
		for y := 0; y < height; y++ {
			targetUI[y] = make([]bool, width)
		}

		// Draw clock into target UI buffer centered on screen
		startX := (width - (len(timeStr) * 4)) / 2
		startY := (height - 5) / 2
		for i, char := range timeStr {
			glyph := digitFont[char]
			for gy, row := range glyph {
				for gx, val := range row {
					if val != ' ' {
						px := startX + i*4 + gx
						py := startY + gy
						if px >= 0 && px < width && py >= 0 && py < height {
							targetUI[py][px] = true
						}
					}
				}
			}
		}

		// Update UI mask and inject micro-latency forces:
		// High latency erodes interface pixels, turning them into fluid density & kinetic velocity
		erosionRate := 0.02 + (latencyJitter * 0.05)
		for y := 0; y < height; y++ {
			for x := 0; x < width; x++ {
				if targetUI[y][x] {
					// Regenerate interface slowly if untouched, but latency erodes it
					if uiMask[y][x] < 1.0 {
						uiMask[y][x] += 0.01
					}
				} else {
					uiMask[y][x] *= 0.9 // Fast fade out non-clock regions
				}

				// High micro-latency triggers interface dissolution
				if targetUI[y][x] && latencyJitter > 0.1 && rand.Float64() < erosionRate {
					uiMask[y][x] -= 0.3
					if uiMask[y][x] < 0 {
						uiMask[y][x] = 0
					}

					// Erode UI into fluid density + micro-velocity injection
					density[y][x] += 2.0
					angle := rand.Float64() * 2 * math.Pi
					force := 0.5 + latencyJitter*2.0
					vx[y][x] += math.Cos(angle) * force
					vy[y][x] += math.Sin(angle)*force + 0.2 // slight downward gravity bias
				}
			}
		}

		// Fluid Dynamics: Advection, Diffuse, and Gravity
		newDensity := make([][]float64, height)
		for y := 0; y < height; y++ {
			newDensity[y] = make([]float64, width)
		}

		for y := 1; y < height-1; y++ {
			for x := 1; x < width-1; x++ {
				// Apply buoyancy and downward gravity to fluid
				vy[y][x] += 0.05 * density[y][x]

				// Semi-Lagrangian Advection for fluid particles
				srcX := float64(x) - vx[y][x]
				srcY := float64(y) - vy[y][x]

				if srcX < 0 {
					srcX = 0
				}
				if srcX >= width-1 {
					srcX = width - 2
				}
				if srcY < 0 {
					srcY = 0
				}
				if srcY >= height-1 {
					srcY = height - 2
				}

				x0, y0 := int(srcX), int(srcY)
				sx, sy := srcX-float64(x0), srcY-float64(y0)

				// Bilinear interpolation
				d := (1-sx)*(1-sy)*density[y0][x0] +
					sx*(1-sy)*density[y0][x0+1] +
					(1-sx)*sy*density[y0+1][x0] +
					sx*sy*density[y0+1][x0+1]

				newDensity[y][x] = d * 0.98 // Dissipation factor
			}
		}
		density = newDensity

		// Render combining Fluid Density + Dissolving Clock UI Mask
		out := make([]byte, 0, width*height+height)
		out = append(out, "\033[H"...) // Reset cursor position

		for y := 0; y < height; y++ {
			for x := 0; x < width; x++ {
				dVal := density[y][x]
				uVal := uiMask[y][x]

				// If UI mask is strong, render crisp text; as it erodes, reveal fluid underneath
				if uVal > 0.5 {
					out = append(out, '█')
				} else if uVal > 0.1 {
					out = append(out, '▒')
				} else {
					idx := int(dVal * float64(len(densityRamp)-1))
					if idx < 0 {
						idx = 0
					}
					if idx >= len(densityRamp) {
						idx = len(densityRamp) - 1
					}
					out = append(out, byte(densityRamp[idx]))
				}
			}
			out = append(out, '\n')
		}

		// Output frame
		os.Stdout.Write(out)
	}
}