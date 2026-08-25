#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <unistd.h>
#include <time.h>

#define WIDTH 80
#define HEIGHT 40
#define MAX_DEPTH 12
#define DECAY_RATE 0.08f

typedef struct {
    char ch;
    int color;
    float energy;
} Cell;

Cell canvas[HEIGHT][WIDTH];

// Color palette mapping energy/depth to ANSI terminal escape sequences
const int COLOR_PALETTE[] = {196, 202, 208, 214, 220, 226, 118, 46, 48, 51, 39, 21};
const char DENSITY_CHARS[] = " .:-=+*#%@";

void clear_screen() {
    printf("\033[H");
}

void hide_cursor() {
    printf("\033[?25l");
}

void show_cursor() {
    printf("\033[?25h");
}

void init_canvas() {
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            canvas[y][x].ch = ' ';
            canvas[y][x].color = 0;
            canvas[y][x].energy = 0.0f;
        }
    }
}

// Render the ASCII buffer to the terminal using ANSI colors
void draw_canvas() {
    clear_screen();
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            Cell c = canvas[y][x];
            if (c.energy > 0.05f) {
                int char_idx = (int)(c.energy * (sizeof(DENSITY_CHARS) - 2));
                if (char_idx >= (int)sizeof(DENSITY_CHARS) - 1) char_idx = sizeof(DENSITY_CHARS) - 2;
                char render_ch = (c.ch != ' ') ? c.ch : DENSITY_CHARS[char_idx];
                printf("\033[38;5;%dm%c", c.color, render_ch);
            } else {
                putchar(' ');
            }
        }
        putchar('\n');
    }
    fflush(stdout);
}

// Decay the canvas buffer simulating hyperbolic stack unwinding entropy
void decay_canvas() {
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            if (canvas[y][x].energy > 0.0f) {
                canvas[y][x].energy -= DECAY_RATE;
                if (canvas[y][x].energy <= 0.0f) {
                    canvas[y][x].energy = 0.0f;
                    canvas[y][x].ch = ' ';
                }
            }
        }
    }
}

// Project Poincaré disk / hyperbolic coordinates onto ASCII screen grid
void plot_hyperbolic_branch(int x0, int y0, int x1, int y1, int depth, char symbol) {
    int dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
    int dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
    int err = dx + dy, e2;

    int color = COLOR_PALETTE[depth % 12];

    while (1) {
        if (x0 >= 0 && x0 < WIDTH && y0 >= 0 && y0 < HEIGHT) {
            canvas[y0][x0].ch = symbol;
            canvas[y0][x0].color = color;
            canvas[y0][x0].energy = 1.0f;
        }
        if (x0 == x1 && y0 == y1) break;
        e2 = 2 * err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
    }
}

// Trace execution of recursive tree with hyperbolic branch scaling
void trace_recursive_call(int depth, float angle, float x, float y, float length) {
    if (depth > MAX_DEPTH) return;

    // Hyperbolic distortion contraction factor
    float hyperbolic_scale = tanh(length / (depth + 1.0f));
    float next_x = x + cos(angle) * length * 12.0f * hyperbolic_scale;
    float next_y = y + sin(angle) * length * 6.0f * hyperbolic_scale; // Aspect ratio compensation

    // Execution trace call visualization
    plot_hyperbolic_branch((int)x, (int)y, (int)next_x, (int)next_y, depth, '|');
    draw_canvas();
    usleep(40000);

    // Recurse left and right branches (Simulating algorithm trace)
    if (depth < MAX_DEPTH) {
        trace_recursive_call(depth + 1, angle - 0.45f, next_x, next_y, length * 0.82f);
        trace_recursive_call(depth + 1, angle + 0.45f, next_x, next_y, length * 0.82f);
    }

    // Stack unwinding -> trigger local decay and canvas frame update
    decay_canvas();
    plot_hyperbolic_branch((int)x, (int)y, (int)next_x, (int)next_y, depth, '~');
    draw_canvas();
    usleep(25000);
}

int main() {
    printf("\033[2J"); // Clear terminal
    hide_cursor();
    init_canvas();

    // Begin real-time recursive hyperbolic fractal trace
    trace_recursive_call(0, -M_PI_2, WIDTH / 2.0f, HEIGHT - 2, 1.8f);

    // Final entropy decay loop
    for (int i = 0; i < 20; i++) {
        decay_canvas();
        draw_canvas();
        usleep(50000);
    }

    show_cursor();
    printf("\033[0m\nTrace execution complete.\n");
    return 0;
}