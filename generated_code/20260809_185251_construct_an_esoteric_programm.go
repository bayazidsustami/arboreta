package main

import (
	"fmt"
	"math"
	"strings"
	"unicode"
)

// SonnetVM interprets Shakespearean sonnets as executable code.
// - Rhyme Scheme (ABAB CDCD EFEF GG) maps to stack machine instruction types.
// - Metric Stress Patterns (iambic pentameter) control 2D spatial coordinates
//   and stitch densities for real-time procedural embroidery generation.
type SonnetVM struct {
	stack   []int
	canvas  [][]rune
	width   int
	height  int
	cursorX int
	cursorY int
}

// NewSonnetVM initializes an embroidery canvas and execution environment.
func NewSonnetVM(w, h int) *SonnetVM {
	c := make([][]rune, h)
	for i := range c {
		c[i] = make([]rune, w)
		for j := range c[i] {
			c[i][j] = '.' // Empty fabric weave
		}
	}
	return &SonnetVM{
		stack:   make([]int, 0),
		canvas:  c,
		width:   w,
		height:  h,
		cursorX: w / 2,
		cursorY: h / 2,
	}
}

// Push appends a value onto the VM stack.
func (vm *SonnetVM) Push(v int) {
	vm.stack = append(vm.stack, v)
}

// Pop removes and returns the top value from the VM stack.
func (vm *SonnetVM) Pop() int {
	if len(vm.stack) == 0 {
		return 0
	}
	v := vm.stack[len(vm.stack)-1]
	vm.stack = vm.stack[:len(vm.stack)-1]
	return v
}

// EstimateStress measures the line's metric stress signature (iambic beats).
// Returns alternating stress array (0 = unstressed, 1 = stressed) and total stress weight.
func EstimateStress(line string) ([]int, int) {
	words := strings.Fields(line)
	var stressPattern []int
	totalWeight := 0

	syllableCount := 0
	for _, word := range words {
		vowels := 0
		for _, r := range strings.ToLower(word) {
			if strings.ContainsRune("aeiouy", r) {
				vowels++
			}
		}
		if vowels == 0 {
			vowels = 1
		}
		for i := 0; i < vowels; i++ {
			// Alternate stress heuristic modeling iambic pentameter (da-DUM da-DUM)
			stress := (syllableCount + i) % 2
			stressPattern = append(stressPattern, stress)
			if stress == 1 {
				totalWeight += (i + 1) * 2
			} else {
				totalWeight += 1
			}
		}
		syllableCount += vowels
	}
	return stressPattern, totalWeight
}

// ExtractRhymeKey extracts the phonetic ending tail of a line to categorize rhymes.
func ExtractRhymeKey(line string) string {
	cleaned := ""
	for _, r := range strings.ToLower(line) {
		if unicode.IsLetter(r) {
			cleaned += string(r)
		}
	}
	if len(cleaned) < 3 {
		return cleaned
	}
	return cleaned[len(cleaned)-3:]
}

// ClassifyRhymeScheme maps lines to Shakespearean Sonnet Rhyme Scheme (ABAB CDCD EFEF GG).
func ClassifyRhymeScheme(lines []string) []rune {
	scheme := make([]rune, len(lines))
	keys := make([]string, len(lines))
	for i, l := range lines {
		keys[i] = ExtractRhymeKey(l)
	}

	knownRhymes := make(map[rune]string)
	labels := []rune{'A', 'B', 'C', 'D', 'E', 'F', 'G'}
	labelIdx := 0

	for i := 0; i < len(lines); i++ {
		if scheme[i] != 0 {
			continue
		}
		currentLabel := labels[labelIdx%len(labels)]
		scheme[i] = currentLabel
		knownRhymes[currentLabel] = keys[i]

		// Find rhyming pair (e.g. line 0 with line 2 for ABAB)
		for j := i + 1; j < len(lines); j++ {
			if scheme[j] == 0 && (keys[i] == keys[j] || (len(keys[i]) > 0 && len(keys[j]) > 0 && keys[i][len(keys[i])-2:] == keys[j][len(keys[j])-2:])) {
				scheme[j] = currentLabel
				break
			}
		}
		labelIdx++
	}
	return scheme
}

// EmbroiderStitch renders procedural stitches onto the fabric grid based on stack & stress parameters.
func (vm *SonnetVM) EmbroiderStitch(stress []int, opVal int) {
	stitchChars := []rune{'+', 'x', '*', '#', '@', '%', 'O', 'S'}
	char := stitchChars[abs(opVal)%len(stitchChars)]

	steps := len(stress)
	radius := float64(abs(opVal)%5 + 2)

	for i, s := range stress {
		angle := (float64(i) / float64(steps)) * 2 * math.Pi
		dx := int(math.Round(radius * math.Cos(angle)))
		dy := int(math.Round(radius * math.Sin(angle)))

		if s == 1 {
			// Stressed syllable creates explicit cross-stitch node
			x := (vm.cursorX + dx + vm.width) % vm.width
			y := (vm.cursorY + dy + vm.height) % vm.height
			vm.canvas[y][x] = char
		}
	}

	// Advance cursor based on stress momentum
	vm.cursorX = (vm.cursorX + opVal + len(stress)) % vm.width
	vm.cursorY = (vm.cursorY + len(stress)) % vm.height
}

// ExecuteLine runs the bytecode instruction defined by the rhyme opcode.
func (vm *SonnetVM) ExecuteLine(op rune, stress []int, weight int, lineText string) {
	switch op {
	case 'A': // Push metric weight onto stack
		vm.Push(weight)
		vm.EmbroiderStitch(stress, weight)
	case 'B': // Add top two values
		v1, v2 := vm.Pop(), vm.Pop()
		res := v1 + v2
		vm.Push(res)
		vm.EmbroiderStitch(stress, res)
	case 'C': // Multiply top two values
		v1, v2 := vm.Pop(), vm.Pop()
		res := v1 * v2
		vm.Push(res)
		vm.EmbroiderStitch(stress, res)
	case 'D': // Duplicate top value
		v := vm.Pop()
		vm.Push(v)
		vm.Push(v)
		vm.EmbroiderStitch(stress, v)
	case 'E': // Modulo operation
		v1, v2 := vm.Pop(), vm.Pop()
		if v1 == 0 {
			v1 = 1
		}
		res := v2 % v1
		vm.Push(res)
		vm.EmbroiderStitch(stress, res)
	case 'F': // Push line character count
		val := len(lineText)
		vm.Push(val)
		vm.EmbroiderStitch(stress, val)
	case 'G': // Finalize pattern & weave gold thread border
		v := vm.Pop()
		vm.EmbroiderStitch(stress, v+7)
	}
}

// Render outputs the generated procedural embroidery pattern to terminal.
func (vm *SonnetVM) Render() {
	fmt.Println("┌" + strings.Repeat("─", vm.width) + "┐")
	for _, row := range vm.canvas {
		fmt.Print("│")
		for _, cell := range row {
			fmt.Print(string(cell))
		}
		fmt.Println("│")
	}
	fmt.Println("└" + strings.Repeat("─", vm.width) + "┘")
}

func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}

func main() {
	// A complete 14-line Shakespearean Sonnet (Sonnet 18 variant formatted for execution)
	sonnet := []string{
		"Shall I compare thee to a summer's day?",        // A
		"Thou art more lovely and more temperate:",       // B
		"Rough winds do shake the darling buds of May,",  // A
		"And summer's lease hath all too short a date:",  // B
		"Sometime too hot the eye of heaven shines,",     // C
		"And often is his gold complexion dimm'd;",       // D
		"And every fair from fair sometime declines,",    // C
		"By chance or nature's changing course untrimm'd;", // D
		"But thy eternal summer shall not fade,",         // E
		"Nor lose possession of that fair thou ow'st;",   // F
		"Nor shall Death brag thou wander'st in his shade,", // E
		"When in eternal lines to time thou grow'st:",    // F
		"So long as men can breathe or eyes can see,",    // G
		"So long lives this and this gives life to thee.",// G
	}

	fmt.Println("=== SONNETCODE INTERPRETER ===")
	fmt.Println("Source Code (Shakespearean Sonnet):")
	for i, line := range sonnet {
		fmt.Printf("%02d: %s\n", i+1, line)
	}
	fmt.Println("\nAnalyzing Sonnet Architecture & Metric Stress...")

	rhymeScheme := ClassifyRhymeScheme(sonnet)
	vm := NewSonnetVM(40, 15)

	fmt.Println("\nExecution Trace:")
	fmt.Println("Line | Opcode | Stress Beats | Metric Weight | Stack State")
	fmt.Println("-----+--------+--------------+---------------+----------------")

	for i, line := range sonnet {
		op := rhymeScheme[i]
		stress, weight := EstimateStress(line)
		vm.ExecuteLine(op, stress, weight, line)

		stressStr := ""
		for _, s := range stress {
			if s == 1 {
				stressStr += "/"
			} else {
				stressStr += "-"
			}
		}

		fmt.Printf(" %02d  |   %c    | %-12s | %-13d | %v\n", i+1, op, stressStr, weight, vm.stack)
	}

	fmt.Println("\nGenerated Real-Time Procedural Embroidery Pattern:")
	vm.Render()
}