package main

import (
	"bufio"
	"fmt"
	"math/rand"
	"os"
	"strings"
	"time"
)

// A poetic and procedural log visualizer transforming terminal errors 
// into a tranquil, typographic digital forest.
func main() {
	// Seed randomness for organic generation
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))

	// Sample mock system logs if none are piped in
	var lines []string
	stat, _ := os.Stdin.Stat()
	if (stat.Mode() & os.ModeCharDevice) == 0 {
		scanner := bufio.NewScanner(os.Stdin)
		for scanner.Scan() {
			lines = append(lines, scanner.Text())
		}
	} else {
		lines = []string{
			"INFO: System boot sequence initiated successfully.",
			"WARN: Memory usage threshold exceeded 85%.",
			"ERROR: syntax error: unexpected token '}', expecting ';'",
			"DEBUG: Garbage collection cycle completed in 12ms.",
			"CRITICAL: segmentation fault at address 0x7fff5fbff800 (core dumped)",
			"WARN: Network latency spike detected on interface eth0.",
			"ERROR: syntax error: undefined variable 'stream_ref'",
			"CRITICAL: segmentation fault at null pointer dereference",
		}
	}

	fmt.Println("\033[H\033[2J") // Clear terminal screen
	fmt.Println(" 🌱 Initializing Digital Arboreal Environment...\n")
	time.Sleep(500 * time.Millisecond)

	for _, line := range lines {
		lower := strings.ToLower(line)
		
		switch {
		// Syntax errors bloom into weeping digital willows
		case strings.Contains(lower, "syntax error"):
			renderWillow(line, rng)

		// Segmentation faults trigger falling leaves of red hexadecimal dust
		case strings.Contains(lower, "segmentation fault"):
			renderHexDust(line, rng)

		// Generic errors or warnings grow sturdy oak branches
		case strings.Contains(lower, "error") || strings.Contains(lower, "warn"):
			renderTrunk(line)

		// Normal logs gently sprout soft grass
		default:
			renderGrass(line)
		}

		time.Sleep(300 * time.Millisecond)
	}

	fmt.Println("\n 🌲 Ecosystem simulation complete. The forest sleeps. 🌲")
}

// Renders a weeping willow cascading from a syntax error log
func renderWillow(log string, rng *rand.Rand) {
	fmt.Printf("\033[32m[Willow Bloom] %s\033[0m\n", log)
	willowBranches := []string{
		"       ~.~.~.~.~",
		"     /           \\",
		"    |   (syntax)  |",
		"    |||  |||  |||",
		"    \\\\|  |||  |//",
		"     \\\\\\ ||| ///",
		"      \\\\\\|///",
		"        \\|/",
		"         |  (drooping gracefully)",
		"         |",
	}
	for _, branch := range willowBranches {
		fmt.Printf("  \033[36m%s\033[0m\n", branch)
		time.Sleep(40 * time.Millisecond)
	}
	fmt.Println()
}

// Renders falling red hexadecimal dust from a segmentation fault
func renderHexDust(log string, rng *rand.Rand) {
	fmt.Printf("\033[31m[Segfault Dust] %s\033[0m\n", log)
	hexChars := []string{"0", "1", "A", "F", "C", "E", "8"}
	
	for i := 0.0; i < 5; i++ {
		indent := strings.Repeat(" ", int(i)*2)
		var sb strings.Builder
		sb.WriteString(indent)
		for j := 0; j < 12; j++ {
			sb.WriteString(hexChars[rng.Intn(len(hexChars))] + " ")
		}
		fmt.Printf("  \033[31m%s\033[0m\n", sb.String())
		time.Sleep(50 * time.Millisecond)
	}
	fmt.Println("  \033[31m     * * * (dust settles on the forest floor) * * *\033[0m\n")
}

// Renders a sturdy trunk for standard warnings and minor errors
func renderTrunk(log string) {
	fmt.Printf("\033[33m[Arbor Growth] %s\033[0m\n", log)
	fmt.Println("         ###")
	fmt.Println("        #_#_#")
	fmt.Println("         |||")
	fmt.Println("         ||| \n")
}

// Renders quiet meadow grass for informational logs
func renderGrass(log string) {
	fmt.Printf("\033[32m[Sprout] %s\033[0m\n", log)
	fmt.Println("     ,v, ,v, ,v,\n")
}