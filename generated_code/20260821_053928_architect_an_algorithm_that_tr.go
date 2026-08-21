import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"math"
	"math/rand"
	"strings"
	"time"
)

// StructuralTapestry encapsulates the AST-derived tapestry state.
type StructuralTapestry struct {
	Width, Height int
	Grid          [][]rune
	Nodes         map[string]int
	UnusedVars    int
	MemoryLeaks   int
}

// NewStructuralTapestry analyzes Go code and initializes the visual fabric.
func NewStructuralTapestry(src string, w, h int) (*StructuralTapestry, error) {
	fset := token.NewFileSet()
	node, err := parser.ParseFile(fset, "src.go", src, parser.ParseComments)
	if err != nil {
		return nil, err
	}

	st := &StructuralTapestry{
		Width:  w,
		Height: h,
		Grid:   make([][]rune, h),
		Nodes:  make(map[string]int),
	}
	for i := range st.Grid {
		st.Grid[i] = make([]rune, w)
		for j := range st.Grid[i] {
			st.Grid[i][j] = ' '
		}
	}

	// Traverses the AST to measure structural frequency, decay, and leak patterns.
	declaredVars := make(map[string]bool)
	usedVars := make(map[string]bool)

	ast.Inspect(node, func(n ast.Node) bool {
		if n == nil {
			return true
		}
		// Measure node structural frequency
		st.Nodes[fmt.Sprintf("%T", n)]++

		// Track unused variable candidates
		if v, ok := n.(*ast.ValueSpec); ok {
			for _, id := range v.Names {
				declaredVars[id.Name] = true
			}
		}
		if id, ok := n.(*ast.Ident); ok {
			usedVars[id.Name] = true
		}

		// Detect memory leak heuristics (e.g., long-lived slice appends or missing releases)
		if call, ok := n.(*ast.CallExpr); ok {
			if fun, ok := call.Fun.(*ast.Ident); ok && fun.Name == "append" {
				st.MemoryLeaks++
			}
		}
		return true
	})

	for v := range declaredVars {
		if !usedVars[v] && v != "_" {
			st.UnusedVars++
		}
	}

	return st, nil
}

// Weave constructs the self-organizing digital tapestry.
func (st *StructuralTapestry) Weave() {
	// 1. Structural Frequency Waves (Background Tapestry)
	freqTotal := 0
	for _, count := range st.Nodes {
		freqTotal += count
	}

	for y := 0; y < st.Height; y++ {
		for x := 0; x < st.Width; x++ {
			nx := float64(x) / float64(st.Width)
			ny := float64(y) / float64(st.Height)
			wave := math.Sin(nx*10.0+float64(freqTotal)) * math.Cos(ny*10.0+float64(freqTotal))
			if wave > 0.3 {
				st.Grid[y][x] = '░'
			} else if wave > -0.3 {
				st.Grid[y][x] = '▒'
			} else {
				st.Grid[y][x] = '▓'
			}
		}
	}

	// 2. Visual Decay of Unused Variables (Withering ash & dust)
	rand.Seed(time.Now().UnixNano())
	decayChars := []rune{'·', '.', '`', ' '}
	for i := 0; i < st.UnusedVars*12; i++ {
		rx := rand.Intn(st.Width)
		ry := rand.Intn(st.Height)
		st.Grid[ry][rx] = decayChars[rand.Intn(len(decayChars))]
	}

	// 3. Blooming Fractal Memory Leaks (Julia set blooms blooming in memory)
	bloomPoints := st.MemoryLeaks + 1
	for b := 0; b < bloomPoints; b++ {
		cx := rand.Float64()*0.4 - 0.7
		cy := rand.Float64()*0.4 + 0.27015
		
		for y := 0; y < st.Height; y++ {
			for x := 0; x < st.Width; x++ {
				zx := 1.5 * (float64(x) - float64(st.Width)/2) / (0.5 * float64(st.Width))
				zy := (float64(y) - float64(st.Height)/2) / (0.5 * float64(st.Height))
				
				i := 0
				maxIter := 15
				for zx*zx+zy*zy < 4 && i < maxIter {
					tmp := zx*zx - zy*zy + cx
					zy = 2*zx*zy + cy
					zx = tmp
					i++
				}
				
				if i < maxIter && i > 3 {
					fractalGiphy := []rune{'❀', '❁', '❄', '✼', '☸', '❖'}
					st.Grid[y][x] = fractalGiphy[i%len(fractalGiphy)]
				}
			}
		}
	}
}

// Render outputs the visual weave to stdout.
func (st *StructuralTapestry) Render() {
	var sb strings.Builder
	for _, row := range st.Grid {
		sb.WriteString(string(row) + "\n")
	}
	fmt.Print(sb.String())
}

func main() {
	// Sample Go source code passed to the structural tapestry translator
	sampleSource := `
package main

import "fmt"

var unusedGlobal string

func leakMemory() {
	var unusedLocal int
	cache := []string{}
	for i := 0; i < 1000; i++ {
		cache = append(cache, "blooming fractal memory leak node")
	}
}

func main() {
	fmt.Println("Digital Tapestry")
}
`

	tapestry, err := NewStructuralTapestry(sampleSource, 80, 24)
	if err != nil {
		fmt.Printf("Error parsing AST: %v\n", err)
		return
	}

	tapestry.Weave()
	tapestry.Render()
}