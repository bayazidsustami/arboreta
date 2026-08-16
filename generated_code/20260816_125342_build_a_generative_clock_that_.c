#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>
#include <unistd.h>

#define WIDTH 80
#define HEIGHT 24

// Reads internal CPU temperature (Linux target) with a procedural fall-back for simulation
float read_cpu_temp(void) {
    FILE *fp = fopen("/sys/class/thermal/thermal_zone0/temp", "r");
    if (fp) {
        int millidegrees;
        if (fscanf(fp, "%d", &millidegrees) == 1) {
            fclose(fp);
            return millidegrees / 1000.0f;
        }
        fclose(fp);
    }
    // Fallback simulation based on system noise/time
    return 45.0f + 15.0f * (float)sin((double)time(NULL) / 10.0);
}

// Procedural 3D noise approximation for sculpture surface detailing
float noise3D(float x, float y, float z) {
    int X = (int)floorf(x) & 255;
    int Y = (int)floorf(y) & 255;
    int Z = (int)floorf(z) & 255;
    return (sinf(X * 12.9898f + Y * 78.233f + Z * 37.719f) + 1.0f) * 0.5f;
}

// Visual palette mapping growth (metallic density) and thermal rust
char render_char(float density, float rust_factor) {
    if (density < 0.2f) return ' ';
    if (rust_factor > 0.65f) {
        // High thermal rust states
        char rust_chars[] = {'.', ':', 'x', '%', '#'};
        int idx = (int)(rust_factor * 5) % 5;
        return rust_chars[idx];
    } else {
        // Pristine metallic structures
        char metal_chars[] = {'-', '=', '+', '*', '8', 'M'};
        int idx = (int)(density * 5) % 6;
        return metal_chars[idx];
    }
}

int main(void) {
    // Hide cursor and clear terminal window
    printf("\033[?25l\033[2J");

    while (1) {
        time_t raw_time = time(NULL);
        struct tm *t = localtime(&raw_time);
        float temp = read_cpu_temp();

        // Time encoded directly into growth structure parameters
        int hours = t->tm_hour;
        int mins  = t->tm_min;
        int secs  = t->tm_sec;

        // Thermal stress coefficient dictates structural decay and rust formation
        float rust_intensity = (temp - 30.0f) / 50.0f; 
        if (rust_intensity < 0.0f) rust_intensity = 0.0f;
        if (rust_intensity > 1.0f) rust_intensity = 1.0f;

        printf("\033[H"); // Reset cursor position to top-left

        for (int y = 0; y < HEIGHT; y++) {
            for (int x = 0; x < WIDTH; x++) {
                // Map screen space to normalized coordinate space (-1.5 to 1.5)
                float nx = (x - WIDTH / 2.0f) / (HEIGHT / 2.0f);
                float ny = (y - HEIGHT / 2.0f) / (HEIGHT / 2.0f);

                // 1. Hour Sculpture: Core trunk growth via radial harmonic waves
                float h_angle = atan2f(ny, nx);
                float h_radius = sqrtf(nx * nx + ny * ny);
                float h_branches = fabsf(sinf((hours % 12 + 1) * h_angle));
                float hour_density = (1.2f - h_radius) + h_branches * 0.4f;

                // 2. Minute Sculpture: Branching lattices shifting over space
                float m_wave = sinf(nx * (mins % 10 + 1) + ny * (mins / 10 + 1));
                float min_density = (1.0f - fabsf(ny - m_wave * 0.5f));

                // 3. Second Sculpture: Dynamic dynamic decay/pulse lattice
                float s_phase = (secs / 60.0f) * 6.28318f;
                float sec_density = sinf(nx * cosf(s_phase) + ny * sinf(s_phase) + noise3D(nx, ny, s_phase));

                // Composite overall metal sculpture density
                float total_density = (hour_density * 0.4f) + (min_density * 0.4f) + (sec_density * 0.3f);
                
                // Thermal decay subtracts from structural volume
                total_density -= (rust_intensity * 0.35f * noise3D(nx * 3.0f, ny * 3.0f, secs * 0.1f));

                // Local rust distribution perturbed by CPU heat state
                float local_rust = rust_intensity + 0.3f * noise3D(nx * 5.0f, ny * 5.0f, (float)secs);

                putchar(render_char(total_density, local_rust));
            }
            putchar('\n');
        }

        // Status bar showing real-time metrics
        printf("\n\033[1;33m[GENERATIVE TEMPORAL SCULPTURE]\033[0m CPU Temp: \033[1;31m%.1f°C\033[0m | Time Structure: %02d:%02d:%02d\n",
               temp, hours, mins, secs);

        usleep(100000); // 10 fps update rate
    }

    return 0;
}