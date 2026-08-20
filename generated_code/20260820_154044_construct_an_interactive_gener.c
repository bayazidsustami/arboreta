#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <signal.h>
#include <string.h>
#include <math.h>

/*
 * Generative Interactive ASCII Ecosystem
 * Dynamic terminal window resizing simulates localized gravitational collapse,
 * altering the environmental mass density and shifting the evolution rules
 * of self-replicating Cellular Automata organisms.
 */

typedef struct {
    float density;
    int state;
    int age;
    char glyph;
} Cell;

static int width = 80;
static int height = 24;
static int prev_width = 80;
static int prev_height = 24;
static int resized = 0;

static Cell *grid = NULL;
static Cell *next_grid = NULL;

static struct termios orig_termios;

void disable_raw_mode(void) {
    printf("\033[?25h\033[0m\033[H\033[2J");
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios);
}

void enable_raw_mode(void) {
    tcgetattr(STDIN_FILENO, &orig_termios);
    atexit(disable_raw_mode);
    struct termios raw = orig_termios;
    raw.c_lflag &= ~(ECHO | ICANON);
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
    printf("\033[?25l");
}

void update_terminal_size(void) {
    struct winsize ws;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0) {
        if (ws.ws_col > 0 && ws.ws_row > 0) {
            prev_width = width;
            prev_height = height;
            width = ws.ws_col;
            height = ws.ws_row;
            if (width != prev_width || height != prev_height) {
                resized = 1;
            }
        }
    }
}

void handle_winch(int sig) {
    (void)sig;
    update_terminal_size();
}

void init_grids(void) {
    free(grid);
    free(next_grid);
    grid = calloc(width * height, sizeof(Cell));
    next_grid = calloc(width * height, sizeof(Cell));

    for (int i = 0; i < width * height; i++) {
        if ((rand() % 100) < 15) {
            grid[i].state = 1;
            grid[i].density = (float)(rand() % 100) / 100.0f;
            grid[i].age = 0;
            grid[i].glyph = '*';
        } else {
            grid[i].state = 0;
            grid[i].density = 0.0f;
            grid[i].age = 0;
            grid[i].glyph = ' ';
        }
    }
}

/* Gravitational collapse triggered when terminal boundaries shrink */
void apply_gravitational_collapse(void) {
    float scale_x = (float)prev_width / (float)width;
    float scale_y = (float)prev_height / (float)height;
    
    Cell *temp = calloc(width * height, sizeof(Cell));

    /* Compress organism density into new geometry relative to center of mass */
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            int old_x = (int)(x * scale_x);
            int old_y = (int)(y * scale_y);
            if (old_x >= 0 && old_x < prev_width && old_y >= 0 && old_y < prev_height) {
                int old_idx = old_y * prev_width + old_x;
                int new_idx = y * width + x;
                temp[new_idx] = grid[old_idx];
                
                /* Increase energy density due to gravitational compaction */
                if (scale_x > 1.0f || scale_y > 1.0f) {
                    temp[new_idx].density *= (scale_x * scale_y);
                    if (temp[new_idx].density > 1.0f) temp[new_idx].density = 1.0f;
                    temp[new_idx].age += 2;
                }
            }
        }
    }

    free(grid);
    free(next_grid);
    grid = temp;
    next_grid = calloc(width * height, sizeof(Cell));
    resized = 0;
}

char map_glyph(int state, float density, int age) {
    if (!state) return ' ';
    
    const char *organism_species = ".':;-=+*#%@";
    int species_len = 11;
    
    int index = (int)(density * species_len) + (age / 10);
    if (index >= species_len) index = species_len - 1;
    if (index < 0) index = 0;
    
    return organism_species[index];
}

void step_simulation(void) {
    int cx = width / 2;
    int cy = height / 2;

    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            int idx = y * width + x;
            int neighbors = 0;
            float neighbor_density = 0.0f;

            /* Calculate localized gravitational pulling forces toward center */
            float dx = (float)(x - cx);
            float dy = (float)(y - cy);
            float dist = sqrtf(dx * dx + dy * dy) + 0.1f;
            float gravity_bias = 1.0f / dist;

            for (int dy_n = -1; dy_n <= 1; dy_n++) {
                for (int dx_n = -1; dx_n <= 1; dx_n++) {
                    if (dx_n == 0 && dy_n == 0) continue;
                    int nx = (x + dx_n + width) % width;
                    int ny = (y + dy_n + height) % height;
                    int n_idx = ny * width + nx;

                    if (grid[n_idx].state) {
                        neighbors++;
                        neighbor_density += grid[n_idx].density;
                    }
                }
            }

            /* Evolution rules parameterized by gravitational density */
            Cell current = grid[idx];
            Cell *next = &next_grid[idx];

            if (current.state) {
                /* Organisms survive under specific local gravity conditions */
                if (neighbors == 2 || neighbors == 3 || (neighbor_density > 2.5f && neighbors <= 5)) {
                    next->state = 1;
                    next->age = current.age + 1;
                    next->density = (current.density * 0.9f) + (neighbor_density * 0.05f) + gravity_bias;
                    if (next->density > 1.0f) next->density = 1.0f;
                } else {
                    next->state = 0;
                    next->density = current.density * 0.5f;
                    next->age = 0;
                }
            } else {
                /* Self-replication triggered by critical neighbor density threshold */
                if (neighbors == 3 || (neighbor_density > 1.8f && neighbor_density < 3.2f)) {
                    next->state = 1;
                    next->age = 0;
                    next->density = (neighbor_density / (neighbors + 1)) + gravity_bias;
                    if (next->density > 1.0f) next->density = 1.0f;
                } else {
                    next->state = 0;
                    next->density = 0.0f;
                    next->age = 0;
                }
            }

            next->glyph = map_glyph(next->state, next->density, next->age);
        }
    }

    /* Swap buffers */
    Cell *tmp = grid;
    grid = next_grid;
    next_grid = tmp;
}

void render(void) {
    char *buffer = malloc(width * height * 32 + height + 64);
    if (!buffer) return;
    
    int pos = 0;
    pos += sprintf(buffer + pos, "\033[H");

    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            Cell c = grid[y * width + x];
            if (c.state) {
                /* Dynamic color shift based on age and energy density */
                int color = 31 + ((c.age + (int)(c.density * 10)) % 6);
                pos += sprintf(buffer + pos, "\033[%dm%c", color, c.glyph);
            } else {
                pos += sprintf(buffer + pos, " ");
            }
        }
        if (y < height - 1) {
            pos += sprintf(buffer + pos, "\n");
        }
    }

    write(STDOUT_FILENO, buffer, pos);
    free(buffer);
}

int check_input(void) {
    struct timeval tv = {0, 0};
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(STDIN_FILENO, &fds);
    if (select(STDIN_FILENO + 1, &fds, NULL, NULL, &tv) > 0) {
        char c;
        if (read(STDIN_FILENO, &c, 1) > 0) {
            if (c == 'q' || c == 'Q' || c == 27) return 1;
            if (c == 'r' || c == 'R') init_grids();
        }
    }
    return 0;
}

int main(void) {
    srand((unsigned int)time(NULL));
    
    enable_raw_mode();
    update_terminal_size();
    init_grids();

    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = handle_winch;
    sigaction(SIGWINCH, &sa, NULL);

    while (1) {
        if (check_input()) break;

        if (resized) {
            apply_gravitational_collapse();
        }

        step_simulation();
        render();

        usleep(50000); /* 20 FPS */
    }

    return 0;
}