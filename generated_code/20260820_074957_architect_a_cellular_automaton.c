#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>

#define WIDTH 60
#define HEIGHT 20
#define GENERATIONS 40

/* Concrete poetry frame to morph into: A silhouette of an hourglass */
static const char *POEM_MASK[HEIGHT] = {
    "************************************************************",
    " ********************************************************** ",
    "  ********************************************************  ",
    "   ******************************************************   ",
    "    ****************************************************    ",
    "     **************************************************     ",
    "      ************************************************      ",
    "       **********************************************       ",
    "        ********************************************        ",
    "         ******************************************         ",
    "         ******************************************         ",
    "        ********************************************        ",
    "       **********************************************       ",
    "      ************************************************      ",
    "     **************************************************     ",
    "    ****************************************************    ",
    "   ******************************************************   ",
    "  ********************************************************  ",
    " ********************************************************** ",
    "************************************************************"
};

/* Phonetic stress map: Vowels represent primary/secondary stress drivers */
int extract_stress_energy(const char *phrase) {
    int energy = 0;
    for (int i = 0; phrase[i] != '\0'; i++) {
        char c = tolower((unsigned char)phrase[i]);
        if (c == 'a' || c == 'e' || c == 'i' || c == 'o' || c == 'u') {
            energy += (i % 2 == 0) ? 2 : 1; /* Alternating stress weight */
        } else if (isalpha((unsigned char)c)) {
            energy += 1;
        }
    }
    return energy;
}

int main(void) {
    const char *whisper = "soft whispers drift through silent shadows of time";
    int stress_energy = extract_stress_energy(whisper);
    
    int grid[HEIGHT][WIDTH];
    int next_grid[HEIGHT][WIDTH];
    
    /* Seed 1D initial state using phonetic stress values, centered in row 0 */
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            grid[y][x] = 0;
        }
    }
    for (int x = 0; x < WIDTH; x++) {
        grid[0][x] = ((x + stress_energy) * 2654435761u) % 2;
    }

    /* ASCII shade spectrum from dynamic entropy to static poem structure */
    const char *shades = " .:-=+*#%@";

    for (int gen = 0; gen < GENERATIONS; gen++) {
        /* Clear terminal screen using ANSI escape code */
        printf("\033[H\033[J");
        
        /* Render current cellular automata / concrete poetry state */
        for (int y = 0; y < HEIGHT; y++) {
            for (int x = 0; x < WIDTH; x++) {
                int val = grid[y][x];
                
                /* As generations progress, force state toward the concrete poem mask */
                if (gen > 15 && POEM_MASK[y][x] == ' ') {
                    /* Fade out cells outside the poetry silhouette */
                    val = 0;
                } else if (gen > 25 && POEM_MASK[y][x] == '*') {
                    /* Crystallize cells inside the poetry silhouette */
                    val = 1;
                }

                if (val == 1) {
                    int char_idx = (x + y + gen) % 8 + 1;
                    putchar(shades[char_idx]);
                } else {
                    putchar(' ');
                }
            }
            putchar('\n');
        }

        /* Compute next generation using Rule 30 / Game of Life hybrid step */
        for (int y = 0; y < HEIGHT; y++) {
            for (int x = 0; x < WIDTH; x++) {
                int left   = grid[y][(x - 1 + WIDTH) % WIDTH];
                int center = grid[y][x];
                int right  = grid[y][(x + 1) % WIDTH];
                
                /* Elementary CA Rule 30 derivation for evolution */
                int rule30 = left ^ (center | right);
                
                /* Neighbor count from adjacent vertical cells */
                int up   = grid[(y - 1 + HEIGHT) % HEIGHT][x];
                int down = grid[(y + 1) % HEIGHT][x];
                int neighbors = left + right + up + down;

                /* Hybrid mutation logic */
                if (center == 1) {
                    next_grid[y][x] = (neighbors == 2 || neighbors == 3 || rule30) ? 1 : 0;
                } else {
                    next_grid[y][x] = (neighbors == 3 || rule30) ? 1 : 0;
                }
            }
        }

        /* Copy back to active grid */
        for (int y = 0; y < HEIGHT; y++) {
            for (int x = 0; x < WIDTH; x++) {
                grid[y][x] = next_grid[y][x];
            }
        }

        usleep(100000); /* 100ms frame delay */
    }

    return 0;
}