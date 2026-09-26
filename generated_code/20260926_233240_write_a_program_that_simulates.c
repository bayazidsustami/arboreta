#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

#if defined(_WIN32)
#include <conio.h>
#include <windows.h>
#else
#include <termios.h>
#include <unistd.h>
#include <sys/select.h>
#endif

#define WIDTH 80
#define HEIGHT 24
#define MAX_POLYPS 500

// Coral polyp structure
typedef struct {
    int x, y;
    int age;
    int color_seed;
    int active;
} Polyp;

Polyp reef[MAX_POLYPS];
int polyp_count = 0;

// Terminal control setup for non-blocking input
#ifndef _WIN32
static struct termios orig_termios;
void reset_terminal_mode(void) {
    tcsetattr(0, TCSANOW, &orig_termios);
}
void set_noncanonical_mode(void) {
    struct termios new_termios;
    tcgetattr(0, &orig_termios);
    memcpy(&new_termios, &orig_termios, sizeof(new_termios));
    new_termios.c_lflag &= ~(ICANON | ECHO);
    new_termios.c_cc[VMIN] = 0;
    new_termios.c_cc[VTIME] = 0;
    tcsetattr(0, TCSANOW, &new_termios);
    atexit(reset_terminal_mode);
}
int kbhit(void) {
    struct timeval tv = { 0L, 0L };
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(0, &fds);
    return select(1, &fds, NULL, NULL, &tv) > 0;
}
int getch(void) {
    unsigned char c;
    if (read(0, &c, 1) < 0) return 0;
    return c;
}
#else
void set_noncanonical_mode(void) {}
#endif

// ANSI color palette generator based on entropy seed
void print_color(int seed) {
    int r = (seed * 33) % 5 + 1;
    int g = (seed * 17) % 5 + 1;
    int b = (seed * 23) % 5 + 1;
    int code = 16 + 36 * r + 6 * g + b;
    printf("\033[38;5%dm", code);
}

void init_reef() {
    memset(reef, 0, sizeof(reef));
    // Seed initial base polyps at the ocean floor
    for (int i = 0; i < 5; i++) {
        reef[i].x = WIDTH / 6 * (i + 1);
        reef.y = HEIGHT - 2;
        reef[i].age = 0;
        reef[i].color_seed = i + 1;
        reef[i].active = 1;
        polyp_count++;
    }
}

void grow_coral(double entropy_factor) {
    if (polyp_count >= MAX_POLYPS) return;
    
    // Find an active polyp to branch from
    int idx = rand() % polyp_count;
    if (!reef[idx].active) return;

    Polyp new_p;
    new_p.x = reef[idx].x + (rand() % 3 - 1);
    new_p.y = reef[idx].y - (rand() % 2 + 1); // Grow upward
    
    // Bounds checking
    if (new_p.x < 1) new_p.x = 1;
    if (new_p.x >= WIDTH - 1) new_p.x = WIDTH - 2;
    if (new_p.y < 1) new_p.y = 1;

    new_p.age = 0;
    // Color mutation driven by typing entropy
    new_p.color_seed = (int)(reef[idx].color_seed + (entropy_factor * 10)) % 216 + 1;
    new_p.active = 1;

    reef[polyp_count++] = new_p;
}

void render_ocean() {
    // Clear screen buffer
    printf("\033[H\033[J");
    printf("\033[44;1m--- DIGITAL CORAL REEF (Type to infuse life/entropy) ---^X to exit\033[0m\n");

    char grid[HEIGHT][WIDTH];
    int color_grid[HEIGHT][WIDTH];
    
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            grid[y][x] = ' ';
            color_grid[y][x] = 0;
        }
    }

    // Populate grid with polyps
    for (int i = 0; i < polyp_count; i++) {
        if (reef[i].active) {
            int px = reef[i].x;
            int py = reef[i].y;
            if (px >= 0 && px < WIDTH && py >= 0 && py < HEIGHT) {
                grid[py][px] = (reef[i].age < 3) ? '*' : '#';
                color_grid[py][px] = reef[i].color_seed;
            }
        }
    }

    // Draw the ocean canvas
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            if (grid[y][x] != ' ') {
                print_color(color_grid[y][x]);
                putchar(grid[y][x]);
                printf("\033[0m");
            } else {
                // Ocean water gradient background simulation
                putchar('.');
            }
        }
        putchar('\n');
    }
}

int main() {
    srand((unsigned int)time(NULL));
    set_noncanonical_mode();
    init_reef();

    clock_t last_time = clock();
    double typing_entropy = 1.0;
    int key_count = 0;

    while (1) {
        clock_t current_time = clock();
        double elapsed = (double)(current_time - last_time) / CLOCKS_PER_SEC;

        if (kbhit()) {
            int c = getch();
            if (c == 24) break; // Ctrl+X to exit
            key_count++;
            
            // Calculate dynamic entropy factor based on cadence timing
            if (elapsed > 0.0) {
                typing_entropy = 1.0 + (1.0 / elapsed);
            }
            last_time = current_time;
            
            // Immediate growth burst on keystroke
            grow_coral(typing_entropy);
        }

        // Ambient background organic growth decay over time
        if (elapsed > 0.5) {
            grow_coral(typing_entropy * 0.5);
            last_time = current_time;
        }

        render_ocean();
        
        #if defined(_WIN32)
        Sleep(50);
        #else
        usleep(50000); // 50ms frame refresh
        #endif
    }

    printf("\033[0m\nReef simulation ended. Total keystrokes processed: %d\n", key_count);
    return 0;
}