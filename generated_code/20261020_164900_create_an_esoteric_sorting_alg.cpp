#include <iostream>
#include <vector>
#include <cmath>
#include <thread>
#include <chrono>
#include <algorithm>

// Clears the terminal screen for smooth frame-by-frame ASCII animation
void clearScreen() {
    std::cout << "\033[2J\033[H";
}

int main() {
    // Unsorted cosmic array representing star masses/coordinates
    std::vector<int> stars = {18, 5, 23, 11, 29, 2, 14, 25, 8, 20, 12, 27, 4, 16, 9};
    int n = stars.size();
    
    const int width = 64;
    const int height = 22;

    bool swapped = true;
    while (swapped) {
        swapped = false;
        for (int i = 0; i < n - 1; ++i) {
            // Render current constellation state
            clearScreen();
            std::cout << "=== GRAVITATIONAL CONSTELLATION SORTING ENGINE ===\n";
            
            std::vector<std::string> grid(height, std::string(width, ' '));

            // Plot each star onto the celestial grid
            for (int j = 0; j < n; ++j) {
                int x = 4 + j * (width - 8) / std::max(1, n - 1);
                int y = height - 2 - (stars[j] * (height - 4) / 32);
                
                if (x >= 0 && x < width && y >= 0 && y < height) {
                    if (j == i || j == i + 1) {
                        grid[y][x] = 'O'; // Active interacting binary stars
                    } else {
                        grid[y][x] = '.'; // Ambient starlight
                    }
                }
            }

            // Draw space boundary box
            std::cout << "+" << std::string(width, '-') << "+\n";
            for (const auto& row : grid) {
                std::cout << "|" << row << "|\n";
            }
            std::cout << "+" << std::string(width, '-') << "+\n";
            
            bool collision = (stars[i] > stars[i + 1]);
            std::cout << "Sector [" << i << "-" << i+1 << "] Status: " 
                      << (collision ? "COLLISION DETECTED (Mass Discrepancy)" : "Stable Orbit") << "\n";

            std::this_thread::sleep_for(std::chrono::milliseconds(120));

            // If out of order, trigger a gravitational anomaly and swap
            if (collision) {
                std::swap(stars[i], stars[i + 1]);
                swapped = true;
                
                // Render spatial distortion wave (gravitational anomaly)
                clearScreen();
                std::cout << "=== GRAVITATIONAL ANOMALY DISTORTION PULSE ===\n";
                std::vector<std::string> warpGrid(height, std::string(width, '~'));
                for (int r = 0; r < height; ++r) {
                    std::cout << "|" << warpGrid[r] << "|\n";
                }
                std::this_thread::sleep_for(std::chrono::milliseconds(80));
            }
        }
    }

    // Final triumphant visualization
    clearScreen();
    std::cout << "Constellation fully aligned in harmonious equilibrium!\n";
    std::cout << "Final Sorted Mass Signature: [ ";
    for (int val : stars) std::cout << val << " ";
    std::cout << "]\n";

    return 0;
}