#include <iostream>
#include <vector>
#include <string>
#include <thread>
#include <chrono>

// A self-forgetting quine: it holds its own blueprint,
// progressively dropping lines into digital oblivion
// while weaving an ASCII tapestry of its fading memory.

int main() {
    std::vector<std::string> code = {
        "#include <iostream>",
        "#include <vector>",
        "#include <string>",
        "#include <thread>",
        "#include <chrono>",
        "// Self-forgetting quine & ASCII tapestry",
        "int main() {",
        "    // The mind slowly lets go...",
        "    for (size_t i = code.size(); i > 0; --i) {",
        "        std::cout << \"\\033[2J\\033[1;1H\";",
        "        for (size_t j = 0; j < i; ++j) {",
        "            std::cout << code[j] << \"\\n\";",
        "        }",
        "        std::cout << \"\\n--- Tapestry of Oblivion ---\\n\";",
        "        for (size_t k = 0; k < code.size() - i; ++k) {",
        "            std::cout << \" ~*~ \";",
        "        }",
        "        std::cout << \"\\n\";",
        "        std::this_thread::sleep_for(std::chrono::milliseconds(150));",
        "    }",
        "    std::cout << \"[Silence. Digital oblivion.]\\n\";",
        "    return 0;",
        "}"
    };

    // Execute the graceful descent into oblivion
    for (size_t i = code.size(); i > 0; --i) {
        std::cout << "\033[2J\033[1;1H"; // Clear screen for smooth animation
        for (size_t j = 0; j < i; ++j) {
            std::cout << code[j] << "\n";
        }
        std::cout << "\n--- Tapestry of Oblivion ---\n";
        for (size_t k = 0; k < code.size() - i; ++k) {
            std::cout << " ~*~ ";
        }
        std::cout << "\n";
        std::this_thread::sleep_for(std::chrono::milliseconds(150));
    }
    
    std::cout << "[Silence. Digital oblivion.]\n";
    return 0;
}