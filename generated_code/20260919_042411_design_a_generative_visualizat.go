package main

import (
	"bytes"
	"fmt"
	"math"
	"math/rand"
	"os"
	"os/exec"
	"strings"
	"time"
)

// Commit represents a single parsed git log entry with a conflict severity factor.
type Commit struct {
	Hash           string
	Message        string
	Timestamp      int64
	ConflictFactor float64
}

// Hypha represents a single growing filament tip in the fungal network.
type Hypha struct {
	X, Y    float64
	VX, VY  float64
	Energy  float64
	Age     int
	MaxAge  int
	Color   string
}

// fetchGitCommits retrieves local git history or falls back to a simulated set if not in a repository.
func fetchGitCommits() []Commit {
	cmd := exec.Command("git", "log", "--pretty=format:%h|%s|%at", "-n", "30")
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	
	var commits []Commit
	if err != nil {
		return []Commit{
			{"a1b2c3d", "Initial commit", time.Now().Add(-100*time.Hour).Unix(), 0.1},
			{"e4f5g6h", "Merge branch 'feature/bio' with severe conflicts", time.Now().Add(-50*time.Hour).Unix(), 0.95},
			{"i7j8k9l", "Fix merge conflict in main.go", time.Now().Add(-20*time.Hour).Unix(), 0.8},
			{"m0n1o2p", "Add spore dispersion logic", time.Now().Unix(), 0.2},
		}
	}

	lines := strings.Split(out.String(), "\n")
	for _, line := range lines {
		parts := strings.SplitN(line, "|", 3)
		if len(parts) == 3 {
			var ts int64
			fmt.Sscanf(parts[2], "%d", &ts)
			msg := strings.ToLower(parts[1])
			
			// Evaluate merge conflict severity from commit message keywords
			factor := 0.1
			if strings.Contains(msg, "conflict") || strings.Contains(msg, "resolve") {
				factor = 0.9
			} else if strings.Contains(msg, "merge") {
				factor = 0.5
			} else if strings.Contains(msg, "fix") {
				factor = 0.3
			}

			commits = append(commits, Commit{
				Hash:           parts[0],
				Message:        parts[1],
				Timestamp:      ts,
				ConflictFactor: factor,
			})
		}
	}
	return commits
}

func main() {
	commits := fetchGitCommits()
	width, height := 80, 24
	
	var network []*Hypha
	rand.Seed(time.Now().UnixNano())
	
	// Seed fungal network nodes based on commit history and conflict severity
	for i, c := range commits {
		startX := float64(width / 2)
		startY := float64(height / 2)
		
		// Color mapping: Cyan for peaceful growth, Magenta/Red for conflict-heavy branches
		color := "\033[36m"
		if c.ConflictFactor > 0.7 {
			color = "\033[35m"
		} else if c.ConflictFactor > 0.4 {
			color = "\033[33m"
		}

		angle := rand.Float64() * 2 * math.Pi
		speed := 0.4 + c.ConflictFactor*1.2
		
		network = append(network, &Hypha{
			X:      startX + float64(i%10-5)*2,
			Y:      startY + float64(i/10-2)*2,
			VX:     math.Cos(angle) * speed,
			VY:     math.Sin(angle) * speed,
			Energy: 15.0 + c.ConflictFactor*25.0,
			Age:    0,
			MaxAge: 40 + int(c.ConflictFactor*40),
			Color:  color,
		})
	}

	// Setup terminal for real-time animation (clear screen, hide cursor)
	fmt.Print("\033[2J\033[?25l")
	defer fmt.Print("\033[?25h\033[0m")

	// Real-time growth and decay simulation loop
	for frame := 0; frame < 180; frame++ {
		grid := make([][]string, height)
		colorGrid := make([][]string, height)
		for y := 0; y < height; y++ {
			grid[y] = make([]string, width)
			colorGrid[y] = make([]string, width)
			for x := 0; x < width; x++ {
				grid[y][x] = " "
				colorGrid[y][x] = "\033[0m"
			}
		}

		var nextGen []*Hypha
		for _, h := range network {
			h.X += h.VX
			h.Y += h.VY
			h.Age++
			h.Energy -= 0.15

			// Wrap around borders smoothly
			if h.X < 0 { h.X = float64(width - 1) }
			if h.X >= float64(width) { h.X = 0 }
			if h.Y < 0 { h.Y = float64(height - 1) }
			if h.Y >= float64(height) { h.Y = 0 }

			ix, iy := int(h.X), int(h.Y)
			if ix >= 0 && ix < width && iy >= 0 && iy < height {
				char := "*"
				if h.Age%2 == 0 { char = "o" }
				if h.Energy < 5 { char = "." }
				grid[iy][ix] = char
				colorGrid[iy][ix] = h.Color
			}

			// Branching based on current energy and organic randomness
			if h.Energy > 4 && h.Age < h.MaxAge && rand.Float64() < 0.2 {
				angle := rand.Float64() * 2 * math.Pi
				nextGen = append(nextGen, &Hypha{
					X:      h.X,
					Y:      h.Y,
					VX:     math.Cos(angle) * 0.7,
					VY:     math.Sin(angle) * 0.7,
					Energy: h.Energy * 0.5,
					Age:    0,
					MaxAge: h.MaxAge / 2,
					Color:  h.Color,
				})
			}

			if h.Energy > 0 && h.Age < h.MaxAge {
				nextGen = append(nextGen, h)
			}
		}
		network = nextGen

		// Render frame
		var buf bytes.Buffer
		buf.WriteString("\033[H")
		buf.WriteString("\033[1;32m=== GIT MYCELIUM NETWORK: BIOLUMINESCENT CONFLICT VISUALIZER ===\033[0m\n")
		
		for y := 0; y < height; y++ {
			for x := 0; x < width; x++ {
				buf.WriteString(colorGrid[y][x] + grid[y][x] + "\033[0m")
			}
			buf.WriteString("\n")
		}
		buf.WriteString(fmt.Sprintf("Frame: %3d | Active Hyphae: %3d | Status: Growing & Decaying\n", frame, len(network)))

		os.Stdout.Write(buf.Bytes())
		time.Sleep(70 * time.Millisecond)
	}
}