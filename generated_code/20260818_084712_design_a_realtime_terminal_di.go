package main

import (
	"fmt"
	"math"

	"math/rand"

	"strings"
	"time"
)

// Language represents a deprecated programming language,
// its ASCII shape template, and a stream of its obsolete functions.
type Language struct {
	Name      string
	Year      string
	Functions []string
	Template  []string
}

// Global collection of dead languages and their deprecated standard functions/keywords.
var languages = []Language{
	{
		Name: "COBOL",
		Year: "1959",
		Functions: []string{
			"PERFORM", "THRU", "VARYING", "ALTER", "GO TO", "DEPENDING ON",
			"EXAMINE", "TRANSFORM", "ENTER", "READY TRACE", "RESET TRACE",
			"COMPUTE", "CORRESPONDING", "DISPLAY", "STOP RUN",
		},
		Template: []string{
			"   ######    ######   ######   ######   ##      ",
			"  ##    ##  ##    ##  ##   ##  ##    ##  ##      ",
			"  ##        ##    ##  ######   ##    ##  ##      ",
			"  ##    ##  ##    ##  ##   ##  ##    ##  ##      ",
			"   ######    ######   ######   ######   ######  ",
		},
	},
	{
		Name: "ALGOL 68",
		Year: "1968",
		Functions: []string{
			"PROC", "LONG REAL", "FLEX", "REF", "LOC", "HEAP", "NIL", "SKIP",
			"GOTO", "COMMENT", "PRAGMAT", "COBEGIN", "COEND", "PAR", "SEMA",
		},
		Template: []string{
			"   ####   ##       #####   ######  ##       #####   #####  ",
			"  ##  ##  ##      ##       ##  ##  ##      ##   ##  ##  ## ",
			"  ######  ##      ##  ###  ##  ##  ##       #####   ###### ",
			"  ##  ##  ##      ##   ##  ##  ##  ##      ##   ##  ##  ## ",
			"  ##  ##  ######   #####   ######  ######   #####   #####  ",
		},
	},
	{
		Name: "Turbo Pascal",
		Year: "1983",
		Functions: []string{
			"Assign", "Reset", "Rewrite", "BlockRead", "BlockWrite", "Mem",
			"MemW", "Port", "PortW", "Mark", "Release", "Overlay", "ClrScr",
			"GotoXY", "HighVideo", "NormVideo", "Keep", "DosExitCode",
		},
		Template: []string{
			"  #####    ######   #####  #####   ######  ##      ",
			"  ##  ##  ##   ##  ##      ##  ##  ##  ##  ##      ",
			"  #####   #######   ####   ##  ##  ######  ##      ",
			"  ##      ##   ##      ##  ##  ##  ##  ##  ##      ",
			"  ##      ##   ##  #####   #####   ##  ##  ######  ",
		},
	},
}

// Shading Palette based on ASCII character density
const density = " .':-=+*#%@"

// FrameBuffer handles rendering characters and terminal ANSI manipulation
type FrameBuffer struct {
	width  int
	height int
	buffer [][]rune
	colors [][]int
}

func NewFrameBuffer(w, h int) *FrameBuffer {
	buf := make([][]rune, h)
	col := make([][]int, h)
	for i := range buf {
		buf[i] = make([]rune, w)
		col[i] = make([]int, w)
		for j := range buf[i] {
			buf[i][j] = ' '
			col[i][j] = 37
		}
	}
	return &FrameBuffer{width: w, height: h, buffer: buf, colors: col}
}

func (fb *FrameBuffer) Clear() {
	for y := 0; y < fb.height; y++ {
		for x := 0; x < fb.width; x++ {
			fb.buffer[y][x] = ' '
			fb.colors[y][x] = 37
		}
	}
}

func (fb *FrameBuffer) Set(x, y int, r rune, colorCode int) {
	if x >= 0 && x < fb.width && y >= 0 && y < fb.height {
		fb.buffer[y][x] = r
		fb.colors[y][x] = colorCode
	}
}

func (fb *FrameBuffer) DrawText(x, y int, text string, colorCode int) {
	for i, r := range text {
		fb.Set(x+i, y, r, colorCode)
	}
}

// Render flushes the frame buffer to the terminal using ANSI escape codes
func (fb *FrameBuffer) Render() {
	var sb strings.Builder
	// Move cursor to top-left
	sb.WriteString("\033[H")

	for y := 0; y < fb.height; y++ {
		lastColor := -1
		for x := 0; x < fb.width; x++ {
			color := fb.colors[y][x]
			if color != lastColor {
				sb.WriteString(fmt.Sprintf("\033[%dm", color))
				lastColor = color
			}
			sb.WriteRune(fb.buffer[y][x])
		}
		sb.WriteString("\033[0m\n")
	}
	fmt.Print(sb.String())
}

// Generates an infinite stream of function names stitched together
func functionStream(funcs []string) <-chan rune {
	ch := make(chan rune, 100)
	go func() {
		for {
			for _, fn := range funcs {
				token := fn + "::"
				for _, r := range token {
					ch <- r
				}
			}
		}
	}()
	return ch
}

func main() {
	// Clear screen & hide cursor
	fmt.Print("\033[2J\033[?25l")
	defer fmt.Print("\033[?25h\033[0m\n") // Restore cursor on exit

	width, height := 78, 22
	fb := NewFrameBuffer(width, height)

	langIdx := 0
	frame := 0
	startTime := time.Now()

	for {
		lang := languages[langIdx]
		stream := functionStream(lang.Functions)

		// Transition effect variables
		fadePhase := math.Sin(float64(frame) * 0.08)
		lightSourceX := float64(width/2) + math.Cos(float64(frame)*0.05)*30.0
		lightSourceY := float64(height/2) + math.Sin(float64(frame)*0.05)*8.0

		fb.Clear()

		// Draw Title Header
		header := fmt.Sprintf("=== NECROLOGIC TERMINAL: %s (%s) ===", lang.Name, lang.Year)
		fb.DrawText((width-len(header))/2, 1, header, 93) // Bright Yellow/Magenta

		// Render Portrait Masked with Deprecated Functions
		tmplHeight := len(lang.Template)
		tmplWidth := len(lang.Template[0])
		startX := (width - tmplWidth) / 2
		startY := (height-tmplHeight)/2 + 1

		for y := 0; y < tmplHeight; y++ {
			row := lang.Template[y]
			for x := 0; x < len(row); x++ {
				if row[x] == '#' {
					targetX := startX + x
					targetY := startY + y

					// Calculate dynamic lighting/shading intensity based on distance from pulsing light point
					dist := math.Hypot(float64(targetX)-lightSourceX, float64(targetY)-lightSourceY)
					intensity := math.Max(0.1, 1.0-(dist/40.0))
					
					// Apply plasma oscillation ripple
					ripple := (math.Sin(float64(targetX)*0.2+float64(frame)*0.1) + 1.0) / 2.0
					finalDensityIdx := int((intensity*0.7 + ripple*0.3) * float64(len(density)-1))
					if finalDensityIdx >= len(density) {
						finalDensityIdx = len(density) - 1
					}

					// Get next character from deprecated function stream
					char := <-stream
					
					// If density is low, replace character with a subtle dot to create shading depth
					if finalDensityIdx < 3 {
						char = rune(density[finalDensityIdx])
					}

					// Determine ANSI Color based on intensity
					colorCode := 31 // Red
					if intensity > 0.6 {
						colorCode = 91 // Bright Red
					} else if intensity > 0.3 {
						colorCode = 33 // Yellow/Amber
					}

					fb.Set(targetX, targetY, char, colorCode)
				}
			}
		}

		// Draw Ambient Code Rain / Particle Dust in Background
		for i := 0; i < 15; i++ {
			rx := rand.Intn(width)
			ry := rand.Intn(height-4) + 2
			if fb.buffer[ry][rx] == ' ' {
				char := rune(density[rand.Intn(4)])
				fb.Set(rx, ry, char, 90) // Dark Gray
			}
		}

		// Draw Footer
		footer := "[ESC/Ctrl+C to quit] Shading with dead standard library symbols..."
		fb.DrawText((width-len(footer))/2, height-1, footer, 36)

		fb.Render()

		// Cycle to next language every 7 seconds
		if time.Since(startTime) > 7*time.Second {
			langIdx = (langIdx + 1) % len(languages)
			startTime = time.Now()
		}

		frame++
		time.Sleep(50 * time.Millisecond)
	}
}