package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"image"
	"image/color"
	"image/draw"
	"image/gif"
	"math"
	"math/rand"
	"os"
	"time"
)

// Organism represents a floating polyphonic entity shaped and tuned by Go AST nodes.
type Organism struct {
	X, Y         float64
	VX, VY       float64
	Radius       float64
	Hue          float64
	Life         float64
	MaxLife      float64
	Notes        []float64 // Polyphonic pitch set (frequencies in Hz)
	ASTNodeType  string
	ChildrenCount int
}

// World manages the spatial canvas and musical decay events.
type World struct {
	Width, Height int
	Organisms    []*Organism
	Canvas       *image.RGBA
	FrameHistory []*image.Paletted
	Palette      color.Palette
}

// ExtractOrganismsFromAST parses a Go source code string into an AST,
// transforming structural code patterns into living polyphonic organisms.
func ExtractOrganismsFromAST(sourceCode string, width, height int) ([]*Organism, error) {
	fset := token.NewFileSet()
	node, err := parser.ParseFile(fset, "self.go", sourceCode, 0)
	if err != nil {
		return nil, err
	}

	var organisms []*Organism

	ast.Inspect(node, func(n ast.Node) bool {
		if n == nil {
			return true
		}

		// Map AST nodes to physical and musical properties
		var nodeType string
		var depth int

		switch t := n.(type) {
		case *ast.FuncDecl:
			nodeType = "FuncDecl"
			depth = 4
		case *ast.CallExpr:
			nodeType = "CallExpr"
			depth = 3
		case *ast.IfStmt:
			nodeType = "IfStmt"
			depth = 2
		case *ast.BinaryExpr:
			nodeType = "BinaryExpr"
			depth = 1
		default:
			return true
		}

		// Fundamental pitch generated based on node position/type
		baseFreq := 130.81 * math.Pow(2.0, float64(depth%4)+(rand.Float64()*0.5)) // Pentatonic scale base

		org := &Organism{
			X:             rand.Float64() * float64(width),
			Y:             rand.Float64() * float64(height),
			VX:            (rand.Float64() - 0.5) * 3.0,
			VY:            (rand.Float64() - 0.5) * 3.0,
			Radius:        10.0 + float64(depth)*4.0,
			Hue:           float64(depth*60) / 360.0,
			Life:          1.0,
			MaxLife:       1.0,
			ASTNodeType:   nodeType,
			ChildrenCount: depth,
			Notes:         []float64{baseFreq, baseFreq * 1.25, baseFreq * 1.5}, // Major triad chord
		}

		organisms = append(organisms, org)
		return true
	})

	return organisms, nil
}

// Update handles movement, bounds collision, decay, and organism interaction.
func (w *World) Update() {
	for i := 0; i < len(w.Organisms); i++ {
		o1 := w.Organisms[i]
		o1.X += o1.VX
		o1.Y += o1.VY

		// Bounce off canvas boundaries
		if o1.X < o1.Radius || o1.X > float64(w.Width)-o1.Radius {
			o1.VX *= -1
		}
		if o1.Y < o1.Radius || o1.Y > float64(w.Height)-o1.Radius {
			o1.VY *= -1
		}

		// Natural lifespan decay
		o1.Life -= 0.005

		// Detect collisions to compose polyphonic sound events
		for j := i + 1; j < len(w.Organisms); j++ {
			o2 := w.Organisms[j]
			dx := o2.X - o1.X
			dy := o2.Y - o1.Y
			dist := math.Hypot(dx, dy)

			if dist < (o1.Radius + o2.Radius) {
				// Elastic bounce collision
				o1.VX, o2.VX = o2.VX, o1.VX
				o1.VY, o2.VY = o2.VY, o1.VY

				// Polyphonic Harmonic Fusion: harmonize frequencies upon collision
				if len(o1.Notes) > 0 && len(o2.Notes) > 0 {
					harmonicFreq := (o1.Notes[0] + o2.Notes[0]) / 2.0
					o1.Notes = append(o1.Notes, harmonicFreq*1.5)
					o2.Notes = append(o2.Notes, harmonicFreq*2.0)
					if len(o1.Notes) > 4 {
						o1.Notes = o1.Notes[1:]
					}
					if len(o2.Notes) > 4 {
						o2.Notes = o2.Notes[1:]
					}
				}
			}
		}
	}

	// Filter dead organisms
	var active []*Organism
	for _, o := range w.Organisms {
		if o.Life > 0 {
			active = append(active, o)
		}
	}
	w.Organisms = active
}

// Render draws the organism state onto the raster image frame.
func (w *World) Render() *image.Paletted {
	// Clear background with translucent trail
	draw.Draw(w.Canvas, w.Canvas.Bounds(), &image.Uniform{color.RGBA{10, 15, 25, 255}}, image.Point{}, draw.Src)

	// Draw floating organisms
	for _, o := range w.Organisms {
		r, g, b := hsvToRGB(o.Hue, 0.8, o.Life)
		c := color.RGBA{R: r, G: g, B: b, A: uint8(o.Life * 255)}

		// Draw central body
		cx, cy := int(o.X), int(o.Y)
		rad := int(o.Radius)

		for y := -rad; y <= rad; y++ {
			for x := -rad; x <= rad; x++ {
				if x*x+y*y <= rad*rad {
					px, py := cx+x, cy+y
					if px >= 0 && px < w.Width && py >= 0 && py < w.Height {
						w.Canvas.Set(px, py, c)
					}
				}
			}
		}
	}

	// Quantize to fixed palette frame for GIF recording
	palettedImg := image.NewPaletted(w.Canvas.Bounds(), w.Palette)
	draw.Draw(palettedImg, palettedImg.Bounds(), w.Canvas, image.Point{}, draw.Src)
	return palettedImg
}

// Convert HSV color space to standard RGB components.
func hsvToRGB(h, s, v float64) (uint8, uint8, uint8) {
	i := math.Floor(h * 6)
	f := h*6 - i
	p := v * (1 - s)
	q := v * (1 - f*s)
	t := v * (1 - (1-f)*s)

	var r, g, b float64
	switch int(i) % 6 {
	case 0:
		r, g, b = v, t, p
	case 1:
		r, g, b = q, v, p
	case 2:
		r, g, b = p, v, t
	case 3:
		r, g, b = p, q, v
	case 4:
		r, g, b = t, p, v
	case 5:
		r, g, b = v, p, q
	}
	return uint8(r * 255), uint8(g * 255), uint8(b * 255)
}

// Self-modifying routine: Mutates current source code file structure.
func selfModifySourceCode(filePath string) error {
	content, err := os.ReadFile(filePath)
	if err != nil {
		return err
	}

	// Inject a subtle AST-altering structural comment/expression safely
	mutation := fmt.Sprintf("\n// Mutation Event at %s\nvar _ = %d\n", time.Now().Format(time.RFC3339), rand.Intn(1000))
	modified := append(content, []byte(mutation)...)

	return os.WriteFile(filePath, modified, 0644)
}

func main() {
	rand.Seed(time.Now().UnixNano())

	width, height := 400, 400
	selfFilename := "main.go"

	// Read self or fallback to local source string
	sourceBytes, err := os.ReadFile(selfFilename)
	sourceCode := string(sourceBytes)
	if err != nil {
		sourceCode = `package main; func PolyphonicOrganism() { if true { x := 1 + 2; _ = x } }`
	}

	// Parse code AST into Polyphonic Organisms
	organisms, err := ExtractOrganismsFromAST(sourceCode, width, height)
	if err != nil {
		fmt.Printf("AST Parse error: %v\n", err)
		return
	}

	// Build default color palette
	palette := color.Palette{color.RGBA{10, 15, 25, 255}}
	for i := 0; i < 255; i++ {
		r, g, b := hsvToRGB(float64(i)/255.0, 0.8, 1.0)
		palette = append(palette, color.RGBA{R: r, G: g, B: b, A: 255})
	}

	world := &World{
		Width:     width,
		Height:    height,
		Organisms: organisms,
		Canvas:    image.NewRGBA(image.Rect(0, 0, width, height)),
		Palette:   palette,
	}

	// Simulation loop rendering composition into animated visual canvas
	outGif := &gif.GIF{}
	frameCount := 60

	for i := 0; i < frameCount; i++ {
		world.Update()
		frame := world.Render()
		outGif.Image = append(outGif.Image, frame)
		outGif.Delay = append(outGif.Delay, 4) // 25 FPS
	}

	// Save rendered ecosystem animation
	f, err := os.Create("ecosystem.gif")
	if err == nil {
		defer f.Close()
		gif.EncodeAll(f, outGif)
		fmt.Println("Ecosystem animation exported to ecosystem.gif")
	}

	// Perform actual self-modification on disk AST
	if _, err := os.Stat(selfFilename); err == nil {
		if err := selfModifySourceCode(selfFilename); err == nil {
			fmt.Println("Source code AST successfully self-modified.")
		}
	}
}