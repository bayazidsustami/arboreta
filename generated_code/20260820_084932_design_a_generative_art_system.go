package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"math"
	"math/rand"
	"runtime"
	"strings"
	"time"
)

// FuncMetrics stores calculated cyclomatic complexity and node counts for parsed functions.
type FuncMetrics struct {
	Name       string
	Complexity int
	Statements int
}

// ASTParser handles runtime self-inspection of the source code.
type ASTParser struct {
	fset *token.FileSet
}

// ParseSelf inspects this file's AST using runtime.Caller to compute real-time complexity metrics.
func (p *ASTParser) ParseSelf() ([]FuncMetrics, error) {
	_, filename, _, ok := runtime.Caller(0)
	if !ok {
		return nil, fmt.Errorf("unable to locate source file")
	}

	p.fset = token.NewFileSet()
	node, err := parser.ParseFile(p.fset, filename, nil, parser.ParseComments)
	if err != nil {
		return nil, err
	}

	var metrics []FuncMetrics
	ast.Inspect(node, func(n ast.Node) bool {
		fn, ok := n.(*ast.FuncDecl)
		if !ok || fn.Body == nil {
			return true
		}

		// Calculate Cyclomatic Complexity: 1 + decision points
		complexity := 1
		stmtCount := 0

		ast.Inspect(fn.Body, func(cn ast.Node) bool {
			if cn != nil {
				stmtCount++
			}
			switch x := cn.(type) {
			case *ast.IfStmt, *ast.ForStmt, *ast.RangeStmt, *ast.CaseClause, *ast.CommClause:
				complexity++
			case *ast.BinaryExpr:
				if x.Op == token.LAND || x.Op == token.LOR {
					complexity++
				}
			}
			return true
		})

		metrics = append(metrics, FuncMetrics{
			Name:       fn.Name.Name,
			Complexity: complexity,
			Statements: stmtCount,
		})
		return true
	})

	return metrics, nil
}

// VisualLabyrinth renders the dynamic visual representation of the AST and runtime state.
type VisualLabyrinth struct {
	width  int
	height int
	grid   [][]rune
	colors [][]int
}

// NewVisualLabyrinth constructs a grid buffer for rendering.
func NewVisualLabyrinth(w, h int) *VisualLabyrinth {
	g := make([][]rune, h)
	c := make([][]int, h)
	for i := range g {
		g[i] = make([]rune, w)
		c[i] = make([]int, w)
	}
	return &VisualLabyrinth{width: w, height: h, grid: g, colors: c}
}

// Evolve recalculates every wall segment based on AST complexity and current memory allocations.
func (vl *VisualLabyrinth) Evolve(funcs []FuncMetrics, mem runtime.MemStats, tick int) {
	if len(funcs) == 0 {
		return
	}

	wallGlyphs := []rune{'█', '▓', '▒', '░', '╬', '╣', '╩', '╦', '╠', '═', '║'}
	heapAllocMB := float64(mem.HeapAlloc) / 1024.0 / 1024.0

	for y := 0; y < vl.height; y++ {
		for x := 0; x < vl.width; x++ {
			// Map grid cell to an analyzed function based on coordinates and animation frame
			fnIdx := (x*3 + y*7 + tick) % len(funcs)
			fn := funcs[fnIdx]

			// Coordinate wave calculations influenced by cyclomatic complexity
			fx := float64(x) * 0.12
			fy := float64(y) * 0.12
			timeOffset := float64(tick) * 0.07

			// Complexity alters spatial frequency and wall density
			freq := float64(fn.Complexity) * 0.25
			waveVal := math.Sin(fx*freq+timeOffset) + math.Cos(fy*freq-timeOffset) + math.Sin((fx+fy)*0.4+float64(mem.Mallocs%100)*0.01)

			// Live memory heap allocation dynamically modifies structural threshold
			threshold := math.Sin(heapAllocMB*0.4 + float64(fn.Statements)*0.03)

			if waveVal > threshold {
				// Pick glyph based on local complexity and wave amplitude
				glyphIdx := int(math.Abs(waveVal*float64(fn.Complexity))) % len(wallGlyphs)
				vl.grid[y][x] = wallGlyphs[glyphIdx]

				// Dynamic 256-color palette index driven by memory pressure and function AST attributes
				color := 16 + int(uint64(fn.Complexity*18)+mem.Alloc/2048+uint64(x+y+tick))%215
				vl.colors[y][x] = color
			} else {
				vl.grid[y][x] = ' '
				vl.colors[y][x] = 0
			}
		}
	}
}

// Render draws the complete labyrinth state directly to the standard output using standard ANSI sequences.
func (vl *VisualLabyrinth) Render(funcs []FuncMetrics, mem runtime.MemStats, frame int) {
	var sb strings.Builder
	// Move cursor top-left and clear display
	sb.WriteString("\033[H\033[2J")

	sb.WriteString("\033[1;36m=== REAL-TIME AST & MEMORY GENERATIVE LABYRINTH ===\033[0m\n")
	sb.WriteString(fmt.Sprintf("Frame: %-6d | Heap Alloc: %6.2f KB | Total Allocations: %-8d | Functions: %d\n",
		frame, float64(mem.HeapAlloc)/1024.0, mem.Mallocs, len(funcs)))
	sb.WriteString(strings.Repeat("─", vl.width) + "\n")

	for y := 0; y < vl.height; y++ {
		for x := 0; x < vl.width; x++ {
			r := vl.grid[y][x]
			col := vl.colors[y][x]
			if r == ' ' {
				sb.WriteRune(' ')
			} else {
				sb.WriteString(fmt.Sprintf("\033[38;5;%dm%c\033[0m", col, r))
			}
		}
		sb.WriteRune('\n')
	}

	sb.WriteString(strings.Repeat("─", vl.width) + "\n")
	sb.WriteString("Parsed AST Cyclomatic Complexities: ")
	for _, f := range funcs {
		sb.WriteString(fmt.Sprintf("\033[1;33m%s\033[0m(M:%d, V:%d) ", f.Name, f.Statements, f.Complexity))
	}
	sb.WriteString("\n")

	fmt.Print(sb.String())
}

// DynamicMemoryPressure creates variable heap allocations to ensure dynamic memory statistics for art evolution.
func DynamicMemoryPressure(cycle int) [][]byte {
	count := (cycle % 7) + 1
	blocks := make([][]byte, count)
	for i := range blocks {
		size := (rand.Intn(100) + 1) * 1024
		blocks[i] = make([]byte, size)
		if len(blocks[i]) > 0 {
			blocks[i][0] = byte(cycle % 255)
		}
	}
	return blocks
}

func main() {
	p := &ASTParser{}
	labyrinth := NewVisualLabyrinth(78, 22)

	var memoryRetention [][]byte
	frame := 0

	for {
		// Parse AST continuously to incorporate self source state
		funcs, err := p.ParseSelf()
		if err != nil {
			funcs = []FuncMetrics{
				{Name: "main", Complexity: 3, Statements: 15},
				{Name: "Evolve", Complexity: 5, Statements: 25},
			}
		}

		// Simulate fluid memory activity
		memoryRetention = DynamicMemoryPressure(frame)
		_ = memoryRetention

		// Fetch current runtime statistics
		var mem runtime.MemStats
		runtime.ReadMemStats(&mem)

		// Evolve and render frames
		labyrinth.Evolve(funcs, mem, frame)
		labyrinth.Render(funcs, mem, frame)

		frame++
		time.Sleep(75 * time.Millisecond)
	}
}