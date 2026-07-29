/*
 * Celestial Git: Interactive Gravitational N-Body Git Commit Map
 * 
 * Synthesizes Git commit histories as celestial N-body systems:
 * - Commits act as gravitational bodies attracting linked commits.
 * - Merge conflicts trigger cosmic collisions generating bright spark debris.
 * - Abandoned branches decay over time into drifting interstellar dust.
 * 
 * Compiled with: g++ -std=c++20 -O3 main.cpp -o celestial_git
 */

#include <iostream>
#include <vector>
#include <cmath>
#include <random>
#include <thread>
#include <chrono>
#include <string>
#include <algorithm>
#include <tuple>

// Terminal canvas configuration
constexpr int WIDTH = 100;
constexpr int HEIGHT = 40;
constexpr double G = 0.8;          // Gravitational constant
constexpr double SOFTENING = 2.0;  // Softening factor to prevent force singularities

enum class EntityType { Commit, Spark, Dust };

struct Entity {
    double x, y;
    double vx, vy;
    double mass;
    EntityType type;
    int life;          // Lifespan for particles (sparks & dust)
    int max_life;
    std::string branch;
    char glyph;
    int r, g, b;
};

class CelestialGitSimulation {
private:
    std::vector<Entity> entities;
    std::mt19937 rng{std::random_device{}()};
    int tick_count = 0;

    void spawn_commit(const std::string& branch, double x, double y, double vx, double vy, int r, int g, int b) {
        entities.push_back({
            x, y, vx, vy,
            15.0, // Commit mass
            EntityType::Commit,
            1000, 1000,
            branch,
            '*',
            r, g, b
        });
    }

    void spawn_sparks(double x, double y, int count) {
        std::uniform_real_distribution<double> vel_dist(-1.5, 1.5);
        std::uniform_int_distribution<int> color_dist(180, 255);
        for (int i = 0; i < count; ++i) {
            entities.push_back({
                x, y,
                vel_dist(rng), vel_dist(rng),
                0.1,
                EntityType::Spark,
                20 + static_cast<int>(rng() % 15), 35,
                "conflict",
                '#',
                255, color_dist(rng), 50
            });
        }
    }

    void spawn_dust(double x, double y, double vx, double vy) {
        std::uniform_real_distribution<double> offset(-0.5, 0.5);
        entities.push_back({
            x + offset(rng), y + offset(rng),
            vx * 0.3 + offset(rng) * 0.1, vy * 0.3 + offset(rng) * 0.1,
            0.01,
            EntityType::Dust,
            80 + static_cast<int>(rng() % 40), 120,
            "decayed",
            '.',
            100, 100, 150
        });
    }

public:
    CelestialGitSimulation() {
        // Root initial commit at center of constellation
        spawn_commit("main", WIDTH / 2.0, HEIGHT / 2.0, 0.0, 0.0, 255, 215, 0);
    }

    void step() {
        tick_count++;

        // Inject new Git branch commits periodically
        if (tick_count % 15 == 0 && entities.size() < 120) {
            std::uniform_real_distribution<double> pos_x(10.0, WIDTH - 10.0);
            std::uniform_real_distribution<double> pos_y(5.0, HEIGHT - 5.0);
            std::uniform_real_distribution<double> vel(-0.4, 0.4);

            static const std::vector<std::tuple<std::string, int, int, int>> branches = {
                {"feature/quantum", 0, 225, 255},
                {"fix/null-pointer", 255, 100, 100},
                {"dev/nebula", 180, 100, 255},
                {"release/v2.0", 100, 255, 100}
            };

            auto& [b_name, r, g, b] = branches[rng() % branches.size()];
            spawn_commit(b_name, pos_x(rng), pos_y(rng), vel(rng), vel(rng), r, g, b);
        }

        // Gravitational N-body force matrix update
        size_t n = entities.size();
        for (size_t i = 0; i < n; ++i) {
            for (size_t j = i + 1; j < n; ++j) {
                double dx = entities[j].x - entities[i].x;
                double dy = entities[j].y - entities[i].y;
                double dist_sq = dx * dx + dy * dy + SOFTENING;
                double dist = std::sqrt(dist_sq);
                
                // Merge conflicts: nearby distinct branch commits trigger cosmic collisions
                if (dist < 2.5 && entities[i].type == EntityType::Commit && entities[j].type == EntityType::Commit && entities[i].branch != entities[j].branch) {
                    spawn_sparks((entities[i].x + entities[j].x) / 2.0, (entities[i].y + entities[j].y) / 2.0, 8);
                }

                double force = (G * entities[i].mass * entities[j].mass) / dist_sq;
                double fx = force * (dx / dist);
                double fy = force * (dy / dist);

                entities[i].vx += fx / entities[i].mass;
                entities[i].vy += fy / entities[i].mass;
                entities[j].vx -= fx / entities[j].mass;
                entities[j].vy -= fy / entities[j].mass;
            }
        }

        // Kinematics and life-cycle logic
        for (auto it = entities.begin(); it != entities.end();) {
            it->x += it->vx;
            it->y += it->vy;

            // Elastic boundary collisions
            if (it->x <= 1 || it->x >= WIDTH - 2) it->vx *= -0.8;
            if (it->y <= 1 || it->y >= HEIGHT - 2) it->vy *= -0.8;

            it->x = std::clamp(it->x, 1.0, static_cast<double>(WIDTH - 2));
            it->y = std::clamp(it->y, 1.0, static_cast<double>(HEIGHT - 2));

            // Abandoned branch decay into drifting interstellar dust
            if (it->type == EntityType::Commit && tick_count > 100 && (rng() % 300 == 0)) {
                spawn_dust(it->x, it->y, it->vx, it->vy);
                it->mass *= 0.85;
                if (it->mass < 2.0) {
                    it = entities.erase(it);
                    continue;
                }
            }

            // Life cycle management for particle debris
            if (it->type != EntityType::Commit) {
                it->life--;
                if (it->life <= 0) {
                    it = entities.erase(it);
                    continue;
                }
            }
            ++it;
        }
    }

    void render() const {
        // Move cursor top-left & hide terminal cursor
        std::cout << "\x1b[H\x1b[?25l";

        // Double buffer allocation
        std::vector<std::string> grid(HEIGHT, std::string(WIDTH, ' '));
        std::vector<std::vector<std::string>> color_grid(HEIGHT, std::vector<std::string>(WIDTH, ""));

        // Render frame boundaries
        for (int x = 0; x < WIDTH; ++x) {
            grid[0][x] = grid[HEIGHT - 1][x] = '-';
        }
        for (int y = 0; y < HEIGHT; ++y) {
            grid[y][0] = grid[y][WIDTH - 1] = '|';
        }

        // Draw entities onto grid
        for (const auto& e : entities) {
            int cx = static_cast<int>(std::round(e.x));
            int cy = static_cast<int>(std::round(e.y));

            if (cx > 0 && cx < WIDTH - 1 && cy > 0 && cy < HEIGHT - 1) {
                grid[cy][cx] = e.glyph;
                
                int r = e.r, g = e.g, b = e.b;
                if (e.type != EntityType::Commit) {
                    double fade = static_cast<double>(e.life) / e.max_life;
                    r = static_cast<int>(r * fade);
                    g = static_cast<int>(g * fade);
                    b = static_cast<int>(b * fade);
                }
                color_grid[cy][cx] = "\x1b[38;2;" + std::to_string(r) + ";" + std::to_string(g) + ";" + std::to_string(b) + "m";
            }
        }

        // Flush frame buffer to terminal
        std::string buffer;
        buffer.reserve(WIDTH * HEIGHT * 20);

        buffer += "\x1b[1;36m=== CELESTIAL GIT: Real-Time N-Body Commit Constellation ===\x1b[0m\n";

        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                if (!color_grid[y][x].empty()) {
                    buffer += color_grid[y][x] + grid[y][x] + "\x1b[0m";
                } else {
                    buffer += grid[y][x];
                }
            }
            buffer += "\n";
        }

        buffer += "\x1b[33mActive Bodies: " + std::to_string(entities.size()) +
                  " | Collisions: Sparks (#) | Decayed Branches: Dust (.)\x1b[0m\n";

        std::cout << buffer << std::flush;
    }
};

int main() {
    // Clear screen
    std::cout << "\x1b[2J";
    
    CelestialGitSimulation sim;

    // Animation loop running at ~30 FPS
    for (int frame = 0; frame < 500; ++frame) {
        sim.step();
        sim.render();
        std::this_thread::sleep_for(std::chrono::milliseconds(33));
    }

    // Restore terminal cursor on exit
    std::cout << "\x1b[?25h\n";
    return 0;
}