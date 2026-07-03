package main

import (
	"bufio"
	"encoding/binary"
	"image"
	"image/color"
	"image/draw"
	"image/png"
	"log"
	"math/rand"
	"os"
	"strconv"
	"strings"
	"time"
)

// simple brush‑stroke language:
// each comment line must have the form:
//   // line x0 y0 x1 y1 r g b
// where (x0,y0)→(x1,y1) is the segment and r,g,b its colour (0‑255).

const (
	canvasSize = 400
	outputFile = "painting.png"
)

func main() {
	rand.Seed(time.Now().UnixNano())

	// 1. open own source file
	self, err := os.Open(os.Args[0])
	if err != nil {
		log.Fatalf("cannot open source: %v", err)
	}
	defer self.Close()

	// 2. create a blank canvas
	img := image.NewRGBA(image.Rect(0, 0, canvasSize, canvasSize))
	draw.Draw(img, img.Bounds(), &image.Uniform{color.White}, image.Point{}, draw.Src)

	// 3. parse comment lines and draw them
	scanner := bufio.NewScanner(self)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if strings.HasPrefix(line, "// line") {
			fields := strings.Fields(line[2:]) // drop leading //
			if len(fields) != 8 {
				continue
			}
			x0, _ := strconv.Atoi(fields[2])
			y0, _ := strconv.Atoi(fields[3])
			x1, _ := strconv.Atoi(fields[4])
			y1, _ := strconv.Atoi(fields[5])
			r, _ := strconv.Atoi(fields[6])
			g, _ := strconv.Atoi(fields[7])
			b, _ := strconv.Atoi(fields[8])
			col := color.RGBA{uint8(r), uint8(g), uint8(b), 255}
			drawLine(img, x0, y0, x1, y1, col)
		}
	}
	if err := scanner.Err(); err != nil {
		log.Fatalf("reading source: %v", err)
	}

	// 4. write the painting
	fout, err := os.Create(outputFile)
	if err != nil {
		log.Fatalf("cannot create image: %v", err)
	}
	png.Encode(fout, img)
	fout.Close()

	// 5. generate a new random stroke and append as comment
	newComment := randomStrokeComment()
	f, err := os.OpenFile(os.Args[0], os.O_APPEND|os.O_WRONLY, 0)
	if err != nil {
		log.Fatalf("cannot append to source: %v", err)
	}
	defer f.Close()
	f.WriteString("\n" + newComment + "\n")
}

// drawLine uses Bresenham's algorithm.
func drawLine(img *image.RGBA, x0, y0, x1, y1 int, col color.Color) {
	dx := abs(x1 - x0)
	sx := -1
	if x0 < x1 {
		sx = 1
	}
	dy := -abs(y1 - y0)
	sy := -1
	if y0 < y1 {
		sy = 1
	}
	err := dx + dy
	for {
		img.Set(x0, y0, col)
		if x0 == x1 && y0 == y1 {
			break
		}
		e2 := 2 * err
		if e2 >= dy {
			err += dy
			x0 += sx
		}
		if e2 <= dx {
			err += dx
			y0 += sy
		}
	}
}

// randomStrokeComment creates a new comment with random parameters.
func randomStrokeComment() string {
	x0 := rand.Intn(canvasSize)
	y0 := rand.Intn(canvasSize)
	x1 := rand.Intn(canvasSize)
	y1 := rand.Intn(canvasSize)
	r := rand.Intn(256)
	g := rand.Intn(256)
	b := rand.Intn(256)
	// pack into comment string
	return "// line " + joinInts(x0, y0, x1, y1, r, g, b)
}

// helper to join ints with spaces
func joinInts(vals ...int) string {
	var sb strings.Builder
	for i, v := range vals {
		if i > 0 {
			sb.WriteByte(' ')
		}
		sb.WriteString(strconv.Itoa(v))
	}
	return sb.String()
}
func abs(a int) int {
	if a < 0 {
		return -a
	}
	return a
}

// line // line 50 50 350 350 0 0 0 (initial stroke)