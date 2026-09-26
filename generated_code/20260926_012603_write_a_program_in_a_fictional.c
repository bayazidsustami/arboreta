#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

#ifdef _WIN32
#include <windows.h>
#define SLEEP_MS(ms) Sleep(ms)
#else
#include <unistd.h>
#define SLEEP_MS(ms) usleep((ms) * 1000)
#endif

/* 
 * TYPO-ASM Virtual Machine & Living Typographic Ecosystem
 * Instructions:
 * 0: INIT - Initialize ecosystem grid
 * 1: RPRD - Sample atmospheric pressure simulation (sine/noise function)
 * 2: EVOL - Evolve typography based on pressure variance
 * 3: RNDR - Render living text ecosystem to stdout
 * 4: LOP  - Loop back to RPRD
 * 5: HALT - End simulation
 */

#define WIDTH 44
#define HEIGHT 16

typedef enum {
    OP_INIT = 0,
    OP_RPRD,
    OP_EVOL,
    OP_RNDR,
    OP_LOP,
    OP_HALT
} Opcode;

typedef struct {
    Opcode op;
    int arg;
} Instruction;

char grid[HEIGHT][WIDTH];
double pressure = 1013.25;
int generation = 0;

void execute_vm() {
    Instruction program[] = {
        {OP_INIT, 0},
        {OP_RPRD, 0},
        {OP_EVOL, 0},
        {OP_RNDR, 0},
        {OP_LOP,  1}, 
        {OP_HALT, 0}
    };

    int pc = 0;
    int running = 1;
    
    while (running) {
        Instruction ins = program[pc];
        switch (ins.op) {
            case OP_INIT: {
                for (int y = 0; y < HEIGHT; y++) {
                    for (int x = 0; x < WIDTH; x++) {
                        grid[y][x] = ' ';
                    }
                }
                pc++;
                break;
            }
            case OP_RPRD: {
                // Simulate atmospheric pressure fluctuation combining real-time ticks
                time_t now = time(NULL);
                double t = (double)now;
                pressure = 1013.25 + 12.5 * sin(t * 0.15) + 4.2 * cos(t * 0.04);
                pc++;
                break;
            }
            case OP_EVOL: {
                generation++;
                int activity = (int)(fabs(pressure - 1013.25)) + 1;
                for (int y = 0; y < HEIGHT; y++) {
                    for (int x = 0; x < WIDTH; x++) {
                        if ((rand() % 100) < activity * 2) {
                            char flora[] = {'.', ':', ';', 'o', 'O', '*', '~', '"', 'v', '^', '#'};
                            grid[y][x] = flora[rand() % 11];
                        } else if (grid[y][x] != ' ') {
                            if (rand() % 8 == 0) grid[y][x] = ' ';
                        }
                    }
                }
                pc++;
                break;
            }
            case OP_RNDR: {
                printf("\033[H\033[J");
                printf("=== TYPO-ECOSYSTEM [TYPO-ASM RUNTIME] ===\n");
                printf("Generation: %d | Pressure: %.2f hPa\n", generation, pressure);
                printf("+--------------------------------------------+\n");
                for (int y = 0; y < HEIGHT; y++) {
                    putchar('|');
                    for (int x = 0; x < WIDTH; x++) {
                        putchar(grid[y][x]);
                    }
                    printf("|\n");
                }
                printf("+--------------------------------------------+\n");
                SLEEP_MS(150);
                pc++;
                break;
            }
            case OP_LOP: {
                if (generation < 60) {
                    pc = ins.arg;
                } else {
                    running = 0;
                }
                break;
            }
            case OP_HALT:
            default:
                running = 0;
                break;
        }
    }
}

int main() {
    srand((unsigned int)time(NULL));
    execute_vm();
    printf("Ecosystem cycle completed.\n");
    return 0;
}