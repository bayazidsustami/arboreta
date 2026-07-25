#include <iostream>
#include <vector>
#include <string>
#include <chrono>
#include <thread>
#include <cmath>
#include <random>
#include <fstream>
#include <sstream>
#include <algorithm>
#include <cstdint>
#include <iomanip>

// Terminal Digital Bonsai System Telemetry Monitor
// - Reads system CPU usage in real-time (/proc/stat with automatic fallback).
// - Generates a procedural recursive bonsai branch structure.
// - IDLE (<25% CPU): Flowers blossom (pink/magenta petals) across the canopy.
// - HIGH CPU (>50% CPU): Branches shed leaves (orange/red drifting particles).

struct Pixel {
    char ch = ' ';
    std::string color = "\033[0m";
};

struct LeafParticle {
    float x, y;
    float vx, vy;
    char symbol;
    std::string color;
};

// Reads CPU load percentage on Linux systems, with procedural simulation fallback
double get_cpu_load() {
    static uint64_t prev_idle = 0, prev_total = 0;
    std::ifstream file("/proc/stat");
    if (!file.is_open()) {
        // Fallback simulation for non-Linux platforms
        static double simulated = 15.0;
        static std::mt19937 rng(1337);
        std::uniform_real_distribution<double> dist(-8.0, 8.0);
        simulated = std::clamp(simulated + dist(rng), 2.0, 98.0);
        return simulated;
    }

    std::string line;
    std::getline(file, line);
    std::istringstream ss(line);
    std::string cpu;
    uint64_t user, nice, system, idle, iowait, irq, softirq, steal;
    ss >> cpu >> user >> nice >> system >> idle >> iowait >> irq >> softirq >> steal;

    uint64_t idle_time = idle + iowait;
    uint64_t total_time = user + nice + system + idle + iowait + irq + softirq + steal;

    uint64_t total_diff = total_time - prev_total;
    uint64_t idle_diff = idle_time - prev_idle;

    prev_total = total_time;
    prev_idle = idle_time;

    if (total_diff == 0) return 0.0;
    return 100.0 * (1.0 - static_cast<double>(idle_diff) / total_diff);
}

const int WIDTH = 64;
const int HEIGHT = 22;
const double PI = 3.14159265358979323846;

// Procedural recursive branch generator for the bonsai structure
void grow_branch(std::vector<std::vector<Pixel>>& canvas, double x, double y, double angle, 
                 int length, int thickness, std::mt19937& rng, std::vector<std::pair<int, int>>& endpoints) {
    if (length <= 0) {
        endpoints.push_back({static_cast<int>(x), static_cast<int>(y)});
        return;
    }

    double dx = std::cos(angle);
    double dy = -std::sin(angle); // Terminal coordinates invert Y axis

    for (int i = 0; i < length; ++i) {
        int ix = std::round(x);
        int iy = std::round(y);

        if (ix >= 0 && ix < WIDTH && iy >= 0 && iy < HEIGHT) {
            if (thickness > 1) {
                canvas[iy][ix].ch = '#';
            } else if (std::abs(dx) > std::abs(dy)) {
                canvas[iy][ix].ch = '~';
            } else {
                canvas[iy][ix].ch = '/';
            }
            canvas[iy][ix].color = "\033[38;5;130m"; // Bonsai Wood Brown
        }

        x += dx;
        y += dy;
    }

    endpoints.push_back({static_cast<int>(std::round(x)), static_cast<int>(std::round(y))});

    std::uniform_real_distribution<double> angle_var(-0.35, 0.35);
    if (length > 2) {
        grow_branch(canvas, x, y, angle + 0.45 + angle_var(rng), length - 2, std::max(1, thickness - 1), rng, endpoints);
        grow_branch(canvas, x, y, angle - 0.45 + angle_var(rng), length - 2, std::max(1, thickness - 1), rng, endpoints);
    }
}

int main() {
    std::mt19937 particle_rng(42);
    std::vector<LeafParticle> falling_leaves;

    // Clear screen and hide terminal cursor
    std::cout << "\033[2J\033[?25l";

    while (true) {
        double cpu_load = get_cpu_load();

        std::vector<std::vector<Pixel>> canvas(HEIGHT, std::vector<Pixel>(WIDTH));
        std::vector<std::pair<int, int>> endpoints;

        // Render Pot & Soil Base
        int base_x = WIDTH / 2;
        int base_y = HEIGHT - 4;

        for (int x = base_x - 12; x <= base_x + 12; ++x) {
            canvas[HEIGHT - 3][x].ch = '=';
            canvas[HEIGHT - 3][x].color = "\033[38;5;240m";
            canvas[HEIGHT - 2][x].ch = '\\';
            canvas[HEIGHT - 2][x].color = "\033[38;5;238m";
        }

        // Generate static deterministic branch skeleton
        std::mt19937 tree_rng(999);
        grow_branch(canvas, base_x, base_y, PI / 2.0, 6, 3, tree_rng, endpoints);

        // Render Foliage & Blossoms based on system telemetry
        std::uniform_real_distribution<double> prob(0.0, 1.0);
        for (const auto& pt : endpoints) {
            for (int dy = -1; dy <= 1; ++dy) {
                for (int dx = -2; dx <= 2; ++dx) {
                    int lx = pt.first + dx;
                    int ly = pt.second + dy;

                    if (lx >= 0 && lx < WIDTH && ly >= 0 && ly < HEIGHT && canvas[ly][lx].ch == ' ') {
                        if (cpu_load < 25.0 && prob(tree_rng) < 0.45) {
                            // Blossoming Cherry Petals during low CPU utilization
                            canvas[ly][lx].ch = (prob(tree_rng) < 0.5) ? '*' : '@';
                            canvas[ly][lx].color = "\033[38;5;205m"; // Pink Blossom
                        } else if (prob(tree_rng) < 0.70) {
                            // Standard Evergreen Canopy
                            canvas[ly][lx].ch = '&';
                            canvas[ly][lx].color = "\033[38;5;34m"; // Vibrant Green
                        }
                    }
                }
            }
        }

        // CPU Spikes trigger leaf shedding physics
        if (cpu_load > 45.0 && !endpoints.empty()) {
            std::uniform_int_distribution<size_t> ep_dist(0, endpoints.size() - 1);
            auto src = endpoints[ep_dist(particle_rng)];
            std::uniform_real_distribution<float> vx_dist(-0.4f, 0.4f);
            falling_leaves.push_back({
                static_cast<float>(src.first), static_cast<float>(src.second),
                vx_dist(particle_rng), 0.6f, 'x', "\033[38;5;208m" // Shedding Orange Leaf
            });
        }

        // Physics step for falling leaf particles
        for (auto it = falling_leaves.begin(); it != falling_leaves.end();) {
            it->x += it->vx;
            it->y += it->vy;

            int ix = std::round(it->x);
            int iy = std::round(it->y);

            if (iy >= HEIGHT - 3 || ix < 0 || ix >= WIDTH) {
                it = falling_leaves.erase(it);
            } else {
                if (canvas[iy][ix].ch == ' ') {
                    canvas[iy][ix].ch = it->symbol;
                    canvas[iy][ix].color = it->color;
                }
                ++it;
            }
        }

        // Move cursor top-left to avoid flicker
        std::cout << "\033[H";

        // Draw Canvas to stdout
        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                std::cout << canvas[y][x].color << canvas[y][x].ch;
            }
            std::cout << "\033[0m\n";
        }

        // Output Status Bar
        std::cout << "\033[38;5;248m CPU Load: [" << std::fixed << std::setprecision(1) << std::setw(5) << cpu_load << "%] ";
        if (cpu_load < 25.0) {
            std::cout << "\033[38;5;205m[Status: IDLE - Sakura Blooming]\033[0m         \n";
        } else if (cpu_load > 45.0) {
            std::cout << "\033[38;5;196m[Status: LOAD SPIKE - Leaves Shedding]\033[0m   \n";
        } else {
            std::cout << "\033[38;5;34m[Status: BALANCED]\033[0m                      \n";
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(120));
    }

    return 0;
}