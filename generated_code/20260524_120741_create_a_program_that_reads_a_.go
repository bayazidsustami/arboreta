package main

import (
	"image"
	"image/color"
	"log"
	"math"
	"math/rand"
	"time"

	"github.com/hajimehoshi/ebiten/v2"
	"github.com/hajimehoshi/ebiten/v2/ebitenutil"
	"github.com/hajimehoshi/oto/v2"
	"gocv.io/x/gocv"
)

// ---------- Audio ----------
type sine struct {
	freq   float64
	pos    float64
	inc    float64
	volume float64
}

func (s *sine) Read(p []byte) (int, error) {
	const sampleRate = 44100
	n := len(p) / 2
	for i := 0; i < n; i++ {
		val := s.volume * math.Sin(2*math.Pi*s.pos)
		s.pos += s.inc
		if s.pos >= 1 {
			s.pos -= 1
		}
		// 16‑bit PCM, little endian
		v := int16(val * 32767)
		p[2*i] = byte(v)
		p[2*i+1] = byte(v >> 8)
	}
	return n * 2, nil
}

func newSine(freq float64) *sine {
	const sampleRate = 44100
	return &sine{
		freq:   freq,
		inc:    freq / sampleRate,
		volume: 0.1,
	}
}

// ---------- Visual ----------
type Game struct {
	img      *ebiten.Image
	angles   []float64
	freqs    []float64
	frameCnt int
}

func (g *Game) Update() error {
	// angles evolve with audio frequencies
	for i := range g.angles {
		g.angles[i] += g.freqs[i] * 0.0005
	}
	g.frameCnt++
	return nil
}

func (g *Game) Draw(screen *ebiten.Image) {
	w, h := screen.Size()
	screen.Fill(color.Black)

	// draw kaleidoscopic mandala
	n := len(g.angles)
	radius := float64(min(w, h)) * 0.4
	for i := 0; i < n; i++ {
		angle := g.angles[i]
		x := float64(w)/2 + radius*math.Cos(angle)
		y := float64(h)/2 + radius*math.Sin(angle)
		c := color.RGBA{uint8(128 + 127*math.Sin(angle)), uint8(128 + 127*math.Sin(angle*1.3)), uint8(128 + 127*math.Sin(angle*1.7)), 255}
		ebitenutil.DrawRect(screen, x-5, y-5, 10, 10, c)
	}

	// simple frame counter
	ebitenutil.DebugPrint(screen, "frame "+strconv.Itoa(g.frameCnt))
}

func (g *Game) Layout(outsideWidth, outsideHeight int) (int, int) {
	return 800, 600
}

// ---------- Helper ----------
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// dominantColors extracts k dominant colors using a very naive clustering.
func dominantColors(img gocv.Mat, k int) []color.RGBA {
	rows, cols := img.Rows(), img.Cols()
	centroids := make([][3]float64, k)
	// initialise with random pixels
	for i := 0; i < k; i++ {
		x := rand.Intn(cols)
		y := rand.Intn(rows)
		px := img.GetVecbAt(y, x)
		centroids[i][0] = float64(px[0])
		centroids[i][1] = float64(px[1])
		centroids[i][2] = float64(px[2])
	}
	// run few k‑means iterations
	for iter := 0; iter < 5; iter++ {
		assign := make([][]int, k)
		for y := 0; y < rows; y++ {
			for x := 0; x < cols; x++ {
				px := img.GetVecbAt(y, x)
				best := 0
				bestDist := 1e9
				for i, c := range centroids {
					dr := float64(px[0]) - c[0]
					dg := float64(px[1]) - c[1]
					db := float64(px[2]) - c[2]
					dist := dr*dr + dg*dg + db*db
					if dist < bestDist {
						bestDist = dist
						best = i
					}
				}
				assign[best] = append(assign[best], y*cols+x)
			}
		}
		// recompute centroids
		for i := range centroids {
			if len(assign[i]) == 0 {
				continue
			}
			var sum [3]float64
			for _, idx := range assign[i] {
				y := idx / cols
				x := idx % cols
				px := img.GetVecbAt(y, x)
				sum[0] += float64(px[0])
				sum[1] += float64(px[1])
				sum[2] += float64(px[2])
			}
			n := float64(len(assign[i]))
			centroids[i][0] = sum[0] / n
			centroids[i][1] = sum[1] / n
			centroids[i][2] = sum[2] / n
		}
	}
	// convert to RGBA slice
	res := make([]color.RGBA, k)
	for i, c := range centroids {
		res[i] = color.RGBA{uint8(c[2]), uint8(c[1]), uint8(c[0]), 255} // OpenCV uses BGR
	}
	return res
}

// map a color to a frequency using a simple pentatonic scale
func colorToFreq(c color.RGBA) float64 {
	// compute hue (0‑360)
	r, g, b := float64(c.R)/255, float64(c.G)/255, float64(c.B)/255
	max := math.Max(r, math.Max(g, b))
	minv := math.Min(r, math.Min(g, b))
	delta := max - minv
	var h float64
	switch {
	case delta == 0:
		h = 0
	case max == r:
		h = 60 * math.Mod((g-b)/delta, 6)
	case max == g:
		h = 60 * ((b - r) / delta + 2)
	case max == b:
		h = 60 * ((r - g) / delta + 4)
	}
	if h < 0 {
		h += 360
	}
	// pentatonic scale frequencies (C4‑C5)
	scale := []float64{261.63, 293.66, 329.63, 392.00, 440.00}
	idx := int(h/72) % len(scale)
	return scale[idx]
}

// ---------- Main ----------
func main() {
	// open webcam
	webcam, err := gocv.OpenVideoCapture(0)
	if err != nil {
		log.Fatalf("cannot open webcam: %v", err)
	}
	defer webcam.Close()

	imgMat := gocv.NewMat()
	defer imgMat.Close()

	// audio context
	const sampleRate = 44100
	ctx, err := oto.NewContext(sampleRate, 2, 2, 8192)
	if err != nil {
		log.Fatalf("audio: %v", err)
	}
	player := ctx.NewPlayer()
	defer player.Close()

	// initialise visual state
	game := &Game{
		img:    ebiten.NewImage(800, 600),
		angles: make([]float64, 5),
		freqs:  make([]float64, 5),
	}

	// launch audio goroutine that mixes current frequencies
	go func() {
		var sources []*sine
		for {
			// regenerate sources from latest frequencies
			sources = sources[:0]
			for _, f := range game.freqs {
				sources = append(sources, newSine(f))
			}
			mixer := oto.NewMixer(ctx)
			for _, s := range sources {
				mixer.AddReader(s)
			}
			player.Reset()
			player.Play()
			// play for a short slice then update
			time.Sleep(100 * time.Millisecond)
		}
	}()

	// main loop: capture, analyze, update frequencies
	go func() {
		for {
			if ok := webcam.Read(&imgMat); !ok {
				continue
			}
			if imgMat.Empty() {
				continue
			}
			colors := dominantColors(imgMat, 5)
			for i, c := range colors {
				game.freqs[i] = colorToFreq(c)
			}
			// small pause to avoid hogging CPU
			time.Sleep(30 * time.Millisecond)
		}
	}()

	// start rendering
	ebiten.SetWindowSize(800, 600)
	ebiten.SetWindowTitle("Audio‑Visual Kaleidoscope")
	if err := ebiten.RunGame(game); err != nil {
		log.Fatal(err)
	}
}