package main

import (
	"bufio"
	"fmt"

	"math"
	"math/rand"
	"os"

	"strings"
	"sync"

	"time"

	"golang.org/x/term"
)

// Braille constants for 2x4 dot mapping per terminal character
var brailleOffsets = [2][4]rune{
	{0x01, 0x02, 0x04, 0x40}, // Left column dots (1, 2, 3, 7)
	{0x08, 0x10, 0x20, 0x80}, // Right column dots (4, 5, 6, 8)
}

// Positive/Negative sentiment lexicons
var (
	positiveWords = map[string]float64{
		"success": 1.5, "ok": 1.0, "ready": 1.0, "connected": 1.2,
		"passed": 1.2, "fast": 1.0, "created": 1.0, "resolved": 1.5,
		"active": 0.8, "optimal": 1.5, "info": 0.2, "completed": 1.2,
	}
	negativeWords = map[string]float64{
		"error": 2.0, "fail": 2.0, "failed": 2.0, "fatal": 3.0,
		"timeout": 1.5, "denied": 1.5, "refused": 1.5, "slow": 1.0,
		"warn": 1.0, "warning": 1.0, "corrupt": 2.5, "panic": 3.0,
	}
)

type Star struct {
	X, Y   float64
	Vx, Vy float64
	Mass   float64
}

type Cluster struct {
	X, Y       float64
	BaseMass   float64
	Sentiment  float64 // Dynamically modified mass shift
	Stars      []*Star
}

type Canvas struct {
	Width, Height int
	Grid          [][]bool
}

func NewCanvas(w, h int) *Canvas {
	grid := make([][]bool, h)
	for i := range grid {
		grid[i] = make([]bool, w)
	}
	return &Canvas{Width: w, Height: h, Grid: grid}
}

func (c *Canvas) Clear() {
	for y := 0; y < c.Height; y++ {
		for x := 0; x < c.Width; x++ {
			c.Grid[y][x] = false
		}
	}
}

func (c *Canvas) Set(x, y int) {
	if x >= 0 && x < c.Width && y >= 0 && y < c.Height {
		c.Grid[y][x] = true
	}
}

// Render encodes the boolean 2x4 sub-pixel grid into Braille Unicode characters
func (c *Canvas) Render() string {
	var sb strings.Builder
	charW, charH := c.Width/2, c.Height/4

	for cy := 0; cy < charH; cy++ {
		for cx := 0; cx < charW; cx++ {
			var r rune = 0x2800 // Braille base pattern
			for dx := 0; dx < 2; dx++ {
				for dy := 0; dy < 4; dy++ {
					px := cx*2 + dx
					py := cy*4 + dy
					if px < c.Width && py < c.Height && c.Grid[py][px] {
						r |= brailleOffsets[dx][dy]
					}
				}
			}
			sb.WriteRune(r)
		}
		sb.WriteRune('\n')
	}
	return sb.String()
}

type Galaxy struct {
	Clusters []*Cluster
	mu       sync.RWMutex
}

func NewGalaxy(w, h int, numClusters, starsPerCluster int) *Galaxy {
	g := &Galaxy{}
	centerX, centerY := float64(w)/2.0, float64(h)/2.0

	for i := 0; i < numClusters; i++ {
		angle := float64(i) * (2 * math.Pi / float64(numClusters))
		dist := 15.0 + rand.Float64()*15.0
		cx := centerX + math.Cos(angle)*dist
		cy := centerY + math.Sin(angle)*dist

		cluster := &Cluster{
			X:        cx,
			Y:        cy,
			BaseMass: 500.0 + rand.Float64()*500.0,
		}

		for j := 0; j < starsPerCluster; j++ {
			// Distribute stars in a spiral swirl around cluster core
			rad := rand.Float64() * 12.0
			theta := rand.Float64() * 2 * math.Pi
			sx := cx + rad*math.Cos(theta)
			sy := cy + rad*math.Sin(theta)

			// Orbital velocity around center
			dx, dy := sx-centerX, sy-centerY
			r := math.Hypot(dx, dy)
			v := math.Sqrt(1200.0 / (r + 1.0))
			vx := -v * (dy / r)
			vy := v * (dx / r)

			cluster.Stars = append(cluster.Stars, &Star{
				X: sx, Y: sy,
				Vx: vx, Vy: vy,
				Mass: 1.0 + rand.Float64()*2.0,
			})
		}
		g.Clusters = append(g.Clusters, cluster)
	}
	return g
}

func (g *Galaxy) Update(dt float64, width, height float64) {
	g.mu.Lock()
	defer g.mu.Unlock()

	// Update gravitational attraction between all star clusters and stars
	for _, c := range g.Clusters {
		effectiveMass := c.BaseMass + c.Sentiment
		if effectiveMass < 10.0 {
			effectiveMass = 10.0 // Prevent total collapse or inverse gravity
		}

		for _, star := range c.Stars {
			// Force towards cluster core
			dx := c.X - star.X
			dy := c.Y - star.Y
			distSq := dx*dx + dy*dy + 25.0 // Softening parameter to avoid division by zero
			force := (effectiveMass * star.Mass) / distSq

			dist := math.Sqrt(distSq)
			star.Vx += (force * (dx / dist)) * dt
			star.Vy += (force * (dy / dist)) * dt

			// Subtle swirl force
			star.Vx += -dy * 0.05 * dt
			star.Vy += dx * 0.05 * dt

			// Velocity damping for fluid feel
			star.Vx *= 0.995
			star.Vy *= 0.995

			star.X += star.Vx * dt
			star.Y += star.Vy * dt

			// Toroidal wrap-around boundaries
			if star.X < 0 {
				star.X += width
			}
			if star.X >= width {
				star.X -= width
			}
			if star.Y < 0 {
				star.Y += height
			}
			if star.Y >= height {
				star.Y -= height
			}
		}
	}
}

func (g *Galaxy) ApplySentiment(sentimentScore float64) {
	g.mu.Lock()
	defer g.mu.Unlock()
	// Distribute sentiment effect across clusters randomly
	for _, c := range g.Clusters {
		c.Sentiment += (sentimentScore * 150.0)
		// Gradual dissipation back to neutral base mass over time
		c.Sentiment *= 0.95
	}
}

// Log sentiment analyzer
func analyzeSentiment(logLine string) float64 {
	words := strings.Fields(strings.ToLower(logLine))
	score := 0.0
	for _, w := range words {
		w = strings.Trim(w, "[],.:;!\"'")
		if val, ok := positiveWords[w]; ok {
			score += val
		}
		if val, ok := negativeWords[w]; ok {
			score -= val
		}
	}
	return score
}

// Generates synthetic live system logs for simulation demonstration
func generateSyntheticLogs(logChan chan<- string) {
	templates := []string{
		"INFO [system] Cluster node active and connected",
		"SUCCESS Data sync completed in 12ms",
		"WARN [network] Connection slow, retrying...",
		"ERROR [auth] Access denied for user admin",
		"FATAL [database] Storage corrupt! Panic triggered",
		"OPTIMAL System status ok, performance resolved",
	}
	for {
		time.Sleep(time.Duration(200+rand.Intn(600)) * time.Millisecond)
		logChan <- templates[rand.Intn(len(templates))]
	}
}

func main() {
	rand.Seed(time.Now().UnixNano())

	// Set raw terminal mode if available
	fd := int(os.Stdin.Fd())
	if term.IsTerminal(fd) {
		oldState, err := term.MakeRaw(fd)
		if err == nil {
			defer term.Restore(fd, oldState)
		}
	}

	// Fetch terminal dimensions
	tw, th, err := term.GetSize(fd)
	if err != nil || tw == 0 || th == 0 {
		tw, th = 80, 24 // Fallback
	}

	// Resolution doubled horizontally and quadrupled vertically using Braille
	subW, subH := tw*2, th*4
	canvas := NewCanvas(subW, subH)
	galaxy := NewGalaxy(subW, subH, 4, 300)

	logChan := make(chan string, 100)
	go generateSyntheticLogs(logChan)

	// Stream live stdin if pipe/redirect exists alongside synthetic logs
	go func() {
		scanner := bufio.NewScanner(os.Stdin)
		for scanner.Scan() {
			logChan <- scanner.Text()
		}
	}()

	// Clear terminal screen & hide cursor
	fmt.Print("\033[2J\033[?25l")
	defer fmt.Print("\033[?25h") // Restore cursor on exit

	ticker := time.NewTicker(30 * time.Millisecond)
	defer ticker.Stop()

	lastLog := "Listening for log stream..."
	var currentScore float64

	for range ticker.C {
		// Process incoming live logs
	DrainLogs:
		for {
			select {
			case logLine := <-logChan:
				currentScore = analyzeSentiment(logLine)
				galaxy.ApplySentiment(currentScore)
				lastLog = logLine
				if len(lastLog) > tw-25 {
					lastLog = lastLog[:tw-25] + "..."
				}
			default:
				break DrainLogs
			}
		}

		// Physics update step
		galaxy.Update(0.15, float64(subW), float64(subH))

		// Clear canvas and draw stars
		canvas.Clear()
		galaxy.mu.RLock()
		for _, c := range galaxy.Clusters {
			for _, star := range c.Stars {
				canvas.Set(int(star.X), int(star.Y))
			}
		}
		galaxy.mu.RUnlock()

		// Move cursor to top-left corner and render frame
		output := canvas.Render()
		hud := fmt.Sprintf("\033[H\033[36m[GALAXY SENTIMENT FLUID ENGINE] | Last Sentiment: %+.1f | Log: %s\033[0m\n", currentScore, lastLog)
		fmt.Print(hud + output)
	}
}