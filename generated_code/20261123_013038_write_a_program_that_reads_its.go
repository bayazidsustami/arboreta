package main

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"math"
	"math/cmplx"
	"os"
	"time"
)

const (
	sampleRate = 22050
	stepDur    = 140 * time.Millisecond
	termW      = 72
	termH      = 24
)

// Lydian & Dorian ambient scale intervals in semitones relative to A2 (110 Hz)
var scaleSemitones = []float64{0, 2, 4, 6, 7, 9, 11, 12, 14, 16, 19}

// Note represents a single voice event parsed from a source token or character.
type Note struct {
	freq    float64
	tension float64 // 0.0 (consonant root/fifth) to 1.0 (dissonant tritone/cluster)
	pan     float64 // -1.0 left to +1.0 right
}

// loadSelfScore reads this source file (or falls back to embedded fallback bytes if run from a temp binary).
func loadSelfScore() []byte {
	if data, err := os.ReadFile("main.go"); err == nil && len(data) > 0 {
		return data
	}
	if len(os.Args) > 0 {
		if data, err := os.ReadFile(os.Args[0]); err == nil && len(data) > 0 {
			return data
		}
	}
	return []byte("func ambientFractalScore(t float64) { return math.Sin(t) * 0.5 }")
}

// chordFromWindow maps a slice of source bytes into a polyphonic chord and harmonic tension metric.
func chordFromWindow(window []byte) ([]Note, float64) {
	if len(window) == 0 {
		return []Note{{freq: 110, tension: 0.1, pan: 0}}, 0.1
	}

	// Pick up to 4 distinct structural voices across the source window
	voices := make([]Note, 0, 4)
	step := len(window) / 4
	if step < 1 {
		step = 1
	}

	var sumTension float64
	for i := 0; i < 4; i++ {
		idx := (i * step) % len(window)
		b := window[idx]

		// Map byte value onto scale degree
		deg := int(b) % len(scaleSemitones)
		octaveShift := 0.0
		if b > 122 { // uppercase/symbols lift into upper shimmer register
			octaveShift = 12.0
		} else if b < 65 { // punctuation/whitespace anchors bass/mid register
			octaveShift = -12.0
		}

		semis := scaleSemitones[deg] + octaveShift
		freq := 220.0 * math.Pow(2.0, semis/12.0)

		// Punctuation, braces, and operators inject higher harmonic tension
		t := 0.15
		switch {
		case b == '{' || b == '}' || b == '(' || b == ')' || b == '[' || b == ']':
			t = 0.72
		case b == ';' || b == ':' || b == '=' || b == '+' || b == '-' || b == '*' || b == '/':
			t = 0.58
		case b == ' ' || b == '\n' || b == '\t':
			t = 0.12
		default:
			t = 0.25 + 0.35*float64(b%7)/6.0
		}

		pan := float64(i)*0.6 - 0.9 // spread voices across stereo field
		voices = append(voices, Note{freq: freq, tension: t, pan: pan})
		sumTension += t
	}

	avgTension := math.Min(1.0, sumTension/float64(len(voices)))
	return voices, avgTension
}

// synthStereoPCM renders a polyphonic ambient buffer (16-bit signed stereo PCM) with slow attack/release envelopes.
func synthStereoPCM(notes []Note, dur time.Duration, phase float64, tension float64) ([]byte, float64) {
	numSamples := int(dur.Seconds() * float64(sampleRate))
	if numSamples < 1 {
		numSamples = 1
	}
	var buf bytes.Buffer
	buf.Grow(numSamples * 4)

	twoPi := 2.0 * math.Pi
	for n := 0; n < numSamples; n++ {
		frac := float64(n) / float64(numSamples)
		// Smooth ambient envelope to prevent clicks between source steps
		env := math.Sin(math.Pi * frac)
		env = env * env

		var mixL, mixR float64
		for vIdx, nt := range notes {
			p := phase + float64(n)*(twoPi*nt.freq/float64(sampleRate)) + float64(vIdx)*0.7
			// Warm sine + soft sub/overtone blend modulated by harmonic tension
			fundamental := math.Sin(p)
			overtone := math.Sin(p*2.0+tension*3.14) * (0.15 + 0.35*tension)
			sample := (fundamental + overtone) * 0.22 * env

			rWeight := (nt.pan + 1.0) * 0.5
			lWeight := 1.0 - rWeight
			mixL += sample * lWeight
			mixR += sample * rWeight
		}

		// Soft saturation limiter
		mixL = math.Tanh(mixL * (1.0 + tension*0.6))
		mixR = math.Tanh(mixR * (1.0 + tension*0.6))

		iL := int16(mixL * 32767.0)
		iR := int16(mixR * 32767.0)
		_ = binary.Write(&buf, binary.LittleEndian, iL)
		_ = binary.Write(&buf, binary.LittleEndian, iR)
	}

	nextPhase := phase + float64(numSamples)*(twoPi*110.0/float64(sampleRate))
	nextPhase = math.Mod(nextPhase, twoPi*1000.0)
	return buf.Bytes(), nextPhase
}

// renderFractal warps a Julia/Mandelbrot hybrid escape-time field according to harmonic tension and time.
func renderFractal(step int, tension float64, freqAnchor float64, snippet string) string {
	const palette = " .:-=+*#%@"
	t := float64(step) * 0.12

	// Tension warps Julia constant c and zooms/rotates the complex plane
	warpAngle := t*0.35 + tension*2.4
	warpRadius := 0.58 + 0.24*tension
	c := complex(
		warpRadius*math.Cos(warpAngle)-0.35*math.Cos(t*0.17),
		warpRadius*math.Sin(warpAngle)+0.22*math.Sin(t*0.23+tension),
	)

	zoom := 1.35 - 0.45*tension + 0.12*math.Sin(t*0.5)
	rot := cmplx.Exp(complex(0, tension*0.75+0.05*math.Sin(t)))

	var out bytes.Buffer
	// Clear screen & home cursor using ANSI escape codes
	out.WriteString("\x1b[H\x1b[2J")
	out.WriteString(fmt.Sprintf("SELF-SCORE AMBIENT FRACTAL | Step: %04d | Tension: %.2f | Anchor: %.1f Hz\n", step, tension, freqAnchor))
	out.WriteString(fmt.Sprintf("Score Slice: %q\n", snippet))

	maxIter := 24 + int(tension*24)
	for py := 0; py < termH; py++ {
		ny := (float64(py)/float64(termH-1)*2.0 - 1.0) * zoom
		for px := 0; px < termW; px++ {
			nx := (float64(px)/float64(termW-1)*2.0 - 1.0) * zoom * 1.5
			z := complex(nx, ny) * rot

			iter := 0
			for iter < maxIter && cmplx.Abs(z) <= 2.0 {
				// Higher tension bends iteration exponent slightly for organic filaments
				if tension > 0.65 && iter%3 == 0 {
					z = cmplx.Pow(z, complex(2.0+0.15*tension, 0.08*tension)) + c
				} else {
					z = z*z + c
				}
				iter++
			}

			if iter == maxIter {
				out.WriteByte('#')
			} else {
				idx := (iter * (len(palette) - 1)) / maxIter
				if idx < 0 {
					idx = 0
				} else if idx >= len(palette) {
					idx = len(palette) - 1
				}
				out.WriteByte(palette[idx])
			}
		}
		out.WriteByte('\n')
	}
	return out.String()
}

func main() {
	src := loadSelfScore()
	windowSize := 24
	if len(src) < windowSize {
		windowSize = len(src)
	}

	var phase float64
	step := 0

	// Stream through own source code continuously, looping seamlessly
	for {
		start := (step * 7) % len(src)
		window := make([]byte, windowSize)
		for i := 0; i < windowSize; i++ {
			window[i] = src[(start+i)%len(src)]
		}

		notes, tension := chordFromWindow(window)
		pcm, nextPhase := synthStereoPCM(notes, stepDur, phase, tension)
		phase = nextPhase

		// Emit raw stereo PCM to a non-TTY stdout pipe if redirected (e.g. `go run main.go | aplay -f S16_LE -r 22050 -c 2`)
		if info, err := os.Stdout.Stat(); err == nil && (info.Mode()&os.ModeCharDevice) == 0 {
			_, _ = os.Stdout.Write(pcm)
		}

		// Clean printable snippet for display
		clean := make([]byte, 0, len(window))
		for _, b := range window {
			if b >= 32 && b <= 126 {
				clean = append(clean, b)
			} else {
				clean = append(clean, ' ')
			}
		}

		frame := renderFractal(step, tension, notes[0].freq, string(clean))
		if info, err := os.Stdout.Stat(); err == nil && (info.Mode()&os.ModeCharDevice) != 0 {
			fmt.Print(frame)
		} else {
			fmt.Fprint(os.Stderr, frame)
		}

		step++
		time.Sleep(stepDur)
	}
}