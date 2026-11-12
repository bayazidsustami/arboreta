#include <iostream>
#include <vector>
#include <chrono>
#include <thread>
#include <random>
#include <cmath>

// Cellular Automata Tapestry simulating 24-hour emotional valence of arcade soundtracks
// Ruleset mutates based on a continuous time-wave representing arcade nostalgia, energy, and melancholy.

const int WIDTH = 60;
const int HEIGHT = 25;

struct CellState {
    int alive;
    double valence; // Emotional valence (-1.0 to 1.0)
};

class ArcadeTapestry {
    std::vector<std::vector<CellState>> grid;
    std::vector<std::vector<CellState>> next_grid;
    int day_tick;

public:
    ArcadeTapestry() : grid(HEIGHT, std::vector<CellState>(WIDTH)), 
                       next_grid(HEIGHT, std::vector<CellState>(WIDTH)), 
                       day_tick(0) {
        std::mt19937 rng(1982); // Vintage 1982 arcade seed
        std::uniform_real_distribution<double> dist(-1.0, 1.0);
        std::uniform_int_distribution<int> bit(0, 1);

        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                grid[y][x] = {bit(rng), dist(rng)};
            }
        }
    }

    // Calculate emotional valence modifier based on 24-hour cycle (e.g., Chiptune major/minor shifts)
    double getValenceModifier(int tick) const {
        double hours = (tick % 1440) / 60.0; // 1440 ticks = 24 hours simulation
        // Sine wave shifting between upbeat synth (positive valence) and ambient drone (negative valence)
        return std::sin(hours * M_PI / 12.0);
    }

    void update() {
        double current_valence = getValenceModifier(day_tick);

        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                int neighbors = 0;
                double neighbor_valence_sum = 0.0;

                // Count Moore neighborhood
                for (int dy = -1; dy <= 1; ++dy) {
                    for (int dx = -1; dx <= 1; ++dx) {
                        if (dx == 0 && dy == 0) continue;
                        int ny = (y + dy + HEIGHT) % HEIGHT;
                        int nx = (x + dx + WIDTH) % WIDTH;
                        if (grid[ny][nx].alive) {
                            neighbors++;
                            neighbor_valence_sum += grid[ny][nx].valence;
                        }
                    }
                }

                // Dynamic rule mutation based on valence soundtrack mapping
                bool is_alive = grid[y][x].alive;
                double cell_valence = grid[y][x].valence;

                // Mutate valence slightly over time
                cell_valence += (current_valence * 0.05) + ((std::rand() % 100 - 50) / 1000.0);
                if (cell_valence > 1.0) cell_valence = 1.0;
                if (cell_valence < -1.0) cell_valence = -1.0;

                // Automata rules shift depending on global valence state
                if (is_alive) {
                    if (neighbors < 2 || neighbors > 3) {
                        is_alive = 0; // Overcrowding or isolation
                    }
                } else {
                    int birth_threshold = 3;
                    if (neighbors == birth_threshold || (neighbors == 2 && current_valence > 0.5)) {
                        is_alive = 1;
                    }
                }

                next_grid[y][x] = {is_alive, cell_valence};
            }
        }

        grid = next_grid;
        day_tick++;
    }

    void render() const {
        // Clear screen ANSI escape
        std::cout << "\033[H\033[J";
        
        double valence = getValenceModifier(day_tick);
        std::cout << "=== ARCADE SOUNDTRACK VALENCE TAPESTRY (Hour: " 
                  << ((day_tick % 1440) / 60) << ":" << ((day_tick % 1440) % 60) 
                  << " | Valence: " << valence << ") ===\n";

        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                if (!grid[y][x].alive) {
                    std::cout << " ";
                } else {
                    // Character density based on emotional valence
                    double v = grid[y][x].valence;
                    if (v > 0.6) std::cout << "#";
                    else if (v > 0.2) std::cout << "*";
                    else if (v > -0.2) std::cout << "+";
                    else if (v > -0.6) std::cout << ".";
                    else std::cout << ":";
                }
            }
            std::cout << "\n";
        }
        std::cout << "============================================================\n";
    }
};

int main() {
    ArcadeTapestry tapestry;
    
    // Run simulation loop
    for (int i = 0; i < 500; ++i) {
        tapestry.render();
        tapestry.update();
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }

    return 0;
}