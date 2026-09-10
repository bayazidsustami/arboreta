#include <iostream>
#include <vector>
#include <cmath>
#include <chrono>
#include <thread>
#include <random>
#include <memory>
#include <algorithm>
#include <numeric>
#include <atomic>

// Standard ANSI terminal escape sequences for visual output
constexpr const char* CLEAR_SCREEN = "\033[2J\033[1;1H";
constexpr const char* CURSOR_HOME  = "\033[H";
constexpr const char* RESET_COLOR  = "\033[0m";

// Constants for CA Canvas and Audio simulation
constexpr int CANVAS_WIDTH = 64;
constexpr int CANVAS_HEIGHT = 24;
constexpr double PI = 3.14159265358979323846;

// Simulates real-time system performance telemetry metrics
struct TelemetryMetrics {
    double cpu_usage;          // Percentage 0.0 - 1.0
    double cache_miss_rate;    // Simulates micro-architectural stalls
    double mem_fragmentation;  // High values indicate high fragmentation
};

// Class simulating real-time system performance tracking
class TelemetryTracker {
public:
    TelemetryTracker() : rng(std::random_device{}()) {}

    TelemetryMetrics fetch() {
        // Generate simulated dynamic hardware metrics
        std::uniform_real_distribution<double> dist(0.0, 1.0);
        
        static double time_step = 0.0;
        time_step += 0.1;

        double cpu = (std::sin(time_step) + 1.0) * 0.4 + dist(rng) * 0.2;
        double cache_misses = (std::cos(time_step * 0.7) + 1.0) * 0.4 + dist(rng) * 0.2;
        double frag = (std::sin(time_step * 0.3) + 1.0) * 0.45 + dist(rng) * 0.1;

        return TelemetryMetrics{
            std::clamp(cpu, 0.0, 1.0),
            std::clamp(cache_misses, 0.0, 1.0),
            std::clamp(frag, 0.0, 1.0)
        };
    }

private:
    std::mt19937 rng;
};

// Generates algorithmic ambient soundscape frames based on memory fragmentation
class AmbientSoundscapeEngine {
public:
    AmbientSoundscapeEngine(int sample_rate = 44100)
        : sample_rate_(sample_rate), phase_base_(0.0), phase_harm_(0.0) {}

    // Renders audio PCM frames represented as ASCII spectral visualizations
    std::string generate_audio_frame(double memory_fragmentation, int frame_size = 512) {
        // Map fragmentation map properties to musical frequencies (Pentatonic Scale)
        static const double frequencies[] = { 130.81, 146.83, 164.81, 196.00, 220.00, 261.63, 293.66 };
        int freq_idx = static_cast<int>(memory_fragmentation * 6.0);
        double base_freq = frequencies[freq_idx];
        double detune_freq = base_freq * (1.0 + (memory_fragmentation * 0.05));

        double rms_energy = 0.0;
        for (int i = 0; i < frame_size; ++i) {
            double sample1 = std::sin(phase_base_);
            double sample2 = 0.5 * std::sin(phase_harm_);
            double mixed = (sample1 + sample2) / 1.5;

            rms_energy += mixed * mixed;

            phase_base_ += 2.0 * PI * base_freq / sample_rate_;
            phase_harm_ += 2.0 * PI * detune_freq / sample_rate_;

            if (phase_base_ > 2.0 * PI) phase_base_ -= 2.0 * PI;
            if (phase_harm_ > 2.0 * PI) phase_harm_ -= 2.0 * PI;
        }

        rms_energy = std::sqrt(rms_energy / frame_size);

        // Convert audio spectrum strength to an ASCII waveform visualization bar
        int bar_length = static_cast<int>(rms_energy * 30);
        std::string bar = "Soundscape Spectrum [";
        for (int i = 0; i < 30; ++i) {
            if (i < bar_length) bar += "=";
            else bar += " ";
        }
        bar += "] " + std::to_string(static_cast<int>(base_freq)) + " Hz";
        return bar;
    }

private:
    int sample_rate_;
    double phase_base_;
    double phase_harm_;
};

// Cellular Automaton canvas seeded by CPU micro-architectural stall patterns
class CellularAutomatonCanvas {
public:
    CellularAutomatonCanvas(int width, int height)
        : width_(width), height_(height), grid_(width * height, 0), next_grid_(width * height, 0) {}

    // Inject seeds based on micro-architectural stall patterns (cache miss spikes)
    void seed_from_stalls(double stall_intensity) {
        int seed_count = static_cast<int>(stall_intensity * 25.0);
        std::mt19937 rng(static_cast<unsigned>(std::chrono::system_clock::now().time_since_epoch().count()));
        std::uniform_int_distribution<int> dist_x(0, width_ - 1);
        std::uniform_int_distribution<int> dist_y(0, height_ - 1);

        for (int i = 0; i < seed_count; ++i) {
            int cx = dist_x(rng);
            int cy = dist_y(rng);
            // Inject dynamic block pattern when high stalls occur
            grid_[cy * width_ + cx] = 1;
            if (cx + 1 < width_) grid_[cy * width_ + (cx + 1)] = 1;
            if (cy + 1 < height_) grid_[(cy + 1) * width_ + cx] = 1;
        }
    }

    // Step Conway's Game of Life logic forward
    void update() {
        for (int y = 0; y < height_; ++y) {
            for (int x = 0; x < width_; ++x) {
                int neighbors = count_neighbors(x, y);
                int idx = y * width_ + x;
                
                if (grid_[idx] == 1) {
                    next_grid_[idx] = (neighbors == 2 || neighbors == 3) ? 1 : 0;
                } else {
                    next_grid_[idx] = (neighbors == 3) ? 1 : 0;
                }
            }
        }
        grid_ = next_grid_;
    }

    // Render cellular automaton frame using ANSI color maps
    void render() const {
        std::string buffer;
        buffer.reserve(width_ * height_ * 10);

        for (int y = 0; y < height_; ++y) {
            for (int x = 0; x < width_; ++x) {
                if (grid_[y * width_ + x] == 1) {
                    buffer += "\033[38;5;46m#\033[0m"; // Vibrant green for active cells
                } else {
                    buffer += "\033[38;5;234m.\033[0m"; // Dark grey for dead cells
                }
            }
            buffer += "\n";
        }
        std::cout << buffer;
    }

private:
    int count_neighbors(int x, int y) const {
        int count = 0;
        for (int dy = -1; dy <= 1; ++dy) {
            for (int dx = -1; dx <= 1; ++dx) {
                if (dx == 0 && dy == 0) continue;
                int nx = (x + dx + width_) % width_;
                int ny = (y + dy + height_) % height_;
                count += grid_[ny * width_ + nx];
            }
        }
        return count;
    }

    int width_;
    int height_;
    std::vector<int> grid_;
    std::vector<int> next_grid_;
};

int main() {
    TelemetryTracker telemetry;
    AmbientSoundscapeEngine soundscape;
    CellularAutomatonCanvas canvas(CANVAS_WIDTH, CANVAS_HEIGHT);

    std::cout << CLEAR_SCREEN;

    // Interactive Loop (Simulating 50 rendering cycles)
    for (int cycle = 0; cycle < 50; ++cycle) {
        std::cout << CURSOR_HOME;

        // 1. Ingest real-time system performance telemetry
        TelemetryMetrics metrics = telemetry.fetch();

        // 2. Convert CPU stall patterns into seeds for the cellular automaton
        canvas.seed_from_stalls(metrics.cache_miss_rate);
        canvas.update();

        // 3. Convert memory fragmentation into ambient audio spectrum frame
        std::string audio_bar = soundscape.generate_audio_frame(metrics.mem_fragmentation);

        // 4. Output the integrated visual loop display
        std::cout << "=== REAL-TIME TELEMETRY FEEDBACK LOOP ===" << "\n";
        std::cout << "CPU Load: [" << static_cast<int>(metrics.cpu_usage * 100.0) << "%] | "
                  << "Stall Rate: [" << static_cast<int>(metrics.cache_miss_rate * 100.0) << "%] | "
                  << "Mem Frag Map: [" << static_cast<int>(metrics.mem_fragmentation * 100.0) << "%]\n";
        std::cout << audio_bar << "\n";
        std::cout << "----------------------------------------------------------------\n";
        
        canvas.render();

        std::cout << "----------------------------------------------------------------\n";
        std::cout << "Press Ctrl+C to terminate simulation loop. Cycle: " << cycle + 1 << "/50\n";

        std::this_thread::sleep_for(std::chrono::milliseconds(150));
    }

    std::cout << RESET_COLOR << "\nLoop finished successfully.\n";
    return 0;
}