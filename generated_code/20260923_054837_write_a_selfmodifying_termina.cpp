#include <iostream>
#include <vector>
#include <cmath>
#include <chrono>
#include <thread>
#include <random>

// Terminal Weeping Willow Particle Fountain with Keyboard Clatter Reactivity
// Pure C++ ANSI Art Engine

struct Particle {
    double x, y;
    double vx, vy;
    double life;
    char glyph;
};

int main() {
    // Hide cursor and clear screen
    std::cout << "\033[?25l\033[2J";
    
    const int width = 80;
    const int height = 24;
    std::vector<Particle> particles;
    std::mt19937 rng(1337);
    std::uniform_real_distribution<double> dist_x(-2.0, 2.0);
    std::uniform_real_distribution<double> dist_v(-0.5, 0.5);

    auto start_time = std::chrono::steady_clock::now();
    int frame = 0;

    while (frame < 300) { // Run for 300 frames as a demo loop
        // Clear buffer
        std::vector<std::string> buffer(height, std::string(width, ' '));

        // Spawn fountain core & willow branches
        if (particles.size() < 150) {
            Particle p;
            p.x = width / 2.0 + dist_x(rng) * 2.0;
            p.y = 5.0;
            p.vx = dist_v(rng) * 0.8;
            p.vy = -1.5 - (rand() % 3) * 0.5;
            p.life = 1.0;
            p.glyph = (rand() % 2 == 0) ? '~' : '*';
            particles.push_back(p);
        }

        // Update particles (Weeping Willow physics: upward burst, arc, and drooping cascade)
        for (auto& p : particles) {
            p.x += p.vx;
            p.y += p.vy;
            // Gravity and weeping willow drooping pull outward/downward
            p.vy += 0.15; 
            if (p.y > 10.0) {
                p.vx += (p.x < width / 2.0) ? -0.05 : 0.05; // Drooping effect
            }
            p.life -= 0.03;

            int ix = static_cast<int>(p.x);
            int iy = static_cast<int>(p.y);
            if (ix >= 0 && ix < width && iy >= 0 && iy < height) {
                buffer[iy][ix] = p.glyph;
            }
        }

        // Remove dead particles
        particles.erase(
            std::remove_if(particles.begin(), particles.end(), [](const Particle& p) {
                return p.life <= 0.0 || p.y >= height;
            }),
            particles.end()
        );

        // Render buffer to terminal
        std::cout << "\033[H"; // Reset cursor
        std::string frame_output = "";
        for (int y = 0; y < height; ++y) {
            frame_output += buffer[y] + "\n";
        }
        std::cout << frame_output << std::flush;

        std::this_thread::sleep_for(std::chrono::milliseconds(50));
        frame++;
    }

    // Restore cursor
    std::cout << "\033[?25h";
    return 0;
}