package main

import (
	"context"
	"crypto/sha256"
	"encoding/binary"
	"fmt"
	"log"
	"math"
	"math/rand"
	"os"
	"os/exec"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"[github.com/gordonklaus/portaudio](https://github.com/gordonklaus/portaudio)"
)

const (
	sampleRate = 44100
	bufSize    = 1024
	width      = 80
	height     = 30
)

// Voice represents an ambient synthesizer voice triggered by a git commit.
type Voice struct {
	freq       float64
	phase      float64
	amplitude  float64
	decay      float64
	filterCut  float64
	filterState float64
	pan        float64
	active     bool
}

// Synthesizer manages polyphonic audio generation and Git stream processing.
type Synth struct {
	mu     sync.Mutex
	voices []Voice
	time   float64
	
	// Flow field state
	field     [][]float64
	particles []Particle
}

type Particle struct {
	x, y   float64
	vx, vy float64
	age    int
	maxAge int
	char   rune
}

func main() {
	portaudio.Initialize()
	defer portaudio.Terminate()

	synth := NewSynth()

	// Audio stream setup
	stream, err := portaudio.OpenDefaultStream(0, 2, sampleRate, bufSize, synth.processAudio)
	if err != nil {
		log.Fatalf("PortAudio Stream Error: %v", err)
	}
	defer stream.Close()

	if err := stream.Start(); err != nil {
		log.Fatalf("PortAudio Start Error: %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		cancel()
	}()

	// Start reading commit history
	commits := make(chan Commit)
	go synth.streamGitCommits(ctx, commits)

	// Main event & visual render loop
	ticker := time.NewTicker(40 * time.Millisecond) // ~25 FPS
	defer ticker.Stop()

	// Hide cursor
	fmt.Print("\033[?25l\033[2J")
	defer fmt.Print("\033[?25h\033[0m\033[2J\033[H")

	for {
		select {
		case <-ctx.Done():
			return
		case commit, ok := <-commits:
			if !ok {
				// Loop or end
				time.Sleep(2 * time.Second)
				return
			}
			synth.TriggerCommitVoice(commit)
		case <-ticker.C:
			synth.UpdateFlowField()
			synth.RenderFrame()
		}
	}
}

type Commit struct {
	Hash     string
	Author   string
	Message  string
	Timestamp int64
}

func NewSynth() *Synth {
	field := make([][]float64, height)
	for i := range field {
		field[i] = make([]float64, width)
	}

	s := &Synth{
		voices:    make([]Voice, 12),
		field:     field,
		particles: make([]Particle, 0),
	}
	return s
}

// Synthesizes dynamic stereo PCM audio buffers.
func (s *Synth) processAudio(out [][]float32) {
	s.mu.Lock()
	defer s.mu.Unlock()

	left := out[0]
	right := out[1]

	for i := 0; i < len(left); i++ {
		s.time += 1.0 / sampleRate
		var outL, outR float64

		// Add subtle ambient drone
		droneBase := 55.0 // A1
		drone := (math.Sin(2*math.Pi*droneBase*s.time) + 0.5*math.Sin(2*math.Pi*(droneBase*1.5)*s.time)) * 0.05
		outL += drone
		outR += drone

		for v := range s.voices {
			voice := &s.voices[v]
			if !voice.active {
				continue
			}

			// Oscillator with soft sine/saw hybrid
			voice.phase += voice.freq / sampleRate
			if voice.phase > 1.0 {
				voice.phase -= 1.0
			}

			rawWave := math.Sin(2 * math.Pi * voice.phase)
			
			// Simple Low-Pass Filter
			voice.filterState += voice.filterCut * (rawWave - voice.filterState)
			sample := voice.filterState * voice.amplitude

			// Stereo panning
			outL += sample * math.Cos(voice.pan*math.Pi/4.0)
			outR += sample * math.Sin(voice.pan*math.Pi/4.0)

			// Exponential decay envelope
			voice.amplitude *= voice.decay
			if voice.amplitude < 0.0001 {
				voice.active = false
			}
		}

		// Master limiting
		left[i] = float32(math.Tanh(outL))
		right[i] = float32(math.Tanh(outR))
	}
}

// Translates commit metadata into audio synthesis parameters and visual disturbances.
func (s *Synth) TriggerCommitVoice(c Commit) {
	s.mu.Lock()
	defer s.mu.Unlock()

	// Hash parsing for deterministic music generation
	h := sha256.Sum256([]byte(c.Hash))
	val1 := binary.BigEndian.Uint32(h[0:4])
	val2 := binary.BigEndian.Uint32(h[4:8])

	// Pentatonic scale frequency calculation
	pentatonic := []float64{146.83, 164.81, 196.00, 220.00, 293.66, 329.63, 392.00, 440.00, 587.33}
	noteIndex := int(val1) % len(pentatonic)
	freq := pentatonic[noteIndex]

	// Find available voice channel
	voiceIdx := -1
	for i := range s.voices {
		if !s.voices[i].active {
			voiceIdx = i
			break
		}
	}
	if voiceIdx == -1 {
		voiceIdx = rand.Intn(len(s.voices))
	}

	pan := float64(val2%100) / 100.0
	s.voices[voiceIdx] = Voice{
		freq:        freq,
		phase:       0,
		amplitude:   0.4,
		decay:       0.99992,
		filterCut:   0.05 + float64(len(c.Message)%50)*0.005,
		filterState: 0,
		pan:         pan,
		active:      true,
	}

	// Spawn fractal flow field particles based on commit info
	px := float64(val1 % uint32(width))
	py := float64(val2 % uint32(height))
	chars := []rune{'*', 'o', '~', '•', '+', 'x', '≈', '░', '▒'}

	for i := 0; i < 15; i++ {
		s.particles = append(s.particles, Particle{
			x:      px + (rand.Float64()*4 - 2),
			y:      py + (rand.Float64()*4 - 2),
			vx:     (rand.Float64() - 0.5) * 2,
			vy:     (rand.Float64() - 0.5) * 2,
			age:    0,
			maxAge: 30 + rand.Intn(40),
			char:   chars[rand.Intn(len(chars))],
		})
	}
}

// Reads real git commit log from the current repository.
func (s *Synth) streamGitCommits(ctx context.Context, out chan<- Commit) {
	defer close(out)

	cmd := exec.CommandContext(ctx, "git", "log", "--pretty=format:%H|%an|%at|%s", "-n", "100")
	bytes, err := cmd.Output()
	
	// Fallback to synthetic streams if not in a git repository
	if err != nil || len(bytes) == 0 {
		s.generateSyntheticCommits(ctx, out)
		return
	}

	lines := strings.Split(string(bytes), "\n")
	for _, line := range lines {
		parts := strings.Split(line, "|")
		if len(parts) < 4 {
			continue
		}
		ts, _ := strconv.ParseInt(parts[2], 10, 64)
		
		select {
		case <-ctx.Done():
			return
		case out <- Commit{Hash: parts[0], Author: parts[1], Timestamp: ts, Message: parts[3]}:
		}

		time.Sleep(250 * time.Millisecond) // Rhythm spacing
	}
}

func (s *Synth) generateSyntheticCommits(ctx context.Context, out chan<- Commit) {
	i := 0
	for {
		select {
		case <-ctx.Done():
			return
		default:
			i++
			h := sha256.Sum256([]byte(fmt.Sprintf("commit-%d-%d", i, time.Now().UnixNano())))
			hashStr := fmt.Sprintf("%x", h)
			out <- Commit{
				Hash:      hashStr,
				Author:    "Algorithmic Composer",
				Message:   fmt.Sprintf("Synthetic audio-visual impulse cluster #%d", i),
				Timestamp: time.Now().Unix(),
			}
			time.Sleep(300 * time.Millisecond)
		}
	}
}

// Computes dynamic fractal soundscape-flow field vectors.
func (s *Synth) UpdateFlowField() {
	s.mu.Lock()
	defer s.mu.Unlock()

	t := s.time * 0.5
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			// Mathematical fractal-like vector synthesis (Julia/Trig deformation)
			fx := (float64(x)/float64(width))*3.0 - 1.5
			fy := (float64(y)/float64(height))*3.0 - 1.5
			
			angle := math.Sin(fx*2.0+t) + math.Cos(fy*2.0-t) + math.Sin(fx*fy*1.5)
			s.field[y][x] = angle
		}
	}

	// Update active particle positions using the flow field vectors
	alive := s.particles[:0]
	for _, p := range s.particles {
		p.age++
		if p.age >= p.maxAge {
			continue
		}

		ix := int(p.x)
		iy := int(p.y)
		if ix >= 0 && ix < width && iy >= 0 && iy < height {
			angle := s.field[iy][ix]
			p.vx = p.vx*0.8 + math.Cos(angle)*0.2
			p.vy = p.vy*0.8 + math.Sin(angle)*0.2
		}

		p.x += p.vx
		p.y += p.vy
		alive = append(alive, p)
	}
	s.particles = alive
}

// Render dynamic ANSI terminal visual output.
func (s *Synth) RenderFrame() {
	s.mu.Lock()
	defer s.mu.Unlock()

	buffer := make([][]rune, height)
	colorBuf := make([][]string, height)
	for i := range buffer {
		buffer[i] = make([]rune, width)
		colorBuf[i] = make([]string, width)
		for j := range buffer[i] {
			buffer[i][j] = ' '
			colorBuf[i][j] = "\033[0m"
		}
	}

	// Draw fractal background density
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			val := s.field[y][x]
			if val > 1.2 {
				buffer[y][x] = '.'
				colorBuf[y][x] = "\033[38;5;236m"
			} else if val < -1.2 {
				buffer[y][x] = '·'
				colorBuf[y][x] = "\033[38;5;238m"
			}
		}
	}

	// Render flow field particles
	for _, p := range s.particles {
		ix := int(p.x)
		iy := int(p.y)
		if ix >= 0 && ix < width && iy >= 0 && iy < height {
			buffer[iy][ix] = p.char
			// Dynamic visual spectrum mapping based on particle age
			lifeRatio := float64(p.age) / float64(p.maxAge)
			if lifeRatio < 0.3 {
				colorBuf[iy][ix] = "\033[1;36m" // Cyan highlight
			} else if lifeRatio < 0.7 {
				colorBuf[iy][ix] = "\033[0;34m" // Deep Blue
			} else {
				colorBuf[iy][ix] = "\033[0;35m" // Magenta fade
			}
		}
	}

	// Build console screen output
	var sb strings.Builder
	sb.WriteString("\033[H") // Move cursor home
	sb.WriteString("\033[1;33m=== GIT COMMIT SYNTHESIZER & FRACTAL FLOW FIELD ===\033[0m\n")

	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			sb.WriteString(colorBuf[y][x])
			sb.WriteRune(buffer[y][x])
		}
		sb.WriteByte('\n')
	}

	sb.WriteString("\033[36mActive Voices: ")
	activeCount := 0
	for _, v := range s.voices {
		if v.active {
			activeCount++
		}
	}
	sb.WriteString(fmt.Sprintf("%d/12 | Particles: %d\033[0m\n", activeCount, len(s.particles)))

	fmt.Print(sb.String())
}