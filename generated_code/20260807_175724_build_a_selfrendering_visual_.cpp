#include <iostream>
#include <vector>
#include <cmath>
#include <string>
#include <chrono>
#include <thread>
#include <fstream>
#include <sstream>
#include <algorithm>

#ifdef _WIN32
#include <windows.h>
#include <pdh.h>
#pragma comment(lib, "pdh.lib")
#else
#include <unistd.h>
#endif

// Platform-independent live CPU usage fetcher
float getCpuUsage() {
#ifdef _WIN32
    static PDH_HQUERY cpuQuery = NULL;
    static PDH_HCOUNTER cpuTotal = NULL;
    if (!cpuQuery) {
        PdhOpenQuery(NULL, 0, &cpuQuery);
        PdhAddEnglishCounter(cpuQuery, "\\Processor(_Total)\\% Processor Time", 0, &cpuTotal);
        PdhCollectQueryData(cpuQuery);
        return 0.0f;
    }
    PDH_FMT_COUNTERVALUE counterVal;
    PdhCollectQueryData(cpuQuery);
    PdhGetFormattedCounterValue(cpuTotal, PDH_FMT_DOUBLE, NULL, &counterVal);
    return (float)counterVal.doubleValue;
#else
    static unsigned long long prevUser = 0, prevUserNice = 0, prevSystem = 0, prevIdle = 0;
    std::ifstream statFile("/proc/stat");
    if (!statFile.is_open()) return 25.0f; // Fallback estimate

    std::string line, cpu;
    std::getline(statFile, line);
    std::istringstream ss(line);
    unsigned long long user, nice, system, idle;
    ss >> cpu >> user >> nice >> system >> idle;

    unsigned long long total = (user - prevUser) + (nice - prevUserNice) + (system - prevSystem) + (idle - prevIdle);
    unsigned long long active = total - (idle - prevIdle);

    prevUser = user; prevUserNice = nice; prevSystem = system; prevIdle = idle;
    if (total == 0) return 0.0f;
    return (float)active / total * 100.0f;
#endif
}

// Estimates AST (Abstract Syntax Tree) depth of C++ code via bracket nesting & indentation tracking
int calculateASTDepth(const std::string& sourceCode) {
    int maxDepth = 0;
    int currentDepth = 0;
    for (char c : sourceCode) {
        if (c == '{' || c == '(' || c == '<') {
            currentDepth++;
            if (currentDepth > maxDepth) maxDepth = currentDepth;
        } else if (c == '}' || c == ')' || c == '>') {
            if (currentDepth > 0) currentDepth--;
        }
    }
    return std::max(3, maxDepth + 2); // Ensure at least 3 petals for aesthetic flower rendering
}

// Terminal Canvas Renderer using ANSI Escape Sequences
int main() {
    // Sample code string acting as the self-contained target AST input
    std::string sourceCode = R"(
        template <typename T>
        auto compute_blooms(T node) {
            if constexpr (requires { node.children(); }) {
                for (auto&& child : node.children()) {
                    compute_blooms(child);
                }
            }
        }
    )";

    int petals = calculateASTDepth(sourceCode);
    const int width = 80;
    const int height = 40;
    float time = 0.0f;

    // Enable ANSI escape sequences for terminal animation
    std::cout << "\033[2J\033[?25l"; // Clear screen, hide cursor

    while (true) {
        float cpuUsage = getCpuUsage();
        // Dynamic color calculation driven by CPU usage (Hue modulation via RGB)
        float cpuNormalized = std::clamp(cpuUsage / 100.0f, 0.0f, 1.0f);
        int r = static_cast<int>(255 * (0.5f + 0.5f * std::sin(time + cpuNormalized * 6.28f)));
        int g = static_cast<int>(255 * (0.5f + 0.5f * std::cos(time * 0.7f)));
        int b = static_cast<int>(255 * (0.5f + 0.5f * std::sin(time * 1.3f + cpuNormalized * 3.14f)));

        std::string frameBuffer = "\033[H"; // Reset cursor to top-left

        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width; ++x) {
                // Normalize coordinates to [-1, 1] adjusted for aspect ratio
                float nx = (float)(x - width / 2) / (width / 4.0f);
                float ny = (float)(y - height / 2) / (height / 4.0f) * 0.5f;

                float radius = std::sqrt(nx * nx + ny * ny);
                float angle = std::atan2(ny, nx);

                // Polar equation defining the generative fractal flower shape
                float petalPattern = std::cos(petals * angle + std::sin(radius * 3.0f - time));
                float petalBoundary = 0.5f + 0.3f * petalPattern;

                // Inner fractal layers
                float core = std::abs(std::sin(radius * 8.0f - time * 2.0f));

                if (radius < petalBoundary) {
                    float charIndex = (1.0f - radius / petalBoundary) * 10.0f + core * 2.0f;
                    char chars[] = " .:-=+*#%@";
                    char symbol = chars[std::clamp((int)charIndex, 0, 9)];
                    
                    // ANSI 24-bit Truecolor formatting
                    frameBuffer += "\033[38;2;" + std::to_string(r) + ";" + 
                                  std::to_string(g) + ";" + std::to_string(b) + "m" + symbol;
                } else {
                    frameBuffer += ' ';
                }
            }
            frameBuffer += '\n';
        }

        // Display telemetry HUD overlay below the flower canvas
        frameBuffer += "\033[0m";
        frameBuffer += " [ AST Depth Petal Count: " + std::to_string(petals) + " ] ";
        frameBuffer += " [ Live CPU Usage: " + std::to_string((int)cpuUsage) + "% ]\n";

        std::cout << frameBuffer << std::flush;

        time += 0.15f;
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }

    return 0;
}