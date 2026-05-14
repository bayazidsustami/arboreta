package main

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

// EsolangDefinition defines the mapping of punctuation to stack operations.
// This esolang uses a stack-based architecture.
type EsolangDefinition struct {
	PunctuationMap map[rune]string
	Instructions   map[string]func(stack *[]int)
}

// VM represents the Virtual Machine state.
type VM struct {
	stack []int
}

func main() {
	// The Input Poem
	// Punctuation rules:
	// , -> Push 1
	// . -> Pop
	// ! -> Duplicate top
	// ? -> Add top two
	// ; -> Multiply top two
	// : -> Clear stack
	poem := `Soft rain falls,
Quietly it descends.
Life grows!
Deeply?
Darkness;
Silence:`

	// Define the language semantics
	def := EsolangDefinition{
		PunctuationMap: map[rune]string{
			',': "PUSH_1",
			'.': "POP",
			'!': "DUP",
			'?': "ADD",
			';': "MUL",
			':': "CLEAR",
		},
	}

	fmt.Println("--- Original Poem ---")
	fmt.Println(poem)
	fmt.Println("\n--- Executing Esolang Logic ---")

	// 1. Transpilation Phase: Convert poem to instruction stream
	instructions := transpile(poem, def.PunctuationMap)
	fmt.Printf("Instruction Stream: %v\n", instructions)

	// 2. Execution Phase: Run the instructions on the VM
	vm := &VM{stack: []int{}}
	execute(instructions, vm)

	// 3. Output Result
	fmt.Printf("\nFinal Stack State: %v\n", vm.stack)
}

// transpile extracts punctuation from the poem and maps them to command strings.
func transpile(input string, mapping map[rune]string) []string {
	var program []string
	for _, char := range input {
		if cmd, ok := mapping[char]; ok {
			program = append(program, cmd)
		}
	}
	return program
}

// execute processes the instruction stream using the VM.
func execute(program []string, vm *VM) {
	for _, instr := range program {
		switch instr {
		case "PUSH_1":
			vm.stack = append(vm.stack, 1)
		case "POP":
			if len(vm.stack) > 0 {
				vm.stack = vm.stack[:len(vm.stack)-1]
			}
		case "DUP":
			if len(vm.stack) > 0 {
				top := vm.stack[len(vm.stack)-1]
				vm.stack = append(vm.stack, top)
			}
		case "ADD":
			if len(vm.stack) >= 2 {
				a := vm.stack[len(vm.stack)-1]
				b := vm.stack[len(vm.stack)-2]
				vm.stack = vm.stack[:len(vm.stack)-2]
				vm.stack = append(vm.stack, a+b)
			}
		case "MUL":
			if len(vm.stack) >= 2 {
				a := vm.stack[len(vm.stack)-1]
				b := vm.stack[len(vm.stack)-2]
				vm.stack = vm.stack[:len(vm.stack)-2]
				vm.stack = append(vm.stack, a*b)
			}
		case "CLEAR":
			vm.stack = []int{}
		}
	}
}