/*
 * Esoteric Lisp-Driven Musical Cellular Automaton (Lisp-Fugue Engine)
 *
 * Each cell in a 2D grid contains a miniature S-expression (Lisp) interpreter
 * and a code string. At each tick, cells evaluate their own and neighbors' code
 * under counterpoint and music theory constraints (consonance, voice leading, fugue subject imitation)
 * to generate a continuously evolving polyphonic fugue rendered to the terminal screen.
 */

#include <iostream>
#include <vector>
#include <string>
#include <sstream>
#include <memory>
#include <map>
#include <cmath>
#include <random>
#include <thread>
#include <chrono>

// Minimal Lisp AST Node and Evaluator
struct SExpr {
    std::string val;
    std::vector<SExpr> children;
    bool is_list = false;
};

SExpr parse_lisp(const std::string& code, size_t& pos) {
    while (pos < code.length() && (code[pos] == ' ' || code[pos] == '\n' || code[pos] == '\t')) pos++;
    SExpr node;
    if (pos >= code.length()) return node;
    
    if (code[pos] == '(') {
        node.is_list = true;
        pos++; // skip '('
        while (pos < code.length()) {
            while (pos < code.length() && (code[pos] == ' ' || code[pos] == '\n' || code[pos] == '\t')) pos++;
            if (pos < code.length() && code[pos] == ')') { pos++; break; }
            node.children.push_back(parse_lisp(code, pos));
        }
    } else {
        node.is_list = false;
        size_t start = pos;
        while (pos < code.length() && code[pos] != ' ' && code[pos] != ')' && code[pos] != '(' && code[pos] != '\n') pos++;
        node.val = code.substr(start, pos - start);
    }
    return node;
}

int eval(const SExpr& node, const std::map<std::string, int>& env) {
    if (!node.is_list) {
        if (node.val.empty()) return 0;
        if (env.count(node.val)) return env.at(node.val);
        try { return std::stoi(node.val); } catch (...) { return 0; }
    }
    if (node.children.empty()) return 0;
    
    std::string op = node.children[0].val;
    if (op == "+") {
        int res = 0;
        for (size_t i = 1; i < node.children.size(); ++i) res += eval(node.children[i], env);
        return res;
    } else if (op == "-") {
        if (node.children.size() < 2) return 0;
        int res = eval(node.children[1], env);
        for (size_t i = 2; i < node.children.size(); ++i) res -= eval(node.children[i], env);
        return res;
    } else if (op == "mod") {
        int a = node.children.size() > 1 ? eval(node.children[1], env) : 0;
        int b = node.children.size() > 2 ? eval(node.children[2], env) : 1;
        return b == 0 ? 0 : (a % b + b) % b;
    } else if (op == "if") {
        int cond = node.children.size() > 1 ? eval(node.children[1], env) : 0;
        if (cond != 0) return node.children.size() > 2 ? eval(node.children[2], env) : 0;
        else return node.children.size() > 3 ? eval(node.children[3], env) : 0;
    } else if (op == "consonance") {
        // Evaluate music theory constraint: check interval quality (0, 3, 4, 7, 8, 9, 12 are consonant)
        int p1 = node.children.size() > 1 ? eval(node.children[1], env) : 0;
        int p2 = node.children.size() > 2 ? eval(node.children[2], env) : 0;
        int diff = std::abs(p1 - p2) % 12;
        return (diff == 0 || diff == 3 || diff == 4 || diff == 7 || diff == 8 || diff == 9) ? 1 : 0;
    } else if (op == "transpose") {
        int pitch = node.children.size() > 1 ? eval(node.children[1], env) : 0;
        int interval = node.children.size() > 2 ? eval(node.children[2], env) : 0;
        return pitch + interval;
    }
    return 0;
}

std::string pitch_to_name(int pitch) {
    static const std::string names[] = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"};
    int note = (pitch % 12 + 12) % 12;
    int octave = (pitch / 12) - 1;
    return names[note] + std::to_string(octave);
}

// Cell structure for automaton
struct Cell {
    std::string lisp_code;
    int current_pitch = 60; // MIDI C4
    int voice_role = 0;    // 0: Bass, 1: Tenor, 2: Alto, 3: Soprano
};

const int GRID_W = 4;
const int GRID_H = 4;

int main() {
    std::vector<Cell> grid(GRID_W * GRID_H);
    std::mt19937 rng(42);

    // Initial Lisp code templates encoding counterpoint constraints and melodic motifs
    std::vector<std::string> templates = {
        "(+ self_pitch (if (consonance self_pitch neighbor_pitch) 2 (- 1)))",
        "(mod (+ self_pitch (transpose neighbor_code_len 5)) 24)",
        "(+ 48 (mod (+ self_pitch neighbor_pitch) 36))",
        "(if (consonance self_pitch 60) (+ self_pitch 7) (- self_pitch 5))"
    };

    for (int i = 0; i < GRID_W * GRID_H; ++i) {
        grid[i].lisp_code = templates[i % templates.size()];
        grid[i].current_pitch = 36 + (i * 5) % 48; // Distribute across registers
        grid[i].voice_role = i % 4;
    }

    // Terminal fugue score header
    std::cout << "\033[2J\033[H"; // Clear screen
    std::cout << "=== ESOTERIC LISP CELLULAR AUTOMATON FUGUE ENGINE ===\n";
    std::cout << "Evaluating cell Lisp source code under counterpoint rules...\n\n";

    int measure = 1;
    while (true) {
        std::vector<Cell> next_grid = grid;
        std::vector<int> current_voices(4, 0);

        for (int y = 0; y < GRID_H; ++y) {
            for (int x = 0; x < GRID_W; ++x) {
                int idx = y * GRID_W + x;
                
                // Neighbor constraint from surrounding cells
                int neighbor_idx = ((y + 1) % GRID_H) * GRID_W + ((x + 1) % GRID_W);
                int neighbor_pitch = grid[neighbor_idx].current_pitch;
                int neighbor_code_len = (int)grid[neighbor_idx].lisp_code.length();

                std::map<std::string, int> env = {
                    {"self_pitch", grid[idx].current_pitch},
                    {"neighbor_pitch", neighbor_pitch},
                    {"neighbor_code_len", neighbor_code_len},
                    {"tick", measure}
                };

                size_t pos = 0;
                SExpr ast = parse_lisp(grid[idx].lisp_code, pos);
                int new_pitch = eval(ast, env);

                // Keep pitch in musical range [36, 84] (C2 to C6)
                if (new_pitch < 36) new_pitch = 36 + (std::abs(new_pitch) % 24);
                if (new_pitch > 84) new_pitch = 60 + (new_pitch % 24);

                next_grid[idx].current_pitch = new_pitch;

                // Mutate source code based on harmonic consonance feedback
                size_t c_pos = 0;
                SExpr check_ast = parse_lisp("(consonance self_pitch neighbor_pitch)", c_pos);
                if (!eval(check_ast, env)) {
                    // Dissonance detected: evolve Lisp code constraint
                    if (rng() % 2 == 0) {
                        next_grid[idx].lisp_code = "(+ self_pitch (if (consonance self_pitch neighbor_pitch) 7 (- 5)))";
                    } else {
                        next_grid[idx].lisp_code = "(transpose neighbor_pitch " + std::to_string((static_cast<int>(rng() % 7)) - 3) + ")";
                    }
                }

                current_voices[grid[idx].voice_role] = new_pitch;
            }
        }

        grid = next_grid;

        // Render Fugue Counterpoint State
        std::cout << "\033[H\033[K";
        std::cout << "--- MEASURE " << measure << " ---\n";
        
        // Render Voices (Bass, Tenor, Alto, Soprano)
        const char* voice_names[] = {"Soprano", "Alto   ", "Tenor  ", "Bass   "};
        for (int v = 3; v >= 0; --v) {
            std::cout << voice_names[3 - v] << " | " << pitch_to_name(current_voices[v]) << "\t[";
            int dots = (current_voices[v] - 36) / 2;
            for (int d = 0; d < 25; ++d) {
                std::cout << (d == dots ? "O" : "-");
            }
            std::cout << "]\n";
        }

        // Render Grid Code Snapshot
        std::cout << "\nCell Automaton Lisp Code Grid:\n";
        for (int y = 0; y < GRID_H; ++y) {
            for (int x = 0; x < GRID_W; ++x) {
                std::string code = grid[y * GRID_W + x].lisp_code;
                if (code.length() > 22) code = code.substr(0, 19) + "...";
                std::cout << "[" << code << "]\t";
            }
            std::cout << "\n";
        }

        std::cout << "\n(Press Ctrl+C to exit)\n" << std::flush;

        std::this_thread::sleep_for(std::chrono::milliseconds(300));
        measure++;
    }

    return 0;
}