#include <iostream>
#include <string>
#include <vector>
#include <cmath>
#include <thread>
#include <chrono>

// Esoteric Rendering Engine: Book-to-Kaleidoscope Transformer
// Vowels dictate color/density modulation; Punctuation triggers particle bursts.

struct Particle {
    double x, y;
    double vx, vy;
    char symbol;
    int lifespan;
};

void renderFrame(int frame, const std::string& text, double saturation, const std::vector<Particle>& particles) {
    const int width = 60;
    const int height = 30;
    std::vector<std::string> screen(height, std::string(width, ' '));

    // Center of the kaleidoscope
    double cx = width / 2.0;
    double cy = height / 2.0;

    // Draw procedural kaleidoscope based on text state and saturation
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            double dx = x - cx;
            double dy = (y - cy) * 2.0; // Aspect ratio correction for terminals
            double dist = std::sqrt(dx * dx + dy * dy);
            double angle = std::atan2(dy, dx);

            // Kaleidoscope symmetry (8 folds)
            double folded_angle = std::fmod(std::abs(angle), M_PI / 4.0);
            
            // Mathematical pattern modulated by saturation
            double val = std::sin(dist * 0.1 * saturation - frame * 0.2) * 
                         std::cos(folded_angle * 8.0 + frame * 0.1);

            if (std::abs(val) > 0.4) {
                int charIndex = (static_cast<int>(dist + frame) % text.length());
                screen[y][x] = text[charIndex];
            }
        }
    }

    // Overlay active punctuation particles
    for (const auto& p : particles) {
        int px = static_cast<int>(cx + p.x);
        int py = static_cast<int>(cy + p.y / 2.0);
        if (px >= 0 && px < width && py >= 0 && py < height) {
            screen[py][px] = p.symbol;
        }
    }

    // Print frame with ANSI clear screen
    std::cout << "\033[H\033[J";
    std::cout << "=== ESOTERIC RENDERING ENGINE (Saturation: " << saturation << ") ===\n";
    for (const auto& row : screen) {
        std::cout << row << "\n";
    }
}

int main() {
    // Simulated ancient public domain book content
    std::string ancient_book = "It was the best of times, it was the worst of times; it was the age of wisdom, "
                               "it was the age of foolishness... Gutenberg edition #1301.";

    double saturation = 1.0;
    std::vector<Particle> particles;
    int text_cursor = 0;

    // Run for 50 evolutionary frames
    for (int frame = 0; frame < 50; ++frame) {
        char current_char = ancient_book[text_cursor];
        text_cursor = (text_cursor + 1) % ancient_book.length();

        // 1. Vowels dictate color/density saturation
        char lower = std::tolower(current_char);
        if (lower == 'a' || lower == 'e' || lower == 'i' || lower == 'o' || lower == 'u') {
            saturation += 0.2;
            if (saturation > 3.0) saturation = 0.5;
        }

        // 2. Punctuation marks trigger geometric particle explosions
        if (current_char == '.' || current_char == ',' || current_char == ';' || current_char == '!') {
            for (int i = 0; i < 12; ++i) {
                double angle = (i / 12.0) * 2.0 * M_PI;
                double speed = 1.5 + (i % 3);
                particles.push_back({0.0, 0.0, std::cos(angle) * speed, std::sin(angle) * speed, current_char, 10});
            }
        }

        // Update existing particles
        for (auto it = particles.begin(); it != particles.end();) {
            it->x += it->vx;
            it->y += it->vy;
            it->lifespan--;
            if (it->lifespan <= 0) {
                it = particles.erase(it);
            } else {
                ++it;
            }
        }

        renderFrame(frame, ancient_book, saturation, particles);
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }

    return 0;
}