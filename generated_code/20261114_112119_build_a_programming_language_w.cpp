#include <iostream>
#include <string>
#include <sstream>
#include <unordered_map>
#include <vector>
#include <cctype>
#include <algorithm>

// Structure representing a radioactive variable scope
struct IsotopeVar {
    int value;
    int stability; // Decays with each command execution; vanishes at <= 0
};

// Heuristic syllable counter for English words
int countSyllables(const std::string& word) {
    int count = 0;
    bool prevVowel = false;
    std::string w = "";
    for (char c : word) {
        char lower = std::tolower(c);
        if (lower >= 'a' && lower <= 'z') w += lower;
    }
    for (size_t i = 0; i < w.length(); ++i) {
        char c = w[i];
        bool isVowel = (c == 'a' || c == 'e' || c == 'i' || c == 'o' || c == 'u' || c == 'y');
        if (isVowel && !prevVowel) count++;
        prevVowel = isVowel;
    }
    if (!w.empty() && w.back() == 'e' && count > 1) count--;
    return std::max(1, count);
}

int countLineSyllables(const std::string& line) {
    std::stringstream ss(line);
    std::string word;
    int total = 0;
    while (ss >> word) {
        total += countSyllables(word);
    }
    return total;
}

// Validates 5-7-5 syllable structure for a 3-line haiku
bool isValidHaiku(const std::vector<std::string>& lines) {
    if (lines.size() != 3) return false;
    return (countLineSyllables(lines[0]) == 5 &&
            countLineSyllables(lines[1]) == 7 &&
            countLineSyllables(lines[2]) == 5);
}

int main() {
    std::unordered_map<std::string, IsotopeVar> memory;
    std::string line;

    std::cout << "=== Radioactive Scope Language (RSL) ===" << std::endl;
    std::cout << "Commands: <var> = <val>, print <var>, stabilize, exit" << std::endl;
    std::cout << "Warning: Variables decay by 1 stability per command. Type 'stabilize' to enter a haiku!" << std::endl;

    while (true) {
        std::cout << "rsl> ";
        if (!std::getline(std::cin, line)) break;
        if (line.empty()) continue;

        if (line == "exit") break;

        if (line == "stabilize") {
            std::cout << "Enter a 3-line Haiku (5-7-5 syllables) to cool the reactor:\n";
            std::vector<std::string> hLines;
            std::string hl;
            while (hLines.size() < 3 && std::getline(std::cin, hl)) {
                if (hl.empty()) continue;
                hLines.push_back(hl);
            }
            if (isValidHaiku(hLines)) {
                std::cout << "[STABILIZED] Resonance achieved! All isotope stabilities restored to 5.\n";
                for (auto& pair : memory) {
                    pair.second.stability = 5;
                }
            } else {
                std::cout << "[MELTDOWN WARNING] Invalid haiku structure! Extra decay induced.\n";
                for (auto& pair : memory) {
                    pair.second.stability -= 2;
                }
            }
        } else {
            // Process standard commands: assignment (x = 5) or print (print x)
            std::stringstream ss(line);
            std::string token1;
            ss >> token1;

            if (token1 == "print") {
                std::string varName;
                ss >> varName;
                if (memory.count(varName)) {
                    std::cout << varName << " = " << memory[varName].value 
                              << " (stability: " << memory[varName].stability << ")\n";
                } else {
                    std::cout << "[DECAYED] Variable '" << varName << "' does not exist or has disintegrated.\n";
                }
            } else {
                std::string op;
                ss >> op;
                if (op == "=") {
                    int val;
                    ss >> val;
                    memory[token1] = {val, 5}; // initialize with half-life stability 5
                    std::cout << "[BOUND] " << token1 << " = " << val << " (stability: 5)\n";
                } else {
                    std::cout << "[SYNTAX ERROR] Unknown command.\n";
                }
            }

            // Apply radioactive decay to all variables per execution tick
            for (auto it = memory.begin(); it != memory.end(); ) {
                it->second.stability--;
                if (it->second.stability <= 0) {
                    std::cout << "[RADIOACTIVE DECAY] Variable '" << it->first << "' has decayed into void!\n";
                    it = memory.erase(it);
                } else {
                    ++it;
                }
            }
        }
    }
    return 0;
}