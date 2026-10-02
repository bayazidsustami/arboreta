#include <iostream>
#include <vector>
#include <string>
#include <chrono>
#include <thread>
#include <random>
#include <algorithm>

#ifdef _WIN32
#include <conio.h>
#include <windows.h>
#else
#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#endif

// Landscape dimensions
const int WIDTH = 80;
const int HEIGHT = 24;

// Terminal mode RAII wrapper for POSIX non-blocking unbuffered input
#ifndef _WIN32
class TerminalMode {
    struct termios orig_termios;
public:
    TerminalMode() {
        tcgetattr(STDIN_FILENO, &orig_termios);
        struct termios raw = orig_termios;
        raw.c_lflag &= ~(ECHO | ICANON);
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
        int flags = fcntl(STDIN_FILENO, F_GETFL, 0);
        fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK);
    }
    ~TerminalMode() {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios);
        int flags = fcntl(STDIN_FILENO, F_GETFL, 0);
        fcntl(STDIN_FILENO, F_SETFL, flags & ~O_NONBLOCK);
    }
};
#endif

// Cross-platform non-blocking key check
bool checkKey(char& c) {
#ifdef _WIN32
    if (_kbhit()) {
        c = _getch();
        return true;
    }
    return false;
#else
    char buf;
    if (read(STDIN_FILENO, &buf, 1) > 0) {
        c = buf;
        return true;
    }
    return false;
#endif
}

int main() {
#ifndef _WIN32
    TerminalMode termMode;
#endif

    // Hide cursor and clear screen
    std::cout << "\033[?25l\033[2J";

    // Moss vitality grid (0 = dead/rock, higher = lush moss)
    std::vector<std::vector<int>> grid(HEIGHT, std::vector<int>(WIDTH, 0));
    std::string density_chars = " .:-*#MW"; // ASCII density ramp

    std::mt19937 rng(std::random_device{}());
    std::uniform_int_distribution<int> dist_w(0, WIDTH - 1);
    std::uniform_int_distribution<int> dist_h(0, HEIGHT - 1);

    auto last_keystroke = std::chrono::steady_clock::now();
    bool running = true;

    while (running) {
        auto now = std::chrono::steady_clock::now();
        double idle_time = std::chrono::duration<double>(now - last_keystroke).count();

        // Handle user input / keystroke entropy
        char key = 0;
        if (checkKey(key)) {
            if (key == 'q' || key == 'Q') {
                running = false;
            }
            last_keystroke = std::chrono::steady_clock::now();
            
            // Inject new life into the fractal landscape based on keystroke entropy
            int seed_x = dist_w(rng);
            int seed_y = dist_h(rng);
            int intensity = (unsigned char)key % 5 + 4;
            for (int dy = -2; dy <= 2; ++dy) {
                for (int dx = -2; dx <= 2; ++dx) {
                    int nx = seed_x + dx;
                    int ny = seed_y + dy;
                    if (nx >= 0 && nx < WIDTH && ny >= 0 && ny < HEIGHT) {
                        grid[ny][nx] = std::min(7, grid[ny][nx] + intensity);
                    }
                }
            }
        }

        // Cellular automaton: growth, fractal spread, and decay (accelerated by idleness)
        std::vector<std::vector<int>> next_grid = grid;
        double decay_chance = 0.03 + (idle_time > 2.0 ? (idle_time - 2.0) * 0.05 : 0.0);

        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                // Natural decay / dying off during inactivity
                if (std::uniform_real_distribution<double>(0.0, 1.0)(rng) < decay_chance) {
                    if (next_grid[y][x] > 0) next_grid[y][x]--;
                }

                // Moss spreading to adjacent cells if vitality is high enough
                if (grid[y][x] > 3) {
                    int dx[] = {-1, 1, 0, 0};
                    int dy[] = {0, 0, -1, 1};
                    for (int i = 0; i < 4; ++i) {
                        int nx = x + dx[i];
                        int ny = y + dy[i];
                        if (nx >= 0 && nx < WIDTH && ny >= 0 && ny < HEIGHT) {
                            if (next_grid[ny][nx] < grid[y][x] - 1 && std::uniform_real_distribution<double>(0.0, 1.0)(rng) < 0.35) {
                                next_grid[ny][nx] = std::max(next_grid[ny][nx], grid[y][x] - 1);
                            }
                        }
                    }
                }
            }
        }
        grid = next_grid;

        // Render frame
        std::string frame = "\033[H"; // Reset cursor to top-left
        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                int v = std::clamp(grid[y][x], 0, (int)density_chars.size() - 1);
                frame += density_chars[v];
            }
            frame += "\n";
        }
        
        // Status footer
        frame += "\n[ASCII MOSS SYNTHESIZER] Type to seed growth | Stop typing to let it wither | Idle: " + std::to_string((int)idle_time) + "s | Press 'q' to exit.  ";
        std::cout << frame << std::flush;

        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }

    // Restore terminal cursor and clear screen on exit
    std::cout << "\033[?25h\033[2J\033[H";
    return 0;
}