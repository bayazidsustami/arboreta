package main

import (
	"crypto/sha256"
	"fmt"
	"math/rand"
	"strings"
	"time"
)

// GhostCompressor encodes a nineteenth-century ghost story into a dynamic,
// self-mutating CSS stylesheet where layout failures and overflow anomalies
// physically model the progression of the haunting.
type GhostCompressor struct {
	entropySource []byte
	storyText     string
}

// NewGhostCompressor initializes the compressor with a ghostly narrative.
func NewGhostCompressor(story string) *GhostCompressor {
	hasher := sha256.New()
	hasher.Write([]byte(story))
	return &GhostCompressor{
		entropySource: hasher.Sum(nil),
		storyText:     story,
	}
}

// MutateCSS generates a volatile CSS stylesheet that shifts rules based on byte parity,
// inducing chaotic layout flexbox collapses, absolute positioning drift, and z-index ghosts.
func (gc *GhostCompressor) MutateCSS() string {
	var cssBuilder strings.Builder
	rand.Seed(time.Now().UnixNano())

	// Base haunting styles for the DOM corpse
	cssBuilder.WriteString("/* --- SPECTRAL MANIFESTATION STYLESHEET --- */\n")
	cssBuilder.WriteString("body {\n")
	cssBuilder.WriteString("  background-color: #050508;\n")
	cssBuilder.WriteString("  color: #a0a0b0;\n")
	cssBuilder.WriteString("  font-family: 'Courier New', monospace;\n")
	cssBuilder.WriteString("  overflow: hidden;\n")
	cssBuilder.WriteString("  perspective: 1px;\n")
	cssBuilder.WriteString("}\n\n")

	// Encode characters into cascading layout distortions
	words := strings.Fields(gc.storyText)
	for i, word := range words {
		// Derive layout failure metrics from the story's entropy and word index
		entropyByte := gc.entropySource[i%len(gc.entropySource)]
		drift := (int(entropyByte) % 40) - 20
		skewAngle := (i % 7) - 3
		opacity := float64(15+(entropyByte%75)) / 100.0

		className := fmt.Sprintf("ghost-phrase-%d", i)

		cssBuilder.WriteString(fmt.Sprintf(".%s {\n", className))
		cssBuilder.WriteString(fmt.Sprintf("  /* Encoded text fragment: %s */\n", word))
		cssBuilder.WriteString(fmt.Sprintf("  position: absolute;\n"))
		cssBuilder.WriteString(fmt.Sprintf("  left: calc(50vw + %dpx);\n", drift*15))
		cssBuilder.WriteString(fmt.Sprintf("  top: calc(50vh + %dpx);\n", (i*23)%600-300))
		cssBuilder.WriteString(fmt.Sprintf("  transform: rotate(%ddeg) scale(%f);\n", skewAngle, 0.8+float64(entropyByte%5)/10.0))
		cssBuilder.WriteString(fmt.Sprintf("  opacity: %f;\n", opacity))
		cssBuilder.WriteString(fmt.Sprintf("  filter: blur(%dpx);\n", entropyByte%4))
		
		// Introduce catastrophic browser layout anomalies on specific triggers
		if entropyByte%3 == 0 {
			cssBuilder.WriteString("  display: grid;\n")
			cssBuilder.WriteString("  grid-template-columns: 0fr 0fr;\n") // Forces grid collapse
			cssBuilder.WriteString("  mix-blend-mode: exclusion;\n")
		} else if entropyByte%3 == 1 {
			cssBuilder.WriteString("  float: left;\n")
			cssBuilder.WriteString("  width: 0px;\n")
			cssBuilder.WriteString("  overflow: visible;\n") // Causes text bleeding and phantom overlap
		} else {
			cssBuilder.WriteString("  position: fixed;\n")
			cssBuilder.WriteString("  clip-path: polygon(0 0, 0% 100%, 100% 50%);\n") // Severs text fragments
		}

		cssBuilder.WriteString("}\n\n")
	}

	return cssBuilder.String()
}

func main() {
	// A classic nineteenth-century ambient text fragment
	tale := "The wind wept hollow through the casement, rattling the ancient iron latch as the pale candlelight flickered into absolute darkness, revealing a silhouette that had no business breathing."

	compressor := NewGhostCompressor(tale)
	stylesheet := compressor.MutateCSS()

	fmt.Println(stylesheet)
}