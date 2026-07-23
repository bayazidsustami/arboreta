// Esoteric Git-to-AudioVisual Cellular Automaton Compiler
// Compiles Git repository commit DAGs into a dynamic 2D cellular automaton grid
// with synthesized audio frequency waveforms and glitched harmonic dynamics.

#include <iostream>
#include <vector>
#include <string>
#include <cmath>
#include <thread>
#include <chrono>
#include <random>
#include <memory>
#include <algorithm>
#include <sstream>

// Structure representing a Git commit node in the repository DAG
struct Commit {
    std::string hash;
    std::string message;
    std::string branch;
    std::vector<std::string> parent_hashes;
    bool is_merge_conflict = false;
    bool is_orphan = false;
};

// Cellular Automaton Cell with state, audio pitch frequency, and entropy level
struct Cell {
    int state = 0;         // 0: dead, 1: commit, 2: conflict (glitch), 3: orphan (decay)
    float frequency = 440; // Frequency synthesized from commit hash
    float entropy = 0.0f;  // Decay entropy for orphan branches
};

class GitAutomatonCompiler {
private:
    static const int WIDTH = 60;
    static const int HEIGHT = 20;
    Cell grid[HEIGHT][WIDTH];
    Cell next_grid[HEIGHT][WIDTH];
    std::vector<Commit> commit_log;
    std::default_random_engine rng;

    // Hashes string commit data into initial CA seed coordinates and audio frequency
    void compile_commit_to_grid(const Commit& commit) {
        size_t hash_val = std::hash<std::string>{}(commit.hash);
        int x = hash_val % WIDTH;
        int y = (hash_val / WIDTH) % HEIGHT;
        float freq = 110.0f + static_cast<float>(hash_val % 880); // Audio pitch (Hz)

        if (commit.is_merge_conflict) {
            // Merge conflict: inject chaotic high-entropy cluster
            for (int dx = -2; dx <= 2; ++dx) {
                for (int dy = -2; dy <= 2; ++dy) {
                    int nx = (x + dx + WIDTH) % WIDTH;
                    int ny = (y + dy + HEIGHT) % HEIGHT;
                    grid[ny][nx].state = 2; // Glitch state
                    grid[ny][nx].frequency = freq * (1.0f + 0.05f * (dx + dy));
                }
            }
        } else if (commit.is_orphan) {
            // Orphan branch: inject decaying background noise seed
            grid[y][x].state = 3;
            grid[y][x].entropy = 1.0f;
            grid[y][x].frequency = 55.0f; // Low noise rumble
        } else {
            // Standard commit: plant structured seed pattern
            grid[y][x].state = 1;
            grid[y][x].frequency = freq;
            grid[(y + 1) % HEIGHT][x].state = 1;
            grid[y][(x + 1) % WIDTH].state = 1;
        }
    }

    // Counts neighboring active cells around (x, y)
    int count_neighbors(int x, int y, int target_state) {
        int count = 0;
        for (int dx = -1; dx <= 1; ++dx) {
            for (int dy = -1; dy <= 1; ++dy) {
                if (dx == 0 && dy == 0) continue;
                int nx = (x + dx + WIDTH) % WIDTH;
                int ny = (y + dy + HEIGHT) % HEIGHT;
                if (grid[ny][nx].state == target_state) count++;
            }
        }
        return count;
    }

public:
    GitAutomatonCompiler() : rng(1337) {
        // Initialize grid
        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                grid[y][x] = Cell{0, 440.0f, 0.0f};
            }
        }
    }

    // Build mock Git repo history with commits, merge conflicts, and orphan branches
    void load_synthetic_git_history() {
        commit_log = {
            {"a1b2c3d", "Initial commit", "main", {}},
            {"e5f6g7h", "Add core engine", "main", {"a1b2c3d"}},
            {"i8j9k0l", "Feature branch start", "feature/audio", {"e5f6g7h"}},
            {"m1n2o3p", "Orphan patch experiments", "orphan/decay", {}, false, true},
            {"q4r5s6t", "Conflict commit A", "main", {"e5f6g7h"}},
            {"u7v8w9x", "Conflict commit B", "feature/audio", {"i8j9k0l"}},
            {"y0z1a2b", "CRITICAL MERGE CONFLICT", "main", {"q4r5s6t", "u7v8w9x"}, true, false},
            {"c3d4e5f", "Orphan branch abandoned", "orphan/decay", {"m1n2o3p"}, false, true},
            {"g6h7i8j", "Post-merge refactor", "main", {"y0z1a2b"}}
        };
    }

    // Update CA state with esoteric rules influenced by Git repo semantics
    void step(int step_num) {
        // Compile new commit into automaton every few steps
        if (step_num < static_cast<int>(commit_log.size())) {
            compile_commit_to_grid(commit_log[step_num]);
        }

        std::uniform_real_distribution<float> dist(0.0f, 1.0f);

        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                int active_neighbors = count_neighbors(x, y, 1);
                int glitch_neighbors = count_neighbors(x, y, 2);
                int orphan_neighbors = count_neighbors(x, y, 3);

                Cell current = grid[y][x];
                Cell& next = next_grid[y][x];
                next = current;

                if (glitch_neighbors > 0) {
                    // Merge conflict rule: Chaotic bitwise transformation & frequency shift
                    next.state = (current.state ^ glitch_neighbors) % 4;
                    next.frequency = current.frequency * 1.05f + (dist(rng) * 50.0f - 25.0f);
                } else if (current.state == 3 || orphan_neighbors > 2) {
                    // Orphan branch rule: Decay into procedural background noise entropy
                    next.entropy += 0.15f;
                    if (next.entropy > 1.0f) {
                        next.state = 0; // Dissipates to void
                        next.entropy = 0.0f;
                    } else {
                        next.state = 3;
                        next.frequency = 40.0f + dist(rng) * 60.0f; // Low noise
                    }
                } else if (current.state == 1) {
                    // Normal commit rule (Conway-like harmonic pulse)
                    if (active_neighbors < 2 || active_neighbors > 3) next.state = 0;
                    else next.state = 1;
                } else {
                    if (active_neighbors == 3) {
                        next.state = 1;
                        next.frequency = 220.0f + active_neighbors * 110.0f;
                    }
                }
            }
        }

        // Swap buffers
        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                grid[y][x] = next_grid[y][x];
            }
        }
    }

    // Render cellular automaton grid and synthesized audio harmonic waveforms to terminal
    void render(int step_num) {
        // Clear screen (ANSI escape)
        std::cout << "\033[H\033[J";
        std::cout << "=== GIT COMMIT ESOTERIC AUDIO-VISUAL COMPILER ===" << std::endl;
        if (step_num < static_cast<int>(commit_log.size())) {
            const auto& c = commit_log[step_num];
            std::cout << "Compiling Commit [" << c.hash << "] Branch: " << c.branch 
                      << " | Msg: " << c.message;
            if (c.is_merge_conflict) std::cout << " \033[31m[MERGE CONFLICT DETECTED]\033[0m";
            if (c.is_orphan) std::cout << " \033[33m[ORPHAN BRANCH DECAY]\033[0m";
            std::cout << std::endl;
        } else {
            std::cout << "Automaton Running... (Free Evolution Phase)" << std::endl;
        }
        std::cout << "------------------------------------------------------------" << std::endl;

        float active_freq_sum = 0.0f;
        int active_cells = 0;

        // Render visual grid
        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                Cell c = grid[y][x];
                if (c.state == 1) {
                    std::cout << "\033[32m#\033[0m"; // Normal commit cell (Green)
                    active_freq_sum += c.frequency;
                    active_cells++;
                } else if (c.state == 2) {
                    std::cout << "\033[31m!\033[0m"; // Glitched merge conflict cell (Red)
                    active_freq_sum += c.frequency * 1.5f; // Disharmonic frequency shift
                    active_cells++;
                } else if (c.state == 3) {
                    std::cout << "\033[33m~\033[0m"; // Orphan branch noise cell (Yellow)
                    active_freq_sum += c.frequency;
                    active_cells++;
                } else {
                    std::cout << " "; // Empty void
                }
            }
            std::cout << "\n";
        }

        // Synthesize and visualize dynamic audio waveform based on CA grid frequencies
        float avg_freq = active_cells > 0 ? (active_freq_sum / active_cells) : 0.0f;
        std::cout << "------------------------------------------------------------" << std::endl;
        std::cout << "Synthesized Audio Output | Dominant Frequency: " << static_cast<int>(avg_freq) << " Hz" << std::endl;
        std::cout << "Oscilloscope Waveform: ";

        for (int i = 0; i < 40; ++i) {
            float sample = std::sin(0.1f * i + step_num * 0.5f + (avg_freq / 100.0f));
            if (avg_freq > 600.0f) sample += (rand() % 100 / 200.0f) - 0.25f; // Glitch noise
            if (sample > 0.5f) std::cout << "^";
            else if (sample < -0.5f) std::cout << "_";
            else std::cout << "~";
        }
        std::cout << " [Audio Stream Active]" << std::endl;
    }
};

int main() {
    GitAutomatonCompiler compiler;
    compiler.load_synthetic_git_history();

    // Simulation run loop
    for (int step = 0; step < 40; ++step) {
        compiler.render(step);
        compiler.step(step);
        std::this_thread::sleep_for(std::chrono::milliseconds(250));
    }

    std::cout << "\nCompilation and execution complete." << std::endl;
    return 0;
}