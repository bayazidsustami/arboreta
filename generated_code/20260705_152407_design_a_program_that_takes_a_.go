package main

import (
	"fmt"
	"image"
	"image/color"
	"math"
	"math/rand"
	"time"

	"github.com/faiface/beep"
	"github.com/faiface/beep/speaker"
	"github.com/faiface/beep/synth"
	"gocv.io/x/gocv"
	"golang.org/x/image/colornames"
)

// Simple L‑system state
type lsystem struct {
	axiom    string
	rules    map[rune]string
	angle    float64
	iterations int
}

// Generate the L‑system string
func (l *lsystem) generate() string {
	s := l.axiom
	for i := 0; i < l.iterations; i++ {
		var next []rune
		for _, ch := range s {
			if repl, ok := l.rules[ch]; ok {
				for _, r := range repl {
					next = append(next, r)
				}
			} else {
				next = append(next, ch)
			}
		}
		s = string(next)
	}
	return s
}

// Map a hue (0‑360) to a note frequency using a custom pentatonic scale
func hueToFreq(h float64) float64 {
	// Base frequencies for C major pentatonic (C D E G A)
	base := []float64{261.63, 293.66, 329.63, 392.00, 440.00}
	// Choose index by hue sector
	idx := int(math.Floor(h/72.0)) % len(base)
	// Octave shift every full rotation
	octave := int(h/360.0)
	return base[idx] * math.Pow(2, float64(octave))
}

// Compute dominant hue of an image using a very cheap average method
func dominantHue(img gocv.Mat) float64 {
	h, s, v := gocv.NewMat(), gocv.NewMat(), gocv.NewMat()
	defer h.Close()
	defer s.Close()
	defer v.Close()
	gocv.CvtColor(img, &h, gocv.ColorBGR2HSV)
	// take centre pixel to keep it fast
	c := h.GetVeciAt(img.Rows()/2, img.Cols()/2)
	hue := float64(c[0]) * 2 // OpenCV hue [0,179] → [0,360]
	return hue
}

// Play a note of given frequency for a short duration
func playFreq(freq float64) {
	sr := beep.SampleRate(44100)
	s := synth.NewOscillator(synth.SinOsc, freq)
	streamer := beep.Take(sr.N(time.Millisecond*200), s)
	speaker.Play(streamer)
}

// Draw mandala based on L‑system string onto an image
func drawMandala(lsysStr string, sz int) *gocv.Mat {
	img := gocv.NewMatWithSize(sz, sz, gocv.MatTypeCV8UC3)
	img.SetTo(gocv.NewScalar(0, 0, 0, 0))

	x, y := float64(sz)/2, float64(sz)/2
	dir := 0.0
	step := float64(sz) / 50.0

	stack := []struct{ x, y, dir float64 }{}

	for _, ch := range lsysStr {
		switch ch {
		case 'F':
			nx := x + step*math.Cos(dir*math.Pi/180)
			ny := y + step*math.Sin(dir*math.Pi/180)
			pt1 := image.Pt(int(x), int(y))
			pt2 := image.Pt(int(nx), int(ny))
			col := colornames.White
			gocv.Line(&img, pt1, pt2, gocv.NewScalar(float64(col.R), float64(col.G), float64(col.B), 0), 1)
			x, y = nx, ny
		case '+':
			dir += 25
		case '-':
			dir -= 25
		case '[':
			stack = append(stack, struct{ x, y, dir float64 }{x, y, dir})
		case ']':
			if len(stack) > 0 {
				top := stack[len(stack)-1]
				stack = stack[:len(stack)-1]
				x, y, dir = top.x, top.y, top.dir
			}
		}
	}
	return &img
}

func main() {
	// Open default webcam
	webcam, err := gocv.OpenVideoCapture(0)
	if err != nil {
		fmt.Printf("Error opening webcam: %v\n", err)
		return
	}
	defer webcam.Close()

	// Create display windows
	winCam := gocv.NewWindow("Webcam")
	defer winCam.Close()
	winMandala := gocv.NewWindow("Mandala")
	defer winMandala.Close()

	// Init audio
	speaker.Init(beep.SampleRate(44100), 4410)

	// Base L‑system
	ls := lsystem{
		axiom:     "F",
		rules:     map[rune]string{'F': "F+F-F-F+F"},
		angle:    90,
		iterations: 2,
	}

	rand.Seed(time.Now().UnixNano())
	frame := gocv.NewMat()
	defer frame.Close()

	for {
		if ok := webcam.Read(&frame); !ok || frame.Empty() {
			continue
		}
		// Show webcam
		winCam.IMShow(frame)

		// Extract dominant hue and map to note
		hue := dominantHue(frame)
		freq := hueToFreq(hue)
		playFreq(freq)

		// Alter L‑system rule based on interval (simple random tweak)
		if rand.Float64() < 0.1 {
			ls.rules['F'] = "F+F-F+F"
		} else {
			ls.rules['F'] = "F+F-F-F+F"
		}
		ls.iterations = 1 + int(hue/120) // 1‑3 iterations

		mandalaStr := ls.generate()
		mandalaImg := drawMandala(mandalaStr, 512)
		winMandala.IMShow(*mandalaImg)

		if winCam.WaitKey(1) == 27 { // ESC to exit
			break
		}
	}
}