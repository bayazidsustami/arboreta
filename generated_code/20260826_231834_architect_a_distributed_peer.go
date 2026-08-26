package main

import (
	"fmt"
	"math"
	"net"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"
)

// Global state tracking lattice state, latency metrics, and user audio parameters.
type Synthesizer struct {
	mu            sync.RWMutex
	latencyMs     float64
	asciiPalette  string
	audioParams   map[string]float64
	peers         []string
}

func NewSynthesizer(peers []string) *Synthesizer {
	return &Synthesizer{
		asciiPalette: " .:-=+*#%@",
		audioParams:  map[string]float64{"harmonic": 1.0, "resonance": 0.5, "tempo": 120},
		peers:        peers,
	}
}

// Evaluates user-submitted poetic DSL lines into synthesis control parameters.
func (s *Synthesizer) ParsePoeticCode(poem string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	lines := strings.Split(poem, "\n")
	for _, line := range lines {
		words := strings.Fields(line)
		for _, w := range words {
			val := float64(len(w))
			switch {
			case strings.Contains(w, "whisper"):
				s.audioParams["resonance"] = math.Min(1.0, val/10.0)
			case strings.Contains(w, "echo"):
				s.audioParams["harmonic"] = val * 0.5
			case strings.Contains(w, "pulse"):
				s.audioParams["tempo"] = 60.0 + val*10.0
			}
		}
	}
}

// Pings peer nodes to measure round-trip network latency fluctuations.
func (s *Synthesizer) MeasurePeerLatency() {
	for {
		if len(s.peers) == 0 {
			// Simulate latency oscillation when no peers are reachable
			t := float64(time.Now().UnixNano()) / 1e9
			s.mu.Lock()
			s.latencyMs = 20.0 + 15.0*math.Sin(t*0.5)
			s.mu.Unlock()
			time.Sleep(200 * time.Millisecond)
			continue
		}

		for _, peer := range s.peers {
			start := time.Now()
			conn, err := net.DialTimeout("tcp", peer, 500*time.Millisecond)
			if err == nil {
				conn.Close()
				rtt := float64(time.Since(start).Microseconds()) / 1000.0
				s.mu.Lock()
				s.latencyMs = rtt
				s.mu.Unlock()
			}
			time.Sleep(300 * time.Millisecond)
		}
	}
}

// Generates and renders a dynamic ASCII mandala driven by network latency.
func (s *Synthesizer) RenderMandala(width, height int) {
	s.mu.RLock()
	lat := s.latencyMs
	res := s.audioParams["resonance"]
	harm := s.audioParams["harmonic"]
	s.mu.RUnlock()

	t := float64(time.Now().UnixNano()) / 1e9
	palette := []rune(s.asciiPalette)
	pLen := float64(len(palette))

	var builder strings.Builder
	builder.WriteString("\033[H") // Clear screen / reposition cursor

	cx, cy := float64(width)/2.0, float64(height)/2.0

	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			dx := (float64(x) - cx) / cx
			dy := (float64(y) - cy) / cy
			
			r := math.Hypot(dx, dy)
			theta := math.Atan2(dy, dx)

			// Polar transformation scaled by peer latency and audio resonance
			wave := math.Sin(r*lat*0.2 - t*3.0) 
			petals := math.Cos(theta * harm * 4.0)
			val := (wave + petals + math.Sin(r*res*10.0)) / 3.0

			norm := (val + 1.0) / 2.0 // Normalize to [0, 1]
			idx := int(norm * pLen)
			if idx < 0 {
				idx = 0
			} else if idx >= len(palette) {
				idx = len(palette) - 1
			}

			builder.WriteRune(palette[idx])
		}
		builder.WriteString("\n")
	}

	fmt.Print(builder.String())
}

func main() {
	syn := NewSynthesizer([]string{"127.0.0.1:8080"})

	// Process sample poetic code input
	syn.ParsePoeticCode(`
		a soft whisper in the cosmic dark
		echoes through space as pulse quickens
	`)

	// Hide cursor & setup clear terminal canvas
	fmt.Print("\033[?25l\033[2J")
	defer fmt.Print("\033[?25h")

	go syn.MeasurePeerLatency()

	// Capture interrupt signal for graceful teardown
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)

	ticker := time.NewTicker(50 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-stop:
			fmt.Println("\nLattice synthesis terminated.")
			return
		case <-ticker.C:
			syn.RenderMandala(60, 30)
		}
	}
}