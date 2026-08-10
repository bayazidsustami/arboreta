#include <iostream>
#include <vector>
#include <thread>
#include <mutex>
#include <chrono>
#include <random>
#include <atomic>
#include <string>

// Digital Terrarium Dimensions
const int WIDTH = 60;
const int HEIGHT = 20;

// Ecosystem Cell States
enum CellType { EMPTY, PLANT, FIRE, ASH, BOT };

struct Cell {
    CellType type = EMPTY;
};

// Global Terrarium Shared State
std::vector<std::vector<Cell>> grid(HEIGHT, std::vector<Cell>(WIDTH));
std::mutex grid_mutex;
std::atomic<bool> running(true);

// Resource Mutexes to simulate Lock Contention / Deadlocks
std::mutex resource_alpha;
std::mutex resource_beta;

// ANSI Terminal Helper to clear display
void clear_screen() {
    std::cout << "\033[2J\033[H";
}

// Cell Render Mapping using Unicode & ANSI Colors
std::string render_cell(const Cell& cell) {
    switch (cell.type) {
        case PLANT: return "\033[32m☘\033[0m";  // Green Flora (Thread Activity)
        case FIRE:  return "\033[31m🔥\033[0m"; // Red Forest Fire (Deadlock Event)
        case ASH:   return "\033[90m░\033[0m";  // Gray Ash (Post-burn Waste)
        case BOT:   return "\033[36m🤖\033[0m"; // Cyan Robotic Organism (Garbage Collector)
        default:    return " ";
    }
}

// Worker Thread: Translates active CPU thread work into self-assembling flora
void cpu_worker_thread(int thread_id) {
    std::mt19937 rng(thread_id + std::chrono::steady_clock::now().time_since_epoch().count());
    std::uniform_int_distribution<int> dist_x(0, WIDTH - 1);
    std::uniform_int_distribution<int> dist_y(0, HEIGHT - 1);

    while (running) {
        std::this_thread::sleep_for(std::chrono::milliseconds(80 + (thread_id * 15)));
        int x = dist_x(rng);
        int y = dist_y(rng);

        std::lock_guard<std::mutex> lock(grid_mutex);
        if (grid[y][x].type == EMPTY) {
            grid[y][x].type = PLANT; // Spawns dynamic life on thread execution
        }
    }
}

// Deadlock Simulator Thread A: Tries to acquire Alpha then Beta
void deadlock_trigger_thread_A() {
    while (running) {
        std::this_thread::sleep_for(std::chrono::milliseconds(600));
        std::unique_lock<std::mutex> lock_a(resource_alpha, std::defer_lock);
        std::unique_lock<std::mutex> lock_b(resource_beta, std::defer_lock);

        if (lock_a.try_lock()) {
            std::this_thread::sleep_for(std::chrono::milliseconds(40));
            if (!lock_b.try_lock()) {
                // Deadlock contention detected! Triggers a forest fire cascade in terrarium
                std::lock_guard<std::mutex> lock(grid_mutex);
                for (int y = 0; y < HEIGHT; ++y) {
                    for (int x = 0; x < WIDTH; ++x) {
                        if (grid[y][x].type == PLANT && (rand() % 5 == 0)) {
                            grid[y][x].type = FIRE;
                        }
                    }
                }
            }
        }
    }
}

// Deadlock Simulator Thread B: Tries to acquire Beta then Alpha
void deadlock_trigger_thread_B() {
    while (running) {
        std::this_thread::sleep_for(std::chrono::milliseconds(700));
        std::unique_lock<std::mutex> lock_b(resource_beta, std::defer_lock);
        std::unique_lock<std::mutex> lock_a(resource_alpha, std::defer_lock);

        if (lock_b.try_lock()) {
            std::this_thread::sleep_for(std::chrono::milliseconds(40));
            lock_a.try_lock();
        }
    }
}

// Garbage Collector Thread: Cleans dead states & spawns corrective robotic organisms
void garbage_collector_thread() {
    while (running) {
        std::this_thread::sleep_for(std::chrono::milliseconds(1200));

        std::lock_guard<std::mutex> lock(grid_mutex);
        bool found_waste = false;

        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                if (grid[y][x].type == FIRE) {
                    grid[y][x].type = ASH; // Extinguishes fire into ash
                    found_waste = true;
                }
            }
        }

        // Garbage collection event spawns robotic organisms to re-cultivate land
        if (found_waste) {
            for (int k = 0; k < 4; ++k) {
                int rx = rand() % WIDTH;
                int ry = rand() % HEIGHT;
                grid[ry][rx].type = BOT;
            }
        }
    }
}

// Simulation Renderer & Terrarium Autonomous Physics Step
void render_and_simulate_step() {
    clear_screen();
    std::cout << "===================== DIGITAL TERRARIUM =====================\n";
    std::cout << " CPU Threads -> Flora (☘) | Deadlocks -> Forest Fire (🔥)\n";
    std::cout << " Garbage Collection -> Waste (░) & Robotic Organisms (🤖)\n";
    std::cout << "=============================================================\n";

    std::lock_guard<std::mutex> lock(grid_mutex);

    // Update ecosystem dynamics
    for (int y = 0; y < HEIGHT; ++y) {
        for (int x = 0; x < WIDTH; ++x) {
            if (grid[y][x].type == BOT) {
                // Bots clear ash and replant flora
                grid[y][x].type = (rand() % 2 == 0) ? PLANT : EMPTY;
            } else if (grid[y][x].type == FIRE) {
                // Propagation of fire to adjacent plants
                if (x + 1 < WIDTH && grid[y][x + 1].type == PLANT) grid[y][x + 1].type = FIRE;
                if (y + 1 < HEIGHT && grid[y + 1][x].type == PLANT) grid[y + 1][x].type = FIRE;
                grid[y][x].type = ASH;
            }
        }
    }

    // Output frame
    for (int y = 0; y < HEIGHT; ++y) {
        std::cout << "|";
        for (int x = 0; x < WIDTH; ++x) {
            std::cout << render_cell(grid[y][x]);
        }
        std::cout << "|\n";
    }
    std::cout << "=============================================================\n";
}

int main() {
    std::ios_base::sync_with_stdio(false);

    // Spawn CPU Active Threads
    std::vector<std::thread> threads;
    for (int i = 0; i < 4; ++i) {
        threads.emplace_back(cpu_worker_thread, i);
    }

    // Spawn System State Threads
    threads.emplace_back(deadlock_trigger_thread_A);
    threads.emplace_back(deadlock_trigger_thread_B);
    threads.emplace_back(garbage_collector_thread);

    // Run live simulation loop for 12 seconds
    auto start = std::chrono::steady_clock::now();
    while (std::chrono::steady_clock::now() - start < std::chrono::seconds(12)) {
        render_and_simulate_step();
        std::this_thread::sleep_for(std::chrono::milliseconds(180));
    }

    // Signal teardown and join threads cleanly
    running = false;
    for (auto& t : threads) {
        if (t.joinable()) t.join();
    }

    clear_screen();
    std::cout << "Digital Terrarium simulation halted successfully.\n";
    return 0;
}