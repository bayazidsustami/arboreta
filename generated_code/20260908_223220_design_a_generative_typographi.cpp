#include <iostream>
#include <vector>
#include <string>
#include <chrono>
#include <thread>
#include <cmath>
#include <cstdlib>
#include <algorithm>
#include <sstream>

#if defined(_WIN32)
    #include <windows.h>
    #include <psapi.h>
#elif defined(__APPLE__)
    #include <sys/types.h>
    #include <sys/sysctl.h>
    #include <mach/mach.h>
    #include <sys/ioctl.h>
    #include <unistd.h>
#else
    #include <sys/sysinfo.h>
    #include <sys/ioctl.h>
    #include <unistd.h>
    #include <fstream>
#endif

// --- Telemetry Fetching System ---
struct SystemStats {
    double cpu_load;       // 0.0 to 1.0
    double memory_usage;   // 0.0 to 1.0
    double network_traffic;// 0.0 to 1.0 (activity indicator)
};

class TelemetryMonitor {
public:
    TelemetryMonitor() : prev_idle_(0), prev_total_(0), net_phase_(0.0) {}

    SystemStats sample() {
        SystemStats stats;
        stats.cpu_load = fetch_cpu();
        stats.memory_usage = fetch_memory();
        stats.network_traffic = fetch_network();
        return stats;
    }

private:
    unsigned long long prev_idle_, prev_total_;
    double net_phase_;

    double fetch_cpu() {
#if defined(__linux__)
        std::ifstream file("/proc/stat");
        std::string line;
        if (std::getline(file, line)) {
            std::istringstream ss(line);
            std::string cpu;
            unsigned long long user, nice, system, idle, iowait, irq, softirq, steal;
            ss >> cpu >> user >> nice >> system >> idle >> iowait >> irq >> softirq >> steal;
            
            unsigned long long idle_time = idle + iowait;
            unsigned long long total_time = user + nice + system + idle + iowait + irq + softirq + steal;
            
            unsigned long long total_diff = total_time - prev_total_;
            unsigned long long idle_diff = idle_time - prev_idle_;
            
            prev_total_ = total_time;
            prev_idle_ = idle_time;
            
            if (total_diff > 0)
                return 1.0 - static_cast<double>(idle_diff) / total_diff;
        }
#endif
        // Simulated fallback dynamic waveform if OS metrics are unavailable/unimplemented
        net_phase_ += 0.15;
        return (std::sin(net_phase_) + 1.0) / 2.0;
    }

    double fetch_memory() {
#if defined(__linux__)
        struct sysinfo info;
        if (sysinfo(&info) == 0) {
            double total = info.totalram;
            double free = info.freeram + info.bufferram;
            return (total - free) / total;
        }
#elif defined(_WIN32)
        MEMORYSTATUSEX memInfo;
        memInfo.dwLength = sizeof(MEMORYSTATUSEX);
        if (GlobalMemoryStatusEx(&memInfo)) {
            return static_cast<double>(memInfo.dwMemoryLoad) / 100.0;
        }
#endif
        return (std::cos(net_phase_ * 0.7) + 1.0) / 2.0;
    }

    double fetch_network() {
#if defined(__linux__)
        std::ifstream file("/proc/net/dev");
        std::string line;
        unsigned long long rx = 0, tx = 0;
        while (std::getline(file, line)) {
            if (line.find(':') != std::string::npos) {
                std::istringstream ss(line.substr(line.find(':') + 1));
                unsigned long long r, t, dummy;
                ss >> r; for (int i = 0; i < 7; ++i) ss >> dummy; ss >> t;
                rx += r; tx += t;
            }
        }
        static unsigned long long prev_bytes = 0;
        unsigned long long total = rx + tx;
        double diff = (prev_bytes == 0) ? 0 : (total - prev_bytes);
        prev_bytes = total;
        return std::min(1.0, diff / 500000.0); // Normalize activity up to ~500KB per sample
#endif
        return (std::sin(net_phase_ * 2.3) + 1.0) / 2.0;
    }
};

// --- Generative Typographic Engine ---
class PoetryEngine {
public:
    PoetryEngine() {
        // Multi-tier vocabulary governed by memory consumption levels
        tier_low_ = {"bit", "core", "echo", "pulse", "flow", "wire", "node", "tick", "sigh", "beam"};
        tier_mid_ = {"silicon", "current", "lattice", "transient", "memory", "voltage", "cascade", "phantom", "circuit", "spectrum"};
        tier_high_ = {"crystallize", "transcendence", "infinitude", "architecture", "ephemeral", "oscillations", "subsumption", "entropy", "synchronicity"};
    }

    void render_frame(const SystemStats& stats) {
        int width = 80, height = 24;
        get_terminal_size(width, height);

        // 1. Memory dictates Vocabulary Tier & Tone
        std::vector<std::string> current_vocab = tier_low_;
        if (stats.memory_usage > 0.33) {
            current_vocab.insert(current_vocab.end(), tier_mid_.begin(), tier_mid_.end());
        }
        if (stats.memory_usage > 0.66) {
            current_vocab.insert(current_vocab.end(), tier_high_.begin(), tier_high_.end());
        }

        // 2. CPU Load dictates Rhythm/Meter (Line length & Syllable structure)
        int lines_count = static_cast<int>(3 + stats.cpu_load * (height - 6));
        int words_per_line = static_cast<int>(2 + stats.cpu_load * 6);

        // Clear terminal screen and hide cursor
        std::cout << "\033[2J\033[H\033[?25l";

        // Generate and position poetry spatially based on Network Traffic
        for (int i = 0; i < lines_count; ++i) {
            std::string line_text = generate_line(current_vocab, words_per_line);

            // 3. Network Traffic governs spatial distortion/layout offset
            double net_shift = std::sin(i * 0.8 + stats.network_traffic * 6.28) * (stats.network_traffic * (width / 4.0));
            int base_indent = static_cast<int>((width - line_text.length()) / 2.0 + net_shift);
            base_indent = std::max(1, std::min(width - (int)line_text.length() - 1, base_indent));

            // Dynamic color pulsing matching resource stress
            int color_code = 31 + static_cast<int>(stats.cpu_load * 5); // Shifts from Cyan/Green to Red

            // Move cursor to specific (y, x) coordinate
            int line_y = static_cast<int>((height - lines_count) / 2.0) + i + 1;
            std::cout << "\033[" << line_y << ";" << base_indent << "H";
            std::cout << "\033[1;" << color_code << "m" << line_text << "\033[0m";
        }

        // Render Telemetry HUD Bar at bottom
        std::cout << "\033[" << height << ";1H\033[90m";
        std::cout << "[CPU Load: " << static_cast<int>(stats.cpu_load * 100) << "% | "
                  << "RAM Usage: " << static_cast<int>(stats.memory_usage * 100) << "% | "
                  << "NET Traffic: " << static_cast<int>(stats.network_traffic * 100) << "%]";
        std::cout << "\033[0m" << std::flush;
    }

    ~PoetryEngine() {
        // Restore cursor visibility on exit
        std::cout << "\033[?25h\n";
    }

private:
    std::vector<std::string> tier_low_;
    std::vector<std::string> tier_mid_;
    std::vector<std::string> tier_high_;

    std::string generate_line(const std::vector<std::string>& vocab, int count) {
        std::string line = "";
        for (int i = 0; i < count; ++i) {
            std::string word = vocab[rand() % vocab.size()];
            if (i == 0) word[0] = std::toupper(word[0]);
            line += word + (i == count - 1 ? "" : " ");
        }
        return line;
    }

    void get_terminal_size(int& width, int& height) {
#if defined(_WIN32)
        CONSOLE_SCREEN_BUFFER_INFO csbi;
        GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &csbi);
        width = csbi.srWindow.Right - csbi.srWindow.Left + 1;
        height = csbi.srWindow.Bottom - csbi.srWindow.Top + 1;
#else
        struct winsize w;
        if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0) {
            width = w.ws_col;
            height = w.ws_row;
        }
#endif
    }
};

int main() {
    std::srand(static_cast<unsigned int>(std::time(nullptr)));
    TelemetryMonitor monitor;
    PoetryEngine engine;

    // Render loop reacting continuously to system telemetry updates
    while (true) {
        SystemStats stats = monitor.sample();
        engine.render_frame(stats);
        
        // Frame pacing dynamically influenced by telemetry meter
        int delay_ms = static_cast<int>(300 - (stats.cpu_load * 200));
        std::this_thread::sleep_for(std::chrono::milliseconds(std::max(50, delay_ms)));
    }

    return 0;
}