#include <iostream>
#include <vector>
#include <cmath>
#include <thread>
#include <chrono>
#include <random>
#include <algorithm>

// Esoteric CPU-Driven Boid Migration Visualizer in C++
// Maps simulated server load to flock entropy, velocity, and ASCII glyph transformation.

const int WIDTH = 80;
const int HEIGHT = 24;

struct Boid {
    double x, y;
    double vx, vy;
};

// Generates a dynamic, fluctuating pseudo-CPU load profile (sine wave + stochastic noise)
double get_simulated_cpu_load(int frame) {
    double base = 0.5 + 0.4 * std::sin(frame * 0.04);
    double noise = (std::rand() % 20 - 10) * 0.015;
    return std::clamp(base + noise, 0.0, 1.0);
}

int main() {
    std::srand(1337);
    std::vector<Boid> flock(45);
    for (auto& b : flock) {
        b.x = std::rand() % WIDTH;
        b.y = std::rand() % HEIGHT;
        b.vx = (std::rand() % 10 - 5) * 0.1;
        b.vy = (std::rand() % 10 - 5) * 0.1;
    }

    // Initialize terminal display: clear screen and hide cursor via ANSI sequences
    std::cout << "\033[2J\033[?25l";

    for (int frame = 0; frame < 400; ++frame) {
        double cpu = get_simulated_cpu_load(frame);
        
        // High CPU introduces high turbulence and velocity; Low CPU maintains serene V-formation gliding
        double speed_mult = 0.4 + cpu * 2.6;
        double turbulence = cpu * 0.9;

        // Update flock dynamics
        for (auto& b : flock) {
            b.x += b.vx * speed_mult;
            b.y += b.vy * speed_mult;

            // Toroidal screen wrapping
            if (b.x < 0) b.x += WIDTH;
            if (b.x >= WIDTH) b.x -= WIDTH;
            if (b.y < 0) b.y += HEIGHT;
            if (b.y >= HEIGHT) b.y -= HEIGHT;

            // Apply load-dependent chaos factor
            b.vx += (static_cast<double>(std::rand()) / RAND_MAX - 0.5) * turbulence;
            b.vy += (static_cast<double>(std::rand()) / RAND_MAX - 0.5) * turbulence;

            // Velocity dampening
            b.vx *= 0.92;
            b.vy *= 0.92;
        }

        // Render frame buffer
        std::vector<std::string> screen(HEIGHT, std::string(WIDTH, ' '));
        for (const auto& b : flock) {
            int ix = static_cast<int>(b.x);
            int iy = static_cast<int>(b.y);
            if (ix >= 0 && ix < WIDTH && iy >= 0 && iy < HEIGHT) {
                char glyph = '.';
                if (cpu > 0.85) glyph = '#';
                else if (cpu > 0.65) glyph = 'x';
                else if (cpu > 0.45) glyph = '~';
                else if (cpu > 0.25) glyph = '>';
                else glyph = '-';
                screen[iy][ix] = glyph;
            }
        }

        // Flush buffer to terminal with cursor reset
        std::cout << "\033[H";
        std::cout << "================================================================================" << std::endl;
        std::cout << "         MIGRATORY FLOCK DATA VISUALIZER (SERVER CPU LOAD MAP)                  " << std::endl;
        std::cout << "================================================================================" << std::endl;
        std::cout << "Load State: [";
        int bars = static_cast<int>(cpu * 40);
        for (int i = 0; i < 40; ++i) {
            std::cout << (i < bars ? "|" : " ");
        }
        std::cout << "] " << static_cast<int>(cpu * 100) << "%" << std::endl;
        std::cout << "--------------------------------------------------------------------------------" << std::endl;

        for (int y = 0; y < HEIGHT; ++y) {
            std::cout << screen[y] << "\n";
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(60));
    }

    // Restore terminal cursor state
    std::cout << "\033[?25h";
    return 0;
}