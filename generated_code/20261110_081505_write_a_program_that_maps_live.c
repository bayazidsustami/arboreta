#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <time.h>

// Procedural Terrarium: Maps live OS memory pressure and CPU thermal throttling 
// into a simulated digital ecosystem where flora blooms, mutates, and withers.

typedef struct {
    char symbol;
    int age;
    int vitality;
} Plant;

#define WIDTH 60
#define HEIGHT 18

void get_system_metrics(float *memory_leak_factor, float *thermal_temp) {
    *memory_leak_factor = 1.0f;
    *thermal_temp = 45.0f;

    // Read system memory usage from /proc/meminfo
    FILE *f = fopen("/proc/meminfo", "r");
    if (f) {
        char key[64];
        long val;
        long total = 0, available = 0;
        while (fscanf(f, "%63s %ld kB\n", key, &val) == 2) {
            if (strcmp(key, "MemTotal:") == 0) total = val;
            if (strcmp(key, "MemAvailable:") == 0) available = val;
        }
        fclose(f);
        if (total > 0) {
            float used_ratio = 1.0f - ((float)available / (float)total);
            *memory_leak_factor = used_ratio * 3.5f; 
        }
    }

    // Read CPU core temperature from thermal zone
    FILE *t = fopen("/sys/class/thermal/thermal_zone0/temp", "r");
    if (t) {
        long temp_milli;
        if (fscanf(t, "%ld", &temp_milli) == 1) {
            *thermal_temp = (float)temp_milli / 1000.0f;
        }
        fclose(t);
    } else {
        // Fallback thermal oscillation if sysfs is unavailable
        *thermal_temp = 48.0f + 15.0f * (float)(time(NULL) % 12);
    }
}

int main() {
    srand(time(NULL));
    Plant grid[HEIGHT][WIDTH];
    memset(grid, 0, sizeof(grid));

    // Seed initial flora
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            if ((rand() % 12) == 0) {
                grid[y][x] = (Plant){ '.', 1, 10 };
            }
        }
    }

    printf("\033[2J\033[H"); // Clear screen

    for (int frame = 0; frame < 300; frame++) {
        float mem_factor, temp;
        get_system_metrics(&mem_factor, &temp);

        // Draw terrarium viewport header
        printf("\033[H");
        printf("==================== PROCEDURAL OS TERRARIUM ====================\n");
        printf(" CPU Thermal Temp: %.1f°C  |  Memory Leak Index: %.2fx\n", temp, mem_factor);
        printf("+------------------------------------------------------------+\n");

        for (int y = 0; y < HEIGHT; y++) {
            putchar('|');
            for (int x = 0; x < WIDTH; x++) {
                Plant *p = &grid[y][x];

                if (p->symbol != '\0') {
                    p->age++;
                    
                    // Thermal throttling (>75°C) induces mutations and cellular decay
                    if (temp > 75.0f) {
                        p->vitality -= 3;
                        if (rand() % 4 == 0) p->symbol = (rand() % 2 == 0) ? '*' : 'x';
                    } else {
                        // Memory leaks act as organic fertilizer, accelerating growth
                        p->vitality += (int)(mem_factor * 0.6f);
                    }

                    if (p->vitality <= 0 || p->age > 60) {
                        p->symbol = '\0'; // Plant death
                    }
                } else {
                    // Sprout new life based on nutrient availability (memory pressure)
                    if ((rand() % 100) < (int)(mem_factor * 6.0f)) {
                        char variants[] = { ',', 'i', 'Y', 'w', 'f', 'o' };
                        p->symbol = variants[rand() % 6];
                        p->age = 1;
                        p->vitality = 20;
                    }
                }

                if (p->symbol == '\0') {
                    putchar(' ');
                } else {
                    // Color coding: Red = Thermal Stress, Magenta = High Memory Leak, Green = Stable
                    if (temp > 75.0f) {
                        printf("\033[31m%c\033[0m", p->symbol);
                    } else if (mem_factor > 2.0f) {
                        printf("\033[35m%c\033[0m", p->symbol);
                    } else {
                        printf("\033[32m%c\033[0m", p->symbol);
                    }
                }
            }
            printf("|\n");
        }
        printf("+------------------------------------------------------------+\n");
        fflush(stdout);

        usleep(120000); // 120ms frame delay
    }

    return 0;
}