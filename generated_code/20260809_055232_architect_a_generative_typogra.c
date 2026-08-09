#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

#define WIDTH 80
#define HEIGHT 40
#define MAX_SPORES 500
#define MAX_HYPHAE 2000

typedef struct {
    float x, y;
    float dx, dy;
    float energy;
    int active;
} Hypha;

typedef struct {
    float x, y;
    float vx, vy;
    int life;
} Spore;

static float nutrient_grid[HEIGHT][WIDTH];
static char display_grid[HEIGHT][WIDTH];
static Hypha hyphae[MAX_HYPHAE];
static int hypha_count = 0;
static Spore spores[MAX_SPORES];
static int spore_count = 0;

// Minimal 5x5 font bitmaps for ASCII letter nutrient maps (A-Z)
static const unsigned char font_5x5[26][5] = {
    {0x0E, 0x11, 0x1F, 0x11, 0x11}, // A
    {0x1E, 0x11, 0x1E, 0x11, 0x1E}, // B
    {0x0E, 0x11, 0x10, 0x11, 0x0E}, // C
    {0x1C, 0x12, 0x11, 0x12, 0x1C}, // D
    {0x1F, 0x10, 0x1E, 0x10, 0x1F}, // E
    {0x1F, 0x10, 0x1E, 0x10, 0x10}, // F
    {0x0E, 0x11, 0x13, 0x11, 0x0F}, // G
    {0x11, 0x11, 0x1F, 0x11, 0x11}, // H
    {0x0E, 0x04, 0x04, 0x04, 0x0E}, // I
    {0x07, 0x02, 0x02, 0x12, 0x0C}, // J
    {0x11, 0x12, 0x1C, 0x12, 0x11}, // K
    {0x10, 0x10, 0x10, 0x10, 0x1F}, // L
    {0x11, 0x1B, 0x15, 0x11, 0x11}, // M
    {0x11, 0x19, 0x15, 0x13, 0x11}, // N
    {0x0E, 0x11, 0x11, 0x11, 0x0E}, // O
    {0x1E, 0x11, 0x1E, 0x10, 0x10}, // P
    {0x0E, 0x11, 0x15, 0x12, 0x0D}, // Q
    {0x1E, 0x11, 0x1E, 0x14, 0x11}, // R
    {0x0F, 0x10, 0x0E, 0x01, 0x1E}, // S
    {0x1F, 0x04, 0x04, 0x04, 0x04}, // T
    {0x11, 0x11, 0x11, 0x11, 0x0E}, // U
    {0x11, 0x11, 0x11, 0x0A, 0x04}, // V
    {0x11, 0x11, 0x15, 0x1B, 0x11}, // W
    {0x11, 0x0A, 0x04, 0x0A, 0x11}, // X
    {0x11, 0x11, 0x0A, 0x04, 0x04}, // Y
    {0x1F, 0x02, 0x04, 0x08, 0x1F}  // Z
};

// Converts input prose characters into spatial nutrient concentrations & spawns initial mycelial tips
void deposit_prose_nutrients(const char *prose) {
    int cursor_x = 5;
    int cursor_y = 5;

    for (size_t i = 0; i < strlen(prose); i++) {
        char c = prose[i];
        if (c >= 'a' && c <= 'z') c -= 32;

        if (c >= 'A' && c <= 'Z') {
            int idx = c - 'A';
            for (int r = 0; r < 5; r++) {
                for (int col = 0; col < 5; col++) {
                    if ((font_5x5[idx][r] >> (4 - col)) & 1) {
                        int gx = cursor_x + col;
                        int gy = cursor_y + r;
                        if (gx < WIDTH && gy < HEIGHT) {
                            nutrient_grid[gy][gx] += 2.5f;

                            // Seed active hyphae on glyph contours
                            if (hypha_count < MAX_HYPHAE && (rand() % 3 == 0)) {
                                float angle = ((float)rand() / RAND_MAX) * 2.0f * 3.14159f;
                                hyphae[hypha_count++] = (Hypha){
                                    .x = (float)gx,
                                    .y = (float)gy,
                                    .dx = cosf(angle) * 0.8f,
                                    .dy = sinf(angle) * 0.8f,
                                    .energy = 1.0f,
                                    .active = 1
                                };
                            }
                        }
                    }
                }
            }
        }

        cursor_x += 6;
        if (cursor_x + 6 >= WIDTH) {
            cursor_x = 5;
            cursor_y += 8;
            if (cursor_y + 5 >= HEIGHT) break;
        }
    }
}

// Diffuses and decays nutrients over time across the 2D matrix
void update_nutrients(void) {
    static float next_grid[HEIGHT][WIDTH];
    for (int y = 1; y < HEIGHT - 1; y++) {
        for (int x = 1; x < WIDTH - 1; x++) {
            float avg = (nutrient_grid[y-1][x] + nutrient_grid[y+1][x] +
                         nutrient_grid[y][x-1] + nutrient_grid[y][x+1]) * 0.25f;
            next_grid[y][x] = (nutrient_grid[y][x] * 0.8f + avg * 0.2f) * 0.98f;
        }
    }
    memcpy(nutrient_grid, next_grid, sizeof(nutrient_grid));
}

// Expands hyphae branches driven by localized nutrient gradients and branching conditions
void grow_mycelium(void) {
    int current_hyphae = hypha_count;
    for (int i = 0; i < current_hyphae; i++) {
        if (!hyphae[i].active) continue;

        int gx = (int)hyphae[i].x;
        int gy = (int)hyphae[i].y;

        if (gx >= 0 && gx < WIDTH && gy >= 0 && gy < HEIGHT) {
            display_grid[gy][gx] = '~'; // Render hyphal thread

            // Absorb nutrients from the current substrate location
            float nutrient = nutrient_grid[gy][gx];
            hyphae[i].energy += nutrient * 0.5f;
            nutrient_grid[gy][gx] *= 0.3f;

            // High nutrient hotspots trigger airborne spore bursts
            if (nutrient > 1.8f && spore_count < MAX_SPORES) {
                float sp_angle = ((float)rand() / RAND_MAX) * 2.0f * 3.14159f;
                spores[spore_count++] = (Spore){
                    .x = hyphae[i].x,
                    .y = hyphae[i].y,
                    .vx = cosf(sp_angle) * 1.5f,
                    .vy = sinf(sp_angle) * 1.5f,
                    .life = 10 + rand() % 15
                };
            }
        }

        // Calculate gradient directional bias towards richer nutrient regions
        float grad_x = 0.0f, grad_y = 0.0f;
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                int nx = gx + dx;
                int ny = gy + dy;
                if (nx >= 0 && nx < WIDTH && ny >= 0 && ny < HEIGHT) {
                    grad_x += dx * nutrient_grid[ny][nx];
                    grad_y += dy * nutrient_grid[ny][nx];
                }
            }
        }

        // Steer growth vector based on gradient field + random exploration momentum
        hyphae[i].dx = hyphae[i].dx * 0.7f + grad_x * 0.2f + (((float)rand() / RAND_MAX) - 0.5f) * 0.3f;
        hyphae[i].dy = hyphae[i].dy * 0.7f + grad_y * 0.2f + (((float)rand() / RAND_MAX) - 0.5f) * 0.3f;

        hyphae[i].x += hyphae[i].dx;
        hyphae[i].y += hyphae[i].dy;
        hyphae[i].energy -= 0.05f;

        // High energy permits hypha to split and branch orthogonally
        if (hyphae[i].energy > 2.0f && hypha_count < MAX_HYPHAE) {
            hyphae[i].energy *= 0.5f;
            hyphae[hypha_count++] = (Hypha){
                .x = hyphae[i].x,
                .y = hyphae[i].y,
                .dx = -hyphae[i].dy,
                .dy = hyphae[i].dx,
                .energy = hyphae[i].energy,
                .active = 1
            };
        }

        // Terminate hypha when depleted or out-of-bounds
        if (hyphae[i].energy <= 0.0f || hyphae[i].x < 0 || hyphae[i].x >= WIDTH ||
            hyphae[i].y < 0 || hyphae[i].y >= HEIGHT) {
            hyphae[i].active = 0;
        }
    }
}

// Simulates airborne spore dispersion and distant germination
void update_spores(void) {
    for (int i = 0; i < spore_count; i++) {
        if (spores[i].life <= 0) continue;

        spores[i].x += spores[i].vx;
        spores[i].y += spores[i].vy;
        spores[i].life--;

        int sx = (int)spores[i].x;
        int sy = (int)spores[i].y;

        if (sx >= 0 && sx < WIDTH && sy >= 0 && sy < HEIGHT) {
            display_grid[sy][sx] = '*'; // Render spore particle

            // Germinate new hypha node upon settling
            if (spores[i].life == 0 && hypha_count < MAX_HYPHAE) {
                float angle = ((float)rand() / RAND_MAX) * 2.0f * 3.14159f;
                hyphae[hypha_count++] = (Hypha){
                    .x = spores[i].x,
                    .y = spores[i].y,
                    .dx = cosf(angle),
                    .dy = sinf(angle),
                    .energy = 0.8f,
                    .active = 1
                };
            }
        }
    }
}

// Renders the combined state of glyph nutrients, fungal threads (~), and spores (*)
void render_frame(int step) {
    printf("\033[H"); // Reset ANSI terminal cursor
    printf("--- Generative Mycelium Typography | Growth Step %02d ---\n", step);

    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            char ch = display_grid[y][x];
            if (ch == ' ') {
                if (nutrient_grid[y][x] > 1.0f) ch = '#';      // Glyphic core
                else if (nutrient_grid[y][x] > 0.3f) ch = '.'; // Diffused nutrient field
            }
            putchar(ch);
        }
        putchar('\n');
    }
}

int main(void) {
    srand((unsigned int)time(NULL));

    const char *prose = "MYCELIUM NETWORK";

    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            display_grid[y][x] = ' ';
            nutrient_grid[y][x] = 0.0f;
        }
    }

    deposit_prose_nutrients(prose);

    for (int step = 0; step < 40; step++) {
        update_nutrients();
        grow_mycelium();
        update_spores();
        render_frame(step + 1);
    }

    printf("\n[Simulation Finished] Total Hyphae Branches: %d | Total Spores Released: %d\n", hypha_count, spore_count);
    return 0;
}