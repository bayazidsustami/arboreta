#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <unistd.h>

#define WIDTH 80
#define HEIGHT 24

// Simulates dynamic network traffic latency using smooth oscillators and jitter
double get_simulated_latency(double t) {
    return 45.0 + 30.0 * sin(t * 0.4) + 15.0 * cos(t * 1.2) + (rand() % 12 - 6);
}

int main() {
    srand(time(NULL));
    // Hide terminal cursor and clear screen
    printf("\x1b[?25l\x1b[2J");

    double t = 0.0;
    char *shading = " .,-~:;=!*#$@";
    int num_shades = 12;

    // Run for 300 frames (approx. 18 seconds at ~60ms/frame)
    for (int frame = 0; frame < 300; frame++) {
        printf("\x1b[H"); // Reset cursor to top-left
        double latency = get_simulated_latency(t);

        // Shift color palette base dynamically based on network latency
        int base_r = (int)(100 + 90 * sin(latency * 0.04));
        int base_g = (int)(130 + 70 * cos(latency * 0.03));
        int base_b = (int)(160 + 80 * sin(latency * 0.05 + 1.5));

        for (int y = 0; y < HEIGHT; y++) {
            for (int x = 0; x < WIDTH; x++) {
                // Multi-layered audio waveform simulation via wave superposition
                double nx = (double)x / WIDTH * 5.0;
                double ny = (double)y / HEIGHT * 2.5;

                double wave1 = sin(nx * 2.5 + t * 2.5) * cos(ny - t * 0.8);
                double wave2 = sin(nx * 4.0 - t * 1.8) * 0.5;
                double wave3 = cos(sqrt(nx * nx + ny * ny) * 3.5 - t * 2.0);

                double val = (wave1 + wave2 + wave3 + 2.5) / 5.0;
                if (val < 0.0) val = 0.0;
                if (val > 1.0) val = 1.0;

                int shade_idx = (int)(val * (num_shades - 1));
                char c = shading[shade_idx];

                // Organic watercolor color drift per cell
                int r = (base_r + (int)(x * 1.2 + y * 1.8)) % 256;
                int g = (base_g + (int)(x * 0.8 - y * 1.2)) % 256;
                int b = (base_b + (int)(y * 2.2)) % 256;

                // Clamp to soft pastel/watercolor intensity bounds
                r = r < 40 ? 40 : (r > 230 ? 230 : r);
                g = g < 40 ? 40 : (g > 230 ? 230 : g);
                b = b < 40 ? 40 : (b > 230 ? 230 : b);

                // Render with ANSI 24-bit TrueColor
                printf("\x1b[38;2;%d;%d;%dm%c", r, g, b, c);
            }
            printf("\n");
        }

        // Live telemetry footer
        printf("\x1b[38;2;200;200;200m[NET LATENCY: %5.1f ms] | Evolving ASCII Watercolor Waveform \x1b[0m\n", latency);

        fflush(stdout);
        usleep(60000); // ~16 FPS frame pacing
        t += 0.08;
    }

    // Restore terminal cursor
    printf("\x1b[?25h\n");
    return 0;
}