package main

import (
	"bytes"
	"fmt"
	"math/rand"
	"os/exec"
	"strings"
	"time"
)

// Commit represents a parsed git commit or a simulated one.
type Commit struct {
	Hash     string
	IsMerge  bool
	IsDelete bool
	Author   string
}

// Node represents a point in our fungal network (mycelium).
type Node struct {
	X, Y     int
	Type     rune // '·' (hyphae), '🍄' (merge conflict mushroom), 'ø' (fossilized spore)
	Color    string
	Children []*Node
}

func main() {
	rand.Seed(time.Now().UnixNano())

	// Try to fetch real git history, fallback to artistic simulation if not a git repo
	commits := fetchGitHistory()
	if len(commits) == 0 {
		commits = generateMockHistory(42)
	}

	// Initialize terminal canvas (width x height)
	width, height := 80, 24
	canvas := make([][]rune, height)
	colors := make([][]string, height)
	for y := 0; y < height; y++ {
		canvas[y] = make([]rune, width)
		colors[y] = make([]string, width)
		for x := 0; x < width; x++ {
			canvas[y][x] = ' '
			colors[y][x] = "\033[90m" // Dim gray background
		}
	}

	// Grow the fungal network from the center based on commits
	cx, cy := width/2, height/2
	currentX, currentY := cx, cy

	// ANSI Color codes
	reset := "\033[0m"
	glowGreen := "\033[32m\033[1m"
	bioCyan := "\033[36m\033[1m"
	fossilGold := "\033[33m"

	for i, c := range commits {
		// Random walk influenced by commit attributes
		angle := rand.Float64() * 2 * 3.14159
		step := 1 + (i % 3)
		currentX += int(float64(step) * cosApprox(angle))
		currentY += int(float64(step) * sinApprox(angle))

		// Wrap around canvas bounds
		if currentX < 1 {
			currentX = 1
		}
		if currentX >= width-1 {
			currentX = width - 2
		}
		if currentY < 1 {
			currentY = 1
		}
		if currentY >= height-1 {
			currentY = height - 2
		}

		if c.IsMerge {
			// Merge conflicts bloom as bioluminescent mushrooms
			canvas[currentY][currentX] = 'Y'
			colors[currentY][currentX] = bioCyan
		} else if c.IsDelete {
			// Deleted branches leave fossilized spores
			canvas[currentY][currentX] = 'ø'
			colors[currentY][currentX] = fossilGold
		} else {
			// Standard fungal hyphae growth
			canvas[currentY][currentX] = '•'
			colors[currentY][currentX] = glowGreen
		}
	}

	// Render the generative art frame to stdout
	fmt.Println("\033[2J\033[H") // Clear screen
	fmt.Println("=== GIT MYCELIUM NETWORK GENERATOR ===")
	fmt.Println("Legend: [•] Hyphae Growth  [Y] Bioluminescent Merge Mushroom  [ø] Fossilized Spore")
	fmt.Println(strings.Repeat("-", width))

	for y := 0; y < height; y++ {
		var sb strings.Builder
		for x := 0; x < width; x++ {
			sb.WriteString(colors[y][x])
			sb.WriteRune(canvas[y][x])
			sb.WriteString(reset)
		}
		fmt.Println(sb.String())
	}
	fmt.Println(strings.Repeat("-", width))
	fmt.Printf("Network sprouted from %d git artifacts.\n", len(commits))
}

// fetchGitHistory attempts to read recent git log entries.
func fetchGitHistory() []Commit {
	cmd := exec.Command("git", "log", "--oneline", "-n", "100", "--parents")
	var out bytes.Buffer
	cmd.Stdout = &out
	if err := cmd.Run(); err != nil {
		return nil
	}

	var commits []Commit
	lines := strings.Split(out.String(), "\n")
	for _, line := range lines {
		if strings.TrimSpace(line) == "" {
			continue
		}
		parts := strings.Fields(line)
		isMerge := len(parts) > 2 // Has multiple parent hashes
		isDelete := strings.Contains(strings.ToLower(line), "delete") || strings.Contains(strings.ToLower(line), "remove")

		commits = append(commits, Commit{
			Hash:     parts[0],
			IsMerge:  isMerge,
			IsDelete: isDelete,
		})
	}
	return commits
}

// generateMockHistory creates synthetic git history if no repo is present.
evalMockHistory := func(count int) []Commit { return nil } // placeholder helper structure
func generateMockHistory(count int) []Commit {
	var mock []Commit
	for i := 0; i < count; i++ {
		isMerge := i%7 == 0
		isDelete := i%11 == 0
		mock = append(mock, Commit{
			Hash:     fmt.Sprintf("mock%d", i),
			IsMerge:  isMerge,
			IsDelete: isDelete,
		})
	}
	return mock
}

// Lightweight approximations for trigonometric offsets without heavy math imports
func cosApprox(a float64) float64 {
	return 1.0 - (a*a)/2.0 + (a*a*a*a)/24.0
}
func sinApprox(a float64) float64 {
	return a - (a*a*a)/6.0 + (a*a*a*a*a)/120.0
}