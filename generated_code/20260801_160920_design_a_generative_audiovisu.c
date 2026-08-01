#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <unistd.h>

#define WIDTH 80
#define HEIGHT 40
#define WAVE_STEPS 4
#define MEM_BLOCKS 16

/* Non-Euclidean spatial transformation (Hyperbolic Poincaré-disk mapping) */
void map_non_euclidean(double x, double y, double *nx, double *ny, double time_val) {
    double r = sqrt(x * x + y * y);
    if (r >= 1.0) r = 0.999;
    /* Warp space based on hyperbolic metric and continuous distortion */
    double factor = (2.0 / (1.0 - r * r)) * (1.0 + 0.2 * sin(time_val + r * 5.0));
    *nx = x * factor;
    *ny = y * factor;
}

int main(void) {
    /* Track live memory allocations (data structure obstacles) */
    void *allocated_nodes[MEM_BLOCKS] = {NULL};
    size_t node_sizes[MEM_BLOCKS] = {0};
    
    /* Fluid grid buffer & Sound wave reflection field */
    double fluid_u[HEIGHT][WIDTH] = {0};
    double fluid_v[HEIGHT][WIDTH] = {0};
    double wave_field[HEIGHT][WIDTH] = {0};

    /* Enable raw terminal rendering setup */
    printf("\033[2J\033[?25l"); /* Clear screen & hide cursor */

    double t = 0.0;
    while (1) {
        t += 0.05;

        /* 1. Dynamic Live Memory Map Updates */
        int slot = rand() % MEM_BLOCKS;
        if (allocated_nodes[slot]) {
            free(allocated_nodes[slot]);
            allocated_nodes[slot] = NULL;
            node_sizes[slot] = 0;
        } else {
            node_sizes[slot] = (size_t)(128 + (rand() % 2048));
            allocated_nodes[slot] = malloc(node_sizes[slot]);
        }

        /* 2. Audio-Visual Wave Injection from Dynamic Memory Addresses */
        for (int i = 0; i < MEM_BLOCKS; i++) {
            if (allocated_nodes[i]) {
                uintptr_t addr = (uintptr_t)allocated_nodes[i];
                int obstacle_x = (int)((addr >> 4) % (WIDTH - 4)) + 2;
                int obstacle_y = (int)((addr >> 8) % (HEIGHT - 4)) + 2;
                double audio_freq = 220.0 + (double)(node_sizes[i] % 880);
                
                /* Inject refractive acoustic energy into fluid */
                wave_field[obstacle_y][obstacle_x] += sin(t * audio_freq * 0.01) * 2.0;
            }
        }

        /* 3. Non-Euclidean Fluid & Wave Refraction Dynamics */
        for (int y = 1; y < HEIGHT - 1; y++) {
            for (int x = 1; x < WIDTH - 1; x++) {
                /* Normalize coordinates to [-1, 1] disk */
                double cx = (double)(x - WIDTH / 2) / (WIDTH / 2);
                double cy = (double)(y - HEIGHT / 2) / (HEIGHT / 2);
                double nx, ny;
                map_non_euclidean(cx, cy, &nx, &ny, t);

                /* Compute warped wave Laplacian for non-Euclidean fluid medium */
                double laplacian = wave_field[y+1][x] + wave_field[y-1][x] +
                                   wave_field[y][x+1] + wave_field[y][x-1] - 4.0 * wave_field[y][x];
                
                fluid_v[y][x] += laplacian * 0.1;
                fluid_u[y][x] += fluid_v[y][x] * 0.5;
                wave_field[y][x] = fluid_u[y][x] * 0.96; /* Acoustic decay */
            }
        }

        /* 4. Render Spatial Simulation & Synthetic Audio Cues to Terminal */
        printf("\033[H"); /* Reset cursor to top-left */
        for (int y = 0; y < HEIGHT; y++) {
            for (int x = 0; x < WIDTH; x++) {
                double val = wave_field[y][x];
                
                /* Check if current cell contains a floating memory obstacle */
                int is_obstacle = 0;
                for (int i = 0; i < MEM_BLOCKS; i++) {
                    if (allocated_nodes[i]) {
                        uintptr_t addr = (uintptr_t)allocated_nodes[i];
                        int ox = (int)((addr >> 4) % (WIDTH - 4)) + 2;
                        int oy = (int)((addr >> 8) % (HEIGHT - 4)) + 2;
                        if (abs(x - ox) <= 1 && abs(y - oy) <= 1) {
                            is_obstacle = 1;
                            break;
                        }
                    }
                }

                if (is_obstacle) {
                    /* Memory structure obstacle - bright yellow refraction node */
                    printf("\033[38;2;255;220;50m█");
                } else {
                    /* Non-Euclidean sound wave fluid continuum - blue/purple gradient */
                    int r_col = (int)(fmin(255, fmax(0, 50 + val * 120)));
                    int g_col = (int)(fmin(255, fmax(0, 30 + val * 60)));
                    int b_col = (int)(fmin(255, fmax(0, 150 + val * 200)));
                    
                    char ch = ' ';
                    if (fabs(val) > 1.2) ch = '#';
                    else if (fabs(val) > 0.8) ch = '*';
                    else if (fabs(val) > 0.4) ch = '~';
                    else if (fabs(val) > 0.1) ch = '.';
                    
                    printf("\033[38;2;%d;%d;%dm%c", r_col, g_col, b_col, ch);
                }
            }
            printf("\n");
        }

        /* Ambient audio representation tone via bell pulse when energy spikes */
        if (fabs(wave_field[HEIGHT/2][WIDTH/2]) > 1.5) {
            printf("\a");
            fflush(stdout);
        }

        usleep(30000); /* ~33 FPS simulation loop */
    }

    /* Cleanup remaining allocations */
    for (int i = 0; i < MEM_BLOCKS; i++) {
        if (allocated_nodes[i]) free(allocated_nodes[i]);
    }

    return 0;
}