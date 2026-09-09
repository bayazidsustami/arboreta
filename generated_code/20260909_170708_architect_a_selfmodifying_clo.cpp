#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <ctime>
#include <cstdlib>
#include <thread>
#include <chrono>
#include <sstream>

// Style index mutating over time: 2
static const int STYLE_INDEX = 2;

// Visual symbol palettes that shift as the source code mutates
const std::vector<std::string> PALETTES = {
    " .:-=+*#%@",
    " ~oO0@#&%",
    " `',;:clodxkkkk",
    " .'`^\"?,!|/\\-=+"
};

const int WIDTH = 60;
const int HEIGHT = 20;

// Render digit bitmaps into the cellular automata grid
void overlayTime(std::vector<std::vector<int>>& grid, int hours, int mins, int secs) {
    char buf[16];
    snprintf(buf, sizeof(buf), "%02d:%02d:%02d", hours, mins, secs);
    std::string timeStr = buf;
    
    // Minimal 3x5 font mapping for '0'-'9' and ':'
    const std::vector<std::vector<std::string>> font = {
        {"###", "# #", "# #", "# #", "###"}, // 0
        {" # ", "## ", " # ", " # ", "###"}, // 1
        {"###", "  #", "###", "#  ", "###"}, // 2
        {"###", "  #", "###", "  #", "###"}, // 3
        {"# #", "# #", "###", "  #", "  #"}, // 4
        {"###", "#  ", "###", "  #", "###"}, // 5
        {"###", "#  ", "###", "# #", "###"}, // 6
        {"###", "  #", "  #", "  #", "  #"}, // 7
        {"###", "# #", "###", "# #", "###"}, // 8
        {"###", "# #", "###", "  #", "###"}, // 9
        {"   ", " # ", "   ", " # ", "   "}  // :
    };

    int startX = (WIDTH - (8 * 4)) / 2;
    int startY = (HEIGHT - 5) / 2;

    for (size_t c = 0; c < timeStr.length(); ++c) {
        int fontIdx = (timeStr[c] == ':') ? 10 : (timeStr[c] - '0');
        for (int r = 0; r < 5; ++r) {
            for (int col = 0; col < 3; ++col) {
                if (font[fontIdx][r][col] != ' ') {
                    int gx = startX + c * 4 + col;
                    int gy = startY + r;
                    if (gx >= 0 && gx < WIDTH && gy >= 0 && gy < HEIGHT) {
                        grid[gy][gx] = PALETTES[STYLE_INDEX % PALETTES.size()].length() - 1;
                    }
                }
            }
        }
    }
}

// Mutates the program's own source file on disk to evolve STYLE_INDEX
void selfModify(const std::string& filename) {
    std::ifstream inFile(filename);
    if (!inFile.is_open()) return;

    std::stringstream buffer;
    std::string line;
    std::string targetPrefix = "static const int STYLE_INDEX = ";

    while (std::getline(inFile, line)) {
        if (line.find(targetPrefix) != std::string::npos) {
            int currentVal = std::stoi(line.substr(targetPrefix.length()));
            int nextVal = (currentVal + 1) % 4;
            buffer << targetPrefix << nextVal << ";\n";
        } else {
            buffer << line << "\n";
        }
    }
    inFile.close();

    std::ofstream outFile(filename);
    if (outFile.is_open()) {
        outFile << buffer.str();
        outFile.close();
    }
}

int main(int argc, char* argv[]) {
    std::vector<std::vector<int>> grid(HEIGHT, std::vector<int>(WIDTH, 0));
    std::vector<std::vector<int>> nextGrid = grid;

    // Seed randomness from initial time
    std::srand(static_cast<unsigned>(std::time(nullptr)));
    for (int y = 0; y < HEIGHT; ++y) {
        for (int x = 0; x < WIDTH; ++x) {
            grid[y][x] = (std::rand() % 100 < 15) ? (std::rand() % 4) : 0;
        }
    }

    std::string palette = PALETTES[STYLE_INDEX % PALETTES.size()];
    int maxState = palette.length() - 1;

    // Run for a short frame burst per execution step
    for (int tick = 0; tick < 10; ++tick) {
        std::time_t now = std::time(nullptr);
        std::tm* localTime = std::localtime(&now);

        // Clear screen via ANSI
        std::cout << "\033[H\033[J";
        std::cout << "=== Self-Modifying Organic Clock [Style Gen: " << STYLE_INDEX << "] ===\n\n";

        // Step 1: Evolve organic cellular automata (Brian's Brain / Custom Decay rules)
        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                int neighbors = 0;
                for (int dy = -1; dy <= 1; ++dy) {
                    for (int dx = -1; dx <= 1; ++dx) {
                        if (dx == 0 && dy == 0) continue;
                        int ny = (y + dy + HEIGHT) % HEIGHT;
                        int nx = (x + dx + WIDTH) % WIDTH;
                        if (grid[ny][nx] > 0) neighbors++;
                    }
                }

                if (grid[y][x] == 0) {
                    nextGrid[y][x] = (neighbors == 2 || neighbors == 3) ? maxState : 0;
                } else {
                    nextGrid[y][x] = grid[y][x] - 1; // Organic fading
                }
            }
        }
        grid = nextGrid;

        // Step 2: Overlay current time onto the dynamic grid
        overlayTime(grid, localTime->tm_hour, localTime->tm_min, localTime->tm_sec);

        // Step 3: Render to console
        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                int charIdx = grid[y][x] % palette.length();
                std::cout << palette[charIdx];
            }
            std::cout << "\n";
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(200));
    }

    // Mutate source code file if provided as argv[0] or fallback to self.cpp
    std::string sourceFile = (argc > 0) ? argv[0] : "main.cpp";
    if (sourceFile.find(".cpp") == std::string::npos) {
        sourceFile = "main.cpp"; // Default source code name assumed for mutation
    }
    selfModify(sourceFile);

    return 0;
}