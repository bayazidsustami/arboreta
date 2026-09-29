#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <unistd.h>
#include <time.h>

#define WIDTH 70
#define HEIGHT 25

// Structure representing local weather conditions
typedef struct {
    double pressure; // Atmospheric pressure in hPa
    double humidity; // Relative humidity percentage
} Weather;

// Simulates dynamic fluctuations in atmospheric pressure and humidity over time
void update_weather(Weather *w, int frame) {
    w->pressure = 1013.25 + 20.0 * sin(frame * 0.15);
    w->humidity = 55.0 + 35.0 * cos(frame * 0.2);
}

// Renders the evolving topological map warped by weather parameters
void render_city(Weather w) {
    // Clear terminal screen using ANSI escape codes
    printf("\033[H\033[J");
    printf("=== NEOPOLIS TOPOLOGICAL MAP ===\n");
    printf("Pressure: %.2f hPa | Humidity: %.2f%%\n\n", w.pressure, w.humidity);

    char canvas[HEIGHT][WIDTH];
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            canvas[y][x] = ' ';
        }
    }

    // Normalizing factors based on weather readings
    double p_factor = w.pressure / 1000.0;
    double h_factor = w.humidity / 100.0;

    // Generate and warp the street grid
    for (int gy = 0; gy < HEIGHT; gy += 5) {
        for (int gx = 0; gx < WIDTH; gx += 8) {
            // Apply trigonometric atmospheric warping to node coordinates
            double wx = gx + h_factor * 6.0 * sin(gy * 0.25 * p_factor);
            double wy = gy + p_factor * 4.0 * cos(gx * 0.25 * h_factor);

            int ix = (int)(wx + 0.5);
            int iy = (int)(wy + 0.5);

            if (ix >= 0 && ix < WIDTH && iy >= 0 && iy < HEIGHT) {
                canvas[iy][ix] = '+';
            }

            // Draw horizontal roads (warped by humidity)
            for (int x = gx + 1; x < gx + 8 && x < WIDTH; x++) {
                double current_wx = x + h_factor * 6.0 * sin(gy * 0.25 * p_factor);
                int cur_ix = (int)(current_wx + 0.5);
                if (cur_ix >= 0 && cur_ix < WIDTH && iy >= 0 && iy < HEIGHT) {
                    canvas[iy][cur_ix] = (w.humidity > 70.0) ? '~' : '-';
                }
            }

            // Draw vertical roads (warped by pressure)
            for (int y = gy + 1; y < gy + 5 && y < HEIGHT; y++) {
                double current_wy = y + p_factor * 4.0 * cos(gx * 0.25 * h_factor);
                int cur_iy = (int)(current_wy + 0.5);
                if (ix >= 0 && ix < WIDTH && cur_iy >= 0 && cur_iy < HEIGHT) {
                    canvas[cur_iy][ix] = (w.pressure < 1005.0) ? '/' : '|';
                }
            }
        }
    }

    // Render city borders
    for (int x = 0; x < WIDTH + 2; x++) printf("#");
    printf("\n");

    for (int y = 0; y < HEIGHT; y++) {
        printf("#");
        for (int x = 0; x < WIDTH; x++) {
            putchar(canvas[y][x]);
        }
        printf("#\n");
    }

    for (int x = 0; x < WIDTH + 2; x++) printf("#");
    printf("\n");
}

int main() {
    Weather weather;
    int frame = 0;

    // Run the live evolution loop
    while (frame < 50) {
        update_weather(&weather, frame);
        render_city(weather);
        usleep(250000); // 250ms delay for smooth animation
        frame++;
    }

    return 0;
}