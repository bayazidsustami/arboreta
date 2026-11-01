package main

import (
	"bytes"
	"encoding/base64"
	"encoding/binary"
	"fmt"
	"math"
	"math/rand"
	"net"
	"os"
	"os/exec"
	"time"
)

// Generates a base64-encoded WAV audio tone triggered by network latency spikes
func generateBase64Tone(freq float64, durationMs int) string {
	sampleRate := 8000
	numSamples := sampleRate * durationMs / 1000
	dataSize := numSamples * 2
	buf := new(bytes.Buffer)
	
	// WAV Header construction
	buf.WriteString("RIFF")
	binary.Write(buf, binary.LittleEndian, uint32(36+dataSize))
	buf.WriteString("WAVE")
	buf.WriteString("fmt ")
	binary.Write(buf, binary.LittleEndian, uint32(16))
	binary.Write(buf, binary.LittleEndian, uint16(1))
	binary.Write(buf, binary.LittleEndian, uint16(1))
	binary.Write(buf, binary.LittleEndian, uint32(sampleRate))
	binary.Write(buf, binary.LittleEndian, uint32(sampleRate*2))
	binary.Write(buf, binary.LittleEndian, uint16(2))
	binary.Write(buf, binary.LittleEndian, uint16(16))
	buf.WriteString("data")
	binary.Write(buf, binary.LittleEndian, uint32(dataSize))

	for i := 0; i < numSamples; i++ {
		t := float64(i) / float64(sampleRate)
		env := 1.0 - float64(i)/float64(numSamples)
		val := int16(math.Sin(2*math.Pi*freq*t) * 16383 * env)
		binary.Write(buf, binary.LittleEndian, val)
	}
	return base64.StdEncoding.EncodeToString(buf.Bytes())
}

// Decodes base64 audio and plays it asynchronously using available system audio players
func playBase64Audio(b64 string) {
	data, err := base64.StdEncoding.DecodeString(b64)
	if err != nil {
		return
	}
	tmpFile, err := os.CreateTemp("", "coral_*.wav")
	if err != nil {
		return
	}
	defer os.Remove(tmpFile.Name())
	if _, err := tmpFile.Write(data); err != nil {
		tmpFile.Close()
		return
	}
	tmpFile.Close()

	go func() {
		var cmd *exec.Cmd
		if _, err := exec.LookPath("afplay"); err == nil {
			cmd = exec.Command("afplay", tmpFile.Name())
		} else if _, err := exec.LookPath("aplay"); err == nil {
			cmd = exec.Command("aplay", "-q", tmpFile.Name())
		} else if _, err := exec.LookPath("ffplay"); err == nil {
			cmd = exec.Command("ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet", tmpFile.Name())
		}
		if cmd != nil {
			cmd.Run()
		}
	}()
}

// Measures live TCP handshake latency to cloudflare DNS
func measureLatency() time.Duration {
	start := time.Now()
	conn, err := net.DialTimeout("tcp", "1.1.1.1:53", 1*time.Second)
	dur := time.Since(start)
	if err != nil {
		return time.Duration(40+rand.Intn(160)) * time.Millisecond
	}
	conn.Close()
	return dur
}

func main() {
	// Setup terminal: clear screen and hide cursor
	fmt.Print("\033[2J\033[?25l")
	defer fmt.Print("\033[?25h\033[0m")

	width, height := 70, 20
	grid := make([][]rune, height)
	colorGrid := make([][]int, height)
	for y := 0; y < height; y++ {
		grid[y] = make([]rune, width)
		colorGrid[y] = make([]int, width)
		for x := 0; x < width; x++ {
			grid[y][x] = ' '
			colorGrid[y][x] = 30
		}
	}

	for x := 0; x < width; x++ {
		grid[height-1][x] = '_'
		colorGrid[height-1][x] = 34
	}

	rand.Seed(time.Now().UnixNano())
	chars := []rune(".,-~:;=!*#$@")

	for {
		lat := measureLatency()
		latMs := float64(lat.Milliseconds())

		// Synthesize and play audio pulse when a latency spike occurs (>100ms)
		if latMs > 100 {
			freq := 200.0 + math.Min(latMs*2.5, 1200.0)
			b64 := generateBase64Tone(freq, 150)
			playBase64Audio(b64)
		}

		// Scroll terminal reef upwards
		for y := 1; y < height-2; y++ {
			copy(grid[y], grid[y+1])
			copy(colorGrid[y], colorGrid[y+1])
		}

		// Grow fractal coral structures based on latency intensity
		for x := 1; x < width-1; x++ {
			y := height - 2
			left := grid[y][x-1] != ' '
			right := grid[y][x+1] != ' '
			if left || right || rand.Float64() < 0.25 {
				idx := int(latMs / 25)
				if idx >= len(chars) {
					idx = len(chars) - 1
				}
				if idx < 0 {
					idx = 0
				}
				grid[y][x] = chars[rand.Intn(idx+1)]
				
				// ANSI Color shifts based on spike severity
				if latMs > 150 {
					colorGrid[y][x] = 91 // Vibrant coral red spike
				} else if latMs > 80 {
					colorGrid[y][x] = 95 // Magenta bloom
				} else {
					colorGrid[y][x] = 36 // Deep cyan calm
				}
			} else {
				grid[y][x] = ' '
			}
		}

		// Render ANSI canvas
		var buf bytes.Buffer
		buf.WriteString("\033[H")
		buf.WriteString(fmt.Sprintf("=== LIVE LATENCY FRACTAL CORAL REEF === Ping: %3.0fms\n", latMs))
		for y := 0; y < height; y++ {
			for x := 0; x < width; x++ {
				c := colorGrid[y][x]
				r := grid[y][x]
				buf.WriteString(fmt.Sprintf("\033[%dm%c\033[0m", c, r))
			}
			buf.WriteString("\n")
		}
		fmt.Print(buf.String())

		time.Sleep(350 * time.Millisecond)
	}
}