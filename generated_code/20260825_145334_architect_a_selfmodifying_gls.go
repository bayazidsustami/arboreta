package main

import (
	"fmt"
	"math"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
)

// ANSI Color characters and Palette definition
const (
	RSI       = "\x1b[0;0H"
	HideCursor = "\x1b[?25l"
	ShowCursor = "\x1b[?25h"
	ResetColor = "\x1b[0m"
)

// EmotionState represents the continuous dynamic feedback vector driven by live text.
type EmotionState struct {
	Chaos     float64 // Frequency / Turbulence (driven by word energy)
	Harmonics float64 // Morphing parameter / Topo complexity
	HueShift  float64 // Color spectrum bias
	Energy    float64 // Pulsing scale / Movement speed
}

// Shader simulates a CPU-computed GLSL raymarching engine rendered directly to ANSI terminals.
type Shader struct {
	Width  int
	Height int
	Time   float64
	State  EmotionState
}

// Words mapped to dynamic emotional vector influences
var sentimentDictionary = map[string]EmotionState{
	"rage":       {Chaos: 2.5, Harmonics: 0.2, HueShift: 0.0, Energy: 2.0},
	"fire":       {Chaos: 1.8, Harmonics: 0.4, HueShift: 0.05, Energy: 1.5},
	"serene":     {Chaos: 0.2, Harmonics: 1.5, HueShift: 0.55, Energy: 0.4},
	"calm":       {Chaos: 0.1, Harmonics: 1.0, HueShift: 0.5, Energy: 0.3},
	"ocean":      {Chaos: 0.4, Harmonics: 1.8, HueShift: 0.6, Energy: 0.6},
	"cyber":      {Chaos: 1.2, Harmonics: 2.5, HueShift: 0.8, Energy: 1.2},
	"love":       {Chaos: 0.5, Harmonics: 1.2, HueShift: 0.9, Energy: 0.8},
	"void":       {Chaos: 0.0, Harmonics: 0.1, HueShift: 0.7, Energy: 0.1},
	"transcend":  {Chaos: 1.5, Harmonics: 3.0, HueShift: 0.75, Energy: 1.4},
}

// 3D Vector Math primitives
type Vec3 struct{ X, Y, Z float64 }

func (v Vec3) Add(o Vec3) Vec3     { return Vec3{v.X + o.X, v.Y + o.Y, v.Z + o.Z} }
func (v Vec3) Sub(o Vec3) Vec3     { return Vec3{v.X - o.X, v.Y - o.Y, v.Z - o.Z} }
func (v Vec3) Mul(s float64) Vec3  { return Vec3{v.X * s, v.Y * s, v.Z * s} }
func (v Vec3) Length() float64     { return math.Sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z) }
func (v Vec3) Normalize() Vec3    { l := v.Length(); if l == 0 { return Vec3{} }; return Vec3{v.X / l, v.Y / l, v.Z / l} }
func (v Vec3) Dot(o Vec3) float64  { return v.X*o.X + v.Y*o.Y + v.Z*o.Z }

// Signed Distance Field (SDF) forming a topological gyroid/torus fusion sculpture.
func (s *Shader) MapSDF(p Vec3) float64 {
	// Apply rotational morphing based on time and chaos
	t := s.Time * s.State.Energy
	cosT, sinT := math.Cos(t*0.5), math.Sin(t*0.5)
	
	// Rotate space around Y axis
	pRot := Vec3{
		X: p.X*cosT - p.Z*sinT,
		Y: p.Y,
		Z: p.X*sinT + p.Z*cosT,
	}

	// Dynamic Gyroid topology equation modulated by emotional harmonics
	scale := 1.5 + s.State.Harmonics
	g := (math.Sin(pRot.X*scale) * math.Cos(pRot.Y*scale) +
		math.Sin(pRot.Y*scale) * math.Cos(pRot.Z*scale) +
		math.Sin(pRot.Z*scale) * math.Cos(pRot.X*scale)) / scale

	// Organic turbulence injection driven by chaos
	turbulence := math.Sin(p.X*3.0+t) * math.Cos(p.Y*3.0+t) * math.Sin(p.Z*3.0+t) * 0.1 * s.State.Chaos
	
	// Base bounding sphere constraint
	sphere := p.Length() - 1.25

	// Smooth minimum blending of gyroid manifold within bounding volume
	return math.Max(sphere, g+turbulence)
}

// Calculate normal vectors for lighting
func (s *Shader) CalculateNormal(p Vec3) Vec3 {
	e := 0.001
	d := s.MapSDF(p)
	return Vec3{
		X: s.MapSDF(Vec3{p.X + e, p.Y, p.Z}) - d,
		Y: s.MapSDF(Vec3{p.X, p.Y + e, p.Z}) - d,
		Z: s.MapSDF(Vec3{p.X, p.Y, p.Z + e}) - d,
	}.Normalize()
}

// Convert HSV values to 24-bit TrueColor ANSI escape strings
func hsvToANSI(h, s, v float64, char rune) string {
	h = math.Mod(h, 1.0)
	if h < 0 { h += 1.0 }
	
	i := math.Floor(h * 6)
	f := h*6 - i
	p := v * (1 - s)
	q := v * (1 - f*s)
	t := v * (1 - (1-f)*s)

	var r, g, b float64
	switch int(i) % 6 {
	case 0: r, g, b = v, t, p
	case 1: r, g, b = q, v, p
	case 2: r, g, b = p, v, t
	case 3: r, g, b = p, q, v
	case 4: r, g, b = t, p, v
	case 5: r, g, b = v, p, q
	}

	ir, ig, ib := int(r*255), int(g*255), int(b*255)
	return fmt.Sprintf("\x1b[38;2;%d;%d;%dm%c", ir, ig, ib, char)
}

// Main Raymarching Render Loop
func (s *Shader) Render() string {
	var sb strings.Builder
	sb.WriteString(RSI)

	lightDir := Vec3{1.0, 2.0, -2.0}.Normalize()
	aspect := float64(s.Width) / float64(s.Height*2) // Correct ASCII aspect ratio

	asciiDensity := []rune(" .':---=+#*%%@@")

	for y := 0; y < s.Height; y++ {
		for x := 0; x < s.Width; x++ {
			// Normalize Screen Coordinates (-1 to 1)
			uv := Vec3{
				X: (float64(x)/float64(s.Width)*2.0 - 1.0) * aspect,
				Y: float64(y)/float64(s.Height)*2.0 - 1.0,
				Z: 0.0,
			}

			// Ray setup
			ro := Vec3{0, 0, -2.5}               // Ray Origin
			rd := Vec3{uv.X, uv.Y, 1.0}.Normalize() // Ray Direction

			// Marching parameters
			dist := 0.0
			hit := false
			var p Vec3

			for step := 0; step < 40; step++ {
				p = ro.Add(rd.Mul(dist))
				d := s.MapSDF(p)
				if d < 0.005 {
					hit = true
					break
				}
				dist += d
				if dist > 5.0 {
					break
				}
			}

			if hit {
				normal := s.CalculateNormal(p)
				diffuse := math.Max(0.0, normal.Dot(lightDir))
				specular := math.Pow(math.Max(0.0, normal.Dot(lightDir)), 16.0)
				
				// Shade based on depth, lighting, and internal state hue
				brightness := math.Min(1.0, diffuse+0.1+specular)
				charIdx := int(brightness * float64(len(asciiDensity)-1))
				if charIdx < 0 { charIdx = 0 }
				if charIdx >= len(asciiDensity) { charIdx = len(asciiDensity) - 1 }

				hue := s.State.HueShift + (p.Z * 0.2) + (s.Time * 0.05)
				sb.WriteString(hsvToANSI(hue, 0.85, brightness, asciiDensity[charIdx]))
			} else {
				sb.WriteString(" ")
			}
		}
		sb.WriteString("\n")
	}

	return sb.String()
}

func main() {
	// Terminal Cleanup Trap
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-c
		fmt.Print(ShowCursor + ResetColor + "\x1b[2J")
		os.Exit(0)
	}()

	fmt.Print(HideCursor + "\x1b[2J")

	// Initial Shader Configuration
	shader := Shader{
		Width:  80,
		Height: 40,
		State: EmotionState{
			Chaos:     0.5,
			Harmonics: 1.0,
			HueShift:  0.6,
			Energy:    0.5,
		},
	}

	// Live Mock Data Stream Feed (simulates sentiment streams)
	textStream := []string{
		"calm ocean waves serenely floating",
		"cyber void matrix transcends logic",
		"rage fire burning chaos everywhere",
		"love transcends all void and chaos",
		"serene calm oceans soft light",
	}

	// Target state for smooth interpolation
	targetState := shader.State
	wordIndex := 0

	ticker := time.NewTicker(33 * time.Millisecond) // ~30 FPS
	defer ticker.Stop()

	streamTicker := time.NewTicker(3 * time.Second) // Ingest new text periodically
	defer streamTicker.Stop()

	for {
		select {
		case <-streamTicker.C:
			// Process live sentiment text feed
			phrase := textStream[wordIndex%len(textStream)]
			wordIndex++
			
			// Parse text, blend emotional influences
			var accumulatedState EmotionState
			words := strings.Fields(phrase)
			count := 0.0

			for _, word := range words {
				if emotion, exists := sentimentDictionary[strings.ToLower(word)]; exists {
					accumulatedState.Chaos += emotion.Chaos
					accumulatedState.Harmonics += emotion.Harmonics
					accumulatedState.HueShift += emotion.HueShift
					accumulatedState.Energy += emotion.Energy
					count++
				}
			}

			if count > 0 {
				targetState = EmotionState{
					Chaos:     accumulatedState.Chaos / count,
					Harmonics: accumulatedState.Harmonics / count,
					HueShift:  accumulatedState.HueShift / count,
					Energy:    accumulatedState.Energy / count,
				}
			}

		case <-ticker.C:
			shader.Time += 0.033

			// Smooth Lerp (Self-modifying weight adaptation) towards target state
			lerp := 0.05
			shader.State.Chaos += (targetState.Chaos - shader.State.Chaos) * lerp
			shader.State.Harmonics += (targetState.Harmonics - shader.State.Harmonics) * lerp
			shader.State.HueShift += (targetState.HueShift - shader.State.HueShift) * lerp
			shader.State.Energy += (targetState.Energy - shader.State.Energy) * lerp

			// Render Topological Shader Frame to Terminal
			fmt.Print(shader.Render())
			fmt.Printf("%s[Feed Sentiment State] Chaos: %.2f | Harmonics: %.2f | Hue: %.2f | Speed: %.2f%s",
				ResetColor, shader.State.Chaos, shader.State.Harmonics, shader.State.HueShift, shader.State.Energy, ResetColor)
		}
	}
}