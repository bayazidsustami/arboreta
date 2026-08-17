package main

import (
	"encoding/binary"
	"fmt"
	"math"
	"math/rand"
	"os"
	"os/exec"
	"os/signal"
	"sync"
	"time"
)

// Audio Engine Configuration
const (
	SampleRate = 44100
	BufSize    = 512
	NumChords  = 5
)

// CoffeeState models the physical and chemical dynamics of the coffee.
type CoffeeState struct {
	mu             sync.Mutex
	Temperature    float64 // Celsius (20.0 - 98.0)
	Viscosity      float64 // Centipoise-like scalar (1.0 = water, 10.0 = sludge)
	Volatiles      float64 // Aroma compounds (0.0 = stale, 1.0 = peak fresh)
	Acidity        float64 // Chemical decay / chlorogenic breakdown (0.0 - 1.0)
	SoluteDensity  float64 // Dissolved solids / milk density
	StirTurbulence float64 // Temporary mechanical energy
}

// Global state and DSP structures
var (
	coffee = CoffeeState{
		Temperature:    92.0,
		Viscosity:      1.2,
		Volatiles:      0.95,
		Acidity:        0.2,
		SoluteDensity:  1.1,
		StirTurbulence: 0.0,
	}

	// Ambient drone frequencies (Hz): Low C pentatonic / extended chord
	// C2 (65.41), G2 (98.00), Eb3 (155.56), Bb3 (233.08), D4 (293.66)
	baseFreqs = [NumChords]float64{65.41, 98.00, 155.56, 233.08, 293.66}
	phases    [NumChords]float64
	lfoPhase  float64

	// Delay line for ambient spatial diffusion
	delayBuffer [16384]float64
	delayIdx    int

	// Low pass filter state
	lpStateL float64
	lpStateR float64
)

func main() {
	// Enable raw terminal mode for real-time keypresses on Unix/Linux/macOS
	exec.Command("stty", "-F", "/dev/tty", "cbreak", "min", "1", "-echo").Run()
	defer exec.Command("stty", "-F", "/dev/tty", "echo").Run()

	// Handle graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt)
	go func() {
		<-sigChan
		// Reset terminal screen on exit
		fmt.Fprint(os.Stderr, "\033[?25h\033[0m\nSonification stopped.\n")
		os.Exit(0)
	}()

	// Launch async routines
	go physicsSimulation()
	go inputListener()
	go renderUI()

	// Hide cursor in terminal stderr UI
	fmt.Fprint(os.Stderr, "\033[?25l")

	// Main Real-Time Audio Generation Loop (outputs raw 16-bit PCM stereo to Stdout)
	outBuf := make([]byte, BufSize*4) // 2 channels * 2 bytes/sample
	for {
		coffee.mu.Lock()
		temp := coffee.Temperature
		visc := coffee.Viscosity
		volatiles := coffee.Volatiles
		acidity := coffee.Acidity
		turbulence := coffee.StirTurbulence
		coffee.mu.Unlock()

		// Calculate DSP parameters derived from coffee physics
		// Viscosity controls low-pass filter cutoff (thicker = darker) and LFO speed
		cutoff := math.Max(0.01, math.Min(0.95, 1.0/(visc*1.8)))
		lfoSpeed := (0.1 / visc) + (turbulence * 0.5)

		// Acidity drives subtle frequency modulation (bitterness/harshness)
		fmIndex := acidity * 1.5

		// Volatiles control delay diffusion feedback (aroma space)
		feedback := math.Min(0.75, volatiles*0.7)

		for i := 0; i < BufSize; i++ {
			t := 1.0 / float64(SampleRate)

			// Advance LFO
			lfoPhase += 2.0 * math.Pi * lfoSpeed * t
			if lfoPhase > 2.0*math.Pi {
				lfoPhase -= 2.0 * math.Pi
			}
			lfoVal := math.Sin(lfoPhase)

			var mixL, mixR float64

			// Synthesize ambient chord layers
			for k := 0; k < NumChords; k++ {
				// Organic pitch drift based on temperature and turbulence
				tempDrift := (temp - 50.0) * 0.05 * float64(k+1)
				stirDetune := (rand.Float64() - 0.5) * turbulence * 2.0
				freq := baseFreqs[k] + tempDrift + stirDetune

				// FM modulation driven by chemical acidity
				modFreq := freq * 2.005
				modulator := math.Sin(phases[k]*2.005) * fmIndex * freq
				phases[k] += 2.0 * math.Pi * (freq + modulator) * t
				if phases[k] > 2.0*math.Pi {
					phases[k] -= 2.0 * math.Pi
				}

				// Soft triangle/sine hybrid waveform synthesis
				rawWave := math.Sin(phases[k]) + 0.3*math.Sin(3.0*phases[k])

				// Stereo panning separation for ambient depth
				pan := 0.5 + 0.3*math.Sin(lfoPhase+float64(k))
				mixL += rawWave * (1.0 - pan)
				mixR += rawWave * pan
			}

			// Scaling mix down
			mixL *= 0.15
			mixR *= 0.15

			// One-pole Low Pass Filter modulated by Viscosity
			lpStateL += cutoff * (mixL - lpStateL)
			lpStateR += cutoff * (mixR - lpStateR)

			// Simple Delay Line / Reverb (Modulated by Volatile Aroma)
			delayReadIdx := (delayIdx - 12000 + len(delayBuffer)) % len(delayBuffer)
			delayedL := delayBuffer[delayReadIdx]
			delayBuffer[delayIdx] = lpStateL + delayedL*feedback
			delayIdx = (delayIdx + 1) % len(delayBuffer)

			outL := lpStateL + delayedL*0.4
			outR := lpStateR + delayedL*0.3

			// Soft-clipping saturation
			outL = math.Tanh(outL)
			outR = math.Tanh(outR)

			// Convert float (-1.0 to +1.0) to 16-bit PCM Little Endian
			sampleL := int16(outL * 32767.0)
			sampleR := int16(outR * 32767.0)

			idx := i * 4
			binary.LittleEndian.PutUint16(outBuf[idx:], uint16(sampleL))
			binary.LittleEndian.PutUint16(outBuf[idx+2:], uint16(sampleR))
		}

		// Write raw audio buffer directly to stdout
		os.Stdout.Write(outBuf)
	}
}

// physicsSimulation updates coffee cooling, evaporation, and chemical decay.
func physicsSimulation() {
	ticker := time.NewTicker(50 * time.Millisecond)
	for range ticker.C {
		coffee.mu.Lock()

		// Newton's law of cooling towards ambient room temp (20°C)
		coolingRate := 0.015
		coffee.Temperature -= (coffee.Temperature - 20.0) * coolingRate * 0.05

		// Viscosity increases as liquid cools and solutes concentrate
		tempFactor := math.Exp((80.0-coffee.Temperature)/40.0) * 0.8
		coffee.Viscosity = 1.0 + (tempFactor * coffee.SoluteDensity)

		// Volatiles evaporate rapidly when hot, augmented by stirring turbulence
		evapRate := (coffee.Temperature / 100.0) * 0.002 * (1.0 + coffee.StirTurbulence*3.0)
		coffee.Volatiles = math.Max(0.01, coffee.Volatiles-evapRate)

		// Chlorogenic acid breaks down into quinic acid over time (Acidity/bitterness rise)
		coffee.Acidity = math.Min(1.0, coffee.Acidity+0.0003)

		// Mechanical energy decay from stirring
		coffee.StirTurbulence *= 0.92

		coffee.mu.Unlock()
	}
}

// inputListener reads single keypresses to interact with the coffee cup.
func inputListener() {
	buf := make([]byte, 1)
	for {
		n, err := os.Stdin.Read(buf)
		if err != nil || n == 0 {
			time.Sleep(10 * time.Millisecond)
			continue
		}

		coffee.mu.Lock()
		switch buf[0] {
		case 's', 'S': // Stir coffee
			coffee.StirTurbulence = math.Min(2.5, coffee.StirTurbulence+0.8)
			coffee.Volatiles = math.Min(1.0, coffee.Volatiles+0.05) // Releases trapped aroma
		case 'h', 'H': // Heat coffee
			coffee.Temperature = math.Min(98.0, coffee.Temperature+15.0)
		case 'm', 'M': // Add milk (increases viscosity, reduces acidity)
			coffee.SoluteDensity += 0.4
			coffee.Acidity = math.Max(0.0, coffee.Acidity-0.15)
		case 'q', 'Q':
			fmt.Fprint(os.Stderr, "\033[?25h\033[0m\nExiting...\n")
			os.Exit(0)
		}
		coffee.mu.Unlock()
	}
}

// renderUI draws live ASCII diagnostics to Stderr (keeping Stdout clean for PCM audio).
func renderUI() {
	ticker := time.NewTicker(100 * time.Millisecond)
	for range ticker.C {
		coffee.mu.Lock()
		temp := coffee.Temperature
		visc := coffee.Viscosity
		aroma := coffee.Volatiles
		acid := coffee.Acidity
		turb := coffee.StirTurbulence
		coffee.mu.Unlock()

		// Generate steam visual based on temperature and turbulence
		steam := "  "
		if temp > 70.0 || turb > 0.5 {
			steam = " ~( ~) "
		} else if temp > 40.0 {
			steam = "  ) (  "
		}

		// Clear console UI frame
		fmt.Fprint(os.Stderr, "\033[H\033[2J")
		fmt.Fprint(os.Stderr, "=== COFFEE VISCOSITY SONIFICATION SYNTHESIZER ===\n")
		fmt.Fprint(os.Stderr, "Pipe output to player: `go run main.go | aplay -f cd` or `ffplay -f s16le -ar 44100 -ac 2 -`\n\n")

		fmt.Fprintf(os.Stderr, "       %s\n", steam)
		fmt.Fprint(os.Stderr, "      (  (   ) )\n")
		fmt.Fprint(os.Stderr, "     .----------.\n")
		fmt.Fprint(os.Stderr, "    /  C O F F E E \\_\\  \n")
		fmt.Fprint(os.Stderr, "   |  [ ambient ]   |  )\n")
		fmt.Fprint(os.Stderr, "   |   ~ drone ~    |--'\n")
		fmt.Fprint(os.Stderr, "    \\______________/\n\n")

		fmt.Fprintf(os.Stderr, " Temperature:  [%-20s] %.1f °C\n", makeBar(temp/100.0), temp)
		fmt.Fprintf(os.Stderr, " Viscosity:    [%-20s] %.2f cP  (Modulates LPF Cutoff)\n", makeBar(visc/5.0), visc)
		fmt.Fprintf(os.Stderr, " Volatiles:    [%-20s] %.0f%%   (Modulates Delay/Reverb Space)\n", makeBar(aroma), aroma*100)
		fmt.Fprintf(os.Stderr, " Acidity/Decay:[%-20s] %.0f%%   (Modulates FM Harshness)\n", makeBar(acid), acid*100)
		fmt.Fprintf(os.Stderr, " Turbulence:   [%-20s] %.2f    (Stir Motion Energy)\n\n", makeBar(turb/2.0), turb)

		fmt.Fprint(os.Stderr, "CONTROLS: [S] Stir Coffee | [H] Heat Cup | [M] Add Milk | [Q] Quit\n")
	}
}

// Helper to draw clean ASCII progress bars
func makeBar(val float64) string {
	val = math.Max(0.0, math.Min(1.0, val))
	numChars := int(val * 20.0)
	bar := ""
	for i := 0; i < 20; i++ {
		if i < numChars {
			bar += "#"
		} else {
			bar += "-"
		}
	}
	return bar
}