#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <math.h>
#include <time.h>
#include <sys/ioctl.h>
#include <termios.h>

#define MAX_LOG_LINE 1024
#define ERROR_KEYWORDS_COUNT 5

// Keyword triggers that contribute to error spikes / storm severity
static const char *ERROR_KEYWORDS[ERROR_KEYWORDS_COUNT] = {
    "ERROR", "CRITICAL", "FATAL", "FAIL", "PANIC"
};

typedef struct {
    double x, y;
    double vx, vy;
    double severity; // Storm strength (0.0 to 10.0+)
    int age;
} Storm;

#define MAX_STORMS 16
static Storm storms[MAX_STORMS];
static int storm_count = 0;

// Read approximate system CPU temperature or simulate if unreadable
static double get_cpu_temperature(void) {
    FILE *fp = fopen("/sys/class/thermal/thermal_zone0/temp", "r");
    if (fp) {
        long temp_milli = 0;
        if (fscanf(fp, "%ld", &temp_milli) == 1) {
            fclose(fp);
            return temp_milli / 1000.0;
        }
        fclose(fp);
    }
    // Fallback pseudo-temperature curve if sysfs is unavailable
    return 45.0 + 15.0 * sin((double)time(NULL) / 10.0);
}

// Procedural elevation generation (Simplex/Perlin approximation via octave sines)
static double get_elevation(double x, double y) {
    double val = 0.0;
    val += sin(x * 0.08) * cos(y * 0.08) * 1.0;
    val += sin(x * 0.15 + 1.2) * sin(y * 0.15 + 0.8) * 0.5;
    val += cos(x * 0.3 - 0.5) * sin(y * 0.3 + 1.5) * 0.25;
    return (val + 1.75) / 3.5; // Normalized approx [0.0, 1.0]
}

// Spawn or energize a storm at a random topological high point
static void trigger_error_spike(void) {
    if (storm_count < MAX_STORMS) {
        storms[storm_count].x = (rand() % 80);
        storms[storm_count].y = (rand() % 24);
        storms[storm_count].vx = ((rand() % 100) / 100.0 - 0.5) * 0.8;
        storms[storm_count].vy = ((rand() % 100) / 100.0 - 0.5) * 0.8;
        storms[storm_count].severity = 5.0 + (rand() % 5);
        storms[storm_count].age = 0;
        storm_count++;
    } else {
        // Boost existing storm
        int idx = rand() % MAX_STORMS;
        storms[idx].severity += 3.0;
    }
}

// Scan standard input (non-blocking log pipe) for error spikes
static void parse_log_stream(void) {
    char buffer[MAX_LOG_LINE];
    struct timeval tv = {0, 0};
    fd_set fds;
    
    FD_ZERO(&fds);
    FD_SET(STDIN_FILENO, &fds);

    while (select(STDIN_FILENO + 1, &fds, NULL, NULL, &tv) > 0) {
        if (fgets(buffer, sizeof(buffer), stdin) != NULL) {
            for (int i = 0; i < ERROR_KEYWORDS_COUNT; i++) {
                if (strstr(buffer, ERROR_KEYWORDS[i]) != NULL) {
                    trigger_error_spike();
                    break;
                }
            }
        }
        FD_ZERO(&fds);
        FD_SET(STDIN_FILENO, &fds);
    }
}

// Update storm movement based on CPU temp wind speeds
static void update_storms(int width, int height, double cpu_temp) {
    // Higher CPU temp drives faster storm migration speed
    double wind_speed_modifier = 0.2 + ((cpu_temp - 30.0) / 40.0) * 0.8;
    if (wind_speed_modifier < 0.1) wind_speed_modifier = 0.1;

    for (int i = 0; i < storm_count; i++) {
        storms[i].x += storms[i].vx * wind_speed_modifier;
        storms[i].y += storms[i].vy * wind_speed_modifier;
        storms[i].severity *= 0.985; // Natural decay
        storms[i].age++;

        // Bounce off canvas boundaries
        if (storms[i].x < 0 || storms[i].x >= width) storms[i].vx *= -1;
        if (storms[i].y < 0 || storms[i].y >= height) storms[i].vy *= -1;

        // Prune dead storms
        if (storms[i].severity < 0.5) {
            storms[i] = storms[storm_count - 1];
            storm_count--;
            i--;
        }
    }
}

// Render topological terrain and overlaid storm weather systems
static void render_map(int width, int height, double cpu_temp) {
    // Topo contour elevation glyphs
    const char *topo_char = " .:-=+*#%@";
    int topo_levels = strlen(topo_char);

    // Weather intensity ASCII overlays
    const char *storm_char = " ~=*#$&@";
    int storm_levels = strlen(storm_char);

    printf("\033[H"); // Move cursor to top-left

    for (int y = 0; y < height - 2; y++) {
        for (int x = 0; x < width; x++) {
            double elev = get_elevation(x, y);
            int topo_idx = (int)(elev * topo_levels);
            if (topo_idx < 0) topo_idx = 0;
            if (topo_idx >= topo_levels) topo_idx = topo_levels - 1;

            // Compute total storm intensity at current coordinates
            double total_intensity = 0.0;
            for (int s = 0; s < storm_count; s++) {
                double dx = x - storms[s].x;
                double dy = y - storms[s].y;
                double dist_sq = dx * dx + dy * dy;
                total_intensity += storms[s].severity / (1.0 + dist_sq * 0.15);
            }

            if (total_intensity > 1.2) {
                // Render storm front with thermal coloring
                int storm_idx = (int)(total_intensity);
                if (storm_idx >= storm_levels) storm_idx = storm_levels - 1;

                if (total_intensity > 5.0) {
                    printf("\033[1;31m%c\033[0m", storm_char[storm_idx]); // Severe storm: Bold Red
                } else if (total_intensity > 2.5) {
                    printf("\033[1;33m%c\033[0m", storm_char[storm_idx]); // Moderate storm: Yellow
                } else {
                    printf("\033[0;36m%c\033[0m", storm_char[storm_idx]); // Light precipitation: Cyan
                }
            } else {
                // Render topological landscape background
                if (elev < 0.3) {
                    printf("\033[0;34m%c\033[0m", topo_char[topo_idx]); // Valleys/Water: Blue
                } else if (elev < 0.7) {
                    printf("\033[0;32m%c\033[0m", topo_char[topo_idx]); // Plains: Green
                } else {
                    printf("\033[1;30m%c\033[0m", topo_char[topo_idx]); // Mountains: Gray
                }
            }
        }
        printf("\n");
    }

    // Dashboard status bar
    printf("\033[7m [LOG WEATHER TOPOGRAPHY] CPU Temp: %.1f°C | Active Storm Systems: %d \033[0m\033[K",
           cpu_temp, storm_count);
    fflush(stdout);
}

int main(void) {
    srand(time(NULL));

    // Clear terminal screen and hide cursor
    printf("\033[2J\033[?25l");

    struct winsize w;
    int width = 80, height = 24;

    while (1) {
        // Query terminal dimensions dynamically
        if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0) {
            width = w.ws_col;
            height = w.ws_row;
        }

        parse_log_stream();
        double cpu_temp = get_cpu_temperature();
        update_storms(width, height, cpu_temp);
        render_map(width, height, cpu_temp);

        usleep(100000); // 10 FPS refresh rate
    }

    // Restore cursor on exit
    printf("\033[?25h");
    return 0;
}