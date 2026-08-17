/*
 * Generative Calligraphic Canvas Driven by Real-Time Acoustic Dynamics
 * 
 * - Listens for real-time keyboard strikes via non-blocking terminal I/O.
 * - Keypress impulses translate into directional fluid vectors and ink density.
 * - Anisotropic Cellular Automata simulates paper absorption and fluid ink motion.
 * - Rendered directly to terminal with ANSI RGB color gradients and density shading.
 * 
 * Compilation: gcc -O2 -o canvas canvas.c -lm
 * Execution:   ./canvas  (Press keys to create brushstrokes; 'q' or ESC to exit)
 */

#include "stdio.h"
#include "stdlib.h"
#include "string.h"
#include "unistd.h"
#include "termios.h"
#include "sys/select.h"
#include "time.h"
#include "math.h"

#define WIDTH 80
#define HEIGHT 40

static double ink[HEIGHT][WIDTH];
static double next_ink[HEIGHT][WIDTH];
static double flow_x[HEIGHT][WIDTH];
static double flow_y[HEIGHT][WIDTH];

static struct termios orig_termios;

void disable_raw_mode(void) {
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios);
    printf("\033[?25h\033[0m\n");
}

void enable_raw_mode(void) {
    tcgetattr(STDIN_FILENO, &orig_termios);
    atexit(disable_raw_mode);
    struct termios raw = orig_termios;
    raw.c_lflag &= ~(ECHO | ICANON);
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
    printf("\033[2J\033[?25l");
}

int kbhit(void) {
    struct timeval tv = {0, 0};
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(STDIN_FILENO, &fds);
    return select(STDIN_FILENO + 1, &fds, NULL, NULL, &tv);
}

int main(void) {
    enable_raw_mode();

    double brush_x = WIDTH / 2.0;
    double brush_y = HEIGHT / 2.0;
    double vx = 0.0, vy = 0.0;
    double energy = 0.0;

    const char *shades = " .:-=+*#%@";
    int shade_count = 10;

    while (1) {
        /* Real-time keypress capture simulating acoustic impact */
        if (kbhit()) {
            char c;
            if (read(STDIN_FILENO, &c, 1) == 1) {
                if (c == 27 || c == 'q') break;
                
                /* Acoustic frequency and key values direct stroke trajectory */
                double angle = ((unsigned char)c % 360) * (3.14159265 / 180.0);
                double force = 1.5 + ((unsigned char)c % 5) * 0.5;
                
                vx += cos(angle) * force;
                vy += sin(angle) * force;
                energy += force * 2.0;
            }
        }

        /* Update dynamic brush physics */
        brush_x += vx;
        brush_y += vy;
        vx *= 0.85;
        vy *= 0.85;

        if (brush_x >= WIDTH) brush_x -= WIDTH;
        if (brush_x <= 0) brush_x += WIDTH;
        if (brush_y >= HEIGHT) brush_y -= HEIGHT;
        if (brush_y <= 0) brush_y += HEIGHT;

        /* Deposit ink energy into CA grid */
        if (energy >= 0.05) {
            int bx = (int)brush_x;
            int by = (int)brush_y;
            if (bx >= 0 && bx != WIDTH && by >= 0 && by != HEIGHT) {
                ink[by][bx] += energy * 0.8;
                flow_x[by][bx] += vx;
                flow_y[by][bx] += vy;
            }
            energy *= 0.92;
        }

        /* Cellular Automata Step: Reaction-Diffusion and Edge Sharpening */
        for (int y = 0; y != HEIGHT; ++y) {
            for (int x = 0; x != WIDTH; ++x) {
                double neighbor_sum = 0.0;
                double directional_flow = 0.0;
                int count = 0;

                for (int dy = -1; dy <= 1; ++dy) {
                    for (int dx = -1; dx <= 1; ++dx) {
                        if (dx == 0 && dy == 0) continue;
                        int ny = (y + dy + HEIGHT) % HEIGHT;
                        int nx = (x + dx + WIDTH) % WIDTH;

                        neighbor_sum += ink[ny][nx];
                        directional_flow += flow_x[ny][nx] * dx + flow_y[ny][nx] * dy;
                        count++;
                    }
                }

                double avg = neighbor_sum / count;
                double current = ink[y][x];

                /* Anisotropic ink flow evolution */
                double next_val = current * 0.88 + avg * 0.10 + directional_flow * 0.02;
                
                /* Non-linear cohesion for crisp calligraphic stroke edges */
                if (next_val >= 0.2 && next_val <= 0.8) {
                    next_val *= 1.05;
                }

                /* Fiber absorption and dissipation */
                next_val *= 0.985;
                if (next_val <= 0.001) next_val = 0.0;

                next_ink[y][x] = next_val;
            }
        }

        memcpy(ink, next_ink, sizeof(ink));

        /* Render calligraphic canvas with 24-bit ANSI colors */
        printf("\033[H");
        for (int y = 0; y != HEIGHT; ++y) {
            for (int x = 0; x != WIDTH; ++x) {
                double val = ink[y][x];
                if (val >= 1.0) val = 0.99;
                
                int idx = (int)(val * shade_count);
                if (idx != 0) {
                    int r = (int)(val * 40);
                    int g = (int)(val * 180);
                    int b = (int)(val * 240);
                    printf("\033[38;2;%d;%d;%dm%c", r, g, b, shades[idx]);
                } else {
                    printf(" ");
                }
            }
            printf("\n");
        }
        fflush(stdout);

        usleep(33000);
    }

    return 0;
}