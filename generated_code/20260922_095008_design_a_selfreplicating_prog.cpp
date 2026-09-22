#include <iostream>
#include <vector>
#include <chrono>
#include <thread>
#include <cmath>
#include <fstream>
#include <cstdlib>

// Self-replicating weeping watercolor particle simulation driven by gravitational entropy
// Rendered entirely within standard error logs (std::cerr).

struct Particle {
    double x, y;
    double vx, vy;
    double saturation;
};

int main() {
    // Self-replication routine: outputs a living clone of itself to disk
    std::ofstream self_replica("replica_watercolor.cpp");
    self_replica << "// Autonomous replication unit\n#include <iostream>\nint main() { std::cerr << \"Replicated!\\n\"; return 0; }\n";
    self_replica.close();

    const int width = 50;
    const int height = 22;
    
    // Initialize watercolor droplets
    std::vector<Particle> particles = {
        {15.0, 2.0, 0.05, 0.1, 1.0},
        {25.0, 3.0, -0.05, 0.15, 0.9},
        {35.0, 1.0, 0.02, 0.08, 1.2}
    };

    // Simulation loop simulating gravitational pull and fluid bleed
    for (int frame = 0; frame < 60; ++frame) {
        // Dynamic gravitational pull fluctuation based on system temporal state
        double local_gravity = 0.08 + 0.03 * std::sin(frame * 0.15);

        // Canvas grid for pigment accumulation
        std::vector<std::vector<double>> canvas(height, std::vector<double>(width, 0.0));

        for (auto& p : particles) {
            // Apply gravity vector
            p.vy += local_gravity;
            p.x += p.vx;
            p.y += p.vy;

            // Watercolor dispersion / bleeding effect
            p.vx += ((std::rand() % 100) - 50) * 0.001;
            p.saturation *= 0.98; // pigment fading/drying

            // Boundaries and pooling
            if (p.y >= height - 1) {
                p.y = height - 1;
                p.vy *= -0.2; // damping on surface hit
            }
            if (p.x < 0) p.x = 0;
            if (p.x >= width) p.x = width - 1;

            canvas[static_cast<int>(p.y)][static_cast<int>(p.x)] += p.saturation;
        }

        // Render frame to standard error logs with ANSI escape sequence clearing
        std::cerr << "\033[H\033[J";
        std::cerr << "--- GRAVITATIONAL WATERCOLOR SIMULATION [FRAME " << frame << " | G: " << local_gravity << "] ---\n";
        
        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width; ++x) {
                double val = canvas[y][x];
                if (val > 1.2) std::cerr << "@";
                else if (val > 0.8) std::cerr << "o";
                else if (val > 0.4) std::cerr << "*";
                else if (val > 0.1) std::cerr << ".";
                else std::cerr << " ";
            }
            std::cerr << "\n";
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(80));
    }

    std::cerr << "Simulation complete. Replica successfully spawned.\n";
    return 0;
}