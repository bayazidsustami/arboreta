package main

import (
	"fmt"
	"math"
	"math/rand"
	"time"
)

// StackVM represents an esoteric stack-based execution engine where memory state
// directly modulates a dynamic ASCII fluid simulation and streams a MIDI arpeggio.
type StackVM struct {
	stack []int
	heap  [16][32]float64
	pc    int
	code  []rune
	notes []int
}

func NewVM(program string) *StackVM {
	return &StackVM{
		stack: make([]int, 0),
		code:  []rune(program),
		notes: []int{60, 62, 64, 67, 69, 72, 74, 76, 79, 81, 84}, // C Major Pentatonic
	}
}

// Step executes a single opcode, mutating the stack and memory fluid dynamics
func (vm *StackVM) Step() bool {
	if vm.pc >= len(vm.code) {
		return false
	}
	op := vm.code[vm.pc]
	vm.pc++

	switch op {
	case '+':
		if len(vm.stack) >= 2 {
			vm.push(vm.pop() + vm.pop())
		}
	case '*':
		if len(vm.stack) >= 2 {
			vm.push(vm.pop() * vm.pop())
		}
	case ':': // Duplicate stack top
		if len(vm.stack) > 0 {
			vm.push(vm.stack[len(vm.stack)-1])
		}
	case '~': // Fluid Injection: Pops Y, X coordinates and injects energy density into memory
		if len(vm.stack) >= 2 {
			y := abs(vm.pop()) % 16
			x := abs(vm.pop()) % 32
			vm.heap[y][x] += 12.0
		}
	case '>': // Push random value onto stack
		vm.push(rand.Intn(100))
	default:
		if op >= '0' && op <= '9' {
			vm.push(int(op - '0'))
		}
	}

	vm.updateFluidSimulation()
	return true
}

func (vm *StackVM) push(v int) { vm.stack = append(vm.stack, v) }
func (vm *StackVM) pop() int {
	if len(vm.stack) == 0 {
		return 0
	}
	v := vm.stack[len(vm.stack)-1]
	vm.stack = vm.stack[:len(vm.stack)-1]
	return v
}

// updateFluidSimulation diffuses memory density across adjacent heap addresses
func (vm *StackVM) updateFluidSimulation() {
	var next [16][32]float64
	for y := 1; y < 15; y++ {
		for x := 1; x < 31; x++ {
			avg := (vm.heap[y-1][x] + vm.heap[y+1][x] + vm.heap[y][x-1] + vm.heap[y][x+1]) / 4.0
			next[y][x] = (vm.heap[y][x]*0.55 + avg*0.45) * 0.95
		}
	}
	vm.heap = next
}

// Render displays real-time ASCII fluid visualizer and active MIDI arpeggio state
func (vm *StackVM) Render() {
	fmt.Print("\033[H\033[2J") // Terminal ANSI reset
	fmt.Println("╔══════════════════════════════════════════════════════════════╗")
	fmt.Println("║  ESOTERIC VM: STACK EXECUTOR & MIDI FLUID MEMORY VISUALIZER  ║")
	fmt.Println("╚══════════════════════════════════════════════════════════════╝")

	densityChars := []rune(" .:-=+*#%@")
	fmt.Println("\n┌─ Dynamic Memory Heap (Fluid Density) ─────────┐")
	for y := 0; y < 16; y++ {
		fmt.Print("│ ")
		for x := 0; x < 32; x++ {
			idx := int(math.Min(float64(len(densityChars)-1), math.Max(0, vm.heap[y][x])))
			fmt.Printf("%c", densityChars[idx])
		}
		fmt.Println(" │")
	}
	fmt.Println("└───────────────────────────────────────────────┘")

	midiPitch := 60
	if len(vm.stack) > 0 {
		midiPitch = vm.notes[abs(vm.stack[len(vm.stack)-1])%len(vm.notes)]
	}

	fmt.Printf("\n[Stack Engine State] : %v\n", vm.stack)
	fmt.Printf("[Real-Time MIDI Note] : Pitch #%d (%s)\n", midiPitch, pitchName(midiPitch))
	fmt.Printf("[Arpeggio Visualizer] : %s\n", renderArpeggio(midiPitch))
}

func pitchName(p int) string {
	names := []string{"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
	return fmt.Sprintf("%s%d", names[p%12], (p/12)-1)
}

func renderArpeggio(pitch int) string {
	bar := ""
	for note := 60; note <= 84; note += 2 {
		if note == pitch {
			bar += "█"
		} else {
			bar += "─"
		}
	}
	return bar
}

func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}

func main() {
	// Program code injecting fluid energy, manipulating arithmetic and stack state
	program := "84+>7~:3*+~>9+~:2*~>5*+~"
	vm := NewVM(program)

	for {
		if !vm.Step() {
			vm.pc = 0 // Continuous execution loop
		}
		vm.Render()
		time.Sleep(100 * time.Millisecond)
	}
}