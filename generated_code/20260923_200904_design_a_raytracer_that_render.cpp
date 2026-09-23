#include <iostream>
#include <string>
#include <vector>
#include <cmath>
#include <chrono>
#include <thread>
#include <algorithm>

// Procedural landscape height function modulated by time
double landscapeHeight(double x, double z, double t) {
    return std::sin(x * 0.4 + t) * std::cos(z * 0.4 + t) * 1.2 + std::sin(x * 0.2 - t * 0.3) * 0.8;
}

// Computes the local vowel frequency of a text snippet
double vowelFrequency(const std::string& s) {
    if (s.empty()) return 0.0;
    int vowels = 0;
    for (char c : s) {
        char lower = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
        if (lower == 'a' || lower == 'e' || lower == 'i' || lower == 'o' || lower == 'u') {
            vowels++;
        }
    }
    return static_cast<double>(vowels) / s.length();
}

int main() {
    const int width = 80;
    const int height = 40;
    const std::string poetry = "To see a world in a grain of sand and a heaven in a wild flower hold infinity in the palm of your hand and eternity in an hour. ";
    
    // Hide terminal cursor for smooth animation
    std::cout << "\033[?25l";

    for (int frame = 0; frame < 150; ++frame) {
        double t = frame * 0.08;
        std::string buffer = "\033[H"; // Move cursor to top-left

        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width; ++x) {
                // Screen coordinates mapped to [-1, 1]
                double u = (x - width / 2.0) / (height / 2.0);
                double v = (height / 2.0 - y) / (height / 2.0);

                // Ray generation from camera perspective
                double rx = u * 1.2;
                double rz = 2.0;
                double ry = v * 1.2;

                // Ray marching loop to intersect the landscape heightfield
                double dist = 0.0;
                bool hit = false;
                double hx = 0, hy = 0, hz = 0;

                for (int step = 0; step < 35; ++step) {
                    hx = rx * dist;
                    hy = ry * dist + 1.8; // Camera elevation
                    hz = rz * dist + 2.5; // Camera distance offset

                    double surfaceY = landscapeHeight(hx, hz, t);
                    if (hy <= surfaceY) {
                        hit = true;
                        break;
                    }
                    dist += 0.15;
                }

                if (hit) {
                    // Compute surface normal via finite differences
                    double eps = 0.01;
                    double dx = (landscapeHeight(hx + eps, hz, t) - landscapeHeight(hx - eps, hz, t)) / (2.0 * eps);
                    double dz = (landscapeHeight(hx, hz + eps, t) - landscapeHeight(hx, hz + eps, t)) / (2.0 * eps);
                    
                    double nx = -dx;
                    double ny = 1.0;
                    double nz = -dz;
                    double len = std::sqrt(nx * nx + ny * ny + nz * nz);
                    nx /= len; ny /= len; nz /= len;

                    // Directional lighting vector
                    double lx = 0.4, ly = 0.8, lz = -0.4;
                    double l_len = std::sqrt(lx * lx + ly * ly + lz * lz);
                    lx /= l_len; ly /= l_len; lz /= l_len;

                    double diffuse = std::max(0.0, nx * lx + ny * ly + nz * lz);

                    // Sample poetry text based on world coordinates and time
                    int textIdx = static_cast<int>(std::abs(hx * 4.0 + hz * 6.0 + t * 4.0)) % poetry.length();
                    std::string snippet = poetry.substr(textIdx, 4);
                    
                    // Surface lighting dynamically dictated by local vowel frequency
                    double vFreq = vowelFrequency(snippet);
                    double dynamicIntensity = diffuse * (0.3 + vFreq * 1.7);

                    // ASCII shading ramp
                    const char* ramp = " .:-=+*#%@";
                    int rampLen = 10;
                    int charIdx = static_cast<int>(dynamicIntensity * (rampLen - 1));
                    charIdx = std::clamp(charIdx, 0, rampLen - 1);

                    buffer += ramp[charIdx];
                } else {
                    buffer += ' ';
                }
            }
            buffer += '\n';
        }
        std::cout << buffer;
        std::this_thread::sleep_for(std::chrono::milliseconds(30));
    }

    // Restore terminal cursor
    std::cout << "\033[?25h";
    return 0;
}