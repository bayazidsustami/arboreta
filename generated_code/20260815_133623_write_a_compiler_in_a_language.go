package main

import (
	"fmt"
	"math"
	"math/rand"
	"strings"
	"time"
)

// Sonnet 18 by William Shakespeare: input poem to compile into cellular tapestry.
const sonnetText = `
Shall I compare thee to a summer's day?
Thou art more lovely and more temperate:
Rough winds do shake the darling buds of May,
And summer's lease hath all too short a date:
Sometime too hot the eye of heaven shines,
And often is his gold complexion dimm'd;
And every fair from fair sometime declines,
By chance or nature's changing course untrimm'd;
But thy eternal summer shall not fade
Nor lose possession of that fair thou ow'st;
Nor shall Death brag thou wander'st in his shade,
When in eternal lines to time thou grow'st:
  So long as men can breathe or eyes can see,
  So long lives this and this gives life to thee.
`

const (
	width  = 70
	height = 30
)

// Sentiment holds normalized emotional weights compiled from poetic vocabulary.
type Sentiment struct {
	Warmth     float64 // Gold, red, orange spectrum
	Melancholy float64 // Indigo, violet, deep shadow spectrum
	Vitality   float64 // Emerald, jade, sunlight spectrum
}

// SonnetCompiler translates poetic structure and semantics into dynamic CA parameters.
type SonnetCompiler struct {
	LineMutationRates []float64
	Palette           Sentiment
}

// Compile analyzes sonnet rhythm (meter deviation) and sentiment to program the CA.
func Compile(text string) *SonnetCompiler {
	lines := strings.Split(strings.TrimSpace(text), "\n")
	rates := make([]float64, 0, len(lines))

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if len(line) == 0 {
			continue
		}

		// Rhythmic Meter Analysis: Estimate syllable count & deviation from iambic pentameter (10 syllables).
		syllables := 0
		words := strings.Fields(line)
		for _, w := range words {
			w = strings.ToLower(w)
			vowels := 0
			for _, ch := range w {
				if strings.ContainsRune("aeiouy", ch) {
					vowels++
				}
			}
			if vowels == 0 {
				vowels = 1
			}
			syllables += vowels
		}

		// Deviation from ideal 10-syllable rhythm increases cell mutation instability.
		rhythmDeviation := math.Abs(float64(syllables) - 10.0)
		mutationRate := 0.02 + (rhythmDeviation * 0.035)
		rates = append(rates, mutationRate)
	}

	// Emotional Sentiment Lexicon Mapping.
	lowerText := strings.ToLower(text)
	warmthWords := []string{"summer", "lovely", "gold", "fair", "sun", "heaven", "shines", "darling", "hot"}
	melancholyWords := []string{"rough", "shake", "short", "dimm'd", "declines", "death", "shade", "fade", "lose"}
	vitalityWords := []string{"day", "buds", "may", "nature", "breathe", "grow'st", "lives", "eternal", "eyes"}

	var s Sentiment
	for _, w := range warmthWords {
		s.Warmth += float64(strings.Count(lowerText, w))
	}
	for _, w := range melancholyWords {
		s.Melancholy += float64(strings.Count(lowerText, w))
	}
	for _, w := range vitalityWords {
		s.Vitality += float64(strings.Count(lowerText, w))
	}

	total := s.Warmth + s.Melancholy + s.Vitality
	if total == 0 {
		s = Sentiment{Warmth: 0.33, Melancholy: 0.33, Vitality: 0.33}
	} else {
		s.Warmth /= total
		s.Melancholy /= total
		s.Vitality /= total
	}

	return &SonnetCompiler{
		LineMutationRates: rates,
		Palette:           s,
	}
}

// Matrix represents the self-organizing continuous cellular automata grid.
type Matrix struct {
	grid    [][]float64
	nextGrid [][]float64
}

func NewMatrix(w, h int) *Matrix {
	g := make([][]float64, h)
	ng := make([][]float64, h)
	for i := range g {
		g[i] = make([]float64, w)
		ng[i] = make([]float64, w)
		for j := range g[i] {
			g[i][j] = rand.Float64()
		}
	}
	return &Matrix{grid: g, nextGrid: ng}
}

// Step advances the CA matrix according to reaction-diffusion-like self-organizing rules.
func (m *Matrix) Step(mutationRate float64) {
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			// Compute 8-neighbor average continuous state value.
			neighborsSum := 0.0
			for dy := -1; dy <= 1; dy++ {
				for dx := -1; dx <= 1; dx++ {
					if dx == 0 && dy == 0 {
						continue
					}
					ny := (y + dy + height) % height
					nx := (x + dx + width) % width
					neighborsSum += m.grid[ny][nx]
				}
			}
			avg := neighborsSum / 8.0

			// Self-organizing state transition: blend local excitation with decay.
			v := m.grid[y][x]
			nextV := v*0.4 + avg*0.58

			// Spontaneous rhythmic mutation injected by meter instability.
			if rand.Float64() < mutationRate {
				nextV += (rand.Float64() - 0.4) * 0.5
			}

			// Clamp state within continuous energy range [0.0, 1.0].
			if nextV < 0 {
				nextV = 0
			} else if nextV > 1 {
				nextV = 1
			}

			m.nextGrid[y][x] = nextV
		}
	}
	m.grid, m.nextGrid = m.nextGrid, m.grid
}

// RenderToANSI outputs the cell state as a colorized tapestry frame using ANSI true-color terminal codes.
func (m *Matrix) RenderToANSI(s Sentiment, currentLine string, frameIndex int) string {
	var b strings.Builder
	b.WriteString("\033[H") // Reset cursor position to top-left

	// Render title and active sonnet line context.
	b.WriteString(fmt.Sprintf("\033[1;37m--- SHAKESPEAREAN SONNET CA TAPESTRY --- Frame %04d ---\033[0m\n", frameIndex))
	b.WriteString(fmt.Sprintf("\033[36mVerse: %-60s\033[0m\n\n", currentLine))

	// Render cellular matrix.
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			val := m.grid[y][x]

			// Translate cell continuous state + sentiment profile into RGB tapestry palette.
			r := int(math.Min(255, val*255*s.Warmth*1.8 + (1-val)*40))
			g := int(math.Min(255, val*255*s.Vitality*1.8 + val*50))
			bCol := int(math.Min(255, val*255*s.Melancholy*1.8 + (1-val)*80))

			// Use block characters for high-density terminal visualization.
			char := "█"
			if val < 0.25 {
				char = "░"
			} else if val < 0.55 {
				char = "▒"
			} else if val < 0.82 {
				char = "▓"
			}

			b.WriteString(fmt.Sprintf("\033[38;2;%d;%d;%dm%s", r, g, bCol, char))
		}
		b.WriteString("\n")
	}

	b.WriteString("\033[0m\n[Warmth: " + fmt.Sprintf("%.2f", s.Warmth) +
		" | Melancholy: " + fmt.Sprintf("%.2f", s.Melancholy) +
		" | Vitality: " + fmt.Sprintf("%.2f", s.Vitality) + "]\n")

	return b.String()
}

func main() {
	rand.Seed(time.Now().UnixNano())

	// Step 1: Compile Shakespearean Sonnet into algorithmic parameters.
	compiler := Compile(sonnetText)
	lines := strings.Split(strings.TrimSpace(sonnetText), "\n")

	// Step 2: Initialize self-organizing continuous Cellular Automata matrix.
	matrix := NewMatrix(width, height)

	// Hide cursor and clear terminal for smooth real-time animation.
	fmt.Print("\033[?25l\033[2J")
	defer fmt.Print("\033[?25h\033[0m\n")

	frame := 0
	// Step 3: Real-time animated tapestry loop where meter drives mutation & sentiment drives color.
	for i, line := range lines {
		line = strings.TrimSpace(line)
		if len(line) == 0 {
			continue
		}

		mutationRate := compiler.LineMutationRates[i]

		// Animate several generational cycles per line of the sonnet.
		for cycle := 0; cycle < 15; cycle++ {
			matrix.Step(mutationRate)
			output := matrix.RenderToANSI(compiler.Palette, line, frame)
			fmt.Print(output)

			frame++
			time.Sleep(60 * time.Millisecond)
		}
	}
}