#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <cmath>
#include <chrono>
#include <thread>
#include <random>
#include <algorithm>
#include <sys/sysinfo.h>

// Thermal Haiku: Translates CPU thermal noise into procedural terminal art & poetry

struct SystemMetrics {
    double cpu_temp;    // CPU Temperature in Celsius
    double ram_usage;   // RAM Usage ratio [0.0 - 1.0]
};

// Fallback noise generator if thermal sensors are inaccessible
double get_pseudo_noise() {
    static std::mt19937 rng(std::random_device{}());
    static std::normal_distribution<double> dist(45.0, 3.5);
    return dist(rng);
}

// Fetch real-time system metrics (Linux sysfs / sysinfo)
SystemMetrics read_system_metrics() {
    SystemMetrics metrics{45.0, 0.5};

    // 1. Read CPU Thermal Sensor
    std::ifstream temp_file("/sys/class/thermal/thermal_zone0/temp");
    if (temp_file.is_open()) {
        double raw_temp;
        if (temp_file >> raw_temp) {
            metrics.cpu_temp = raw_temp > 1000.0 ? raw_temp / 1000.0 : raw_temp;
        }
        temp_file.close();
    } else {
        metrics.cpu_temp = get_pseudo_noise();
    }

    // 2. Read RAM Utilization
    struct sysinfo info;
    if (sysinfo(&info) == 0) {
        double total_ram = info.totalram * info.mem_unit;
        double free_ram = info.freeram * info.mem_unit;
        metrics.ram_usage = (total_ram - free_ram) / total_ram;
    }

    return metrics;
}

// Dynamic Haiku Lexicon mapped to thermal states (Cool / Warm / Hot)
const std::vector<std::string> line1_cool = {"chilled silicon sleeps,", "frost on winter copper,", "silent circuits rest,"};
const std::vector<std::string> line1_warm = {"sparks pulse in the dark,", "humming copper veins,", "currents flow like tides,"};
const std::vector<std::string> line1_hot  = {"fever in the core,", "fire along the traces,", "blazing silicon,"};

const std::vector<std::string> line2_cool = {"calm waves drift across the glass,", "whispers in zero and one,", "cool breeze through the logical gates,"};
const std::vector<std::string> line2_warm = {"data dances through the flames,", "throttled pulses singing light,", "rhythm swells within the grid,"};
const std::vector<std::string> line2_hot  = {"molten thoughts outshine the sun,", "supercharged algorithms scream,", "thermal tempest breaks the shell,"};

const std::vector<std::string> line3_cool = {"dreams remain serene.", "night falls on the grid.", "soft light fades away."};
const std::vector<std::string> line3_warm = {"life breathes through the code.", "energy awake.", "patterns bloom and glow."};
const std::vector<std::string> line3_hot  = {"pinnacle of heat.", "fire burns the page.", "pure power unleashed."};

// Generates a haiku derived from thermal entropy seed
void render_haiku(const SystemMetrics& metrics, int frame) {
    // Seed selection based on thermal noise integer representation
    size_t seed = static_cast<size_t>(metrics.cpu_temp * 1000) + frame;
    
    std::string l1, l2, l3;
    if (metrics.cpu_temp < 50.0) {
        l1 = line1_cool[seed % line1_cool.size()];
        l2 = line2_cool[(seed / 3) % line2_cool.size()];
        l3 = line3_cool[(seed / 7) % line3_cool.size()];
    } else if (metrics.cpu_temp < 70.0) {
        l1 = line1_warm[seed % line1_warm.size()];
        l2 = line2_warm[(seed / 3) % line2_warm.size()];
        l3 = line3_warm[(seed / 7) % line3_warm.size()];
    } else {
        l1 = line1_hot[seed % line1_hot.size()];
        l2 = line2_hot[(seed / 3) % line2_hot.size()];
        l3 = line3_hot[(seed / 7) % line3_hot.size()];
    }

    // Typography spacing swelling/shrinking with RAM usage
    int tracking = static_cast<int>(metrics.ram_usage * 6.0) + 1;
    std::string spacer(tracking, ' ');

    auto format_line = [&](const std::string& text) {
        std::string result = "";
        for (char c : text) {
            result += c;
            result += spacer;
        }
        return result;
    };

    // Color gradient driven by thermal temperature (ANSI terminal escape codes)
    int color_code = 36; // Cyan (cool)
    if (metrics.cpu_temp >= 50.0 && metrics.cpu_temp < 70.0) color_code = 33; // Yellow (warm)
    if (metrics.cpu_temp >= 70.0) color_code = 31; // Red (hot)

    // Clear terminal screen
    std::cout << "\033[2J\033[1;1H";

    // Header metrics display
    std::cout << "\033[90m[ CPU Temp: " << metrics.cpu_temp << "°C | RAM Utilization: " 
              << static_cast<int>(metrics.ram_usage * 100) << "% ]\033[0m\n\n";

    // Visual wave aesthetic proportional to RAM pressure
    int wave_amplitude = static_cast<int>(metrics.ram_usage * 20.0) + 2;
    std::string wave_border = "";
    for (int i = 0; i < 40; ++i) {
        double val = std::sin((i + frame) * 0.2) * wave_amplitude;
        wave_border += (val > 0) ? "~" : "-";
    }

    std::cout << "\033[" << color_code << "m" << wave_border << "\n\n";
    std::cout << "  " << format_line(l1) << "\n\n";
    std::cout << "    " << format_line(l2) << "\n\n";
    std::cout << "  " << format_line(l3) << "\n\n";
    std::cout << wave_border << "\033[0m\n" << std::endl;
}

int main() {
    int frame = 0;
    while (true) {
        SystemMetrics metrics = read_system_metrics();
        render_haiku(metrics, frame++);
        std::this_thread::sleep_for(std::chrono::milliseconds(800));
    }
    return 0;
}