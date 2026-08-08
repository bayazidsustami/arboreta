package main

import (
	"fmt"
	"math"
	"math/rand"
	"strings"
	"time"
)

// MemoryLeak captures telemetry about an uncollected heap block.
type MemoryLeak struct {
	Address uint64
	Size    int
	Trace   string
}

// DanglingPointer represents a reference targeting invalid or deallocated memory.
type DanglingPointer struct {
	SourceAddr uint64
	TargetAddr uint64
	Distance   int
}

// StackOverflow records stack frame depth exhaustion metrics.
type StackOverflow struct {
	Depth       int
	Symbol      string
	FrameBytes  int
}

// MemoryDiagnostic aggregates simulated system memory anomaly data.
type MemoryDiagnostic struct {
	Leaks      []MemoryLeak
	Dangling   []DanglingPointer
	Overflow   StackOverflow
	TotalBytes int
}

// CathedralBlueprint represents the procedural structural geometry of the gothic cathedral.
type CathedralBlueprint struct {
	Title          string
	SpireHeight    int
	ButtressCount  int
	RoseWindowSize int
	NaveWidth      int
	NaveHeight     int
	Gargoyles      int
}

// Canvas provides a 2D character buffer for procedural ascii blueprint rendering.
type Canvas struct {
	Width  int
	Height int
	Grid   [][]rune
}

// NewCanvas initializes a canvas filled with space characters.
func NewCanvas(w, h int) *Canvas {
	grid := make([][]rune, h)
	for i := range grid {
		grid[i] = make([]rune, w)
		for j := range grid[i] {
			grid[i][j] = ' '
		}
	}
	return &Canvas{Width: w, Height: h, Grid: grid}
}

// Set places a character at (x, y) if within bounds.
func (c *Canvas) Set(x, y int, r rune) {
	if x >= 0 && x < c.Width && y >= 0 && y < c.Height {
		c.Grid[y][x] = r
	}
}

// DrawString renders a horizontal string starting at (x, y).
func (c *Canvas) DrawString(x, y int, s string) {
	for i, r := range s {
		c.Set(x+i, y, r)
	}
}

// String turns the grid canvas into printable blueprint output.
func (c *Canvas) String() string {
	var sb strings.Builder
	for _, row := range c.Grid {
		sb.WriteString(string(row))
		sb.WriteRune('\n')
	}
	return sb.String()
}

// SimulateMemoryFaults populates synthetic memory anomalies (leaks, dangling pointers, stack overflow).
func SimulateMemoryFaults() *MemoryDiagnostic {
	r := rand.New(rand.NewSource(time.Now().UnixNano()))

	diag := &MemoryDiagnostic{
		Overflow: StackOverflow{
			Depth:      12 + r.Intn(10), // Controls spire altitude
			Symbol:     "runtime.deepRecursion",
			FrameBytes: 8192,
		},
	}

	// Generate dangling pointers (which spawn flying buttresses)
	numDangling := 6 + r.Intn(5)
	for i := 0; i < numDangling; i++ {
		diag.Dangling = append(diag.Dangling, DanglingPointer{
			SourceAddr: 0x7fff0000 + uint64(r.Intn(0xffff)),
			TargetAddr: 0x00000000 + uint64(r.Intn(0x0fff)),
			Distance:   10 + r.Intn(15),
		})
	}

	// Generate memory leaks (which expand nave size & rose window intricacy)
	numLeaks := 8 + r.Intn(8)
	for i := 0; i < numLeaks; i++ {
		sz := (r.Intn(64) + 1) * 1024
		diag.Leaks = append(diag.Leaks, MemoryLeak{
			Address: 0xc000000000 + uint64(r.Intn(0xffffff)),
			Size:    sz,
			Trace:   fmt.Sprintf("alloc_node_%d", i),
		})
		diag.TotalBytes += sz
	}

	return diag
}

// TranslateFaultsToCathedral maps memory anomalies into architectural blueprint dimensions.
func TranslateFaultsToCathedral(diag *MemoryDiagnostic) *CathedralBlueprint {
	// Stack overflow dictates spire height
	spireHeight := diag.Overflow.Depth

	// Dangling pointers translate into flying buttresses
	buttressCount := len(diag.Dangling)

	// Memory leaks determine nave volume and rose window scale
	roseSize := int(math.Min(7, math.Max(3, float64(diag.TotalBytes/50000))))
	naveWidth := 21 + (len(diag.Leaks) % 4) * 2
	naveHeight := 10 + len(diag.Leaks)/2

	return &CathedralBlueprint{
		Title:          "CATHEDRAL OF DEALLOCATED SOULS",
		SpireHeight:    spireHeight,
		ButtressCount:  buttressCount,
		RoseWindowSize: roseSize,
		NaveWidth:      naveWidth,
		NaveHeight:     naveHeight,
		Gargoyles:      len(diag.Leaks),
	}
}

// RenderBlueprint procedurally draws the cathedral based on computed specifications.
func RenderBlueprint(b *CathedralBlueprint, diag *MemoryDiagnostic) string {
	totalHeight := b.SpireHeight + b.NaveHeight + 12
	width := 75
	c := NewCanvas(width, totalHeight)

	centerX := width / 2
	currY := 0

	// 1. Draw Architectural Header
	c.DrawString(2, currY, "=== GOTHIC CATHEDRAL PROCEDURAL BLUEPRINT ===")
	currY++
	c.DrawString(2, currY, fmt.Sprintf("Source: Stack Overflow Depth (%d frames) -> Spire Height (%d m)", diag.Overflow.Depth, b.SpireHeight))
	currY++
	c.DrawString(2, currY, fmt.Sprintf("Source: Dangling Pointers (%d refs) -> Flying Buttresses (%d units)", len(diag.Dangling), b.ButtressCount))
	currY++
	c.DrawString(2, currY, fmt.Sprintf("Source: Heap Leaks (%d KB total) -> Rose Window & Vaulting", diag.TotalBytes/1024))
	currY += 2

	spireStartY := currY

	// 2. Render Central Spire (dictated by Stack Overflow)
	c.Set(centerX, currY, '+') // Finial cross
	currY++
	c.Set(centerX, currY, '|')
	currY++
	c.DrawString(centerX-1, currY, "/|\\")
	currY++

	for i := 0; i < b.SpireHeight; i++ {
		offset := i / 4
		leftX := centerX - 1 - offset
		rightX := centerX + 1 + offset
		c.Set(leftX, currY, '/')
		c.Set(centerX, currY, '|')
		c.Set(rightX, currY, '\\')

		if i%3 == 0 {
			c.Set(centerX-1, currY, '*')
			c.Set(centerX+1, currY, '*')
		}
		currY++
	}

	// Spire base transition
	naveLeftX := centerX - (b.NaveWidth / 2)
	naveRightX := centerX + (b.NaveWidth / 2)
	c.DrawString(naveLeftX, currY, "/"+strings.Repeat("-", b.NaveWidth-2)+"\\")
	currY++

	naveTopY := currY

	// 3. Render Main Walls & Vaulted Nave
	for i := 0; i < b.NaveHeight; i++ {
		y := naveTopY + i
		c.Set(naveLeftX, y, '|')
		c.Set(naveRightX, y, '|')

		// Interior structural pillars
		c.Set(naveLeftX+4, y, ':')
		c.Set(naveRightX-4, y, ':')
	}

	// 4. Render Flying Buttresses (dictated by Dangling Pointers)
	buttressSpacing := b.NaveHeight / (b.ButtressCount + 1)
	if buttressSpacing < 1 {
		buttressSpacing = 1
	}

	for i := 0; i < b.ButtressCount; i++ {
		bY := naveTopY + 2 + (i * buttressSpacing)
		if bY >= naveTopY+b.NaveHeight-1 {
			break
		}

		span := 8 + (i % 3)
		// Left Flying Buttress
		for x := 1; x <= span; x++ {
			lx := naveLeftX - x
			if x == span {
				c.Set(lx, bY+1, '|')
				c.Set(lx, bY+2, '|')
				c.Set(lx, bY, '^') // Pinnacles on outer pier buttress
			} else {
				c.Set(lx, bY+(x/3), '=')
			}
		}

		// Right Flying Buttress
		for x := 1; x <= span; x++ {
			rx := naveRightX + x
			if x == span {
				c.Set(rx, bY+1, '|')
				c.Set(rx, bY+2, '|')
				c.Set(rx, bY, '^')
			} else {
				c.Set(rx, bY+(x/3), '=')
			}
		}
	}

	// 5. Render Rose Window (dictated by Leaked Memory Volume)
	roseY := naveTopY + (b.NaveHeight / 3)
	c.DrawString(centerX-3, roseY-1, " .---. ")
	c.DrawString(centerX-3, roseY,   "(  O  )")
	c.DrawString(centerX-3, roseY+1, " '---' ")

	// 6. Render Grand Portal / Gothic Arch Entrance at Base
	groundY := naveTopY + b.NaveHeight
	c.DrawString(naveLeftX-2, groundY, strings.Repeat("=", b.NaveWidth+5))
	portalY := groundY - 3

	c.DrawString(centerX-3, portalY,   "  /\\  ")
	c.DrawString(centerX-3, portalY+1, " /  \\ ")
	c.DrawString(centerX-3, portalY+2, "||||||")

	// 7. Scatter Gargoyles (Dangling pointer/leak artifacts on eaves)
	for g := 0; g < b.Gargoyles && g < 4; g++ {
		gx := naveLeftX + (g * 5) + 2
		c.Set(gx, naveTopY-1, '&')
	}

	_ = spireStartY

	return c.String()
}

func main() {
	// Step 1: Capture and simulate system memory fault diagnostics
	diagnostics := SimulateMemoryFaults()

	// Step 2: Map raw memory faults to gothic cathedral architectural elements
	blueprint := TranslateFaultsToCathedral(diagnostics)

	// Step 3: Render and output procedural blueprint
	output := RenderBlueprint(blueprint, diagnostics)
	fmt.Print(output)
}