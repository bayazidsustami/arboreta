package main

import (
	"fmt"
	"math"
	"os"
	"os/exec"
	"runtime"
	"time"
)

// Self-modifying Quine, Synth Engine & Spectrogram Visualizer
func main() {
	// Source code stored as template quine format
	s := `package main

import (
	"fmt"
	"math"
	"os"
	"os/exec"
	"runtime"
	"time"
)

// Self-modifying Quine, Synth Engine & Spectrogram Visualizer
func main() {
	// Source code stored as template quine format
	s := %q
	src := fmt.Sprintf(s, s)

	// 1. Parse source code as ASCII pitch spectrum
	pitches := make([]float64, 0)
	scale := []float64{261.63, 293.66, 329.63, 392.00, 440.00, 523.25} // Pentatonic C5
	for _, char := range src {
		if char > 32 && char < 127 {
			freq := scale[int(char)%%len(scale)]
			pitches = append(pitches, freq)
		}
	}

	// 2. Synthesize Audio Motif & Morph Source into Spectrogram
	sampleRate := 8000
	cols := 60
	rows := 16
	audioBuffer := make([]byte, 0)
	
	// Prepare Visual Terminal Spectrogram Output
	clearScreen()
	fmt.Println("=== SELF-MODIFYING QUINE: SPECTROGRAM MORPH ===")
	
	step := len(pitches) / cols
	if step == 0 { step = 1 }

	for col := 0; col < cols && col*step < len(pitches); col++ {
		freq := pitches[col*step]
		
		// Generate 50ms of audio per pitch (Simple FM/AM Synthesizer)
		dur := 0.05
		numSamples := int(float64(sampleRate) * dur)
		for i := 0; i < numSamples; i++ {
			t := float64(i) / float64(sampleRate)
			env := math.Exp(-3.0 * t / dur)
			wave := math.Sin(2.0 * math.Pi * freq * t)
			mod := math.Sin(2.0 * math.Pi * (freq / 2.0) * t) * 0.5
			val := byte((wave + mod) * env * 60.0 + 128.0)
			audioBuffer = append(audioBuffer, val)
		}

		// Draw Spectrogram Column based on ASCII Pitch
		normFreq := (freq - 250.0) / 300.0
		activeRow := int(normFreq * float64(rows))
		
		moveCursor(1, 1)
		for r := rows; r >= 0; r-- {
			for c := 0; c <= col; c++ {
				pFreq := pitches[c*step]
				pNorm := (pFreq - 250.0) / 300.0
				pRow := int(pNorm * float64(rows))
				
				if r == pRow {
					fmt.Print("\033[38;5;208m#\033[0m") // Orange peak
				} else if r < pRow {
					fmt.Print("\033[38;5;238m:\033[0m") // Spectrum trail
				} else {
					fmt.Print(" ")
				}
			}
			fmt.Println()
		}
		time.Sleep(30 * time.Millisecond)
	}

	// Output PCM audio via system speaker pipe or file dump
	playAudio(audioBuffer, sampleRate)

	// 3. Self-Modification Stage (Mutates pitch map on disk)
	selfModifyingSrc := mutateSource(src)
	_ = os.WriteFile("main.go", []byte(selfModifyingSrc), 0644)
}

func playAudio(buffer []byte, sampleRate int) {
	// Attempts to play PCM directly on Linux/macOS via aplay/afplay or fallback stdout write
	if runtime.GOOS == "linux" {
		cmd := exec.Command("aplay", "-r", fmt.Sprintf("%d", sampleRate), "-f", "U8")
		in, err := cmd.StdinPipe()
		if err == nil {
			cmd.Start()
			in.Write(buffer)
			in.Close()
			cmd.Wait()
		}
	} else if runtime.GOOS == "darwin" {
		tmpFile, _ := os.CreateTemp("", "quine_*.raw")
		defer os.Remove(tmpFile.Name())
		tmpFile.Write(buffer)
		tmpFile.Close()
		exec.Command("afplay", "-r", fmt.Sprintf("%d", sampleRate), "-f", "LEI8", tmpFile.Name()).Run()
	}
}

func mutateSource(src string) string {
	// Slight harmonic transposition upon each mutation cycle
	bytes := []byte(src)
	for i, b := range bytes {
		if b == 'C' { bytes[i] = 'D' } else if b == 'D' { bytes[i] = 'E' }
	}
	return string(bytes)
}

func clearScreen() { fmt.Print("\033[H\033[2J") }
func moveCursor(r, c int) { fmt.Printf("\033[%%d;%%dH", r, c) }
`
	src := fmt.Sprintf(s, s)

	// 1. Parse source code as ASCII pitch spectrum
	pitches := make([]float64, 0)
	scale := []float64{261.63, 293.66, 329.63, 392.00, 440.00, 523.25} // Pentatonic C5
	for _, char := range src {
		if char > 32 && char < 127 {
			freq := scale[int(char)%len(scale)]
			pitches = append(pitches, freq)
		}
	}

	// 2. Synthesize Audio Motif & Morph Source into Spectrogram
	sampleRate := 8000
	cols := 60
	rows := 16
	audioBuffer := make([]byte, 0)
	
	// Prepare Visual Terminal Spectrogram Output
	clearScreen()
	fmt.Println("=== SELF-MODIFYING QUINE: SPECTROGRAM MORPH ===")
	
	step := len(pitches) / cols
	if step == 0 { step = 1 }

	for col := 0; col < cols && col*step < len(pitches); col++ {
		freq := pitches[col*step]
		
		// Generate 50ms of audio per pitch (Simple FM/AM Synthesizer)
		dur := 0.05
		numSamples := int(float64(sampleRate) * dur)
		for i := 0; i < numSamples; i++ {
			t := float64(i) / float64(sampleRate)
			env := math.Exp(-3.0 * t / dur)
			wave := math.Sin(2.0 * math.Pi * freq * t)
			mod := math.Sin(2.0 * math.Pi * (freq / 2.0) * t) * 0.5
			val := byte((wave + mod) * env * 60.0 + 128.0)
			audioBuffer = append(audioBuffer, val)
		}

		// Draw Spectrogram Column based on ASCII Pitch
		normFreq := (freq - 250.0) / 300.0
		activeRow := int(normFreq * float64(rows))
		_ = activeRow
		
		moveCursor(3, 1)
		for r := rows; r >= 0; r-- {
			for c := 0; c <= col; c++ {
				pFreq := pitches[c*step]
				pNorm := (pFreq - 250.0) / 300.0
				pRow := int(pNorm * float64(rows))
				
				if r == pRow {
					fmt.Print("\033[38;5;208m#\033[0m") // Orange peak
				} else if r < pRow {
					fmt.Print("\033[38;5;238m:\033[0m") // Spectrum trail
				} else {
					fmt.Print(" ")
				}
			}
			fmt.Println()
		}
		time.Sleep(30 * time.Millisecond)
	}

	// Output PCM audio via system speaker pipe
	playAudio(audioBuffer, sampleRate)

	// 3. Self-Modification Stage (Mutates pitch map on disk)
	selfModifyingSrc := mutateSource(src)
	_ = os.WriteFile("main.go", []byte(selfModifyingSrc), 0644)
}

func playAudio(buffer []byte, sampleRate int) {
	// Attempts to play PCM directly on Linux/macOS via aplay/afplay
	if runtime.GOOS == "linux" {
		cmd := exec.Command("aplay", "-r", fmt.Sprintf("%d", sampleRate), "-f", "U8")
		in, err := cmd.StdinPipe()
		if err == nil {
			cmd.Start()
			in.Write(buffer)
			in.Close()
			cmd.Wait()
		}
	} else if runtime.GOOS == "darwin" {
		tmpFile, _ := os.CreateTemp("", "quine_*.raw")
		defer os.Remove(tmpFile.Name())
		tmpFile.Write(buffer)
		tmpFile.Close()
		exec.Command("afplay", "-r", fmt.Sprintf("%d", sampleRate), "-f", "LEI8", tmpFile.Name()).Run()
	}
}

func mutateSource(src string) string {
	// Slight harmonic transposition upon each mutation cycle
	bytes := []byte(src)
	for i, b := range bytes {
		if b == 'C' { bytes[i] = 'D' } else if b == 'D' { bytes[i] = 'E' }
	}
	return string(bytes)
}

func clearScreen() { fmt.Print("\033[H\033[2J") }
func moveCursor(r, c int) { fmt.Printf("\033[%d;%dH", r, c) }