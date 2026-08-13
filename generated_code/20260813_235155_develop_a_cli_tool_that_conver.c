/*
 * REAL-TIME ASCII OCEAN ECOSYSTEM
 *
 * Converts system telemetry into an interactive ASCII ocean world:
 * - High CPU usage creates atmospheric hurricane vortices swirling above the sea.
 * - High Memory pressure spawns deep-sea bioluminescent creatures.
 * - Interactive: Press 'f' to feed the ocean, 's' to trigger a storm burst, 'q' to quit.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <math.h>
#include <termios.h>
#include <fcntl.h>
#include <sys/ioctl.h>

#define MAX_CREATURES 35
#define MAX_PARTICLES 60

typedef struct {
    double x, y;
    double vx, vy;
    int type; // 0: Jellyfish, 1: Anglerfish, 2: Glowing Plankton, 3: Food particle
    double phase;
    int color;
} Creature;

static struct termios orig_termios;

void disable_raw_mode(void) {
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios);
    printf("\x1b[?25h\x1b[0m\x1b[2J\x1b[H"); // Restore cursor & clear screen
    fflush(stdout);
}

void enable_raw_mode(void) {
    tcgetattr(STDIN_FILENO, &orig_termios);
    atexit(disable_raw_mode);
    struct termios raw = orig_termios;
    raw.c_lflag &= ~(ECHO | ICANON);
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
    printf("\x1b[?25l"); // Hide cursor
    
    int flags = fcntl(STDIN_FILENO, F_GETFL, 0);
    fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK);
}

// Fetch CPU usage from /proc/stat with smooth fallback for non-Linux systems
double get_cpu_usage(void) {
    static long long prev_user = 0, prev_nice = 0, prev_sys = 0, prev_idle = 0;
    FILE *f = fopen("/proc/stat", "r");
    if (!f) return 0.25 + 0.25 * sin(time(NULL) * 0.8);

    long long user, nice, sys, idle;
    if (fscanf(f, "cpu %lld %lld %lld %lld", &user, &nice, &sys, &idle) != 4) {
        fclose(f);
        return 0.3;
    }
    fclose(f);

    long long total_diff = (user + nice + sys + idle) - (prev_user + prev_nice + prev_sys + prev_idle);
    long long idle_diff = idle - prev_idle;

    prev_user = user; prev_nice = nice; prev_sys = sys; prev_idle = idle;

    if (total_diff <= 0) return 0.1;
    double usage = 1.0 - ((double)idle_diff / total_diff);
    return usage < 0.0 ? 0.0 : (usage > 1.0 ? 1.0 : usage);
}

// Fetch Memory usage from /proc/meminfo with smooth fallback
double get_mem_usage(void) {
    FILE *f = fopen("/proc/meminfo", "r");
    if (!f) return 0.4 + 0.35 * cos(time(NULL) * 0.4);

    long total = 0, avail = 0;
    char line[256];
    while (fgets(line, sizeof(line), f)) {
        if (sscanf(line, "MemTotal: %ld kB", &total) == 1) {}
        if (sscanf(line, "MemAvailable: %ld kB", &avail) == 1) {}
    }
    fclose(f);

    if (total <= 0) return 0.5;
    double usage = 1.0 - ((double)avail / total);
    return usage < 0.0 ? 0.0 : (usage > 1.0 ? 1.0 : usage);
}

int main(void) {
    srand(time(NULL));
    enable_raw_mode();
    
    int width = 80, height = 24;
    struct winsize ws;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0 && ws.ws_row > 0) {
        width = ws.ws_col;
        height = ws.ws_row;
    }

    // Initialize bioluminescent marine creatures
    Creature creatures[MAX_CREATURES];
    for (int i = 0; i < MAX_CREATURES; i++) {
        creatures[i].x = rand() % width;
        creatures[i].y = (height / 2) + rand() % (height / 2 - 2);
        creatures[i].vx = ((rand() % 100) / 400.0) - 0.12;
        creatures[i].vy = ((rand() % 100) / 1000.0) - 0.05;
        creatures[i].type = rand() % 3;
        creatures[i].phase = (rand() % 100) / 10.0;
        int colors[] = {91, 92, 93, 94, 95, 96, 97}; // Vibrant ANSI color palette
        creatures[i].color = colors[rand() % 7];
    }

    double manual_cpu_boost = 0.0;
    double frame = 0;

    while (1) {
        // Query window size dynamically
        if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0 && ws.ws_row > 0) {
            width = ws.ws_col;
            height = ws.ws_row;
        }

        // Process real-time non-blocking keyboard input
        char ch;
        while (read(STDIN_FILENO, &ch, 1) > 0) {
            if (ch == 'q' || ch == 'Q') exit(0);
            if (ch == 's' || ch == 'S') manual_cpu_boost = 0.8; // Trigger artificial storm
            if (ch == 'f' || ch == 'F') { // Spawn bioluminescent food/plankton
                for (int i = 0; i < MAX_CREATURES; i++) {
                    if (creatures[i].type != 3) {
                        creatures[i].x = rand() % width;
                        creatures[i].y = 4;
                        creatures[i].vx = 0;
                        creatures[i].vy = 0.35;
                        creatures[i].type = 3;
                        break;
                    }
                }
            }
        }

        // Calculate real metrics with manual interactive overrides
        double cpu = get_cpu_usage() + manual_cpu_boost;
        if (cpu > 1.0) cpu = 1.0;
        if (manual_cpu_boost > 0) manual_cpu_boost -= 0.04;

        double mem = get_mem_usage();

        // Create display grids (character grid + color grid)
        char grid[height][width];
        int color_grid[height][width];
        memset(grid, ' ', sizeof(grid));
        memset(color_grid, 0, sizeof(color_grid));

        int surface_y = 5;

        // 1. Draw Surface Waves & Ocean Horizon
        for (int x = 0; x < width; x++) {
            double wave = sin(x * 0.18 + frame * 0.25) * 1.1;
            int wy = surface_y + (int)wave;
            if (wy >= 0 && wy < height) {
                grid[wy][x] = '~';
                color_grid[wy][x] = 36; // Cyan wave
            }
        }

        // 2. High CPU Usage -> Swirling Hurricane Vortex
        if (cpu > 0.2) {
            int eye_x = width / 2 + (int)(sin(frame * 0.08) * (width / 4));
            int eye_y = 3;
            int storm_particles = (int)(cpu * MAX_PARTICLES);
            double speed = 0.25 + cpu * 0.6;

            for (int i = 0; i < storm_particles; i++) {
                double angle = frame * speed + i * (6.28 / storm_particles);
                double r = (i % 8) * (cpu * 1.5) + 1.2;
                int px = eye_x + (int)(cos(angle) * r * 2.2); // Aspect-ratio stretched spiral
                int py = eye_y + (int)(sin(angle) * r * 0.6);

                if (px >= 0 && px < width && py >= 0 && py < height) {
                    char symbol = (i % 2 == 0) ? '@' : '*';
                    if (cpu > 0.65) symbol = (i % 3 == 0) ? '%' : '#';
                    grid[py][px] = symbol;
                    // Red for high intensity storm, Yellow/Cyan for moderate
                    color_grid[py][px] = (cpu > 0.7) ? 91 : (cpu > 0.4 ? 93 : 96);
                }
            }
        }

        // 3. High Memory Pressure -> Deep-Sea Bioluminescent Creatures
        int active_creatures = (int)(mem * MAX_CREATURES);
        if (active_creatures < 4) active_creatures = 4; // Keep ocean populated

        for (int i = 0; i < active_creatures; i++) {
            Creature *c = &creatures[i];

            if (c->type == 3) { // Plankton/Food particle falling down
                c->y += c->vy;
                int px = (int)c->x, py = (int)c->y;
                if (py < height && px >= 0 && px < width) {
                    grid[py][px] = '.';
                    color_grid[py][px] = 93; // Glowing yellow
                } else {
                    c->type = rand() % 3; // Respawn as a creature
                    c->y = (height / 2) + rand() % (height / 2 - 2);
                }
                continue;
            }

            // Creature drift physics
            c->phase += 0.12;
            c->x += c->vx + sin(c->phase) * 0.15;
            c->y += c->vy + cos(c->phase) * 0.08;

            // Boundaries & Screen Wrapping
            if (c->x < 0) c->x = width - 6;
            if (c->x >= width - 5) c->x = 0;
            if (c->y <= surface_y + 1) c->y = height - 3;
            if (c->y >= height - 2) c->y = surface_y + 2;

            int px = (int)c->x;
            int py = (int)c->y;

            // Render Creature ASCII Arts
            if (c->type == 0) { // Bioluminescent Jellyfish
                if (py >= 0 && py < height && px >= 0 && px < width - 2) {
                    grid[py][px] = '('; grid[py][px+1] = 'o'; grid[py][px+2] = ')';
                    color_grid[py][px] = c->color; color_grid[py][px+1] = 97; color_grid[py][px+2] = c->color;
                }
                if (py + 1 < height && px >= 0 && px < width - 2) {
                    grid[py+1][px] = '/'; grid[py+1][px+1] = '|'; grid[py+1][px+2] = '\\';
                    color_grid[py+1][px] = c->color; color_grid[py+1][px+1] = c->color; color_grid[py+1][px+2] = c->color;
                }
            } else if (c->type == 1) { // Deep-Sea Anglerfish with glowing lure
                if (py >= 0 && py < height && px >= 0 && px < width - 5) {
                    grid[py][px] = '*'; grid[py][px+1] = '<'; grid[py][px+2] = '='; grid[py][px+3] = 'O'; grid[py][px+4] = '>';
                    color_grid[py][px] = 93; // Bright yellow bioluminescent lure
                    for (int k = 1; k < 5; k++) color_grid[py][px+k] = c->color;
                }
            } else { // Glowing Deep Plankton / Spores
                if (py >= 0 && py < height && px >= 0 && px < width) {
                    grid[py][px] = (sin(c->phase) > 0) ? '*' : 'o';
                    color_grid[py][px] = c->color;
                }
            }
        }

        // Move cursor home for smooth double-buffered display
        printf("\x1b[H");
        
        // HUD Header
        printf("\x1b[1;37m Ocean Telemetry Engine \x1b[0m | ");
        printf("CPU: \x1b[%sm%5.1f%%\x1b[0m [", cpu > 0.7 ? "91" : "92", cpu * 100.0);
        int cpu_bars = (int)(cpu * 10);
        for (int k = 0; k < 10; k++) printf("%s", k < cpu_bars ? "#" : "-");
        printf("] (Hurricanes) | ");

        printf("MEM: \x1b[%sm%5.1f%%\x1b[0m [", mem > 0.7 ? "95" : "96", mem * 100.0);
        int mem_bars = (int)(mem * 10);
        for (int k = 0; k < 10; k++) printf("%s", k < mem_bars ? "#" : "-");
        printf("] (Bioluminescence)\n");

        printf("\x1b[90m Controls: [F]eed Ocean | [S]torm Burst | [Q]uit\x1b[0m\n");

        // Render buffer grid line by line using fast ANSI color state management
        for (int y = 2; y < height - 1; y++) {
            int current_color = -1;
            for (int x = 0; x < width; x++) {
                int col = color_grid[y][x];
                if (col != current_color) {
                    if (col == 0) printf("\x1b[0m");
                    else printf("\x1b[%dm", col);
                    current_color = col;
                }
                putchar(grid[y][x]);
            }
            printf("\x1b[0m\n");
        }

        fflush(stdout);
        usleep(80000); // Framerate cap (~12.5 FPS)
        frame += 0.5;
    }

    return 0;
}