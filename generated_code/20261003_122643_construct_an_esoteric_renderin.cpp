#include <iostream>
#include <vector>
#include <cmath>
#include <thread>
#include <chrono>
#include <random>

// Terminal dimensions for the terrarium viewport
const int WIDTH = 80;
const int HEIGHT = 40;

// Structure representing the state of the digital terrarium
struct TerrariumState {
    double health = 1.0;          // Overall vitality (0.0 to 1.0)
    double latency_ms = 50.0;     // Current simulated network latency
    int dropped_packets = 0;      // Accumulated packet drops
    std::vector<std::string> grid;
    
    TerrariumState() : grid(HEIGHT, std::string(WIDTH, ' ')) {}
};

// Generates a Barnsley fern fractal mapped onto the terminal grid, modulated by latency and health
void render_fern(TerrariumState& state) {
    // Clear grid
    for (int y = 0; y < HEIGHT; ++y) {
        std::fill(state.grid[y].begin(), state.grid[y].end(), ' ');
    }

    // Barnsley fern parameters influenced by network latency
    // Higher latency compresses the growth factor; health determines withering
    int iterations = static_cast<int>(3000 * state.health);
    double x = 0.0, y = 0.0;
    
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<> dis(0.0, 1.0);

    for (int i = 0; i < iterations; ++i) {
        double next_x, next_y;
        double r = dis(gen);

        if (r < 0.01) {
            next_x = 0.0;
            next_y = 0.16 * y;
        } else if (r < 0.86) {
            next_x = 0.85 * x + 0.04 * y;
            next_y = -0.04 * x + 0.85 * y + 1.6;
        } else if (r < 0.93) {
            next_x = 0.2 * x - 0.26 * y;
            next_y = 0.23 * x + 0.22 * y + 1.6;
        } else {
            next_x = -0.15 * x + 0.28 * y;
            next_y = 0.26 * x + 0.24 * y + 0.44;
        }

        x = next_x;
        y = next_y;

        // Map mathematical coordinates to terminal grid
        int screen_x = static_cast<int>(WIDTH / 2 + x * (WIDTH / 10.0));
        int screen_y = static_cast<int>(HEIGHT - 2 - y * (HEIGHT / 12.0));

        if (screen_x >= 0 && screen_x < WIDTH && screen_y >= 0 && screen_y < HEIGHT) {
            // Character density reflects "bloom" or "withering"
            char pixel = '*';
            if (state.health < 0.4) pixel = '.';
            else if (state.health < 0.7) pixel = '+';
            state.grid[screen_y][screen_x] = pixel;
        }
    }
}

// Simulates live network metrics fluctuating over time
void network_pulse_worker(TerrariumState& state, bool& running) {
    std::random_device rd;
    std::mt19937 gen(rd());
    std::normal_distribution<double> latency_dist(60.0, 20.0);
    std::uniform_real_distribution<> drop_dist(0.0, 1.0);

    while (running) {
        double current_latency = latency_dist(gen);
        if (current_latency < 5.0) current_latency = 5.0;
        
        state.latency_ms = current_latency;

        // Check for packet drop event (approx 10% chance per tick)
        if (drop_dist(gen) < 0.12) {
            state.dropped_packets++;
            state.health = std::max(0.1, state.health - 0.25); // Severe wither on drop
        } else {
            // Gradual recovery towards full bloom if latency remains stable
            double target_health = std::max(0.2, 1.0 - (state.latency_ms / 300.0));
            state.health = std::min(1.0, state.health + 0.05);
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(800));
    }
}

int main() {
    TerrariumState terrarium;
    bool running = true;

    // Launch background network telemetry simulation thread
    std::thread net_thread(network_pulse_worker, std::ref(terrarium), std::ref(running));

    // Clear screen initial escape sequence
    std::cout << "\033[2J";

    // Main rendering loop
    for (int frame = 0; frame < 50; ++frame) {
        render_fern(terrarium);

        // Move cursor to top-left for smooth redraw
        std::cout << "\033[H";
        std::cout << "=== ESOTERIC NETWORK TERRARIUM ENGINE ===\n";
        std::cout << "Latency: " << (int)terrarium.latency_ms << " ms | ";
        std::cout << "Health: " << (int)(terrarium.health * 100) << "% | ";
        std::cout << "Drops: " << terrarium.dropped_packets << "\n";
        std::cout << "--------------------------------------------------------------------------------\n";

        for (int y = 0; y < HEIGHT; ++y) {
            std::cout << terrarium.grid[y] << "\n";
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }

    running = false;
    if (net_thread.joinable()) {
        net_thread.join();
    }

    std::cout << "\nTerrarium session terminated.\n";
    return 0;
}