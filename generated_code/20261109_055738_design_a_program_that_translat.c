#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>

#define WIDTH 80
#define HEIGHT 24
#define NUM_BIRDS 15

// Structure representing a migratory pixelated bird
typedef struct {
    float x, y;
    float vx, vy;
    int frame;
} Bird;

// Measures local network latency via a quick ping command
int get_latency() {
    FILE *fp = popen("ping -c 1 -W 1 8.8.8.8 2>/dev/null | grep 'time=' | sed 's/.*time=\\([0-9.]*\\).*/\\1/'", "r");
    if (!fp) return 25;
    char buf[32];
    if (fgets(buf, sizeof(buf), fp) != NULL) {
        pclose(fp);
        int lat = (int)atof(buf);
        return lat > 0 ? lat : 25;
    }
    pclose(fp);
    return 25; // Default fallback latency
}

int main() {
    srand(time(NULL));
    Bird birds[NUM_BIRDS];
    
    // Initialize birds across the screen
    for (int i = 0; i < NUM_BIRDS; i++) {
        birds[i].x = rand() % WIDTH;
        birds[i].y = rand() % HEIGHT;
        birds[i].vx = 0.6f + (rand() % 5) * 0.1f;
        birds[i].vy = 0.0f;
        birds[i].frame = rand() % 2;
    }

    // Hide terminal cursor and clear screen for wallpaper simulation
    printf("\033[?25l\033[2J");

    while (1) {
        int latency = get_latency();
        
        // Latency spikes induce flight turbulence and acceleration
        float speed_multiplier = 1.0f + (latency > 80 ? (latency - 80) / 15.0f : 0.0f);
        
        // Clear frame buffer
        char screen[HEIGHT][WIDTH + 1];
        for (int y = 0; y < HEIGHT; y++) {
            for (int x = 0; x < WIDTH; x++) screen[y][x] = '.';
            screen[y][WIDTH] = '\0';
        }

        // Update bird positions and simulate flock response to network jitter
        for (int i = 0; i < NUM_BIRDS; i++) {
            birds[i].x += birds[i].vx * speed_multiplier;
            
            if (latency > 120) {
                // High latency causes erratic altitude turbulence
                birds[i].y += ((rand() % 5) - 2);
            }

            // Screen wrapping for migration loop
            if (birds[i].x >= WIDTH) birds[i].x = 0;
            if (birds[i].y < 0) birds[i].y = 0;
            if (birds[i].y >= HEIGHT) birds[i].y = HEIGHT - 1;

            int ix = (int)birds[i].x;
            int iy = (int)birds[i].y;
            // Wing flap animation frame
            screen[iy][ix] = (birds[i].frame++ % 2 == 0) ? 'v' : '^';
        }

        // Render wallpaper frame to terminal
        printf("\033[H");
        printf("=== Network Migratory Wallpaper | Latency: %3d ms | Status: %s ===\n", 
               latency, latency > 120 ? "TURBULENT (SPIKE)" : "STABLE FLIGHT");
        for (int y = 0; y < HEIGHT; y++) {
            printf("%s\n", screen[y]);
        }
        
        usleep(150000); // Frame delay
    }

    // Restore terminal cursor on exit
    printf("\033[?25h");
    return 0;
}