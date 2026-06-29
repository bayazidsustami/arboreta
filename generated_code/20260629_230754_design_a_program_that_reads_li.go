package main

import (
	"log"
	"math"
	"os"
	"os/signal"
	"time"

	"github.com/gordonklaus/portaudio"
	"github.com/mjibson/go-dsp/fft"
	"github.com/nsf/termbox-go"
)

// Settings
const (
	sampleRate   = 44100
	framesPerBuf = 1024
	freqBands    = 16 // number of frequency bands
)

// Unicode glyphs chosen for visual variety
var glyphs = []rune{'✶', '✹', '✺', '✻', '✼', '✽', '✾', '✿', '❀', '❁', '❂', '❃', '❄', '❅', '❆', '❇'}

type column struct {
	values []rune // glyphs per row
	age    int    // fade counter
}

func main() {
	// init audio
	if err := portaudio.Initialize(); err != nil {
		log.Fatal(err)
	}
	defer portaudio.Terminate()

	// init terminal
	if err := termbox.Init(); err != nil {
		log.Fatal(err)
	}
	defer termbox.Close()

	// handle ctrl‑c gracefully
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, os.Interrupt)

	// audio buffer
	in := make([]float32, framesPerBuf)
	stream, err := portaudio.OpenDefaultStream(1, 0, sampleRate, len(in), in)
	if err != nil {
		log.Fatal(err)
	}
	defer stream.Close()
	if err = stream.Start(); err != nil {
		log.Fatal(err)
	}
	defer stream.Stop()

	// visual state
	width, height := termbox.Size()
	cols := make([]column, width)

	ticker := time.NewTicker(time.Millisecond * 30)
	defer ticker.Stop()

loop:
	for {
		select {
		case <-ticker.C:
			// read audio
			if err = stream.Read(); err != nil {
				log.Println(err)
				continue
			}
			// compute magnitude spectrum
			signalF := make([]complex128, len(in))
			for i, v := range in {
				signalF[i] = complex(float64(v), 0)
			}
			spec := fft.FFT(signalF)
			// map to bands
			bandSize := len(spec) / freqBands
			for i := 0; i < freqBands; i++ {
				start := i * bandSize
				end := start + bandSize
				var sum float64
				for j := start; j < end; j++ {
					sum += cmplxAbs(spec[j])
				}
				amp := sum / float64(bandSize)
				// choose glyph based on amplitude
				idx := int(math.Min(float64(len(glyphs)-1), amp*20))
				if idx < 0 {
					idx = 0
				}
				// push into scrolling columns
				colIdx := (i * width) / freqBands
				shiftColumn(&cols[colIdx], glyphs[idx])
			}
			// render
			termbox.Clear(termbox.ColorDefault, termbox.ColorDefault)
			for x, c := range cols {
				for y := 0; y < len(c.values) && y < height; y++ {
					fg := termbox.ColorWhite
					ageFactor := 1.0 - float64(c.age)/float64(height)
					if ageFactor < 0 {
						ageFactor = 0
					}
					if ageFactor < 0.5 {
						fg = termbox.ColorBlack
					}
					termbox.SetCell(x, height-1-y, c.values[y], fg, termbox.ColorDefault)
				}
			}
			termbox.Flush()
		case <-sig:
			break loop
		}
	}
}

// shiftColumn inserts a new glyph at the bottom, ages existing ones and discards overflow.
func shiftColumn(col *column, g rune) {
	if len(col.values) < 1 {
		col.values = []rune{}
	}
	// age increase
	col.age++
	// prepend new glyph
	col.values = append([]rune{g}, col.values...)
	// trim to reasonable length
	if len(col.values) > 100 {
		col.values = col.values[:100]
	}
}

// cmplxAbs returns magnitude of a complex number.
func cmplxAbs(c complex128) float64 {
	return math.Hypot(real(c), imag(c))
}