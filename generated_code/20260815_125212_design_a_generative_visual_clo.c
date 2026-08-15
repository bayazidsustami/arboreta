#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>
#include <unistd.h>

#define WIDTH 80
#define HEIGHT 40
#define NUM_SPECIES 3

// ASCII shade palette representing lichen density on the rock face
const char *PALETTE = " .':;o*x%#@";

typedef struct {
    double energy;      // Density / growth level
    int species;        // 0: Hours (Golden), 1: Minutes (Cyan/Green), 2: Seconds (Magenta)
    double age;         // Age factor controlling decay
} Cell;

Cell grid[HEIGHT][WIDTH];
Cell next_grid[HEIGHT][WIDTH];

// Initialize rock texture noise and seed lichen colonies
void init_simulation() {
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            grid[y][x].energy = ((double)rand() / RAND_MAX) * 0.05; // Base rock grain
            grid[y][x].species = -1;
            grid[y][x].age = 0.0;
        }
    }
}

// Check if a point falls within digits representing the target value
int is_in_digit(int x, int y, int val, int x_offset, int y_offset) {
    // 3x5 font representations for numbers 0-9
    static const unsigned short font[10] = {
        0x7B6F, // 0
        0x2C97, // 1
        0x73E7, // 2
        0x73CF, // 3
        0x5BC9, // 4
        0x79CF, // 5
        0x79EF, // 6
        0x7249, // 7
        0x7BEF, // 8
        0x7BCE  // 9
    };
    
    int d1 = val / 10;
    int d2 = val % 10;
    
    // Check digit 1
    int dx = x - x_offset;
    int dy = y - y_offset;
    if (dx >= 0 && dx < 3 && dy >= 0 && dy < 5) {
        int bit = (4 - dy) * 3 + (2 - dx);
        if ((font[d1] >> bit) & 1) return 1;
    }
    
    // Check digit 2
    dx = x - (x_offset + 4);
    if (dx >= 0 && dx < 3 && dy >= 0 && dy < 5) {
        int bit = (4 - dy) * 3 + (2 - dx);
        if ((font[d2] >> bit) & 1) return 1;
    }
    
    return 0;
}

void step_simulation() {
    time_t rawtime;
    struct tm *timeinfo;
    time(&rawtime);
    timeinfo = localtime(&rawtime);

    int hours = timeinfo->tm_hour;
    int mins = timeinfo->tm_min;
    int secs = timeinfo->tm_sec;

    // Center digits across the screen
    int y_center = HEIGHT / 2 - 2;
    int h_x = WIDTH / 2 - 14;
    int m_x = WIDTH / 2 - 3;
    int s_x = WIDTH / 2 + 8;

    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            // Determine nutrient target zones based on current time digits
            int target_species = -1;
            if (is_in_digit(x, y, hours, h_x, y_center)) target_species = 0;
            else if (is_in_digit(x, y, mins, m_x, y_center)) target_species = 1;
            else if (is_in_digit(x, y, secs, s_x, y_center)) target_species = 2;

            // Calculate local neighborhood state (growth diffusion & cross-pollination)
            double avg_energy = 0.0;
            int neighbor_species_count[NUM_SPECIES] = {0};
            int active_neighbors = 0;

            for (int dy = -1; dy <= 1; dy++) {
                for (int dx = -1; dx <= 1; dx++) {
                    if (dx == 0 && dy == 0) continue;
                    int nx = (x + dx + WIDTH) % WIDTH;
                    int ny = (y + dy + HEIGHT) % HEIGHT;

                    avg_energy += grid[ny][nx].energy;
                    if (grid[ny][nx].species >= 0) {
                        neighbor_species_count[grid[ny][nx].species]++;
                        active_neighbors++;
                    }
                }
            }
            avg_energy /= 8.0;

            Cell current = grid[y][x];
            Cell next = current;

            // Spontaneous growth at time-digit attractors
            if (target_species != -1) {
                if (current.species == -1 || current.species == target_species) {
                    next.species = target_species;
                    next.energy += 0.25;
                    next.age = 0;
                } else {
                    // Hybrid decay/cross-pollination when time shifts
                    next.energy -= 0.15;
                    if (next.energy <= 0.05) {
                        next.species = target_species;
                        next.age = 0;
                    }
                }
            } else {
                // Organic radial expansion (cellular automata growth)
                if (current.species == -1 && active_neighbors > 2) {
                    // Pick dominant neighbor species (cross-pollination)
                    int max_c = -1, dom_sp = -1;
                    for (int s = 0; s < NUM_SPECIES; s++) {
                        if (neighbor_species_count[s] > max_c) {
                            max_c = neighbor_species_count[s];
                            dom_sp = s;
                        }
                    }
                    if (((double)rand() / RAND_MAX) < 0.2) {
                        next.species = dom_sp;
                        next.energy = avg_energy * 0.8;
                    }
                } else if (current.species >= 0) {
                    // Organic growth/decay kinetics
                    next.energy += (avg_energy - current.energy) * 0.3;
                    next.age += 0.05;
                    // Natural die-back away from target zones
                    next.energy -= 0.04 + (next.age * 0.005);
                }
            }

            // Cap density range
            if (next.energy > 1.0) next.energy = 1.0;
            if (next.energy < 0.0) {
                next.energy = 0.0;
                next.species = -1;
            }

            next_grid[y][x] = next;
        }
    }

    // Double buffering swap
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            grid[y][x] = next_grid[y][x];
        }
    }
}

void render() {
    // Clear screen and reset cursor
    printf("\033[H");

    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            Cell c = grid[y][x];
            int char_idx = (int)(c.energy * 10.0);
            if (char_idx > 10) char_idx = 10;
            if (char_idx < 0) char_idx = 0;

            char symbol = PALETTE[char_idx];

            // Color selection based on species (Hours: Yellow/Gold, Mins: Cyan, Secs: Magenta)
            if (c.species == 0) {
                printf("\033[1;33m%c\033[0m", symbol); // Gold / Hours
            } else if (c.species == 1) {
                printf("\033[1;36m%c\033[0m", symbol); // Cyan / Minutes
            } else if (c.species == 2) {
                printf("\033[1;35m%c\033[0m", symbol); // Magenta / Seconds
            } else {
                printf("\033[0;30m%c\033[0m", symbol); // Dark Rock Surface
            }
        }
        printf("\n");
    }
}

int main() {
    srand((unsigned int)time(NULL));
    init_simulation();

    // Hide cursor and clear terminal space
    printf("\033[?25l\033[2J");

    while (1) {
        step_simulation();
        render();
        usleep(80000); // ~12 FPS simulation tick
    }

    // Restore cursor on exit
    printf("\033[?25h");
    return 0;
}