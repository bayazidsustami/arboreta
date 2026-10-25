#include <iostream>
#include <vector>
#include <cmath>
#include <thread>
#include <chrono>
#include <random>
#include <fstream>
#include <sstream>
#include <string>

// Structure representing a tree in the forest, generated from a prime number
struct Tree {
    int id;               // The prime number
    int height;           // Height of the tree based on prime magnitude
    int branchCount;      // Number of branches derived from factor complexity
    double baseSway;      // Individual phase offset for wind resonance
};

// Cross-platform network traffic sampler to determine live wind direction
double getLiveNetworkTraffic() {
#if defined(_WIN32)
    // Fallback or basic simulation for Windows if specific iphlpapi is omitted for single-file portability
    static long long lastBytes = 0;
    long long currentBytes = lastBytes + 1024 + (rand() % 4096); 
    double delta = static_cast<double>(currentBytes - lastBytes);
    lastBytes = currentBytes;
    return delta;
#else
    // Linux /proc/net/dev reader for actual live local network traffic
    std::ifstream netdev("/proc/net/dev");
    if (!netdev.is_open()) return 50.0;
    
    std::string line;
    long long totalBytes = 0;
    // Skip header lines
    std::getline(netdev, line);
    std::getline(netdev, line);
    while (std::getline(netdev, line)) {
        std::istringstream iss(line);
        std::string interfaceName;
        iss >> interfaceName;
        if (interfaceName.find("lo") == 0) continue; // Skip loopback
        long long rxBytes, txBytes;
        char colon;
        iss >> rxBytes >> colon;
        // Skip some fields to get to tx bytes
        for (int i = 0; i < 7; ++i) { long long dummy; iss >> dummy; }
        iss >> txBytes;
        totalBytes += (rxBytes + txBytes);
    }
    
    static long long previousBytes = totalBytes;
    double delta = static_cast<double>(totalBytes - previousBytes);
    previousBytes = totalBytes;
    return delta < 0 ? 100.0 : delta;
#endif
}

// Check if a number is prime
bool isPrime(int n) {
    if (n <= 1) return false;
    if (n <= 3) return true;
    if (n % 2 == 0 || n % 3 == 0) return false;
    for (int i = 5; i * i <= n; i += 6) {
        if (n % i == 0 || n % (i + 2) == 0) return false;
    }
    return true;
}

// Count divisors/factors to determine branch complexity
int getFactorComplexity(int n) {
    int count = 0;
    for (int i = 1; i <= sqrt(n); ++i) {
        if (n % i == 0) {
            count += (i * i == n) ? 1 : 2;
        }
    }
    return count;
}

int main() {
    // Hide cursor & clear screen for rendering engine loop
    std::cout << "\033[?25l\033[2J";

    const int forestWidth = 70;
    const int forestHeight = 20;
    
    // Generate prime number sequence for the forest
    std::vector<Tree> forest;
    int candidatePrimes[] = {3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73};
    
    for (int i = 0; i < 10; ++i) {
        int p = candidatePrimes[i % 20];
        Tree t;
        t.id = p;
        t.height = 4 + (p % 6);
        t.branchCount = getFactorComplexity(p + 1); // Factors of neighborhood reflect branch divergence
        t.baseSway = i * 0.5;
        forest.push_back(t);
    }

    int frame = 0;
    while (frame < 150) { // Run for 150 frames as a demo loop
        // Sample live local network traffic to dictate wind velocity and direction
        double netTraffic = getLiveNetworkTraffic();
        double windForce = std::sin(frame * 0.2) * (1.0 + std::log10(netTraffic + 1.0) * 0.5);

        // Render buffer
        std::vector<std::string> screen(forestHeight, std::string(forestWidth, ' '));

        // Draw ground
        for (int x = 0; x < forestWidth; ++x) {
            screen[forestHeight - 1][x] = '_';
        }

        // Procedurally render each prime tree
        int spacing = forestWidth / (forest.size() + 1);
        for (size_t i = 0; i < forest.size(); ++i) {
            const auto& tree = forest[i];
            int rootX = spacing * (i + 1);
            int rootY = forestHeight - 1;

            // Draw trunk with wind sway effect
            for (int h = 0; h < tree.height; ++h) {
                int currentY = rootY - 1 - h;
                int offset = static_cast<int>(std::round(windForce * (static_cast<double>(h) / tree.height)));
                int currentX = rootX + offset;

                if (currentX >= 0 && currentX < forestWidth && currentY >= 0 && currentY < forestHeight) {
                    screen[currentY][currentX] = '|';

                    // Procedurally attach branches based on factor complexity
                    if (h > 1 && h % 2 == 0 && (h / 2) <= tree.branchCount) {
                        int leftBranchX = currentX - 1;
                        int rightBranchX = currentX + 1;
                        if (leftBranchX >= 0) screen[currentY][leftBranchX] = '/';
                        if (rightBranchX < forestWidth) screen[currentY][rightBranchX] = '\\';
                    }
                }
            }

            // Crown of the tree (Prime foliage marker '*')
            int crownY = rootY - 1 - tree.height;
            int crownX = rootX + static_cast<int>(std::round(windForce));
            if (crownX >= 0 && crownX < forestWidth && crownY >= 0 && crownY < forestHeight) {
                screen[crownY][crownX] = '*';
            }
        }

        // Output frame to console with ANSI home escape sequence
        std::string frameBuffer = "\033[H";
        frameBuffer += "=== PRIME OVERGROWN FOREST RENDERER (Live Net Wind: " + std::to_string(netTraffic) + " B/s) ===\n";
        for (const auto& row : screen) {
            frameBuffer += row + "\n";
        }
        std::cout << frameBuffer << std::flush;

        std::this_thread::sleep_for(std::chrono::milliseconds(100));
        ++frame;
    }

    // Restore cursor
    std::cout << "\033[?25h";
    return 0;
}