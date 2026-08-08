/*
 * Real-Time Memory Heap Profiler & Gothic Cathedral Procedural Renderer
 *
 * Architecture:
 * - Simulated Memory Manager / GC Engine: Tracks heap allocations, triggers garbage collection cycles,
 *   and introduces intentional memory leaks to simulate process degradation.
 * - Procedural ASCII Renderer: Constructs a Gothic Cathedral (Spires, Flying Buttresses, Rose Window, Nave)
 *   and applies structural decay noise functions proportional to heap memory leak severity.
 * - Real-Time Visualizer: Dual-threaded loop driving live memory dynamics and ANSI terminal updates.
 */

#include <iostream>
#include <vector>
#include <string>
#include <thread>
#include <chrono>
#include <mutex>
#include <atomic>
#include <random>
#include <algorithm>
#include <iomanip>
#include <cmath>

// Terminal ANSI Color Codes
namespace Color {
    const std::string RESET   = "\033[0m";
    const std::string BOLD    = "\033[1m";
    const std::string GREY    = "\033[90m";
    const std::string RED     = "\033[31m";
    const std::string GREEN   = "\033[32m";
    const std::string YELLOW  = "\033[33m";
    const std::string CYAN    = "\033[36m";
    const std::string MAGENTA = "\033[35m";
    const std::string WHITE   = "\033[97m";
}

// Memory Allocation Record
struct Block {
    void* address;
    size_t size;
    bool marked;
    bool is_leaked;
};

// Simulated Heap & Garbage Collection Profiler
class GothicHeapProfiler {
private:
    std::vector<Block> heap_;
    mutable std::mutex mutex_;
    size_t total_allocated_bytes_{0};
    size_t total_freed_bytes_{0};
    size_t leaked_bytes_{0};
    size_t gc_cycle_count_{0};
    bool gc_active_{false};

public:
    void allocate(size_t size, bool force_leak = false) {
        std::lock_guard<std::mutex> lock(mutex_);
        void* dummy_ptr = reinterpret_cast<void*>(0x1000 + heap_.size() * 0x20);
        heap_.push_back({dummy_ptr, size, false, force_leak});
        total_allocated_bytes_ += size;
        if (force_leak) {
            leaked_bytes_ += size;
        }
    }

    void run_garbage_collection() {
        std::lock_guard<std::mutex> lock(mutex_);
        gc_active_ = true;
        gc_cycle_count_++;

        // Mark phase: Mark non-leaked blocks
        for (auto& block : heap_) {
            if (!block.is_leaked) {
                block.marked = true;
            }
        }

        // Sweep phase: Free marked blocks
        auto it = heap_.begin();
        while (it != heap_.end()) {
            if (it->marked && !it->is_leaked) {
                total_freed_bytes_ += it->size;
                it = heap_.erase(it);
            } else {
                it->marked = false; // Reset for next GC
                ++it;
            }
        }
        gc_active_ = false;
    }

    struct Metrics {
        size_t live_bytes;
        size_t leaked_bytes;
        size_t total_allocated;
        size_t gc_cycles;
        float structural_integrity; // 1.0 (perfect) to 0.0 (ruin)
        bool gc_running;
    };

    Metrics get_metrics() const {
        std::lock_guard<std::mutex> lock(mutex_);
        size_t live = 0;
        for (const auto& b : heap_) live += b.size;

        // Structural integrity decays as leaked bytes ratio grows relative to active heap limit
        float leak_ratio = (total_allocated_bytes_ > 0) 
            ? static_cast<float>(leaked_bytes_) / static_cast<float>(total_allocated_bytes_ * 0.4f)
            : 0.0f;
        
        float integrity = std::max(0.0f, 1.0f - leak_ratio);

        return { live, leaked_bytes_, total_allocated_bytes_, gc_cycle_count_, integrity, gc_active_ };
    }
};

// Procedural ASCII Cathedral Generator and Decay Engine
class CathedralRenderer {
private:
    static constexpr int WIDTH = 74;
    static constexpr int HEIGHT = 24;

    std::vector<std::string> base_cathedral_;
    std::mt19937 rng_{1337};

    void build_base_blueprint() {
        base_cathedral_ = {
            "                            /\\                            ",
            "                           /  \\                           ",
            "                          / || \\                          ",
            "                         |  ||  |                         ",
            "                         |  ||  |                         ",
            "               /\\        |  ||  |        /\\               ",
            "              /  \\       |  ||  |       /  \\              ",
            "             /    \\  /\\  |  ||  |  /\\  /    \\             ",
            "            |  ||  |/  \\||  ||  ||/  \\|  ||  |            ",
            "            |  ||  |    ||  ||  ||    |  ||  |            ",
            "            |  ||  | /\\ ||(  @  )|| /\\ |  ||  |            ",
            "           /|  ||  |/  \\||  ||  ||/  \\|  ||  |\\           ",
            "          / |  ||  |    ||  ||  ||    |  ||  | \\          ",
            "         /  |  ||  | /\\ ||      || /\\ |  ||  |  \\         ",
            "        /===|__||__|/  \\||______||/  \\|__|__||===\\        ",
            "        |   |      |    |        |    |      |   |        ",
            "        |   |  /\\  |    |  /--\\  |    |  /\\  |   |        ",
            "        |   | /  \\ |    | /    \\ |    | /  \\ |   |        ",
            "        |   ||    ||    ||      ||    ||    ||   |        ",
            "        |___||____||____||______||____||____||___|        ",
            "       /__________________________________________\\       ",
            "       |  ||  ||  ||  ||  ||  ||  ||  ||  ||  ||  |       ",
            "       |__||__||__||__||__||__||__||__||__||__||__|       ",
            "      [============================================]      "
        };
    }

    char crumble_char(char orig, float decay) {
        if (orig == ' ') return ' ';
        std::uniform_real_distribution<float> dist(0.0f, 1.0f);
        if (dist(rng_) < decay) {
            const std::string rubble = ".,;:*~' ";
            return rubble[dist(rng_) * (rubble.size() - 1)];
        }
        return orig;
    }

public:
    CathedralRenderer() {
        build_base_blueprint();
    }

    void render(const GothicHeapProfiler::Metrics& metrics) {
        // Clear screen and position cursor to top-left
        std::cout << "\033[2J\033[H";

        // Render Heap Header Dashboard
        std::cout << Color::BOLD << Color::CYAN << "==========================================================================" << Color::RESET << "\n";
        std::cout << Color::BOLD << " REAL-TIME C++ HEAP PROFILER " << Color::GREY << ":: " 
                  << Color::MAGENTA << "GOTHIC CATHEDRAL PROFILE" << Color::RESET << "\n";
        std::cout << Color::CYAN << "==========================================================================" << Color::RESET << "\n";

        float integrity_pct = metrics.structural_integrity * 100.0f;
        std::string integrity_color = (integrity_pct > 75.0f) ? Color::GREEN : (integrity_pct > 35.0f) ? Color::YELLOW : Color::RED;

        std::cout << " Heap Allocated: " << Color::BOLD << std::setw(8) << metrics.live_bytes << " B" << Color::RESET
                  << " | Leaked: " << Color::RED << std::setw(8) << metrics.leaked_bytes << " B" << Color::RESET
                  << " | GC Cycles: " << Color::YELLOW << metrics.gc_cycles << Color::RESET << "\n";

        std::cout << " Integrity: [" << integrity_color;
        int bar_width = 30;
        int filled = static_cast<int>(metrics.structural_integrity * bar_width);
        for (int i = 0; i < bar_width; ++i) {
            if (i < filled) std::cout << "#";
            else std::cout << ".";
        }
        std::cout << Color::RESET << "] " << integrity_color << std::fixed << std::setprecision(1) << integrity_pct << "%" << Color::RESET;

        if (metrics.gc_running) {
            std::cout << Color::BOLD << Color::GREEN << " <GC IN PROGRESS SANCTIFICATION>" << Color::RESET;
        }
        std::cout << "\n\n";

        // Structural decay severity (0.0 = sound, 1.0 = total ruin)
        float decay_factor = std::pow(1.0f - metrics.structural_integrity, 1.5f);

        // Render Cathedral Frame
        for (size_t r = 0; r < base_cathedral_.size(); ++r) {
            std::string line = base_cathedral_[r];
            std::cout << "   ";
            for (size_t c = 0; c < line.size(); ++c) {
                char ch = line[c];
                char rendered_ch = crumble_char(ch, decay_factor);

                // Dynamic ANSI coloring based on cathedral structure and status
                if (rendered_ch != ch) {
                    std::cout << Color::RED << rendered_ch << Color::RESET; // Crumbles/cracks
                } else if (metrics.gc_running && (ch == '|' || ch == '/' || ch == '\\')) {
                    std::cout << Color::GREEN << ch << Color::RESET; // Sacred GC energy sweep
                } else if (ch == '@' || ch == '(' || ch == ')') {
                    std::cout << Color::YELLOW << ch << Color::RESET; // Rose Window
                } else if (ch == '+' || ch == '^' || ch == '=') {
                    std::cout << Color::CYAN << ch << Color::RESET; // Spires & Roofs
                } else {
                    std::cout << Color::WHITE << ch << Color::RESET; // Stone Structure
                }
            }
            std::cout << "\n";
        }
        std::cout << Color::CYAN << "==========================================================================" << Color::RESET << "\n";
        std::cout << Color::GREY << " [Press Ctrl+C to stop] - Garbage Collections rebuild; Memory Leaks destroy." << Color::RESET << "\n";
    }
};

int main() {
    GothicHeapProfiler profiler;
    CathedralRenderer renderer;
    std::atomic<bool> running{true};

    // Background Thread: Simulates real-time application memory lifecycle
    std::thread workload_thread([&]() {
        std::mt19937 rng(42);
        std::uniform_int_distribution<size_t> alloc_dist(64, 1024);
        std::uniform_int_distribution<int> action_dist(0, 100);

        while (running) {
            int action = action_dist(rng);

            if (action < 60) {
                // Normal allocation
                profiler.allocate(alloc_dist(rng), false);
            } else if (action < 85) {
                // Garbage Collection trigger
                profiler.run_garbage_collection();
            } else {
                // Memory Leak Event (Causes dynamic structural integrity degradation)
                profiler.allocate(alloc_dist(rng) * 3, true);
            }

            std::this_thread::sleep_for(std::chrono::milliseconds(120));
        }
    });

    // Main Thread: Real-Time Rendering Engine Loop (~15 FPS)
    while (true) {
        auto metrics = profiler.get_metrics();
        renderer.render(metrics);
        std::this_thread::sleep_for(std::chrono::milliseconds(66));
    }

    running = false;
    if (workload_thread.joinable()) {
        workload_thread.join();
    }

    return 0;
}