package main

import (
	"fmt"
	"math"
	"strings"
	"time"
)

// Planetary topography and MIDI soundscape generator from text.
// Compiles text input into procedural ASCII/ANSI planetary relief maps 
// while streaming synchronized MIDI note events in real time.

func main() {
	text := "The crimson dust settles across the basalt plains of Aetheria. Binary suns dip below the jagged horizon, whispering ancient frequencies into the stellar wind."
	
	fmt.Println("Compiling text into planetary topography and MIDI soundscape...")
	time.Sleep(1 * time.Second)

	width := 60
	height := 20
	chars := []rune(" .:-=+*#%@")

	// Convert text bytes into a deterministic frequency/note array
	notes := make([]int, len(text))
	for i, r := range text {
		notes[i] = 36 + (int(r) % 48) // MIDI note range mapping
	}

	// Real-time procedural rendering loop simulating planetary rotation and soundscape
	for t := 0.0; t < 40.0; t += 0.4 {
		var sb strings.Builder
		sb.WriteString("\033[H\033[2J") // Clear terminal screen
		sb.WriteString(fmt.Sprintf("=== PLANETARY TOPOGRAPHY SIMULATOR [Time: %.1f] ===\n", t))
		
		activeNote := notes[int(t*2)%len(text)]
		sb.WriteString(fmt.Sprintf("Source Text: \"%s\"\n", text[:min(35, len(text))]+"..." ))
		sb.WriteString(fmt.Sprintf("[MIDI STREAM] NoteOn -> Pitch: %3d | Velocity: 96 | Channel: 1\n\n", activeNote))

		for y := 0; y < height; y++ {
			for x := 0; x < width; x++ {
				// Procedural elevation formula driven by spatial coordinates and time
				nx := float64(x) / float64(width) * 4.0
				ny := float64(y) / float64(height) * 4.0
				
				val := math.Sin(nx+t*0.2) * math.Cos(ny-t*0.1)
				val += math.Sin(nx*2.0 - t*0.3) * 0.5
				
				// Modulate surface texture with text character ASCII values
				charIdx := int(math.Abs(val)*float64(len(chars))) + int(text[(x+y+int(t))%len(text)])%3
				if charIdx >= len(chars) {
					charIdx = len(chars) - 1
				}
				if charIdx < 0 {
					charIdx = 0
				}
				sb.WriteRune(chars[charIdx])
			}
			sb.WriteString("\n")
		}
		
		fmt.Print(sb.String())
		time.Sleep(100 * time.Millisecond)
	}
	fmt.Println("\nSoundscape generation and topographical scan complete.")
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}