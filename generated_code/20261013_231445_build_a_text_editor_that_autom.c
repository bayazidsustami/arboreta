/*
 * Pulsar-Driven Fractal Text Editor (Constellation Engine)
 * 
 * This program simulates a terminal-based text editor that monitors your keystroke 
 * timing. When your typing tempo synchronizes with a simulated distant pulsar 
 * frequency (target: 333ms per keystroke interval), the editor dissolves the 
 * standard text buffer and renders a recursive ASCII Mandelbrot/Star constellation.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <termios.h>
#include <sys/time.h>
#include <math.h>

#define PULSAR_TARGET_MS 333.0
#define TOLERANCE 45.0
#define BUFFER_SIZE 1024

// Terminal configuration helpers
struct termios orig_termios;

void disable_raw_mode() {
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios);
}

void enable_raw_mode() {
    tcgetattr(STDIN_FILENO, &orig_termios);
    atexit(disable_raw_mode);
    struct termios raw = orig_termios;
    raw.c_lflag &= ~(ECHO | ICANON);
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
}

// Get current time in milliseconds
double get_time_ms() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (tv.tv_sec * 1000.0) + (tv.tv_usec / 1000.0);
}

// Render recursive fractal constellation view
void render_fractal_constellation(int frame) {
    printf("\033[H\033[J"); // Clear screen
    printf("=== [ PULSAR RESONANCE ACHIEVED: CONSTELLATION MODE ACTIVE ] ===\n");
    printf("Matching Pulsar PSR B0329+54 Rhythm (~333ms). Source code mutating...\n\n");

    int width = 70;
    int height = 20;
    double scale = 1.0 + sin(frame * 0.1) * 0.5;

    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            double zx = 1.5 * (x - width / 2.0) / (0.5 * scale * width);
            double zy = (y - height / 2.0) / (0.5 * scale * height);
            double cX = zx, cY = zy;
            int iter = 0;
            int max_iter = 30;

            while (zx * zx + zy * zy < 4.0 && iter < max_iter) {
                double tmp = zx * zx - zy * zy + cX;
                zy = 2.0 * zx * zy + cY;
                zx = tmp;
                iter++;
            }

            if (iter == max_iter) {
                putchar('.');
            } else if (iter > 20) {
                putchar('*');
            } else if (iter > 10) {
                putchar('+');
            } else {
                putchar(' ');
            }
        }
        putchar('\n');
    }
    printf("\n[Press any key to return to editor, 'q' to exit]\n");
}

int main() {
    char text_buffer[BUFFER_SIZE];
    int buf_len = 0;
    memset(text_buffer, 0, BUFFER_SIZE);

    enable_raw_mode();
    
    double last_keypress_time = get_time_ms();
    int constellation_mode = 0;
    int frame_counter = 0;

    // Non-blocking input setup using select() or simple read with timeout could be used,
    // but here we use standard getchar in raw mode (blocking per keypress).
    while (1) {
        if (constellation_mode) {
            render_fractal_constellation(frame_counter++);
        } else {
            printf("\033[H\033[J");
            printf("--- PULSAR TEXT EDITOR --- (Type steadily at ~3%dms intervals)\n", (int)PULSAR_TARGET_MS);
            printf("Buffer: %s_\n\n", text_buffer);
            printf("[Instructions: Type characters. Match the pulsar beat to trigger fractal mode. Press ESC to quit.]\n");
        }

        char c;
        if (read(STDIN_FILENO, &c, 1) == 1) {
            if (c == 27) { // ESC key
                break;
            }

            if (constellation_mode) {
                constellation_mode = 0; // Exit constellation on keypress
                continue;
            }

            double current_time = get_time_ms();
            double delta = current_time - last_keypress_time;
            last_keypress_time = current_time;

            // Check if tempo matches pulsar rhythm within tolerance
            if (buf_len > 2 && fabs(delta - PULSAR_TARGET_MS) < TOLERANCE) {
                constellation_mode = 1;
            }

            if (c == 127 || c == 8) { // Backspace
                if (buf_len > 0) text_buffer[--buf_len] = '\0';
            } else if (c >= 32 && c <= 126 && buf_len < BUFFER_SIZE - 1) {
                text_buffer[buf_len++] = c;
                text_buffer[buf_len] = '\0';
            }
        }
    }

    disable_raw_mode();
    printf("\nExiting Pulsar Editor. Safe travels through the cosmos!\n");
    return 0;
}