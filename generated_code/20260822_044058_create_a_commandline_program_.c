#define _POSIX_C_SOURCE 199309L
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define WIDTH 80
#define HEIGHT 30

/* Unicode characters representing forest density/decay stages */
static const char *TREE_STAGES[] = {
    " ",       /* Empty / Dead */
    "\033[32m\u25B2\033[0m", /* Healthy sprout: Green Triangle (▲) */
    "\033[32m\u2663\033[0m", /* Lush tree: Green Club (♣) */
    "\033[33m\u2663\033[0m", /* Autumn tree: Yellow Club (♣) */
    "\033[31m\u25B2\033[0m", /* Decaying/burning tree: Red Triangle (▲) */
    "\033[90m\u253C\033[0m"  /* Dead stump/ash: Gray Cross (┼) */
};

#define MAX_STAGE 5

/*
 * Reads CPU energy metrics from Linux sysfs / Powercap RAPL.
 * Falls back to reading CPU usage from /proc/stat if RAPL is unavailable.
 */
static uint64_t get_cpu_power_seed(void) {
    FILE *fp = fopen("/sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj", "r");
    if (fp) {
        uint64_t energy = 0;
        if (fscanf(fp, "%lu", &energy) == 1) {
            fclose(fp);
            return energy;
        }
        fclose(fp);
    }

    /* Fallback: Read total CPU work time from /proc/stat */
    fp = fopen("/proc/stat", "r");
    if (fp) {
        long unsigned user, nice, system, idle;
        if (fscanf(fp, "cpu %lu %lu %lu %lu", &user, &nice, &system, &idle) == 4) {
            fclose(fp);
            return (uint64_t)(user + nice + system);
        }
        fclose(fp);
    }

    /* Emergency fallback: time seed */
    return (uint64_t)time(NULL);
}

/* Linear Congruential Generator seeded dynamically by CPU power metrics */
static uint32_t lcg_rand(uint64_t *state) {
    *state = (*state * 6364136223846793005ULL) + 1442695040888963407ULL;
    return (uint32_t)(*state >> 32);
}

/* 2D Fractal Noise generator to shape initial forest geography */
static float fractal_noise(int x, int y, uint64_t seed) {
    uint64_t state = seed + (x * 374761393) + (y * 668265263);
    float n1 = (lcg_rand(&state) % 1000) / 1000.0f;
    state += (x / 2 * 1442695040) + (y / 2 * 6364136223);
    float n2 = (lcg_rand(&state) % 1000) / 1000.0f;
    return (n1 * 0.6f) + (n2 * 0.4f);
}

int main(void) {
    int grid[HEIGHT][WIDTH];
    int next_grid[HEIGHT][WIDTH];

    /* Sample initial CPU energy reading to seed grid generation */
    uint64_t power_seed = get_cpu_power_seed();
    
    /* Initialize grid using dynamic fractal noise */
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            float val = fractal_noise(x, y, power_seed);
            if (val > 0.65f) grid[y][x] = 2;       /* Lush tree */
            else if (val > 0.45f) grid[y][x] = 1;  /* Young tree */
            else grid[y][x] = 0;                   /* Empty land */
        }
    }

    /* Hide cursor and clear terminal */
    printf("\033[?25l\033[2J");

    while (1) {
        /* Read live energy input per tick to influence dynamic decay/growth rate */
        uint64_t live_power = get_cpu_power_seed();
        uint64_t rng_state = live_power;
        
        /* Power delta drives environmental stress factor (higher power = faster decay) */
        int decay_stress = (int)(live_power % 100);

        /* Render forest matrix */
        printf("\033[H"); /* Move cursor to home */
        printf("\033[1;36m=== LIVE CPU POWER CELLULAR AUTOMATON FOREST ===\033[0m\n");
        printf("Energy Seed Signal: %lu uJ | Thermal Stress: %d%%\n\n", live_power, decay_stress);

        for (int y = 0; y < HEIGHT; y++) {
            for (int x = 0; x < WIDTH; x++) {
                int stage = grid[y][x];
                printf("%s", TREE_STAGES[stage]);
            }
            printf("\n");
        }

        /* Cellular Automaton Rules Engine */
        for (int y = 0; y < HEIGHT; y++) {
            for (int x = 0; x < WIDTH; x++) {
                /* Count active tree neighbors */
                int neighbors = 0;
                for (int dy = -1; dy <= 1; dy++) {
                    for (int dx = -1; dx <= 1; dx++) {
                        if (dx == 0 && dy == 0) continue;
                        int ny = y + dy, nx = x + dx;
                        if (ny >= 0 && ny < HEIGHT && nx >= 0 && nx < WIDTH) {
                            if (grid[ny][nx] >= 1 && grid[ny][nx] <= 3) neighbors++;
                        }
                    }
                }

                int current = grid[y][x];
                int next = current;
                uint32_t r = lcg_rand(&rng_state) % 100;

                if (current == 0) {
                    /* Sprout growth influenced by nearby trees and low heat stress */
                    if (neighbors >= 2 && r < (unsigned)(20 - (decay_stress / 10))) {
                        next = 1;
                    }
                } else if (current == 1) {
                    /* Young tree grows into lush tree */
                    if (r < 40) next = 2;
                } else if (current == 2) {
                    /* Decay rule: High CPU activity induces heat decay (lush -> autumn) */
                    if (r < (unsigned)(5 + (decay_stress / 5))) {
                        next = 3;
                    }
                } else if (current == 3) {
                    /* Autumn trees turn to burning/decaying stage */
                    if (r < 30) next = 4;
                } else if (current == 4) {
                    /* Burning trees collapse into stumps */
                    if (r < 50) next = 5;
                } else if (current == 5) {
                    /* Ash dissolves into empty land */
                    if (r < 20) next = 0;
                }

                next_grid[y][x] = next;
            }
        }

        /* Copy back next generation */
        memcpy(grid, next_grid, sizeof(grid));

        /* Frame timing (~100ms per step) */
        struct timespec ts = {0, 100000000L};
        nanosleep(&ts, NULL);
    }

    /* Restore cursor (unreachable loop exit) */
    printf("\033[?25h");
    return 0;
}