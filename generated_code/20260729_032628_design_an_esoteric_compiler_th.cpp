#include <iostream>
#include <vector>
#include <string>
#include <sstream>
#include <fstream>
#include <cmath>
#include <random>
#include <algorithm>
#include <memory>
#include <iomanip>

// Estoteric Git-to-Starmap Compiler & Visualizer
// Compiles git commit histories into procedural SVG canvas starmaps.
// Cyclomatic complexity controls star luminosity, radius, and constellation geometry.

struct Commit {
    std::string hash;
    std::string author;
    std::string date;
    std::string message;
    int filesChanged = 0;
    int linesAdded = 0;
    int linesDeleted = 0;
    int cyclomaticComplexity = 1; // Derived complexity metric
};

struct Star {
    double x, y;          // Canvas coordinates
    double brightness;    // [0.1, 1.0] derived from complexity
    double radius;        // Derived from lines changed & complexity
    std::string color;    // Spectral class color based on commit balance
    Commit commit;
};

// Generates simulated git commit history with varying structural metrics
std::vector<Commit> fetchGitHistory() {
    std::vector<Commit> history = {
        {"a1b2c3d", "Alice", "2026-01-10", "Initial commit", 3, 150, 0, 2},
        {"e4f5g6h", "Bob", "2026-01-12", "Add parser & AST evaluation", 8, 420, 30, 14},
        {"i7j8k9l", "Alice", "2026-01-15", "Refactor control flow analyzer", 5, 210, 180, 8},
        {"m0n1o2p", "Charlie", "2026-01-18", "Fix memory leak in GC collector", 2, 45, 12, 18},
        {"q3r4s5t", "Bob", "2026-01-20", "Implement async task dispatcher", 12, 890, 120, 25},
        {"u6v7w8x", "Dave", "2026-01-22", "Update documentation & README", 1, 15, 5, 1},
        {"y9z0a1b", "Alice", "2026-01-25", "Optimize loop unrolling pass", 6, 310, 95, 16},
        {"c2d3e4f", "Charlie", "2026-01-28", "Add unit tests for AST nodes", 4, 180, 10, 4},
        {"g5h6i7j", "Bob", "2026-02-01", "Major overhaul of codegen backend", 15, 1250, 640, 32},
        {"k8l9m0n", "Eve", "2026-02-05", "Fix edge-case bug in lexer", 1, 8, 3, 6}
    };
    return history;
}

// Maps commits to procedural stellar coordinate space
std::vector<Star> mapCommitsToStars(const std::vector<Commit>& commits, double width, double height) {
    std::vector<Star> stars;
    std::mt19937 rng(1337); // Deterministic seed for reproducible constellations
    std::uniform_real_distribution<double> distJitter(-20.0, 20.0);

    double totalCommits = static_cast<double>(commits.size());

    for (size_t i = 0; i < commits.size(); ++i) {
        const auto& c = commits[i];
        
        // Procedural position along spiral evolutionary path
        double t = (i + 1) / totalCommits;
        double angle = t * 4.0 * M_PI;
        double radius = (0.15 + 0.35 * t) * std::min(width, height);
        
        double x = width / 2.0 + radius * std::cos(angle) + distJitter(rng);
        double y = height / 2.0 + radius * std::sin(angle) + distJitter(rng);

        // Normalize complexity (1 to 35 range) to brightness [0.2, 1.0]
        double brightness = std::clamp(c.cyclomaticComplexity / 32.0, 0.2, 1.0);

        // Calculate radius based on volume of changes and complexity
        double starRadius = 2.5 + (std::log10(c.linesAdded + c.linesDeleted + 1) * 1.8) * (brightness * 0.8 + 0.2);

        // Determine spectral temperature/color based on add/delete balance
        std::string color;
        double ratio = static_cast<double>(c.linesAdded) / (c.linesAdded + c.linesDeleted + 1);
        if (c.cyclomaticComplexity > 20) {
            color = "#ff4500"; // Deep red/orange hypergiant for extreme complexity
        } else if (ratio > 0.75) {
            color = "#a0c8ff"; // Blue-white dwarf (heavy addition)
        } else if (ratio < 0.35) {
            color = "#ff69b4"; // Stellar purple/pink (heavy refactoring/deletion)
        } else {
            color = "#fff8e7"; // Yellow-white main sequence
        }

        stars.push_back({x, y, brightness, starRadius, color, c});
    }

    return stars;
}

// Generates an SVG starmap string representing the compiled constellation
std::string compileToSVG(const std::vector<Star>& stars, double width, double height) {
    std::ostringstream svg;

    svg << "<svg xmlns=\"[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)\" viewBox=\"0 0 " << width << " " << height 
        << "\" width=\"100%\" height=\"100%\" style=\"background: #050510;\">\n";

    // Defs for glowing effects
    svg << "<defs>\n"
        << "  <filter id=\"glow\" x=\"-50%\" y=\"-50%\" width=\"200%\" height=\"200%\">\n"
        << "    <feGaussianBlur stdDeviation=\"4\" result=\"blur\" />\n"
        << "    <feMerge>\n"
        << "      <feMergeNode in=\"blur\" />\n"
        << "      <feMergeNode in=\"SourceGraphic\" />\n"
        << "    </feMerge>\n"
        << "  </filter>\n"
        << "</defs>\n";

    // Background cosmic dust/nebula glow
    svg << "<circle cx=\"" << width / 2.0 << "\" cy=\"" << height / 2.0 
        << "\" r=\"" << std::min(width, height) * 0.45 
        << "\" fill=\"#1a0033\" opacity=\"0.25\" filter=\"url(#glow)\" />\n";

    // Render Constellation Lines (edges connecting chronological evolution & complex nodes)
    svg << "<g stroke=\"rgba(255, 255, 255, 0.15)\" stroke-width=\"1\" stroke-dasharray=\"2,4\">\n";
    for (size_t i = 1; i < stars.size(); ++i) {
        svg << "  <line x1=\"" << stars[i-1].x << "\" y1=\"" << stars[i-1].y 
            << "\" x2=\"" << stars[i].x << "\" y2=\"" << stars[i].y << "\" />\n";
    }
    
    // Additional constellation links between high-complexity nodes
    for (size_t i = 0; i < stars.size(); ++i) {
        for (size_t j = i + 2; j < stars.size(); ++j) {
            if (stars[i].commit.cyclomaticComplexity > 12 && stars[j].commit.cyclomaticComplexity > 12) {
                double dx = stars[i].x - stars[j].x;
                double dy = stars[i].y - stars[j].y;
                if (std::sqrt(dx*dx + dy*dy) < 250.0) {
                    svg << "  <line x1=\"" << stars[i].x << "\" y1=\"" << stars[i].y 
                        << "\" x2=\"" << stars[j].x << "\" y2=\"" << stars[j].y 
                        << "\" stroke=\"rgba(160, 200, 255, 0.25)\" stroke-width=\"1.5\" />\n";
                }
            }
        }
    }
    svg << "</g>\n";

    // Render Stars (Commits)
    svg << "<g id=\"stars\">\n";
    for (const auto& star : stars) {
        // Star Outer Halo (Brightness dependent)
        svg << "  <circle cx=\"" << star.x << "\" cy=\"" << star.y 
            << "\" r=\"" << star.radius * 2.2 << "\" fill=\"" << star.color 
            << "\" opacity=\"" << star.brightness * 0.35 
            << "\" filter=\"url(#glow)\" />\n";

        // Core Star Node
        svg << "  <circle cx=\"" << star.x << "\" cy=\"" << star.y 
            << "\" r=\"" << star.radius << "\" fill=\"" << star.color 
            << "\" opacity=\"" << star.brightness << "\">\n"
            << "    <title>Commit: " << star.commit.hash << "&#10;"
            << "Author: " << star.commit.author << "&#10;"
            << "Complexity: " << star.commit.cyclomaticComplexity << "&#10;"
            << "Message: " << star.commit.message << "</title>\n"
            << "  </circle>\n";

        // Star Label / Hash Annotation for prominent nodes
        if (star.commit.cyclomaticComplexity > 10) {
            svg << "  <text x=\"" << star.x + star.radius + 5 << "\" y=\"" << star.y + 4 
                << "\" fill=\"#88aaff\" font-family=\"monospace\" font-size=\"10\" opacity=\"0.7\">"
                << star.commit.hash << " (v=" << star.commit.cyclomaticComplexity << ")</text>\n";
        }
    }
    svg << "</g>\n";

    // Title / Starmap Metadata Overlay
    svg << "<text x=\"20\" y=\"35\" fill=\"#ffffff\" font-family=\"sans-serif\" font-size=\"16\" font-weight=\"bold\">"
        << "GIT COMMIT STARMAP COMPILER</text>\n";
    svg << "<text x=\"20\" y=\"55\" fill=\"#8888aa\" font-family=\"monospace\" font-size=\"12\">"
        << "Compiled " << stars.size() << " celestial nodes from commit history</text>\n";

    svg << "</svg>\n";
    return svg.str();
}

int main() {
    const double CANVAS_WIDTH = 1000.0;
    const double CANVAS_HEIGHT = 800.0;

    std::cout << "[Git-Starmap Compiler v1.0]\n";
    std::cout << "--> Extracting git commit history & computing cyclomatic complexity metrics...\n";
    
    std::vector<Commit> history = fetchGitHistory();

    std::cout << "--> Mapping evolutionary trajectories into celestial vector space...\n";
    std::vector<Star> starmap = mapCommitsToStars(history, CANVAS_WIDTH, CANVAS_HEIGHT);

    std::cout << "--> Compiling procedural constellation SVG...\n";
    std::string svgOutput = compileToSVG(starmap, CANVAS_WIDTH, CANVAS_HEIGHT);

    const std::string filename = "starmap.svg";
    std::ofstream outFile(filename);
    if (outFile) {
        outFile << svgOutput;
        outFile.close();
        std::cout << "--> Success! Starmap compiled and saved to '" << filename << "'.\n";
    } else {
        std::cerr << "--> Error: Could not write file '" << filename << "'.\n";
        return 1;
    }

    return 0;
}