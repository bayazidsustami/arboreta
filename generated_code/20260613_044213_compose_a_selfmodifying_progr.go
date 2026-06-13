package main

import (
	"bufio"
	"bytes"
	"fmt"
	"io/ioutil"
	"os"
	"strings"
	"unicode/utf8"
)

const (
	startMarker = "//===CANVAS START===\n"
	endMarker   = "//===CANVAS END===\n"
)

// simple CA: count non‑space neighbours (8‑connected) and map to a block
var shades = []rune{' ', '░', '▒', '▓', '█'}

func main() {
	// read own source
	srcPath := os.Args[0]
	data, err := ioutil.ReadFile(srcPath)
	if err != nil {
		panic(err)
	}
	lines := strings.Split(string(data), "\n")

	// extract the canvas region (or empty if first run)
	var canvasLines []string
	inCanvas := false
	var bodyStart, bodyEnd int
	for i, l := range lines {
		if l == strings.TrimSpace(startMarker) {
			inCanvas = true
			bodyStart = i + 1
			continue
		}
		if l == strings.TrimSpace(endMarker) {
			inCanvas = false
			bodyEnd = i
			break
		}
		if inCanvas {
			// strip leading comment slashes
			canvasLines = append(canvasLines, strings.TrimPrefix(l, "//"))
		}
	}
	// build 2‑D rune grid from previous canvas (or from source itself on first run)
	grid := buildGrid(canvasLines, lines)

	// apply one step of CA
	newGrid := step(grid)

	// render new grid as comment lines
	var buf bytes.Buffer
	buf.WriteString(startMarker)
	for _, row := range newGrid {
		buf.WriteString("//")
		for _, r := range row {
			buf.WriteRune(r)
		}
		buf.WriteString("\n")
	}
	buf.WriteString(endMarker)

	// reconstruct the file: everything before startMarker, then new canvas, then rest after endMarker
	var out bytes.Buffer
	// copy up to startMarker (inclusive)
	for i := 0; i <= bodyStart-2 && i < len(lines); i++ {
		out.WriteString(lines[i] + "\n")
	}
	// insert new canvas
	out.Write(buf.Bytes())
	// copy the remainder after endMarker
	for i := bodyEnd + 1; i < len(lines); i++ {
		out.WriteString(lines[i] + "\n")
	}

	// write back
	if err := ioutil.WriteFile(srcPath, out.Bytes(), 0644); err != nil {
		panic(err)
	}
}

// buildGrid creates a rectangular rune matrix from either a previous canvas or the source code itself.
func buildGrid(canvas []string, src []string) [][]rune {
	if len(canvas) > 0 {
		return linesToGrid(canvas)
	}
	// fall back: use the source code lines (excluding the canvas markers)
	var srcLines []string
	for _, l := range src {
		if strings.HasPrefix(l, startMarker) || strings.HasPrefix(l, endMarker) {
			continue
		}
		srcLines = append(srcLines, l)
	}
	return linesToGrid(srcLines)
}

// convert slice of strings to rectangular rune slice, padding with spaces.
func linesToGrid(strs []string) [][]rune {
	max := 0
	for _, s := range strs {
		if w := utf8.RuneCountInString(s); w > max {
			max = w
		}
	}
	grid := make([][]rune, len(strs))
	for i, s := range strs {
		row := []rune(s)
		if len(row) < max {
			padding := make([]rune, max-len(row))
			for i := range padding {
				padding[i] = ' '
			}
			row = append(row, padding...)
		}
		grid[i] = row
	}
	return grid
}

// one CA step: count neighbours that are not space, map count to shade.
func step(g [][]rune) [][]rune {
	h, w := len(g), len(g[0])
	newG := make([][]rune, h)
	for y := 0; y < h; y++ {
		newG[y] = make([]rune, w)
		for x := 0; x < w; x++ {
			cnt := 0
			for dy := -1; dy <= 1; dy++ {
				for dx := -1; dx <= 1; dx++ {
					if dy == 0 && dx == 0 {
						continue
					}
					ny, nx := y+dy, x+dx
					if ny >= 0 && ny < h && nx >= 0 && nx < w && g[ny][nx] != ' ' {
						cnt++
					}
				}
			}
			// clamp count to index range
			if cnt >= len(shades) {
				cnt = len(shades) - 1
			}
			newG[y][x] = shades[cnt]
		}
	}
	return newG
}

// minimal main to silence unused import warnings in case of future extensions
func _() {
	_ = bufio.NewReader(os.Stdin)
	fmt.Println()
}