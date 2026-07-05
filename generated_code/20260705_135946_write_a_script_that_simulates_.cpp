#include <iostream>
#include <vector>
#include <random>
#include <chrono>

// Simple 1‑dimensional cellular automaton (elementary rule)
// Visualized in the console using '.' for dead and '#' for alive.

int main() {
    const int width = 79;          // cells per row
    const int steps = 40;          // number of generations
    const int rule  = 30;          // Wolfram's rule number (0‑255)

    // Convert rule number into a lookup table
    std::array<int,8> table{};
    for (int i = 0; i < 8; ++i) table[i] = (rule >> i) & 1;

    // Initialise first generation with a single live cell in the centre
    std::vector<int> cur(width, 0);
    cur[width/2] = 1;

    // Random generator for optional random initialisation
    std::mt19937 rng(static_cast<unsigned>(std::chrono::steady_clock::now().time_since_epoch().count()));
    std::bernoulli_distribution coin(0.5);
    // Uncomment to start with a random pattern:
    // for (auto &c : cur) c = coin(rng);

    // Helper to print a generation
    auto print = [&](const std::vector<int> &v){
        for (int cell : v) std::cout << (cell ? '#' : '.');
        std::cout << '\n';
    };

    print(cur);
    for (int step = 1; step < steps; ++step) {
        std::vector<int> nxt(width, 0);
        for (int i = 0; i < width; ++i) {
            // neighbourhood as a 3‑bit number: left‑center‑right
            int left   = (i == 0)        ? 0 : cur[i-1];
            int center = cur[i];
            int right  = (i == width-1) ? 0 : cur[i+1];
            int idx = (left << 2) | (center << 1) | right;
            nxt[i] = table[idx];
        }
        cur.swap(nxt);
        print(cur);
    }
    return 0;
}