#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <unistd.h>

#define WIDTH 40
#define HEIGHT 20

typedef struct {
    unsigned int src_ip;
    unsigned int dst_ip;
    unsigned short src_port;
    unsigned short dst_port;
    unsigned short length;
} Packet;

// Virtual watercolor canvas storing pigment concentration (0.0 to 1.0)
float canvas[HEIGHT][WIDTH];

// Initialize the canvas with clean paper texture
void init_canvas() {
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            canvas[y][x] = 0.0f;
        }
    }
}

// Simulate the slow drying and bleeding/fading of watercolor over time
void decay_canvas() {
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            canvas[y][x] *= 0.88f; 
        }
    }
}

// Drop packet header pigments onto the watercolor paper
void add_pigment(Packet *p) {
    int cx = (p->src_port ^ p->dst_port) % WIDTH;
    int cy = p->length % HEIGHT;
    float intensity = (float)(p->length % 100) / 100.0f + 0.4f;
    
    // Simulate wet watercolor bleeding outward in a soft radial gradient
    for (int y = cy - 3; y <= cy + 3; y++) {
        for (int x = cx - 3; x <= cx + 3; x++) {
            if (y >= 0 && y < HEIGHT && x >= 0 && x < WIDTH) {
                float dist = sqrtf((float)((x - cx) * (x - cx) + (y - cy) * (y - cy)));
                if (dist < 3.5f) {
                    canvas[y][x] += intensity * (3.5f - dist) / 3.5f;
                    if (canvas[y][x] > 1.0f) canvas[y][x] = 1.0f;
                }
            }
        }
    }
}

// Render the decaying watercolor painting to the terminal using ASCII shades
void render_painting() {
    const char *shades = " .:-=+*#%@";
    printf("\033[H\033[J"); // ANSI escape to clear screen and reset cursor
    printf("=== VICTORIAN CALLIOPE & NETWORK WATERCOLOR CANVAS ===\n");
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            int idx = (int)(canvas[y][x] * 9.0f);
            if (idx < 0) idx = 0;
            if (idx > 9) idx = 9;
            putchar(shades[idx]);
            putchar(shades[idx]); // Double character for proper aspect ratio
        }
        putchar('\n');
    }
}

// Translate packet parameters into steam- whistle calliope notes
void play_calliope(Packet *p) {
    const char *notes[] = {"C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"};
    int note_idx = p->src_port % 8;
    unsigned int psi = (p->dst_port % 60) + 15;
    
    printf("[Calliope Steam Whistle] Note: %-2s | Boiler Pressure: %2u PSI | Payload: %4u bytes\n", 
           notes[note_idx], psi, p->length);
}

int main() {
    srand((unsigned int)time(NULL));
    init_canvas();

    // Simulate incoming network stream for 40 packets
    for (int i = 0; i < 40; i++) {
        Packet p;
        p.src_ip = rand();
        p.dst_ip = rand();
        p.src_port = (unsigned short)(rand() % 65535);
        p.dst_port = (unsigned short)(rand() % 65535);
        p.length = (unsigned short)(64 + (rand() % 1400));

        add_pigment(&p);
        decay_canvas();
        render_painting();
        play_calliope(&p);

        usleep(180000); // 180ms delay between packets
    }

    printf("\nCanvas dry. Performance concluded.\n");
    return 0;
}