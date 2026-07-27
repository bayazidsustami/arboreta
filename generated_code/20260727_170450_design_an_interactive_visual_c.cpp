#include <iostream>
#include <vector>
#include <cmath>
#include <complex>
#include <random>
#include <thread>
#include <chrono>
#include <string>
#include <algorithm>

// Interactive ANSI Git-Fractal Ecosystem Visualizer
// Renders git graph dynamics as an evolving fractal with tectonic shifts and invasive flora.

const int WIDTH = 80;
const int HEIGHT = 40;

struct CommitNode {
    std::string hash;
    enum Type { NORMAL, REFACTOR, MERGE_CONFLICT } type;
    double weight;
};

struct FloraCell {
    int x, y;
    int age;
    char glyph;
};

class GitFractalEcosystem {
private:
    std::complex<double> c{-0.7, 0.27015}; // Julia set parameter
    double tectonicShift = 0.0;
    double zoom = 1.0;
    std::vector<FloraCell> flora;
    std::default_random_engine rng;

    // ANSI helper for RGB color string
    std::string colorRGB(int r, int g, int b) {
        return "\033[38;2;" + std::to_string(r) + ";" + std::to_string(g) + ";" + std::to_string(b) + "m";
    }

    // ANSI helper to reset styling
    std::string colorReset() {
        return "\033[0m";
    }

public:
    GitFractalEcosystem() : rng(1337) {}

    // Simulates git commit events affecting ecosystem parameters
    void processCommit(const CommitNode& commit) {
        if (commit.type == CommitNode::REFACTOR) {
            // Refactor triggers tectonic shift altering fractal topology
            tectonicShift += commit.weight * 0.15;
            c = std::complex<double>(-0.7 + 0.1 * std::cos(tectonicShift), 0.27015 + 0.1 * std::sin(tectonicShift));
            zoom += 0.05;
        } else if (commit.type == CommitNode::MERGE_CONFLICT) {
            // Merge conflict seeds invasive digital flora
            std::uniform_int_distribution<int> distX(5, WIDTH - 5);
            std::uniform_int_distribution<int> distY(5, HEIGHT - 5);
            const char floraGlyphs[] = {'@', '#', '&', '%', '*', '§', '¥'};
            for (int i = 0; i < 8; ++i) {
                flora.push_back({distX(rng), distY(rng), 0, floraGlyphs[i % 7]});
            }
        }
    }

    // Step digital flora growth outwards like invasive vines
    void updateEcosystem() {
        std::vector<FloraCell> newFlora;
        std::uniform_int_distribution<int> dir(-1, 1);
        
        for (auto& cell : flora) {
            cell.age++;
            if (cell.age < 15 && flora.size() < 300) {
                int nx = std::clamp(cell.x + dir(rng), 0, WIDTH - 1);
                int ny = std::clamp(cell.y + dir(rng), 0, HEIGHT - 1);
                newFlora.push_back({nx, ny, 0, cell.glyph});
            }
        }
        flora.insert(flora.end(), newFlora.begin(), newFlora.end());
    }

    // Render Julia fractal backdrop with overlaid invasive flora canvas
    void render(const std::string& currentStatus) {
        std::cout << "\033[H"; // Cursor home

        std::vector<std::string> screen(HEIGHT, std::string(WIDTH, ' '));
        
        // Compute Julia Fractal backdrop
        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                double zx = 1.5 * (x - WIDTH / 2.0) / (0.5 * zoom * WIDTH);
                double zy = (y - HEIGHT / 2.0) / (0.5 * zoom * HEIGHT);
                std::complex<double> z(zx, zy);
                
                int iter = 0;
                const int max_iter = 32;
                while (std::norm(z) < 4.0 && iter < max_iter) {
                    z = z * z + c;
                    iter++;
                }

                if (iter == max_iter) {
                    std::cout << colorRGB(20, 25, 45) << ".";
                } else {
                    int r = (iter * 8 + static_cast<int>(tectonicShift * 20)) % 256;
                    int g = (iter * 14) % 256;
                    int b = (255 - iter * 7) % 256;
                    std::cout << colorRGB(r, g, b) << (iter % 2 == 0 ? "~" : "^");
                }
            }
            std::cout << "\n";
        }

        // Overlay Invasive Digital Flora
        for (const auto& cell : flora) {
            std::cout << "\033[" << (cell.y + 1) << ";" << (cell.x + 1) << "H";
            int green = std::min(255, 100 + cell.age * 10);
            int red = std::min(255, 180 + cell.age * 5);
            std::cout << colorRGB(red, green, 40) << cell.glyph;
        }

        // Status banner
        std::cout << "\033[" << HEIGHT + 1 << ";1H" << colorReset();
        std::cout << "=== GIT FRACTAL ECOSYSTEM ===" << "\n";
        std::cout << "Status: " << currentStatus << " | Flora count: " << flora.size() << "      \n";
    }
};

int main() {
    // Clear screen & hide cursor
    std::cout << "\033[2J\033[?25l";

    GitFractalEcosystem ecosystem;

    std::vector<CommitNode> gitStream = {
        {"a1b2c3d", CommitNode::NORMAL, 1.0},
        {"e5f6g7h", CommitNode::REFACTOR, 2.5},
        {"i9j0k1l", CommitNode::MERGE_CONFLICT, 1.0},
        {"m2n3o4p", CommitNode::NORMAL, 1.0},
        {"q5r6s7t", CommitNode::REFACTOR, 3.1},
        {"u8v9w0x", CommitNode::MERGE_CONFLICT, 2.0},
        {"y1z2a3b", CommitNode::REFACTOR, 1.8},
        {"c4d5e6f", CommitNode::MERGE_CONFLICT, 1.5}
    };

    for (size_t i = 0; i < 60; ++i) {
        std::string status = "Evolving environment...";
        if (i % 7 == 0 && (i / 7) < gitStream.size()) {
            const auto& commit = gitStream[i / 7];
            ecosystem.processCommit(commit);
            if (commit.type == CommitNode::REFACTOR) {
                status = "TECTONIC SHIFT! Code Refactor in commit [" + commit.hash + "]";
            } else if (commit.type == CommitNode::MERGE_CONFLICT) {
                status = "INVASIVE FLORA BLOOM! Merge Conflict in commit [" + commit.hash + "]";
            } else {
                status = "Commit [" + commit.hash + "] integrated cleanly.";
            }
        }

        ecosystem.updateEcosystem();
        ecosystem.render(status);
        std::this_thread::sleep_for(std::chrono::milliseconds(150));
    }

    // Show cursor on exit
    std::cout << "\033[?25h" << colorReset() << std::endl;
    return 0;
}