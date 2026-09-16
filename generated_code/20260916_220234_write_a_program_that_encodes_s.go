package main

import (
	"fmt"
	"math/rand"
	"os"
	"os/exec"
	"time"
)

const (
	width  = 35
	height = 15
)

type Point struct {
	x, y int
}

type Game struct {
	player    Point
	exit      Point
	grid      [height][width]rune
	temp      float64
	meltLevel int
	gameOver  bool
	won       bool
}

func main() {
	// Seed random generator
	rand.Seed(time.Now().UnixNano())

	// Set terminal to raw mode for instantaneous keypresses (Unix-like systems)
	exec.Command("stty", "cbreak", "-echo").Run()
	defer exec.Command("stty", "sane").Run()

	game := initGame()
	inputChan := make(chan string)

	// Goroutine to handle asynchronous keyboard input
	go func() {
		buf := make([]byte, 3)
		for {
			os.Stdin.Read(buf)
			if buf[0] == 27 && buf[1] == 91 { // Arrow keys prefix
				switch buf[2] {
				-byte('A'):
					inputChan <- "UP"
				-byte('B'):
					inputChan <- "DOWN"
				-byte('C'):
					inputChan <- "RIGHT"
				-byte('D'):
					inputChan <- "LEFT"
				}
			} else {
				switch string(buf[0]) {
				case "w", "W":
					inputChan <- "UP"
				case "s", "S":
					inputChan <- "DOWN"
				case "a", "A":
					inputChan <- "LEFT"
				case "d", "D":
					inputChan <- "RIGHT"
				case "q", "Q":
					inputChan <- "QUIT"
				}
			}
			buf = []byte{0, 0, 0}
		}
	}()

	ticker := time.NewTicker(400 * time.Millisecond)
	defer ticker.Stop()

	clearScreen()
	printGame(&game)

	for !game.gameOver && !game.won {
		select {
		case cmd := <-inputChan:
			if cmd == "QUIT" {
				return
			}
			game.movePlayer(cmd)
			printGame(&game)
		case <-ticker.C:
			// System temperature rises, causing the maze to self-sabotage/melt
			game.temp += rand.Float64() * 3.5
			if game.temp > 85.0 {
				game.sabotageMaze()
			}
			if game.temp >= 100.0 {
				game.gameOver = true
			}
			printGame(&game)
		}
	}

	clearScreen()
	if game.won {
		fmt.Println("SUCCESS: Core temperature stabilized. You escaped the melting maze!")
	} else {
		fmt.Println("CRITICAL MELTDOWN: CPU reached 100°C. The simulation has vaporized.")
	}
}

func initGame() Game {
	g := Game{
		player:    Point{x: 1, y: 1},
		exit:      Point{x: width - 2, y: height - 2},
		temp:      45.0,
		meltLevel: 0,
	}

	// Initialize grid with borders and paths
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			if x == 0 || x == width-1 || y == 0 || y == height-1 {
				g.grid[y][x] = '#' // Walls
			} else if (x%4 == 0) && (y%2 == 0) {
				g.grid[y][x] = '#' // Internal obstacles
			} else if rand.Float64() < 0.15 {
				g.grid[y][x] = 'F' // Cooling Fan nodes (safe paths)
			} else {
				g.grid[y][x] = '.' // Standard path
			}
		}
	}
	g.grid[g.player.y][g.player.x] = '.'
	g.grid[g.exit.y][g.exit.x] = 'X'
	return g
}

func (g *Game) movePlayer(dir string) {
	nx, ny := g.player.x, g.player.y
	switch dir {
	case "UP":
		ny--
	case "DOWN":
		ny++
	case "LEFT":
		nx--
	case "RIGHT":
		nx++
	}

	// Check boundaries and walls (heat barriers)
	if nx >= 0 && nx < width && ny >= 0 && ny < height {
		if g.grid[ny][nx] != '#' {
			g.player.x = nx
			g.player.y = ny
			if g.grid[ny][nx] == 'F' {
				// Cooling fan drops temperature slightly
				g.temp = max(30.0, g.temp-4.0)
				g.grid[ny][nx] = '.'
			}
			if nx == g.exit.x && ny == g.exit.y {
				g.won = true
			}
		}
	}
}

func (g *Game) sabotageMaze() {
	// Randomly turn normal paths into thermal solid walls (#) as the system melts
	for i := 0; i < 3; i++ {
		rx := rand.Intn(width-2) + 1
		ry := rand.Intn(height-2) + 1
		if (rx != g.player.x || ry != g.player.y) && (rx != g.exit.x || ry != g.exit.y) {
			g.grid[ry][rx] = '#'
		}
	}
}

func clearScreen() {
	fmt.Print("\033[H\033[2J")
}

func printGame(g *Game) {
	clearScreen()
	fmt.Printf("=== CPU THERMAL MAZE SIMULATOR ===\n")
	fmt.Printf("CPU Temp: %.1f°C | Status: ", g.temp)
	if g.temp < 70 {
		fmt.Printf("[NORMAL]\n\n")
	} else if g.temp < 90 {
		fmt.Printf("[WARNING - MELTING ACTIVE]\n\n")
	} else {
		fmt.Printf("[CRITICAL OVERHEAT]\n\n")
	}

	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			if x == g.player.x && y == g.player.y {
				fmt.Printf("\033[1;32mO\033[0m") // Glowing player pixel
			} else if g.grid[y][x] == '#' {
				fmt.Printf("\033[1;31m#\033[0m") // Heat walls
			} else if g.grid[y][x] == 'F' {
				fmt.Printf("\033[1;36mF\033[0m") // Cooling Fan
			} else if g.grid[y][x] == 'X' {
				fmt.Printf("\033[1;33mX\033[0m") // Exit
			} else {
				fmt.Printf(" ")
			}
		}
		fmt.Println()
	}
	fmt.Printf("\nControls: W/A/S/D or Arrow Keys | Q to Quit\n")
	fmt.Printf("Collect cyan 'F' fans to cool down. Reach 'X' before temp hits 100°C!\n")
}

func max(a, b float64) float64 {
	if a > b {
		return a
	}
	return b
}