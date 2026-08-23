package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"math/rand"
	"strings"
	"time"

	"[github.com/gdamore/tcell/v2](https://github.com/gdamore/tcell/v2)"
)

// Thread represents a single strand of woven syntax/execution state.
type Thread struct {
	Char       rune
	Color      tcell.Color
	Complexity int
	NodeInfo   string
}

// Loom holds the grid of woven threads and execution steps.
type Loom struct {
	Warp       [][]Thread
	Width      int
	Height     int
	StepCursor int
	Code       string
	Steps      []Thread
}

func main() {
	sampleCode := `package main

func Fibonacci(n int) int {
	if n <= 1 {
		return n
	}
	a, b := 0, 1
	for i := 2; i <= n; i++ {
		a, b = b, a+b
	}
	return b
}`

	loom, err := NewLoom(sampleCode, 60, 22)
	if err != nil {
		fmt.Println("Error weaving loom:", err)
		return
	}

	screen, err := tcell.NewScreen()
	if err != nil {
		fmt.Println("Screen error:", err)
		return
	}
	if err := screen.Init(); err != nil {
		fmt.Println("Screen init error:", err)
		return
	}
	defer screen.Fini()

	rand.Seed(time.Now().UnixNano())

	for {
		screen.Clear()
		loom.Draw(screen)
		screen.Show()

		ev := screen.PollEvent()
		switch ev := ev.(type) {
		case *tcell.EventKey:
			if ev.Key() == tcell.KeyEscape || ev.Key() == tcell.KeyCtrlC || ev.Rune() == 'q' {
				return
			}
			// Unravel step-by-step using Space or Right Arrow
			if ev.Key() == tcell.KeyRight || ev.Rune() == ' ' {
				loom.UnravelStep()
			}
			// Re-weave back using Left Arrow
			if ev.Key() == tcell.KeyLeft {
				loom.ReweaveStep()
			}
		}
	}
}

// NewLoom parses Go AST, extracts complexity threads, and weaves a tapestry grid.
func NewLoom(code string, w, h int) (*Loom, error) {
	fset := token.NewFileSet()
	node, err := parser.ParseFile(fset, "", code, 0)
	if err != nil {
		return nil, err
	}

	var steps []Thread
	palette := []tcell.Color{
		tcell.ColorCyan, tcell.ColorGreen, tcell.ColorYellow,
		tcell.ColorOrange, tcell.ColorRed, tcell.ColorMagenta,
	}

	// Walk AST to convert syntax nodes into weighted threads based on nesting/complexity
	var walk func(ast.Node, int)
	walk = func(n ast.Node, depth int) {
		if n == nil {
			return
		}

		char := '┼'
		comp := depth + 1
		info := "Statement"

		switch n.(type) {
		case *ast.FuncDecl:
			char = '⯁'
			comp += 2
			info = "FuncDecl"
		case *ast.IfStmt:
			char = '⬡'
			comp += 3
			info = "IfStmt (Branch)"
		case *ast.ForStmt:
			char = '⟳'
			comp += 4
			info = "ForStmt (Loop)"
		case *ast.BinaryExpr:
			char = '⤞'
			comp += 1
			info = "BinaryExpr"
		case *ast.AssignStmt:
			char = '|=|'
			char = '═'
			info = "Assignment"
		case *ast.Ident:
			char = '•'
			info = "Identifier"
		}

		color := palette[comp%len(palette)]
		steps = append(steps, Thread{
			Char:       char,
			Color:      color,
			Complexity: comp,
			NodeInfo:   info,
		})

		ast.Inspect(n, func(child ast.Node) bool {
			if child != n && child != nil {
				walk(child, depth+1)
				return false
			}
			return true
		})
	}

	walk(node, 0)

	loom := &Loom{
		Width:      w,
		Height:     h,
		Code:       code,
		Steps:      steps,
		StepCursor: len(steps), // Start fully woven
	}

	loom.generateWarp()
	return loom, nil
}

// Generate the woven matrix layout from AST thread data.
func (l *Loom) generateWarp() {
	l.Warp = make([][]Thread, l.Height)
	for r := 0; r < l.Height; r++ {
		l.Warp[r] = make([]Thread, l.Width)
		for c := 0; c < l.Width; c++ {
			idx := (r*l.Width + c) % len(l.Steps)
			baseThread := l.Steps[idx]

			// Weaving pattern logic: Warp vs Weft visual interlacing
			if (r+c)%2 == 0 {
				baseThread.Char = '│'
			} else if (r-c)%3 == 0 {
				baseThread.Char = '─'
			}

			l.Warp[r][c] = baseThread
		}
	}
}

func (l *Loom) UnravelStep() {
	if l.StepCursor > 0 {
		l.StepCursor--
	}
}

func (l *Loom) ReweaveStep() {
	if l.StepCursor < len(l.Steps) {
		l.StepCursor++
	}
}

// Draw renders the digital loom, source code, and unraveled thread state.
func (l *Loom) Draw(s tcell.Screen) {
	drawText(s, 2, 1, tcell.ColorWhite, "=== DIGITAL LOOM: SYNTAX TAPESTRY DEBUGGER ===")
	drawText(s, 2, 2, tcell.ColorDarkGray, "[Space/Right Arrow] Unravel Thread (Debug) | [Left Arrow] Reweave | [Q] Quit")

	// Render Fabric Grid
	totalCells := l.Width * l.Height
	activeCells := (l.StepCursor * totalCells) / len(l.Steps)

	for r := 0; r < l.Height; r++ {
		for c := 0; c < l.Width; c++ {
			cellIdx := r*l.Width + c
			x := c + 4
			y := r + 4

			if cellIdx < activeCells {
				t := l.Warp[r][c]
				s.SetContent(x, y, t.Char, nil, tcell.StyleDefault.Foreground(t.Color))
			} else {
				// Unraveled thread representation
				s.SetContent(x, y, '·', nil, tcell.StyleDefault.Foreground(t.ColorDarkGray))
			}
		}
	}

	// Render Source Code Panel
	lines := strings.Split(l.Code, "\n")
	drawText(s, l.Width+8, 4, tcell.ColorYellow, "--- SOURCE CODE ---")
	for i, line := range lines {
		s.SetContent(l.Width+6, i+6, '>', nil, tcell.StyleDefault.Foreground(t.ColorGreen))
		drawText(s, l.Width+8, i+6, tcell.ColorLightCyan, line)
	}

	// Render Debugger Thread Status
	if l.StepCursor < len(l.Steps) {
		curr := l.Steps[l.StepCursor]
		status := fmt.Sprintf("UNRAVELED NODE: [%s] Complexity Level: %d", curr.NodeInfo, curr.Complexity)
		drawText(s, 4, l.Height+5, tcell.ColorRed, status)
	} else {
		drawText(s, 4, l.Height+5, tcell.ColorGreen, "STATUS: Fabric fully woven. Unravel to step through execution AST.")
	}
}

func drawText(s tcell.Screen, x, y int, color tcell.Color, text string) {
	style := tcell.StyleDefault.Foreground(color)
	for i, r := range text {
		s.SetContent(x+i, y, r, nil, style)
	}
}