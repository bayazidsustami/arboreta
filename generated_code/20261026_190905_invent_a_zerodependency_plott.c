#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <math.h>

#define WIDTH 80
#define HEIGHT 24
#define NUM_CONSTELLATIONS 12
#define STARS_PER_CONST 6

// Represents a node in a typographic constellation driven by network pulses
typedef struct {
    float x, y;
    float vx, vy;
    char glyph;
    int color_intensity;
} Star;

typedef struct {
    Star stars[STARS_PER_CONST];
    float cx, cy; // Center of mass
    float energy; // Driven by simulated network traffic spikes
} Constellation;

// Clear screen and hide cursor using ANSI escape sequences
void init_terminal() {
    printf("\033[2J\033[?25l");
    fflush(stdout);
}

// Restore terminal state on exit
void reset_terminal() {
    printf("\033[?25h\n");
    fflush(stdout);
}

int main() {
    srand(time(NULL));
    init_terminal();

    Constellation consts[NUM_CONSTELLATIONS];
    char glyph_pool[] = "+*#~:.=xXoO";

    // Initialize constellations
    for (int i = 0; i < NUM_CONSTELLATIONS; i++) {
        consts[i].cx = (float)(rand() % WIDTH);
        consts[i].cy = (float)(rand() % HEIGHT);
        consts[i].energy = 1.0f;
        for (int j = 0; j < STARS_PER_CONST; j++) {
            consts[i].stars[j].x = consts[i].cx + ((rand() % 9) - 4);
            consts[i].stars[j].y = consts[i].cy + ((rand() % 5) - 2);
            consts[i].stars[j].vx = ((float)(rand() % 100) / 50.0f) - 1.0f;
            consts[i].stars[j].vy = ((float)(rand() % 100) / 50.0f) - 1.0f;
            consts[i].stars[j].glyph = glyph_pool[rand() % (sizeof(glyph_pool) - 1)];
            consts[i].stars[j].color_intensity = rand() % 5 + 1;
        }
    }

    char buffer[HEIGHT][WIDTH + 1];
    int color_buffer[HEIGHT][WIDTH];

    int frames = 0;
    while (frames < 300) { // Run for 300 frames (~10 seconds at 30fps)
        // Simulate incoming network traffic bursts (random packet payload volume)
        float network_packet_spike = (rand() % 100 < 25) ? ((float)(rand() % 50) / 10.0f) : 0.2f;

        // Clear display buffers
        for (int y = 0; y < HEIGHT; y++) {
            for (int x = 0; x < WIDTH; x++) {
                buffer[y][x] = ' ';
                color_buffer[y][x] = 30; // Default dark background/dim
            }
            buffer[y][WIDTH] = '\0';
        }

        // Update physics and constellation swarm
        for (int i = 0; i < NUM_CONSTELLATIONS; i++) {
            // Apply network energy pulse to constellation drift
            consts[i].energy += (network_packet_spike - consts[i].energy) * 0.2f;
            consts[i].cx += cosf(frames * 0.05f + i) * consts[i].energy;
            consts[i].cy += sinf(frames * 0.03f + i) * (consts[i].energy * 0.5f);

            // Wrap around screen boundaries with bleeding drift
            if (consts[i].cx < 0) consts[i].cx = WIDTH - 1;
            if (consts[i].cx >= WIDTH) consts[i].cx = 0;
            if (consts[i].cy < 0) consts[i].cy = HEIGHT - 1;
            if (consts[i].cy >= HEIGHT) consts[i].cy = 0;

            for (int j = 0; j < STARS_PER_CONST; j++) {
                Star *s = &consts[i].stars[j];
                s->x += s->vx * consts[i].energy;
                s->y += s->vy * consts[i].energy;

                // Soft tether back to constellation center
                s->vx += (consts[i].cx - s->x) * 0.01f;
                s->vy += (consts[i].cy - s->y) * 0.01f;

                // Damping
                s->vx *= 0.90f;
                s->vy *= 0.90f;

                int ix = (int)s->x % WIDTH;
                int iy = (int)s->y % HEIGHT;
                if (ix < 0) ix += WIDTH;
                if (iy < 0) iy += HEIGHT;

                buffer[iy][ix] = s->glyph;
                color_buffer[iy][ix] = 31 + (i % 6); // Vibrant ANSI color mapping
            }
        }

        // Render buffer to terminal with zero-flicker move cursor
        printf("\033[H");
        for (int y = 0; y < HEIGHT; y++) {
            for (int x = 0; x < WIDTH; x++) {
                if (buffer[y][x] != ' ') {
                    printf("\033[1;%dm%c\033[0m", color_buffer[y][x], buffer[y][x]);
                } else {
                    putchar(' ');
                }
            }
            putchar('\n');
        }

        // Display simulated traffic telemetry overlay
        printf(" [TRAFFIC SWARM STREAM] :: Active Nodes: %d | Packet Energy Spike: %.2f \n", 
               NUM_CONSTELLATIONS * STARS_PER_CONST, network_packet_spike);

        fflush(stdout);
        usleep(40000); // ~25 FPS frame pacing
        frames++;
    }

    reset_terminal();
    return 0;
}