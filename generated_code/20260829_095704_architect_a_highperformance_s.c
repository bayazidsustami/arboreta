#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define WIDTH 80
#define HEIGHT 40
#define CELL_DEAD 0
#define CELL_ALIVE 1
#define CELL_MAGMA 2

typedef struct Commit {
    char hash[8];
    int parent_count;
    struct Commit* parents[2];
    int changes;
} Commit;

typedef struct {
    int grid[HEIGHT][WIDTH];
    int next_grid[HEIGHT][WIDTH];
} Landscape;

void init_landscape(Landscape* l) {
    memset(l->grid, CELL_DEAD, sizeof(l->grid));
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            l->grid[y][x] = (rand() % 100 < 20) ? CELL_ALIVE : CELL_DEAD;
        }
    }
}

void trigger_geological_event(Landscape* l, int severity) {
    int epicenter_x = rand() % WIDTH;
    int epicenter_y = rand() % HEIGHT;
    int radius = (severity % 5) + 3;

    for (int y = -radius; y <= radius; y++) {
        for (int x = -radius; x <= radius; x++) {
            int target_y = (epicenter_y + y + HEIGHT) % HEIGHT;
            int target_x = (epicenter_x + x + WIDTH) % WIDTH;
            if (x * x + y * y <= radius * radius) {
                l->grid[target_y][target_x] = CELL_MAGMA;
            }
        }
    }
}

int count_neighbors(Landscape* l, int y, int x, int state) {
    int count = 0;
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            if (dy == 0 && dx == 0) continue;
            int ny = (y + dy + HEIGHT) % HEIGHT;
            int nx = (x + dx + WIDTH) % WIDTH;
            if (l->grid[ny][nx] == state) count++;
        }
    }
    return count;
}

void step_simulation(Landscape* l) {
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            int current = l->grid[y][x];
            int alive_neighbors = count_neighbors(l, y, x, CELL_ALIVE);
            int magma_neighbors = count_neighbors(l, y, x, CELL_MAGMA);

            if (current == CELL_MAGMA) {
                l->next_grid[y][x] = (rand() % 100 < 60) ? CELL_DEAD : CELL_ALIVE;
            } else if (magma_neighbors > 0) {
                l->next_grid[y][x] = CELL_MAGMA;
            } else if (current == CELL_ALIVE) {
                l->next_grid[y][x] = (alive_neighbors == 2 || alive_neighbors == 3) ? CELL_ALIVE : CELL_DEAD;
            } else {
                l->next_grid[y][x] = (alive_neighbors == 3) ? CELL_ALIVE : CELL_DEAD;
            }
        }
    }
    memcpy(l->grid, l->next_grid, sizeof(l->grid));
}

void render_landscape(Landscape* l, Commit* c) {
    printf("\033[H");
    printf("Commit: %s | Parents: %d | Event: %s\n", 
           c->hash, c->parent_count, 
           c->parent_count > 1 ? "CATASTROPHIC MERGE MAGMA ERUPTION" : "Standard Mutation");
    printf("+");
    for (int x = 0; x < WIDTH; x++) printf("-");
    printf("+\n");

    for (int y = 0; y < HEIGHT; y++) {
        printf("|");
        for (int x = 0; x < WIDTH; x++) {
            switch (l->grid[y][x]) {
                case CELL_DEAD:  putchar(' '); break;
                case CELL_ALIVE: putchar('*'); break;
                case CELL_MAGMA: putchar('#'); break;
            }
        }
        printf("|\n");
    }

    printf("+");
    for (int x = 0; x < WIDTH; x++) printf("-");
    printf("+\n");
}

Commit* generate_commit_chain(int count) {
    Commit* chain = calloc(count, sizeof(Commit));
    for (int i = 0; i < count; i++) {
        snprintf(chain[i].hash, 8, "%07x", rand() % 0xFFFFFFF);
        chain[i].changes = (rand() % 20) + 1;
        if (i > 0) {
            chain[i].parents[0] = &chain[i - 1];
            chain[i].parent_count = 1;
            if (i > 2 && rand() % 100 < 30) {
                chain[i].parents[1] = &chain[i - (2 + rand() % (i - 1))];
                chain[i].parent_count = 2;
            }
        }
    }
    return chain;
}

int main(void) {
    srand(time(NULL));
    Landscape landscape;
    init_landscape(&landscape);

    int total_commits = 20;
    Commit* history = generate_commit_chain(total_commits);

    printf("\033[2J");
    for (int i = 0; i < total_commits; i++) {
        Commit* c = &history[i];

        if (c->parent_count > 1) {
            trigger_geological_event(&landscape, c->changes);
        } else {
            for (int k = 0; k < c->changes; k++) {
                int rx = rand() % WIDTH;
                int ry = rand() % HEIGHT;
                landscape.grid[ry][rx] = CELL_ALIVE;
            }
        }

        for (int ticks = 0; ticks < 5; ticks++) {
            step_simulation(&landscape);
            render_landscape(&landscape, c);
            usleep(100000);
        }
    }

    free(history);
    return 0;
}