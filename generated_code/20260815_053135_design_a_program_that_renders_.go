package main

import (
	"fmt"
	"math"
	"math/cmplx"

	"[github.com/gordonklaus/portaudio](https://github.com/gordonklaus/portaudio)"
)

const (
	width      = 80
	height     = 24
	sampleRate = 44100
	bufferSize = 1024
	numBins    = bufferSize / 2
)

// Density maps from low intensity to high intensity
var densityRamps = []string{
	" .'`^\"",
	" -_~:;=",
	" +!*?%&",
	" %#@$W#",
}

// FFT performs a fast Cooley-Tukey Radix-2 FFT in place
func FFT(buffer []complex128) {
	n := len(buffer)
	if n <= 1 {
		return
	}

	even := make([]complex128, n/2)
	odd := make([]complex128, n/2)
	for i := 0; i < n/2; i++ {
		even[i] = buffer[2*i]
		odd[i] = buffer[2*i+1]
	}

	FFT(even)
	FFT(odd)

	for k := 0; k < n/2; k++ {
		angle := -2 * math.Pi * float64(k) / float64(n)
		t := cmplx.Rect(1, angle) * odd[k]
		buffer[k] = even[k] + t
		buffer[k+n/2] = even[k] - t
	}
}

func main() {
	portaudio.Initialize()
	defer portaudio.Terminate()

	audioBuffer := make([]float32, bufferSize)
	stream, err := portaudio.OpenDefaultStream(1, 0, sampleRate, bufferSize, audioBuffer)
	if err != nil {
		fmt.Printf("Error opening audio stream: %v\n", err)
		return
	}
	defer stream.Close()

	if err := stream.Start(); err != nil {
		fmt.Printf("Error starting audio stream: %v\n", err)
		return
	}
	defer stream.Stop()

	// Clear terminal screen
	fmt.Print("\033[2J")

	var t float64
	fftBuf := make([]complex128, bufferSize)
	bands := make([]float64, width)

	for {
		if err := stream.Read(); err != nil {
			continue
		}

		// Prepare complex input for FFT
		for i := 0; i < bufferSize; i++ {
			// Apply Hann window
			window := 0.5 * (1 - math.Cos(2*math.Pi*float64(i)/float64(bufferSize-1)))
			fftBuf[i] = complex(float64(audioBuffer[i])*window, 0)
		}

		FFT(fftBuf)

		// Map FFT magnitudes to screen width (frequency bands)
		for x := 0; x < width; x++ {
			bin := int(math.Pow(float64(x)/float64(width), 1.5) * float64(numBins-1))
			mag := cmplx.Abs(fftBuf[bin]) / float64(bufferSize)
			
			// Smooth energy transition
			bands[x] = bands[x]*0.6 + mag*0.4
		}

		// Move cursor to top-left
		fmt.Print("\033[H")

		frame := make([]byte, 0, width*height+height)
		t += 0.05

		for y := 0; y < height; y++ {
			for x := 0; x < width; x++ {
				// Calculate landscape height modulated by audio spectrum
				freqEnergy := bands[x] * 15.0
				terrain := math.Sin(float64(x)*0.1+t)*2.0 + math.Cos(float64(x)*0.05-t*0.5)*3.0
				baseline := float64(height)*0.65 - terrain - freqEnergy

				if float64(y) >= baseline {
					// Depth along vertical axis
					depth := float64(y) - baseline
					
					// Select harmonic ramp based on frequency intensity
					energyIdx := int(bands[x] * float64(len(densityRamps)))
					if energyIdx >= len(densityRamps) {
						energyIdx = len(densityRamps) - 1
					}
					ramp := densityRamps[energyIdx]

					// Select char in ramp based on depth
					charIdx := int(depth*0.8) % len(ramp)
					frame = append(frame, ramp[charIdx])
				} else {
					// Sky background
					if y == 2 && x%20 == 0 && bands[x] > 0.1 {
						frame = append(frame, '*') // Audio-reactive stars
					} else {
						frame = append(frame, ' ')
					}
				}
			}
			frame = append(frame, '\n')
		}

		fmt.Print(string(frame))
	}
}