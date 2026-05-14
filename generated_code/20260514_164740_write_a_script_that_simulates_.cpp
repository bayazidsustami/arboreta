#include <iostream>
#include <vector>
#include <thread>
#include <chrono>

/**
 * This script implements Conway's Game of Life, a classic cellular automaton.
 * Rules:
 * 1. Any live cell with < 2 live neighbors dies (underpopulation).
 * 2. Any live cell with 2 or 3 live neighbors lives on.
 * 3. Any live cell with > 3 live neighbors dies (overpopulation).
 * 4. Any dead cell with exactly 3 live neighbors becomes a live cell (reproduction).
 */

class GameOfLife {
private:
    int rows;
    int cols;
    std::vector<std::vector<bool>> grid;

public:
    GameOfLife(int r, int c) : rows(r), cols(c), grid(r, std::vector<bool>(c, false)) {}

    // Set a cell to alive
    void setCell(int r, int c, bool alive) {
        if (r >= 0 && r < rows && c >= 0 && c < cols) {
            grid[r][c] = alive;
        }
    }

    // Count live neighbors for a specific cell (handling boundaries)
    int countNeighbors(int r, int c) {
        int count = 0;
        for (int i = -1; i <= 1; ++i) {
            for (int j = -1; j <= 1; ++j) {
                if (i == 0 && j == 0) continue; // Skip the cell itself
                int nr = r + i;
                int nc = c + j;
                if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
                    if (grid[nr][nc]) count++;
                }
            }
        }
        return count;
    }

    // Compute the next generation based on the rules
    void update() {
        std::vector<std::vector<bool>> nextGrid = grid;

        for (int r = 0; r < rows; ++r) {
            for (int c = 0; c < cols; ++c) {
                int neighbors = countNeighbors(r, c);
                if (grid[r][c]) {
                    // Rule 1 & 3: Death
                    if (neighbors < 2 || neighbors > 3) {
                        nextGrid[r][c] = false;
                    }
                    // Rule 2: Survival (stays true)
                } else {
                    // Rule 4: Reproduction
                    if (neighbors == 3) {
                        nextGrid[r][c] = true;
                    }
                }
            }
        }
        grid = nextGrid;
    }

    // Print the current state to the console
    void display() {
        // Clear console (works on most terminals)
        std::cout << "\033[2J\033[1;1H"; 
        
        for (int r = 0; r < rows; ++r) {
            for (int c = 0; c < cols; ++c) {
                std::cout << (grid[r][c] ? "█" : ".");
            }
            std::cout << "\n";
        }
    }
};

int main() {
    const int ROWS = 20;
    const int COLS = 40;
    GameOfLife game(ROWS, COLS);

    // Seed an initial pattern: A "Glider"
    game.setCell(1, 2, true);
    game.setCell(2, 3, true);
    game.setCell(3, 1, true);
    game.setCell(3, 2, true);
    game.setCell(3, 3, true);

    // Seed another pattern: A "Block" (Still Life)
    game.setCell(10, 10, true);
    game.setCell(10, 11, true);
    game.setCell(11, 10, true);
    game.setCell(11, 11, true);

    // Simulation loop
    for (int generation = 0; generation < 100; ++generation) {
        game.display();
        std::cout << "Generation: " << generation << std::endl;
        
        game.update();
        
        // Slow down the animation
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }

    return 0;
}