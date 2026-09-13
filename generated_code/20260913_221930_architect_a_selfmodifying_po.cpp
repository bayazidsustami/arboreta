#include <iostream>
#include <vector>
#include <string>
#include <cmath>
#include <random>
#include <chrono>
#include <thread>
#include <fstream>
#include <sstream>

// Reads live CPU temp (Linux /sys fallback to simulated wave if unreadable)
double get_cpu_temp(double frame) {
    std::ifstream file("/sys/class/thermal/thermal_zone0/temp");
    if (file.is_open()) {
        double temp_milli;
        file >> temp_milli;
        return temp_milli / 1000.0;
    }
    // Fallback thermal simulation: 42°C base + dynamic oscillation
    return 42.0 + 15.0 * (std::sin(frame * 0.05) * std::cos(frame * 0.02) + 1.0);
}

// Single-function architecture fulfilling the self-modifying, poetic Markov thermal visualizer
void thermal_poetic_gradient() {
    // 1. Poetic Corpus Vocabulary
    std::vector<std::string> words = {
        "ember", "whisper", "pulse", "silicon", "drift", "heat", "glow", 
        "silent", "breath", "flame", "frost", "shadow", "spark", "ocean"
    };

    // 2. Markov Transition Matrix initialized dynamically
    const size_t N = words.size();
    std::vector<std::vector<double>> markov(N, std::vector<double>(N, 1.0 / N));

    std::mt19937 rng(1337);
    size_t current_word_idx = 0;
    double frame = 0.0;

    // Enable alternate screen buffer & hide cursor
    std::cout << "\033[?1049h\033[?25l";

    for (int step = 0; step < 300; ++step) { // Main execution loop
        double temp = get_cpu_temp(frame);
        
        // --- Self-Modifying Markov Logic ---
        // Temperature distorts transition probabilities, mutating the text generator's state
        double temp_factor = std::clamp((temp - 30.0) / 50.0, 0.05, 1.0);
        for (size_t i = 0; i < N; ++i) {
            double sum = 0.0;
            for (size_t j = 0; j < N; ++j) {
                // Modulate transition weights dynamically based on thermal energy
                markov[i][j] *= (1.0 + 0.5 * std::sin(temp_factor * (i + j + frame)));
                sum += markov[i][j];
            }
            for (size_t j = 0; j < N; ++j) markov[i][j] /= sum; // Normalize
        }

        // Sample next word from modified Markov row
        std::discrete_distribution<size_t> dist(markov[current_word_idx].begin(), markov[current_word_idx].end());
        current_word_idx = dist(rng);
        std::string word = words[current_word_idx];

        // --- Visually Symmetrical Color Gradient Renderer ---
        std::ostringstream buffer;
        buffer << "\033[H"; // Move to top-left

        const int width = 60;
        const int height = 20;

        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width; ++x) {
                // Symmetrical distance from center (0.0 to 1.0)
                double dx = (x - width / 2.0) / (width / 2.0);
                double dy = (y - height / 2.0) / (height / 2.0);
                double dist_center = std::sqrt(dx * dx + dy * dy);

                // Thermal color mapping: low temp -> blue/cyan, high temp -> magenta/fire
                int r = static_cast<int>(127.5 * (1.0 + std::sin(temp_factor * 5.0 - dist_center * 3.0)));
                int g = static_cast<int>(127.5 * (1.0 + std::cos(dist_center * 4.0 - temp_factor * 2.0)));
                int b = static_cast<int>(255.0 * std::clamp(1.0 - dist_center, 0.0, 1.0));

                // Superimpose poetic text in a symmetrical central band
                char ch = ' ';
                if (y == height / 2 && std::abs(x - width / 2) < static_cast<int>(word.length() / 2)) {
                    int char_idx = x - (width / 2 - word.length() / 2);
                    if (char_idx >= 0 && char_idx < static_cast<int>(word.length())) {
                        ch = word[char_idx];
                    }
                } else if (dist_center < 0.8) {
                    ch = (static_cast<int>(dist_center * 10 + frame) % 2 == 0) ? '.' : ':';
                }

                // Truecolor terminal ANSI sequence (24-bit)
                buffer << "\033[38;2;" << r << ";" << g << ";" << b << "m" << ch;
            }
            buffer << "\033[0m\n";
        }

        // Overlay status text
        buffer << "\033[1;37m Live CPU Temp: " << temp << " °C | State: " << word << "\033[0m\n";

        std::cout << buffer.str() << std::flush;
        std::this_thread::sleep_for(std::chrono::milliseconds(80));
        frame += 0.2;
    }

    // Restore terminal screen & cursor
    std::cout << "\033[?25h\033[?1049l";
}

int main() {
    thermal_poetic_gradient();
    return 0;
}