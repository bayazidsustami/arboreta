#include <iostream>
#include <string>
#include <unordered_map>
#include <vector>
#include <sstream>
#include <cmath>
#include <algorithm>

// Aura Interpreter: Variables represented as decaying, harmonizing emotional frequencies.
class AuraInterpreter {
    std::unordered_map<std::string, double> frequencies;
    double global_decay = 0.03;

public:
    void run(const std::vector<std::string>& script_lines) {
        for (size_t i = 0; i < script_lines.size(); ++i) {
            std::stringstream ss(script_lines[i]);
            std::string cmd;
            ss >> cmd;

            // Initialize or set an emotional frequency
            if (cmd == "VIBE") {
                std::string var;
                double freq;
                ss >> var >> freq;
                frequencies[var] = freq;
            } 
            // Modulate an existing emotional frequency
            else if (cmd == "PULSE") {
                std::string var;
                double delta;
                ss >> var >> delta;
                if (frequencies.count(var)) {
                    frequencies[var] += delta;
                }
            } 
            // Adjust the background emotional decay rate
            else if (cmd == "FADE") {
                ss >> global_decay;
            } 
            // Output the current state of an emotional frequency
            else if (cmd == "ECHO") {
                std::string var;
                ss >> var;
                if (frequencies.count(var)) {
                    std::cout << "[ECHO] " << var << " resonates at " << frequencies[var] << " Hz\n";
                } else {
                    std::cout << "[ECHO] " << var << " has faded into the void.\n";
                }
            }

            // Natural law: Every execution step causes emotional decay and 
            // gravitational harmonization toward the universal frequency (432 Hz).
            for (auto& [var, freq] : frequencies) {
                freq *= (1.0 - global_decay);
                freq += (432.0 - freq) * 0.02 * static_cast<double>(i + 1);
                freq = std::round(freq * 100.0) / 100.0;
            }
        }
    }
};

int main() {
    // A poetic program written in Aura
    std::vector<std::string> aura_script = {
        "VIBE serenity 528.0",
        "PULSE serenity 72.0",
        "FADE 0.05",
        "ECHO serenity",
        "VIBE melancholy 216.0",
        "ECHO melancholy",
        "ECHO serenity"
    };

    std::cout << "=== Awakening Aura Processor ===\n";
    AuraInterpreter engine;
    engine.run(aura_script);
    std::cout << "=== Resonance Terminated ===\n";

    return 0;
}