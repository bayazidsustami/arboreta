#include <iostream>
#include <vector>
#include <string>
#include <sstream>
#include <algorithm>

// Esoteric Text Editor: Automatically refactors codebase into haikus after 3 compile failures.
class HaikuEditor {
private:
    int fail_count = 0;
    std::vector<std::string> buffer;

    // Approximate syllable count heuristic for English words
    int countSyllables(const std::string& word) {
        if (word.empty()) return 0;
        int syllables = 0;
        bool prev_vowel = false;
        std::string vowels = "aeiouyAEIOUY";
        for (char c : word) {
            bool is_vowel = (vowels.find(c) != std::string::npos);
            if (is_vowel && !prev_vowel) {
                syllables++;
            }
            prev_vowel = is_vowel;
        }
        if (!word.empty() && (word.back() == 'e' || word.back() == 'E') && syllables > 1) {
            syllables--;
        }
        return std::max(1, syllables);
    }

    // Helper to extract words and build a line matching a target syllable count (5 or 7)
    std::string buildHaikuLine(std::vector<std::string>& words, int target) {
        std::string current_line = "";
        int current_syllables = 0;
        while (!words.empty()) {
            std::string w = words.front();
            int s = countSyllables(w);
            if (current_syllables + s > target && current_syllables > 0) {
                break;
            }
            words.erase(words.begin());
            current_line += (current_line.empty() ? "" : " ") + w;
            current_syllables += s;
            if (current_syllables >= target) break;
        }
        if (current_line.empty()) current_line = "void state flows away";
        return current_line;
    }

    // Refactors code tokens into a strict 5-7-5 haiku stanza
    std::vector<std::string> refactorToHaiku(const std::vector<std::string>& code) {
        std::vector<std::string> words;
        for (const auto& line : code) {
            std::stringstream ss(line);
            std::string w;
            while (ss >> w) {
                // Filter out non-alphanumeric tokens for pure poetic flow
                std::string clean = "";
                for (char c : w) if (isalnum(c)) clean += c;
                if (!clean.empty()) words.push_back(clean);
            }
        }

        if (words.empty()) {
            return {"Code is now quite blank", "Silence fills the empty screen", "Bugs are found no more"};
        }

        std::vector<std::string> haiku;
        haiku.push_back(buildHaikuLine(words, 5));
        haiku.push_back(buildHaikuLine(words, 7));
        haiku.push_back(buildHaikuLine(words, 5));
        return haiku;
    }

public:
    void addCode(const std::string& line) {
        buffer.push_back(line);
    }

    // Simulates compilation attempt
    void compile(bool success) {
        if (success) {
            std::cout << "[Editor] Compilation successful! Failure streak reset.\n";
            fail_count = 0;
        } else {
            fail_count++;
            std::cout << "[Editor] Compilation failed! Streak: " << fail_count << "/3\n";
            if (fail_count >= 3) {
                std::cout << "\n*** ENLIGHTENMENT PROTOCOL ENGAGED ***\n";
                std::cout << "Three compilation failures detected. Converting codebase to poetry...\n\n";
                
                std::vector<std::string> new_buffer;
                while (!buffer.empty()) {
                    auto stanza = refactorToHaiku(buffer);
                    for (const auto& line : stanza) {
                        new_buffer.push_back("// " + line);
                    }
                }
                buffer = new_buffer;
                fail_count = 0;
            }
        }
    }

    void display() const {
        std::cout << "=== Codebase Buffer ===\n";
        for (size_t i = 0; i < buffer.size(); ++i) {
            std::cout << i + 1 << ": " << buffer[i] << "\n";
        }
        std::cout << "=======================\n\n";
    }
};

int main() {
    HaikuEditor editor;
    
    // Initial buggy codebase
    editor.addCode("int main() {");
    editor.addCode("    std::cout << \"Compiling is hard\";");
    editor.addCode("    syntax error here;");
    editor.addCode("    return 0;");
    editor.addCode("}");

    editor.display();

    // Triggering three consecutive failures
    editor.compile(false);
    editor.compile(false);
    editor.compile(false);

    // Displaying the refactored poetic codebase
    editor.display();

    return 0;
}