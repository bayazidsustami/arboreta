/*
 * TetrisGC: A Recursive Interpreter with Memory Layout Rendered as a Playable Tetris Engine
 *
 * Concepts:
 * - A recursive AST interpreter evaluating Lisp-like expressions (Fibonacci, Factorial, etc.).
 * - Memory allocations (heap blocks) are shaped like Tetris polyominos falling into a 10x20 grid memory space.
 * - Interactive controls allow shifting (A/D), rotating (W), or dropping (S) currently allocating heap blocks.
 * - Garbage Collection: Triggered periodically via Mark-and-Sweep. If a completed horizontal line on the 
 *   Tetris grid consists ENTIRELY of unreachable garbage memory blocks, GC clears the line and drops upper memory down!
 */

#include <iostream>
#include <vector>
#include <string>
#include <memory>
#include <thread>
#include <chrono>
#include <deque>
#include <random>
#include <algorithm>
#include <termios.h>
#include <unistd.h>
#include <fcntl.h>

constexpr int BOARD_WIDTH = 10;
constexpr int BOARD_HEIGHT = 20;

// Terminal Non-blocking Input Setup
struct TerminalSettings {
    termios orig_termios;
    TerminalSettings() {
        tcgetattr(STDIN_FILENO, &orig_termios);
        termios raw = orig_termios;
        raw.c_lflag &= ~(ECHO | ICANON);
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
        int flags = fcntl(STDIN_FILENO, F_GETFL, 0);
        fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK);
    }
    ~TerminalSettings() {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios);
    }
};

// Heap Cell Representation
struct Cell {
    bool occupied = false;
    bool marked = false;     // Marked during GC reachability phase
    char symbol = '.';       // Visual identifier
    int block_id = 0;        // Unique block tracking ID
};

// Polyomino shape templates (Tetris pieces representing AST Node Allocations)
const std::vector<std::vector<std::vector<int>>> SHAPES = {
    {{1, 1, 1, 1}},                         // I
    {{1, 1}, {1, 1}},                       // O
    {{0, 1, 0}, {1, 1, 1}},                 // T
    {{1, 0, 0}, {1, 1, 1}},                 // L
    {{0, 0, 1}, {1, 1, 1}},                 // J
    {{0, 1, 1}, {1, 1, 0}},                 // S
    {{1, 1, 0}, {0, 1, 1}}                  // Z
};

struct Piece {
    std::vector<std::vector<int>> shape;
    int x, y;
    int id;
    char symbol;
};

// Interpreter AST Node & Values
enum class NodeType { INT, PAIR, CALL };

struct HeapNode {
    int id;
    NodeType type;
    int val;
    std::shared_ptr<HeapNode> left;
    std::shared_ptr<HeapNode> right;
    bool marked = false;
};

class TetrisHeapEngine {
public:
    Cell board[BOARD_HEIGHT][BOARD_WIDTH];
    Piece active_piece;
    bool has_active = false;
    int current_id = 0;

    TetrisHeapEngine() {
        clear_board();
    }

    void clear_board() {
        for (int r = 0; r < BOARD_HEIGHT; ++r) {
            for (int c = 0; c < BOARD_WIDTH; ++c) {
                board[r][c] = Cell();
            }
        }
    }

    bool check_collision(const Piece& p, int off_x, int off_y) {
        for (size_t r = 0; r < p.shape.size(); ++r) {
            for (size_t c = 0; c < p.shape[r].size(); ++c) {
                if (p.shape[r][c]) {
                    int nx = p.x + c + off_x;
                    int ny = p.y + r + off_y;
                    if (nx < 0 || nx >= BOARD_WIDTH || ny < 0 || ny >= BOARD_HEIGHT) return true;
                    if (board[ny][nx].occupied) return true;
                }
            }
        }
        return false;
    }

    bool spawn_block(int block_id, char sym) {
        static std::mt19937 rng(1337);
        std::uniform_int_distribution<int> dist(0, SHAPES.size() - 1);
        
        active_piece.shape = SHAPES[dist(rng)];
        active_piece.x = BOARD_WIDTH / 2 - active_piece.shape[0].size() / 2;
        active_piece.y = 0;
        active_piece.id = block_id;
        active_piece.symbol = sym;
        has_active = true;

        if (check_collision(active_piece, 0, 0)) {
            // Memory Overflow / Out of Heap space! Trigger hard GC sweep.
            return false;
        }
        return true;
    }

    void move_active(int dx, int dy) {
        if (!has_active) return;
        if (!check_collision(active_piece, dx, dy)) {
            active_piece.x += dx;
            active_piece.y += dy;
        }
    }

    void rotate_active() {
        if (!has_active) return;
        Piece rotated = active_piece;
        int R = rotated.shape.size();
        int C = rotated.shape[0].size();
        std::vector<std::vector<int>> new_shape(C, std::vector<int>(R, 0));
        for (int r = 0; r < R; ++r) {
            for (int c = 0; c < C; ++c) {
                new_shape[c][R - 1 - r] = rotated.shape[r][c];
            }
        }
        rotated.shape = new_shape;
        if (!check_collision(rotated, 0, 0)) {
            active_piece = rotated;
        }
    }

    bool step_gravity() {
        if (!has_active) return false;
        if (!check_collision(active_piece, 0, 1)) {
            active_piece.y += 1;
            return true;
        } else {
            // Lock piece into Memory Matrix
            for (size_t r = 0; r < active_piece.shape.size(); ++r) {
                for (size_t c = 0; c < active_piece.shape[r].size(); ++c) {
                    if (active_piece.shape[r][c]) {
                        int ny = active_piece.y + r;
                        int nx = active_piece.x + c;
                        if (ny >= 0 && ny < BOARD_HEIGHT && nx >= 0 && nx < BOARD_WIDTH) {
                            board[ny][nx].occupied = true;
                            board[ny][nx].symbol = active_piece.symbol;
                            board[ny][nx].block_id = active_piece.id;
                            board[ny][nx].marked = true; // Initially marked
                        }
                    }
                }
            }
            has_active = false;
            return false;
        }
    }

    // Garbage Collection Line Clear Strategy
    int gc_sweep_lines() {
        int cleared = 0;
        for (int r = BOARD_HEIGHT - 1; r >= 0; --r) {
            bool full_row = true;
            bool contains_live = false;

            for (int c = 0; c < BOARD_WIDTH; ++c) {
                if (!board[r][c].occupied) full_row = false;
                if (board[r][c].occupied && board[r][c].marked) contains_live = true;
            }

            // A line is GC cleared if it's completely filled AND consists strictly of unreferenced blocks
            if (full_row && !contains_live) {
                cleared++;
                for (int drop_r = r; drop_r > 0; --drop_r) {
                    for (int c = 0; c < BOARD_WIDTH; ++c) {
                        board[drop_r][c] = board[drop_r - 1][c];
                    }
                }
                for (int c = 0; c < BOARD_WIDTH; ++c) {
                    board[0][c] = Cell();
                }
                r++; // Re-check current row index after shift
            }
        }
        return cleared;
    }

    void reset_marks() {
        for (int r = 0; r < BOARD_HEIGHT; ++r) {
            for (int c = 0; c < BOARD_WIDTH; ++c) {
                board[r][c].marked = false;
            }
        }
    }

    void mark_block(int id) {
        for (int r = 0; r < BOARD_HEIGHT; ++r) {
            for (int c = 0; c < BOARD_WIDTH; ++c) {
                if (board[r][c].occupied && board[r][c].block_id == id) {
                    board[r][c].marked = true;
                }
            }
        }
    }
};

// Main System Architecture
class InteractiveTetrisInterpreter {
private:
    TetrisHeapEngine heap;
    int next_node_id = 1;
    std::vector<std::shared_ptr<HeapNode>> call_stack;

    void render_ui(const std::string& current_op, int result) {
        std::cout << "\033[H"; // Move cursor top-left
        std::cout << "====================================================\n";
        std::cout << "     TETRIS-GC: RECURSIVE INTERPRETER MEMORY        \n";
        std::cout << "====================================================\n";
        std::cout << " Controls: [A] Left | [D] Right | [W] Rotate | [S] Drop \n";
        std::cout << " Current Operation: " << current_op << "\n";
        std::cout << " Expression Yield:  " << (result != -1 ? std::to_string(result) : "Evaluating...") << "\n";
        std::cout << "----------------------------------------------------\n";

        // Create temporary buffer for rendering active piece
        Cell temp_board[BOARD_HEIGHT][BOARD_WIDTH];
        for (int r = 0; r < BOARD_HEIGHT; ++r)
            for (int c = 0; c < BOARD_WIDTH; ++c)
                temp_board[r][c] = heap.board[r][c];

        if (heap.has_active) {
            for (size_t r = 0; r < heap.active_piece.shape.size(); ++r) {
                for (size_t c = 0; c < heap.active_piece.shape[r].size(); ++c) {
                    if (heap.active_piece.shape[r][c]) {
                        int ny = heap.active_piece.y + r;
                        int nx = heap.active_piece.x + c;
                        if (ny >= 0 && ny < BOARD_HEIGHT && nx >= 0 && nx < BOARD_WIDTH) {
                            temp_board[ny][nx].occupied = true;
                            temp_board[ny][nx].symbol = heap.active_piece.symbol;
                            temp_board[ny][nx].marked = true;
                        }
                    }
                }
            }
        }

        for (int r = 0; r < BOARD_HEIGHT; ++r) {
            std::cout << "|";
            for (int c = 0; c < BOARD_WIDTH; ++c) {
                if (!temp_board[r][c].occupied) {
                    std::cout << " . ";
                } else {
                    if (temp_board[r][c].marked) {
                        // Live Memory = Bold Green Block
                        std::cout << "\033[1;32m[" << temp_board[r][c].symbol << "]\033[0m";
                    } else {
                        // Unreferenced Garbage = Dim Red Block
                        std::cout << "\033[2;31m[" << temp_board[r][c].symbol << "]\033[0m";
                    }
                }
            }
            std::cout << "|\n";
        }
        std::cout << "====================================================\n";
        std::cout << " Stack Frame Depth: " << call_stack.size() << " frames\n";
        std::cout << " Memory Legend: \033[1;32m[X]\033[0m Live Heap  |  \033[2;31m[X]\033[0m Garbage Block\n";
    }

    void handle_input() {
        char ch;
        while (read(STDIN_FILENO, &ch, 1) > 0) {
            if (ch == 'a' || ch == 'A') heap.move_active(-1, 0);
            if (ch == 'd' || ch == 'D') heap.move_active(1, 0);
            if (ch == 'w' || ch == 'W') heap.rotate_active();
            if (ch == 's' || ch == 'S') heap.step_gravity();
        }
    }

    void allocate_node_in_heap(std::shared_ptr<HeapNode> node, char sym) {
        heap.spawn_block(node->id, sym);
        while (heap.has_active) {
            handle_input();
            heap.step_gravity();
            mark_and_sweep();
            render_ui("ALLOCATE HEAP NODE #" + std::to_string(node->id), -1);
            std::this_thread::sleep_for(std::chrono::milliseconds(120));
        }
    }

    void mark_dfs(std::shared_ptr<HeapNode> node) {
        if (!node || node->marked) return;
        node->marked = true;
        heap.mark_block(node->id);
        mark_dfs(node->left);
        mark_dfs(node->right);
    }

    void mark_and_sweep() {
        // Reset all mark state in heat matrix
        heap.reset_marks();
        
        // Mark phase: Traverse active evaluation stack roots
        for (auto& root : call_stack) {
            mark_dfs(root);
        }

        // Sweep phase: Clear completed garbage lines
        heap.gc_sweep_lines();
    }

public:
    InteractiveTetrisInterpreter() {}

    // Recursive Interpreter function for Fibonacci: Fib(n) = Fib(n-1) + Fib(n-2)
    int eval_fib(int n) {
        auto node = std::make_shared<HeapNode>();
        node->id = next_node_id++;
        node->type = NodeType::CALL;
        node->val = n;

        call_stack.push_back(node);
        allocate_node_in_heap(node, 'F');

        int result = 0;
        if (n <= 1) {
            result = n;
        } else {
            // Evaluate Left Child Branch
            node->left = std::make_shared<HeapNode>();
            node->left->id = next_node_id++;
            node->left->type = NodeType::INT;
            allocate_node_in_heap(node->left, 'L');
            int lhs = eval_fib(n - 1);

            // Evaluate Right Child Branch
            node->right = std::make_shared<HeapNode>();
            node->right->id = next_node_id++;
            node->right->type = NodeType::INT;
            allocate_node_in_heap(node->right, 'R');
            int rhs = eval_fib(n - 2);

            result = lhs + rhs;
        }

        // Post-evaluation processing: Pop local reference from stack frame
        call_stack.pop_back();

        // Run real-time GC trigger
        mark_and_sweep();
        render_ui("RETURN Fib(" + std::to_string(n) + ") = " + std::to_string(result), result);
        std::this_thread::sleep_for(std::chrono::milliseconds(200));

        return result;
    }

    void run() {
        std::cout << "\033[2J\033[H"; // Clear screen
        int target = 6;
        int final_val = eval_fib(target);

        // Final Hold Screen
        while (true) {
            handle_input();
            heap.step_gravity();
            mark_and_sweep();
            render_ui("COMPLETED: Fib(" + std::to_string(target) + ") = " + std::to_string(final_val), final_val);
            std::this_thread::sleep_for(std::chrono::milliseconds(200));
        }
    }
};

int main() {
    TerminalSettings term;
    InteractiveTetrisInterpreter interpreter;
    interpreter.run();
    return 0;
}