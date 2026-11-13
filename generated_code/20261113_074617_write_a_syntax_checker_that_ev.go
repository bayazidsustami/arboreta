package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"math/rand"
	"os"
)

// ASTMetrics stores structural properties extracted from the source code AST.
type ASTMetrics struct {
	Nodes       int
	MaxDepth    int
	Funcs       int
	Stmts       int
	Exprs       int
	Identifiers int
}

// visitor implements ast.Visitor to traverse the AST and collect structural metrics.
type visitor struct {
	metrics ASTMetrics
	depth   int
}

func (v *visitor) Visit(node ast.Node) ast.Visitor {
	if node == nil {
		v.depth--
		return nil
	}
	v.depth++
	v.metrics.Nodes++
	if v.depth > v.metrics.MaxDepth {
		v.metrics.MaxDepth = v.depth
	}

	switch node.(type) {
	case *ast.FuncDecl:
		v.metrics.Funcs++
	case ast.Stmt:
		v.metrics.Stmts++
	case ast.Expr:
		v.metrics.Exprs++
	case *ast.Ident:
		v.metrics.Identifiers++
	}
	return v
}

// GenerateFern simulates the Barnsley fern influenced by AST metrics and calculates aesthetic scores.
func GenerateFern(m ASTMetrics) (float64, [][]bool) {
	seed := int64(m.Nodes*31 + m.MaxDepth*17 + m.Funcs*7)
	rng := rand.New(rand.NewSource(seed))

	const iterations = 40000
	x, y := 0.0, 0.0

	const width, height = 60, 25
	grid := make([][]bool, height)
	for i := range grid {
		grid[i] = make([]bool, width)
	}

	minX, maxX := -2.1820, 2.6558
	minY, maxY := 0.0, 9.9983

	pointsInBounds := 0
	for i := 0; i < iterations; i++ {
		r := rng.Float64()
		var nx, ny float64

		mod := float64(m.Stmts) / float64(m.Nodes+1) * 0.005

		if r < 0.01 {
			nx = 0
			ny = 0.16 * y
		} else if r < 0.86+mod {
			nx = 0.85*x + 0.04*y
			ny = -0.04*x + 0.85*y + 1.6
		} else if r < 0.93 {
			nx = 0.2*x - 0.26*y
			ny = 0.23*x + 0.22*y + 1.6
		} else {
			nx = -0.15*x + 0.28*y
			ny = 0.26*x + 0.24*y + 0.44
		}
		x, y = nx, ny

		gx := int(float64(width-1) * (x - minX) / (maxX - minX))
		gy := int(float64(height-1) * (maxY - y) / (maxY - minY))

		if gx >= 0 && gx < width && gy >= 0 && gy < height {
			grid[gy][gx] = true
			pointsInBounds++
		}
	}

	score := float64(pointsInBounds) / float64(iterations) * 100.0
	return score, grid
}

func main() {
	srcCode := `package main
import "fmt"
func main() {
    fmt.Println("Aesthetically pleasing botanical syntax tree!")
}`

	if len(os.Args) > 1 {
		if content, err := os.ReadFile(os.Args[1]); err == nil {
			srcCode = string(content)
		}
	} else if content, err := os.ReadFile("main.go"); err == nil {
		srcCode = string(content)
	}

	fset := token.NewFileSet()
	node, err := parser.ParseFile(fset, "source.go", srcCode, parser.AllErrors)
	if err != nil {
		fmt.Printf("SYNTAX ERROR: Fern withered due to parse failure: %v\n", err)
		os.Exit(1)
	}

	v := &visitor{}
	ast.Walk(v, node)

	score, grid := GenerateFern(v.metrics)

	fmt.Println("=== BOTANICAL AST SYNTAX & AESTHETICS CHECKER ===")
	fmt.Printf("AST Nodes: %d | Max Depth: %d | Functions: %d | Statements: %d\n",
		v.metrics.Nodes, v.metrics.MaxDepth, v.metrics.Funcs, v.metrics.Stmts)
	fmt.Printf("Aesthetic Fern Score: %.2f/100\n", score)

	if score > 20.0 {
		fmt.Println("VERDICT: PASSED. The AST forms a lush, balanced, structurally gorgeous fern!")
	} else {
		fmt.Println("VERDICT: FAILED. The AST looks like a shriveled weed. Refactor for better foliage.")
		os.Exit(1)
	}

	fmt.Println("\nRendering Fern Visualization:")
	for _, row := range grid {
		for _, lit := range row {
			if lit {
				fmt.Print("*")
			} else {
				fmt.Print(" ")
			}
		}
		fmt.Println()
	}
}