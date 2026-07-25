/*
 * Micro-Fluctuating Self-Modifying Quine & Watercolor Map Renderer
 * 
 * 1. Reads CPU temperature micro-fluctuations (sysfs or jitter fallback).
 * 2. Uses thermal entropy to weave dynamic landscape contours and SVG watercolor filters.
 * 3. Self-modifies its own C++ source code file (__FILE__) to persist evolution state.
 * 4. Outputs 'map.svg' displaying the imaginary continent.
 */

#include <iostream>
#include <fstream>
#include <string>
#include <cmath>
#include <chrono>
#include <sstream>
#include <iomanip>

// PERSISTENT_STATE_START
static double THERMAL_STATE = 36.500000;
static int EVOLUTION_GEN = 0;
// PERSISTENT_STATE_END

constexpr double PI = 3.14159265358979323846;

// Query CPU temperature or fallback to high-resolution time micro-jitter
double read_cpu_temperature() {
    std::ifstream thermal_file("/sys/class/thermal/thermal_zone0/temp");
    double raw_temp = 0.0;
    if (thermal_file >> raw_temp) {
        return raw_temp / 1000.0;
    }
    // Microsecond thermal fluctuation simulation fallback
    auto t = std::chrono::high_resolution_clock::now().time_since_epoch().count();
    return 35.0 + (t % 15000) / 1000.0;
}

// Render watercolor SVG map of an imaginary continent
void render_watercolor_map(double temp, int gen) {
    std::ofstream svg("map.svg");
    if (!svg.is_open()) return;

    svg << "<?xml opacity=\"1.0\" encoding=\"UTF-8\"?>\n";
    svg << "<svg xmlns=\"[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)\" viewBox=\"0 0 1000 800\">\n";
    svg << "  <defs>\n";
    
    // Dynamic watercolor noise filter driven by CPU temperature
    double freq = 0.008 + (std::fmod(temp, 5.0) * 0.003);
    int displacement = 20 + static_cast<int>(temp) % 15;
    
    svg << "    <filter id=\"watercolor\" x=\"-20%\" y=\"-20%\" width=\"140%\" height=\"140%\">\n";
    svg << "      <feTurbulence type=\"fractalNoise\" baseFrequency=\"" << freq 
        << "\" numOctaves=\"5\" result=\"noise\"/>\n";
    svg << "      <feDisplacementMap in=\"SourceGraphic\" in2=\"noise\" scale=\"" << displacement 
        << "\" xChannelSelector=\"R\" yChannelSelector=\"G\"/>\n";
    svg << "    </filter>\n";
    
    // Atmospheric Ocean Gradient
    svg << "    <radialGradient id=\"ocean\" cx=\"50%\" cy=\"50%\" r=\"75%\">\n";
    svg << "      <stop offset=\"0%\" stop-color=\"#1e293b\"/>\n";
    svg << "      <stop offset=\"100%\" stop-color=\"#0f172a\"/>\n";
    svg << "    </radialGradient>\n";
    svg << "  </defs>\n";

    // Ocean Background
    svg << "  <rect width=\"1000\" height=\"800\" fill=\"url(#ocean)\"/>\n";

    // Watercolor Coastlines and Layered Terrain
    svg << "  <g filter=\"url(#watercolor)\">\n";
    
    const char* terrain_colors[] = {"#d97706", "#b45309", "#4d7c0f", "#15803d", "#047857", "#0f766e"};
    int total_layers = 6;
    
    for (int layer = 0; layer < total_layers; ++layer) {
        double base_radius = 280.0 - (layer * 35.0);
        double opacity = 0.35 + (layer * 0.1);
        
        svg << "    <path d=\"M ";
        int steps = 72;
        for (int i = 0; i <= steps; ++i) {
            double angle = i * (2.0 * PI / steps);
            
            // Harmonic wave formula modulated by thermal entropy and generation
            double r = base_radius 
                     + std::sin(angle * 3.0 + temp) * 45.0 
                     + std::cos(angle * 7.0 - gen * 0.2) * 25.0 
                     + std::sin(angle * 11.0 + temp * 0.5) * 12.0;
            
            double x = 500.0 + r * std::cos(angle);
            double y = 400.0 + r * std::sin(angle);
            
            svg << x << "," << y << (i == steps ? " Z\"" : " L ");
        }
        svg << " fill=\"" << terrain_colors[layer] << "\" fill-opacity=\"" << opacity 
            << "\" stroke=\"#fef3c7\" stroke-width=\"0.5\"/>\n";
    }
    
    svg << "  </g>\n";

    // Metadata & Overlay
    svg << "  <text x=\"40\" y=\"750\" fill=\"#f8fafc\" font-family=\"monospace\" font-size=\"14\" opacity=\"0.85\">";
    svg << "CONTINENT EVOLUTION GEN " << gen << " | THERMAL SEED: " << std::fixed << std::setprecision(3) << temp << " C";
    svg << "</text>\n";
    svg << "</svg>\n";
}

// Self-modify the executable's own source code file (__FILE__)
void self_modify(double new_temp, int new_gen) {
    std::ifstream in(__FILE__);
    if (!in.is_open()) return;

    std::string content((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
    in.close();

    std::string start_marker = "// PERSISTENT_STATE_START";
    std::string end_marker = "// PERSISTENT_STATE_END";

    size_t start_pos = content.find(start_marker);
    size_t end_pos = content.find(end_marker);

    if (start_pos != std::string::npos && end_pos != std::string::npos) {
        std::ostringstream new_state;
        new_state << start_marker << "\n"
                  << "static double THERMAL_STATE = " << std::fixed << std::setprecision(6) << new_temp << ";\n"
                  << "static int EVOLUTION_GEN = " << new_gen << ";\n";

        content.replace(start_pos, (end_pos - start_pos), new_state.str());

        std::ofstream out(__FILE__);
        if (out.is_open()) {
            out << content;
        }
    }
}

int main() {
    double current_temp = read_cpu_temperature();
    int next_gen = EVOLUTION_GEN + 1;

    // Render watercolor SVG continent
    render_watercolor_map(current_temp, next_gen);

    // Persist thermal state mutations directly into source code
    self_modify(current_temp, next_gen);

    std::cout << "Rendered 'map.svg' [Gen " << next_gen 
              << " | Thermal Seed: " << current_temp << " C]\n";
    std::cout << "Source file (" << __FILE__ << ") updated.\n";

    return 0;
}