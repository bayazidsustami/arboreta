#include <iostream>
#include <vector>
#include <string>
#include <cmath>
#include <fstream>
#include <algorithm>

// Structure representing a crystal seed generated from a line of poetry
struct Seed {
    double x, y;
    double r, g, b;
    double growth_rate;
};

int main() {
    // Abstract poetry input where line breaks dictate growth characteristics
    std::vector<std::string> poem = {
        "Silent algorithms weave the dark,",
        "Crystalline thoughts ignite a spark,",
        "Time fractures into glowing glass,",
        "As endless iterations pass."
    };

    const int width = 500;
    const int height = 500;

    std::vector<Seed> seeds;
    for (size_t i = 0; i < poem.size(); ++i) {
        const std::string& line = poem[i];
        
        // Derive unique color palette from the character values of the line
        double r = 0, g = 0, b = 0;
        for (char c : line) {
            r += c * 17;
            g += c * 31;
            b += c * 47;
        }
        r = std::fmod(r, 256);
        g = std::fmod(g, 256);
        b = std::fmod(b, 256);

        // Line break and length dictate the cellular growth rate
        double growth = 0.6 + (static_cast<double>(line.length()) / 12.0);

        // Position seed points dynamically across the canvas based on index
        double cx = width * (0.25 + 0.5 * (static_cast<double>(i) / std::max(1.0, static_cast<double>(poem.size() - 1))));
        double cy = height * (0.25 + 0.4 * std::sin(i * 1.57));
        
        seeds.push_back({cx, cy, r, g, b, growth});
    }

    // Output a self-rendering PPM image file representing the poetry-driven Voronoi diagram
    std::ofstream ppm("poetry_voronoi.ppm");
    ppm << "P3\n" << width << " " << height << "\n255\n";

    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            double min_dist = 1e9;
            int closest_seed = 0;

            for (size_t i = 0; i < seeds.size(); ++i) {
                // Compute distance weighted inversely by the growth rate of the poetry line
                double dx = x - seeds[i].x;
                double dy = y - seeds[i].y;
                double dist = std::sqrt(dx * dx + dy * dy) / seeds[i].growth_rate;
                
                // Add harmonic crystalline distortion to simulate natural crystal facets
                dist += std::sin(x * 0.04 + i) * std::cos(y * 0.04 + i) * 6.0;

                if (dist < min_dist) {
                    min_dist = dist;
                    closest_seed = i;
                }
            }

            // Shade pixel based on closest seed color and crystalline distance gradients
            const auto& s = seeds[closest_seed];
            int pr = static_cast<int>(s.r + std::fmod(min_dist, 40));
            int pg = static_cast<int>(s.g + std::fmod(min_dist * 0.7, 40));
            int pb = static_cast<int>(s.b + std::fmod(min_dist * 1.3, 40));

            pr = std::min(255, std::max(0, pr));
            pg = std::min(255, std::max(0, pg));
            pb = std::min(255, std::max(0, pb));

            ppm << pr << " " << pg << " " << pb << "\n";
        }
    }

    std::cout << "Poetry successfully compiled into poetry_voronoi.ppm\n";
    return 0;
}