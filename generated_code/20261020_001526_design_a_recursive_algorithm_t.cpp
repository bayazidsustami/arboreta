#include <iostream>
#include <vector>
#include <string>
#include <fstream>
#include <cmath>
#include <thread>
#include <chrono>
#include <random>

// Reads live CPU temperature or simulates fluctuation if unavailable
double getCPUTemperature() {
    std::ifstream tempFile("/sys/class/thermal/thermal_zone0/temp");
    if (tempFile.is_open()) {
        double temp;
        tempFile >> temp;
        return temp / 1000.0;
    }
    static double baseTemp = 45.0;
    auto now = std::chrono::steady_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::seconds>(now.time_since_epoch()).count();
    return baseTemp + 12.0 * std::sin(duration * 0.2);
}

// Grammar rules mapping audio byte values and thermal factors to botanical structures
struct LSystemGrammar {
    std::string produce(char byte, double tempFactor) {
        if (byte < 64) {
            return (tempFactor > 1.1) ? "FF[+X][-X]F" : "F[-F]F";
        } else if (byte < 128) {
            return (tempFactor > 1.25) ? "F[+FX]--F" : "F[+F]F[-F]";
        } else if (byte < 192) {
            return "F[-X][+X]F";
        } else {
            return (tempFactor < 0.95) ? "F" : "F[+FX][-FX]F";
        }
    }
};

// Recursive algorithm mapping corrupted audio byte sequences into L-system strings
std::string expandSystem(const std::string& current, const std::vector<unsigned char>& bytes, int depth, double tempFactor, size_t& byteIndex) {
    if (depth <= 0) return current;
    std::string next = "";
    LSystemGrammar grammar;
    for (char c : current) {
        if (c == 'F' || c == 'X') {
            unsigned char b = bytes[byteIndex % bytes.size()];
            byteIndex++;
            next += grammar.produce(static_cast<char>(b), tempFactor);
        } else {
            next += c;
        }
    }
    return expandSystem(next, bytes, depth - 1, tempFactor, byteIndex);
}

// Renders the resulting plant growth and decay based on thermal health
void renderPlant(const std::string& lsysString, double healthFactor) {
    std::cout << "\033[2J\033[1;1H";
    std::cout << "=== AUDIO-BOTANICAL L-SYSTEM (Thermal Factor: " << healthFactor << "x) ===" << std::endl;
    
    int branchCount = 0;
    int leafCount = 0;
    for (char c : lsysString) {
        if (c == 'F') branchCount++;
        if (c == '+') leafCount++;
    }

    std::cout << "Complexity: " << lsysString.length() << " | Branches: " << branchCount << " | Nodes: " << leafCount << std::endl;
    std::cout << "Visual Structure:" << std::endl;

    int lineLength = 0;
    for (char c : lsysString) {
        if (c == 'F') {
            std::cout << (healthFactor > 1.15 ? "\033[32m|\033[0m" : "\033[33m~\033[0m");
            lineLength++;
        } else if (c == '+') {
            std::cout << "\033[32m*\033[0m";
        } else if (c == '-') {
            std::cout << "\033[31m-\033[0m";
        } else if (c == '[') {
            std::cout << "(";
        } else if (c == ']') {
            std::cout << ")";
        }
        if (lineLength > 75) {
            std::cout << std::endl;
            lineLength = 0;
        }
    }
    std::cout << std::endl << std::string(50, '=') << std::endl;
}

int main() {
    // Generate mock corrupted audio stream with erratic byte distributions
    std::vector<unsigned char> corruptedBytes(128);
    std::mt19937 rng(1337);
    std::uniform_int_distribution<int> dist(0, 255);
    for (auto& b : corruptedBytes) {
        b = static_cast<unsigned char>(dist(rng));
    }

    std::cout << "Booting Audio-Botanical Morphogenesis Engine..." << std::endl;

    for (int step = 0; step < 6; ++step) {
        double currentTemp = getCPUTemperature();
        double baselineTemp = 45.0;
        double tempFactor = currentTemp / baselineTemp;

        std::string axiom = "X";
        size_t byteIndex = step * 13;
        
        // Execute recursive mapping influenced by CPU thermal state
        std::string lsys = expandSystem(axiom, corruptedBytes, 3, tempFactor, byteIndex);

        // Visualize botanical growth/decay
        renderPlant(lsys, tempFactor);

        std::this_thread::sleep_for(std::chrono::seconds(1));
    }

    return 0;
}