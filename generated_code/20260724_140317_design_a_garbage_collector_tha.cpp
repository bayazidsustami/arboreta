#include <iostream>
#include <vector>
#include <memory>
#include <unordered_map>
#include <random>
#include <chrono>
#include <thread>
#include <string>
#include <algorithm>

// Terminal dimensions
constexpr int WIDTH = 60;
constexpr int HEIGHT = 20;

// Colors (ANSI Escape Sequences)
const std::string RESET   = "\033[0m";
const std::string CLEAR   = "\033[2J\033[1;1H";
const std::string HIDE_CUR = "\033[?25l";
const std::string SHOW_CUR = "\033[?25h";

// Visual States
const std::string SUNLIGHT = "\033[1;33m*\033[0m"; // Active Memory Pointer
const std::string BLOOM    = "\033[1;35m@\033[0m"; // Deallocating / Blooming Memory
const std::string MOSS_1   = "\033[0;32m~\033[0m"; // Leaked Memory (Young Moss)
const std::string MOSS_2   = "\033[1;32m#\033[0m"; // Leaked Memory (Dense Moss)
const std::string EMPTY    = " ";

struct Cell {
    std::string symbol = EMPTY;
    bool is_active = false;
    bool is_leaked = false;
    bool is_blooming = false;
    int age = 0;
};

class TerminalEcosystemGC {
private:
    Cell grid[HEIGHT][WIDTH];
    std::unordered_map<void*, std::pair<int, int>> memory_map;
    std::mt19937 rng{std::random_device{}()};

    void render() {
        std::string buffer = CLEAR;
        buffer += "=== TERMINAL ECOSYSTEM GARBAGE COLLECTOR ===\n";
        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                buffer += grid[y][x].symbol;
            }
            buffer += "\n";
        }
        buffer += "Sunlight (*): Active | Bloom (@): Freed | Moss (~/#): Leaked\n";
        std::cout << buffer << std::flush;
    }

public:
    TerminalEcosystemGC() {
        std::cout << HIDE_CUR;
    }

    ~TerminalEcosystemGC() {
        std::cout << SHOW_CUR << RESET;
    }

    // Allocate memory and place standard "Sunlight" in the terminal ecosystem
    void* allocate(size_t size) {
        void* ptr = ::operator new(size);
        std::uniform_int_distribution<int> distX(0, WIDTH - 1);
        std::uniform_int_distribution<int> distY(0, HEIGHT - 1);

        int x = distX(rng);
        int y = distY(rng);

        memory_map[ptr] = {x, y};
        grid[y][x] = {SUNLIGHT, true, false, false, 0};
        
        step_ecosystem();
        return ptr;
    }

    // Deallocate memory with an organic "Blooming" visual transition
    void deallocate(void* ptr) {
        if (memory_map.find(ptr) == memory_map.end()) return;

        auto [x, y] = memory_map[ptr];
        memory_map.erase(ptr);
        ::operator delete(ptr);

        // Visual Deallocation: Bloom and vanish organically
        grid[y][x] = {BLOOM, false, false, true, 0};
        render();
        std::this_thread::sleep_for(std::chrono::milliseconds(150));

        grid[y][x] = {EMPTY, false, false, false, 0};
        step_ecosystem();
    }

    // Simulate unreferenced leaks sprouting into chaotic visual moss
    void simulate_leak() {
        std::uniform_int_distribution<int> distX(0, WIDTH - 1);
        std::uniform_int_distribution<int> distY(0, HEIGHT - 1);

        int x = distX(rng);
        int y = distY(rng);

        if (!grid[y][x].is_active && !grid[y][x].is_blooming) {
            grid[y][x] = {MOSS_1, false, true, false, 1};
        }
        step_ecosystem();
    }

    // Spread chaotic moss across adjacent cells
    void step_ecosystem() {
        std::vector<std::pair<int, int>> moss_growth;

        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                if (grid[y][x].is_leaked) {
                    grid[y][x].age++;
                    if (grid[y][x].age > 3) {
                        grid[y][x].symbol = MOSS_2;
                    }

                    // Spread moss to neighbors
                    int dx[] = {-1, 1, 0, 0};
                    int dy[] = {0, 0, -1, 1};
                    for (int i = 0; i < 4; ++i) {
                        int nx = x + dx[i];
                        int ny = y + dy[i];
                        if (nx >= 0 && nx < WIDTH && ny >= 0 && ny < HEIGHT) {
                            if (!grid[ny][nx].is_active && !grid[ny][nx].is_leaked && !grid[ny][nx].is_blooming) {
                                std::uniform_int_distribution<int> chance(0, 10);
                                if (chance(rng) > 7) {
                                    moss_growth.push_back({nx, ny});
                                }
                            }
                        }
                    }
                }
            }
        }

        for (auto [gx, gy] : moss_growth) {
            grid[gy][gx] = {MOSS_1, false, true, false, 1};
        }

        render();
    }

    // Sweep: Clean up the chaotic moss consuming the console
    void collect_garbage() {
        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                if (grid[y][x].is_leaked) {
                    grid[y][x] = {BLOOM, false, false, true, 0};
                }
            }
        }
        render();
        std::this_thread::sleep_for(std::chrono::milliseconds(300));

        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                if (grid[y][x].is_blooming) {
                    grid[y][x] = {EMPTY, false, false, false, 0};
                }
            }
        }
        render();
    }
};

int main() {
    TerminalEcosystemGC gc;

    // Simulate dynamic allocations (Sunlight)
    std::vector<void*> active_pointers;
    for (int i = 0; i < 15; ++i) {
        active_pointers.push_back(gc.allocate(128));
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }

    // Simulate memory leaks (Chaotic Moss Sprouting)
    for (int i = 0; i < 10; ++i) {
        gc.simulate_leak();
        std::this_thread::sleep_for(std::chrono::milliseconds(150));
    }

    // Deallocate active pointers with Blooming effect
    for (void* ptr : active_pointers) {
        gc.deallocate(ptr);
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }

    // Let moss spread further
    for (int i = 0; i < 5; ++i) {
        gc.simulate_leak();
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
    }

    // Trigger Garbage Collection to purge moss and restore console
    std::this_thread::sleep_for(std::chrono::milliseconds(500));
    gc.collect_garbage();

    std::cout << "\nEcosystem successfully balanced and garbage collected!\n";
    return 0;
}