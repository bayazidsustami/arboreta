package main

import (
	"fmt"
	"math"
	"math/cmplx"
	"math/rand"
	"strings"
	"sync"
	"time"
)

// Opcode constants representing instructions in our esoteric bytecode
const (
	OpNop byte = iota
	OpInc
	OpDec
	OpShiftL
	OpShiftR
	OpXor
	OpMultiply
	OpChaos
)

// PoemVerse holds a line of live poetry with its rhythm (syllable cadence) and sentiment score (-1.0 to 1.0)
type PoemVerse struct {
	Text      string
	Rhythm    float64
	Sentiment float64
}

// Interpreter manages program state, bytecode memory, and live poetry stream integration
type Interpreter struct {
	Memory    []byte
	PC        int
	Registers [4]byte
	mu        sync.RWMutex
	Zoom      float64
	OffsetX   float64
	OffsetY   float64
	MaxIter   int
}

// NewInterpreter initializes the interpreter with an esoteric bytecode program
func NewInterpreter(programSize int) *Interpreter {
	mem := make([]byte, programSize)
	// Seed memory with initial instructions
	for i := range mem {
		mem[i] = byte(rand.Intn(8))
	}
	return &Interpreter{
		Memory:  mem,
		Zoom:    1.0,
		MaxIter: 30,
	}
}

// MutateBytecode alters the program's instructions based on poetry rhythm and sentiment
func (interp *Interpreter) MutateBytecode(verse PoemVerse) {
	interp.mu.Lock()
	defer interp.mu.Unlock()

	// Adjust fractal geometry dynamic parameters based on sentiment and rhythm
	interp.Zoom += verse.Sentiment * 0.15
	if interp.Zoom < 0.2 {
		interp.Zoom = 0.2
	}
	interp.OffsetX += math.Cos(verse.Rhythm) * 0.1
	interp.OffsetY += math.Sin(verse.Rhythm) * 0.1

	// Mutate memory cells dynamically based on cadence rhythm
	mutationStep := int(math.Max(1, verse.Rhythm*5))
	for i := 0; i < len(interp.Memory); i += mutationStep {
		if verse.Sentiment > 0 {
			interp.Memory[i] = (interp.Memory[i] + byte(verse.Rhythm*10)) % 8
		} else {
			interp.Memory[i] = (interp.Memory[i] ^ byte(math.Abs(verse.Sentiment)*255)) % 8
		}
	}
}

// ExecuteCycle runs a single step of the self-modifying program execution
func (interp *Interpreter) ExecuteCycle() {
	interp.mu.Lock()
	defer interp.mu.Unlock()

	if len(interp.Memory) == 0 {
		return
	}

	op := interp.Memory[interp.PC]
	regIdx := interp.PC % len(interp.Registers)

	switch op {
	case OpInc:
		interp.Registers[regIdx]++
	case OpDec:
		interp.Registers[regIdx]--
	case OpShiftL:
		interp.Memory[interp.PC] = interp.Registers[regIdx] << 1
	case OpShiftR:
		interp.Memory[interp.PC] = interp.Registers[regIdx] >> 1
	case OpXor:
		interp.Registers[regIdx] ^= interp.Memory[(interp.PC+1)%len(interp.Memory)]
	case OpMultiply:
		interp.Registers[regIdx] *= 3
	case OpChaos:
		// Self-modification: write register value directly into future instruction space
		target := (interp.PC + int(interp.Registers[regIdx])) % len(interp.Memory)
		interp.Memory[target] = interp.Registers[regIdx] % 8
	}

	interp.PC = (interp.PC + 1) % len(interp.Memory)
}

// RenderFractal Canvas renders the memory heap state as a Julia/Mandelbrot morphing fractal canvas
func (interp *Interpreter) RenderFractal(width, height int) string {
	interp.mu.RLock()
	defer interp.mu.RUnlock()

	// Compute complex constant C driven by live register states
	cReal := (float64(interp.Registers[0])/255.0)*2.0 - 1.0
	cImag := (float64(interp.Registers[1])/255.0)*2.0 - 1.0
	c := complex(cReal, cImag)

	// ASCII density ramp for rendering intensity gradients
	asciiRamp := " .:-=+*#%@"
	var sb strings.Builder
	sb.WriteString("\033[H") // Move cursor to top-left for smooth terminal refresh

	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			// Map screen coordinates to complex plane
			zx := (float64(x)/float64(width)-0.5)*3.5/interp.Zoom + interp.OffsetX
			zy := (float64(y)/float64(height)-0.5)*2.0/interp.Zoom + interp.OffsetY
			z := complex(zx, zy)

			// Execute fractal iteration mapped against memory byte influence
			iter := 0
			memByte := float64(interp.Memory[(x+y*width)%len(interp.Memory)]) / 255.0
			for cmplx.Abs(z) <= 2.0 && iter < interp.MaxIter {
				z = z*z + c + complex(memByte*0.1, 0)
				iter++
			}

			// Pick ASCII character and ANSI true-color encoding
			charIdx := (iter * (len(asciiRamp) - 1)) / interp.MaxIter
			r := uint8((iter * 9) % 255)
			g := uint8((int(memByte*255) + iter*4) % 255)
			b := uint8((255 - iter*8) % 255)

			sb.WriteString(fmt.Sprintf("\033[38;2;%d;%d;%dm%c\033[0m", r, g, b, asciiRamp[charIdx]))
		}
		sb.WriteString("\n")
	}
	return sb.String()
}

// Simulated stream generator supplying live poetry verses
func streamPoetry(ch chan<- PoemVerse) {
	verses := []PoemVerse{
		{"Whispering shadows dance in electric night", 0.82, 0.45},
		{"Silent echoes crumble through frozen time", 0.31, -0.65},
		{"Chaos blooms softly under crimson stars", 0.95, 0.80},
		{"Void consumes the lingering spark of hope", 0.15, -0.90},
		{"Golden algorithms sing pure harmony", 0.76, 0.92},
	}
	for {
		for _, v := range verses {
			ch <- v
			time.Sleep(1500 * time.Millisecond)
		}
	}
}

func main() {
	const canvasWidth = 80
	const canvasHeight = 35
	const programSize = canvasWidth * canvasHeight

	interp := NewInterpreter(programSize)
	poetryChan := make(chan PoemVerse)

	go streamPoetry(poetryChan)

	// Clear screen before starting render loop
	fmt.Print("\033[2J")

	var currentVerse PoemVerse
	ticker := time.NewTicker(80 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case v := <-poetryChan:
			currentVerse = v
			interp.MutateBytecode(v)
		case <-ticker.C:
			// Run multiple interpreter execution steps per frame cycle
			for i := 0; i < 50; i++ {
				interp.ExecuteCycle()
			}
			canvas := interp.RenderFractal(canvasWidth, canvasHeight)
			fmt.Print(canvas)
			fmt.Printf("\033[K\033[1;33mVerse:\033[0m %-45s | \033[1;36mRhythm:\033[0m %.2f | \033[1;35mSentiment:\033[0m %.2f\n",
				currentVerse.Text, currentVerse.Rhythm, currentVerse.Sentiment)
		}
	}
}

An informative visual walkthrough on implementing Mandelbrot fractal rendering in Go can be found in [ASCII Art in 5 mins - Golang](https://www.youtube.com/watch?v=27-KA5oAUoY). This video demonstrates mapping complex coordinates into terminal ASCII representations, which mirrors the color-rendering logic used in the program's fractal canvas above.
http://googleusercontent.com/youtube_content/1