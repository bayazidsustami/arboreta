package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"
)

// Wing frames for animated ASCII birds across wingbeat phases.
var wingFrames = []string{
	`  \v/  `,
	`  -v-  `,
	`  /v\  `,
	`   v   `,
}

// Color palette shifts with typing rhythm from calm twilight to brisk ember.
var rhythmPalette = []string{
	"\x1b[38;5;111m", // calm sky blue
	"\x1b[38;5;116m", // steady teal
	"\x1b[38;5;150m", // flowing sage
	"\x1b[38;5;221m", // warm gold
	"\x1b[38;5;209m", // brisk coral
}

type bird struct {
	x       float64
	y       int
	speed   float64
	phase   float64
	drift   float64
	hueIdx  int
}

type flockState struct {
	mu          sync.Mutex
	birds       []bird
	lastKeyTime time.Time
	bpm         float64 // derived typing cadence in beats/keystrokes per minute
	energy      float64 // smoothed 0.0..1.0 rhythm intensity
	pulse       float64 // visual ripple boosted on each keystroke
}

func newFlock(width, height int) *flockState {
	now := time.Now()
	fs := &flockState{
		lastKeyTime: now,
		bpm:         90,
		energy:      0.25,
	}
	count := max(8, min(36, (width*height)/90))
	for i := range count {
		fs.birds = append(fs.birds, bird{
			x:      float64(i * (width / max(1, count))),
			y:      1 + (i * 3 % max(2, height-3)),
			speed:  0.18 + float64(i%5)*0.05,
			phase:  float64(i) * 0.85,
			drift:  float64(i%3 - 1) * 0.04,
			hueIdx: i % len(rhythmPalette),
		})
	}
	return fs
}

// recordKeystroke maps inter-keystroke intervals into wingbeat speed, color, and flock lift.
func (fs *flockState) recordKeystroke(now time.Time, width, height int) {
	fs.mu.Lock()
	defer fs.mu.Unlock()

	dt := now.Sub(fs.lastKeyTime).Seconds()
	fs.lastKeyTime = now

	if dt > 0.02 && dt < 4.0 {
		instBPM := min(480.0, max(30.0, 60.0/dt))
		fs.bpm = fs.bpm*0.65 + instBPM*0.35
	}

	targetEnergy := min(1.0, max(0.05, (fs.bpm-45.0)/260.0))
	fs.energy = fs.energy*0.7 + targetEnergy*0.3
	fs.pulse = 1.0

	// Spawn an occasional newcomer on rapid bursts so the tapestry breathes with typing.
	if len(fs.birds) < 42 && fs.energy > 0.55 && int(now.UnixNano())%3 == 0 {
		fs.birds = append(fs.birds, bird{
			x:      0,
			y:      1 + int(now.UnixNano()>>8)%max(2, height-3),
			speed:  0.25 + fs.energy*0.55,
			phase:  float64(len(fs.birds)),
			drift:  float64(int(now.UnixNano())%3-1) * 0.05,
			hueIdx: min(len(rhythmPalette)-1, int(fs.energy*float64(len(rhythmPalette)))),
		})
	}
	_ = width
}

func (fs *flockState) stepAndRender(width, height int) string {
	fs.mu.Lock()
	defer fs.mu.Unlock()

	// Gentle decay when the typist pauses so birds glide and slow naturally.
	sinceKey := time.Since(fs.lastKeyTime).Seconds()
	if sinceKey > 0.35 {
		fs.energy = max(0.05, fs.energy*0.965)
		fs.bpm = max(35.0, fs.bpm*0.985)
	}
	fs.pulse = max(0.0, fs.pulse*0.88)

	// Wingbeat angular velocity scales smoothly with typing rhythm.
	flapRate := 0.14 + fs.energy*0.75 + fs.pulse*0.25
	baseHue := min(len(rhythmPalette)-1, int(fs.energy*float64(len(rhythmPalette)-1)))

	canvas := make([][]rune, height)
	colors := make([][]string, height)
	for r := range height {
		canvas[r] = make([]rune, width)
		colors[r] = make([]string, width)
		for c := range width {
			canvas[r][c] = ' '
		}
	}

	// Subtle woven horizon/wind threads that shift with rhythm energy.
	for r := 1; r < height-1; r++ {
		if r%(4-min(2, int(fs.energy*3))) == 0 {
			for c := 0; c < width; c += 6 {
				offset := int(fs.pulse * 3)
				col := (c + r*2 + offset) % width
				if canvas[r][col] == ' ' {
					canvas[r][col] = '·'
					colors[r][col] = "\x1b[38;5;238m"
				}
			}
		}
	}

	for i := range fs.birds {
		b := &fs.birds[i]
		b.phase += flapRate + b.drift*0.2
		b.x += b.speed + fs.energy*0.55 + fs.pulse*0.35

		if int(b.x) >= width {
			b.x = -6
			b.y = 1 + ((b.y + int(fs.bpm)) % max(2, height-3))
		}

		// Subtle vertical wave tied to each bird's wing cycle.
		wy := b.y + int(1.5*sinApprox(b.phase*0.5))
		if wy < 1 {
			wy = 1
		} else if wy >= height-1 {
			wy = height - 2
		}

		frameIdx := int(b.phase) % len(wingFrames)
		if frameIdx < 0 {
			frameIdx += len(wingFrames)
		}
		frame := []rune(wingFrames[frameIdx])
		hue := rhythmPalette[(baseHue+b.hueIdx)%len(rhythmPalette)]

		for offset, ch := range frame {
			if ch == ' ' {
				continue
			}
			cx := int(b.x) + offset
			if cx >= 0 && cx < width {
				canvas[wy][cx] = ch
				colors[wy][cx] = hue
			}
		}
	}

	var sb strings.Builder
	sb.Grow(width*height*2 + 256)
	sb.WriteString("\x1b[H") // cursor home

	header := fmt.Sprintf(
		" Cadence: %5.0f KPM  |  Wing Energy: %3.0f%%  |  Flock: %2d  |  Type to flap • Ctrl+C to quit ",
		fs.bpm, fs.energy*100, len(fs.birds),
	)
	if len(header) > width {
		header = header[:width]
	}
	sb.WriteString("\x1b[48;5;235m\x1b[38;5;252m")
	sb.WriteString(header)
	if len(header) < width {
		sb.WriteString(strings.Repeat(" ", width-len(header)))
	}
	sb.WriteString("\x1b[0m\n")

	for r := 0; r < height-1; r++ {
		lastColor := ""
		for c := 0; c < width; c++ {
			ch := canvas[r][c]
			col := colors[r][c]
			if ch == ' ' {
				if lastColor != "" {
					sb.WriteString("\x1b[0m")
					lastColor = ""
				}
				sb.WriteByte(' ')
				continue
			}
			if col != lastColor {
				sb.WriteString("\x1b[0m")
				sb.WriteString(col)
				lastColor = col
			}
			sb.WriteRune(ch)
		}
		if lastColor != "" {
			sb.WriteString("\x1b[0m")
		}
		sb.WriteByte('\n')
	}

	return sb.String()
}

// Fast sine approximation to keep per-frame math lightweight without extra imports.
func sinApprox(x float64) float64 {
	const pi = 3.141592653589793
	for x > pi {
		x -= 2 * pi
	}
	for x < -pi {
		x += 2 * pi
	}
	x2 := x * x
	return x * (1 - x2/6 + x2*x2/120)
}

func terminalSize() (int, int) {
	cmd := exec.Command("stty", "size")
	cmd.Stdin = os.Stdin
	out, err := cmd.Output()
	if err == nil {
		var rows, cols int
		if _, scanErr := fmt.Sscanf(strings.TrimSpace(string(out)), "%d %d", &rows, &cols); scanErr == nil && cols >= 30 && rows >= 8 {
			return cols, rows
		}
	}
	return 80, 24
}

func enableRawMode() (restore func(), err error) {
	stateCmd := exec.Command("stty", "-g")
	stateCmd.Stdin = os.Stdin
	orig, err := stateCmd.Output()
	if err != nil {
		return nil, err
	}
	rawCmd := exec.Command("stty", "raw", "-echo")
	rawCmd.Stdin = os.Stdin
	if err := rawCmd.Run(); err != nil {
		return nil, err
	}
	saved := strings.TrimSpace(string(orig))
	return func() {
		cmd := exec.Command("stty", saved)
		cmd.Stdin = os.Stdin
		_ = cmd.Run()
	}, nil
}

func main() {
	restore, err := enableRawMode()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to enable raw terminal input: %v\n", err)
		os.Exit(1)
	}
	defer func() {
		restore()
		fmt.Print("\x1b[?25h\x1b[0m\n") // show cursor & reset colors
	}()

	fmt.Print("\x1b[?25l\x1b[2J") // hide cursor & clear screen

	width, height := terminalSize()
	flock := newFlock(width, height)

	keyCh := make(chan byte, 64)
	doneCh := make(chan struct{})

	go func() {
		buf := make([]byte, 1)
		for {
			n, readErr := os.Stdin.Read(buf)
			if readErr != nil || n == 0 {
				close(doneCh)
				return
			}
			b := buf[0]
			if b == 3 { // Ctrl+C
				close(doneCh)
				return
			}
			select {
			case keyCh <- b:
			default:
			}
		}
	}()

	ticker := time.NewTicker(45 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-doneCh:
			return
		case <-keyCh:
			w, h := terminalSize()
			flock.recordKeystroke(time.Now(), w, h)
		case <-ticker.C:
			w, h := terminalSize()
			frame := flock.stepAndRender(w, h)
			fmt.Print(frame)
		}
	}
}