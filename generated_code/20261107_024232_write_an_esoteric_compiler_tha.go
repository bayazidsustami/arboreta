// Package main implements an esoteric compiler translating Jupiter's simulated
// atmospheric telemetry into a self-mutating Lisp interpreter for fractal poetry.
package main

import (
	"fmt"
	"math"
	"math/rand"
	"time"
)

// JupiterPressure simulates real-time atmospheric pressure telemetry from Jupiter (in bars).
// At 1 bar level, it hovers around 2.4 bars, fluctuating with Jovian storm dynamics.
func JupiterPressure() float64 {
	t := float64(time.Now().UnixNano()) / 1e9
	return 2.4 + 1.2*math.Sin(t*0.5) + 0.3*math.Cos(t*1.7)
}

// LispValue represents an AST node or value in our micro-Lisp.
type LispValue struct {
	Type   string // "list", "symbol", "number"
	Val    string
	List   []*LispValue
	Mutate float64
}

// EsotericCompiler compiles Jupiter pressure into execution mutation rules.
type EsotericCompiler struct {
	PressureFactor float64
}

func NewEsotericCompiler(pressure float64) *EsotericCompiler {
	return &EsotericCompiler{PressureFactor: pressure}
}

// MutateAST applies self-mutation based on Jovian pressure distortion.
func (c *EsotericCompiler) MutateAST(node *LispValue) {
	if node == nil {
		return
	}
	node.Mutate = c.PressureFactor
	if node.Type == "list" && len(node.List) > 0 {
		// Self-mutation: under high pressure, duplicate elements to expand structural resonance
		if c.PressureFactor > 3.0 && len(node.List) > 1 {
			node.List = append(node.List, node.List[0])
		}
		for _, child := range node.List {
			c.MutateAST(child)
		}
	}
}

// EvalFractalPoetry executes the mutated Lisp program semantics to produce recursive poetry.
func EvalFractalPoetry(depth int, vocab []string, r *rand.Rand) string {
	if depth <= 0 {
		return vocab[r.Intn(len(vocab))]
	}
	word1 := vocab[r.Intn(len(vocab))]
	word2 := vocab[r.Intn(len(vocab))]
	sub := EvalFractalPoetry(depth-1, vocab, r)
	return fmt.Sprintf("%s (%s [%s])", word1, sub, word2)
}

func main() {
	pressure := JupiterPressure()
	fmt.Printf("--- JOVIAN TELEMETRY ACQUIRED ---\n")
	fmt.Printf("Atmospheric Pressure: %.4f bars\n", pressure)

	compiler := NewEsotericCompiler(pressure)

	// Base Lisp AST representing a fractal poetry generator routine
	ast := &LispValue{
		Type: "list",
		List: []*LispValue{
			{Type: "symbol", Val: "define"},
			{Type: "symbol", Val: "fractal-verse"},
			{
				Type: "list",
				List: []*LispValue{
					{Type: "symbol", Val: "storm"},
					{Type: "symbol", Val: "hydrogen"},
					{Type: "symbol", Val: "vortex"},
				},
			},
		},
	}

	// Compile and self-mutate AST based on pressure
	compiler.MutateAST(ast)

	vocab := []string{"cyclone", "ammonia", "belt", "zone", "magnetosphere", "radiance", "abyss", "storm"}

	fmt.Printf("\n--- COMPILING SELF-MUTATING LISP AST ---\n")
	fmt.Printf("Mutation Factor Applied: %.4f\n", ast.Mutate)

	fmt.Printf("\n--- FRACTAL POETRY EMISSION ---\n")
	rng := rand.New(rand.NewSource(int64(pressure * 1000)))
	for i := 1; i <= 3; i++ {
		poem := EvalFractalPoetry(i, vocab, rng)
		fmt.Printf("Verse %d: %s\n", i, poem)
	}
}