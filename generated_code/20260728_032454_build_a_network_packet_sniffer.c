#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <unistd.h>
#include <pthread.h>
#include <pcap.h>

#define WIDTH 80
#define HEIGHT 24
#define NUM_DROPS 100

// Shared thread metrics
typedef struct {
    long packets_captured;
    long packets_dropped;
    pthread_mutex_t lock;
} PacketStats;

PacketStats g_stats = {0, 0, PTHREAD_MUTEX_INITIALIZER};

// Raindrop particle structure
typedef struct {
    float x, y;
    float speed;
    char symbol;
} Raindrop;

// Simulates continuous network sniffing or captures live traffic via libpcap
void *packet_sniffer_thread(void *arg) {
    char errbuf[PCAP_ERRBUF_SIZE];
    pcap_t *handle = pcap_open_live("wlan0", 65535, 1, 100, errbuf);

    if (!handle) {
        // Fallback: If no live Wi-Fi interface is accessible without root, simulate packet loss & arrival
        while (1) {
            usleep(10000 + rand() % 30000); // Simulated network delay
            pthread_mutex_lock(&g_stats.lock);
            g_stats.packets_captured++;
            if ((rand() % 100) < 15) { // 15% simulated packet loss
                g_stats.packets_dropped++;
            }
            pthread_mutex_unlock(&g_stats.lock);
        }
        return NULL;
    }

    struct pcap_pkthdr header;
    struct pcap_stat ps;

    while (1) {
        const u_char *pkt = pcap_next(handle, &header);
        pthread_mutex_lock(&g_stats.lock);
        if (pkt) {
            g_stats.packets_captured++;
        }
        if (pcap_stats(handle, &ps) == 0) {
            g_stats.packets_dropped = ps.ps_drop;
        }
        pthread_mutex_unlock(&g_stats.lock);
    }

    pcap_close(handle);
    return NULL;
}

// Perlin/Value noise approximation for procedural archipelago generation
float noise2d(float x, float y) {
    int xi = (int)x, yi = (int)y;
    float xf = x - xi, yf = y - yi;
    float n00 = sinf(xi * 12.9898f + yi * 78.233f) * 43758.5453f;
    float n10 = sinf((xi + 1) * 12.9898f + yi * 78.233f) * 43758.5453f;
    float n01 = sinf(xi * 12.9898f + (yi + 1) * 78.233f) * 43758.5453f;
    float n11 = sinf((xi + 1) * 12.9898f + (yi + 1) * 78.233f) * 43758.5453f;
    n00 -= floorf(n00); n10 -= floorf(n10); n01 -= floorf(n01); n11 -= floorf(n11);
    float i1 = n00 + xf * (n10 - n00);
    float i2 = n01 + xf * (n11 - n01);
    return i1 + yf * (i2 - i1);
}

// Fractal Brownian Motion for rich terrain generation
float fbm(float x, float y) {
    float val = 0.0f, amp = 0.5f;
    for (int i = 0; i < 4; i++) {
        val += amp * noise2d(x, y);
        x *= 2.0f; y *= 2.0f; amp *= 0.5f;
    }
    return val;
}

int main() {
    srand(time(NULL));

    // Spawn network sniffer in a background thread
    pthread_t sniffer;
    pthread_create(&sniffer, NULL, packet_sniffer_thread, NULL);

    Raindrop drops[NUM_DROPS];
    for (int i = 0; i < NUM_DROPS; i++) {
        drops[i].x = rand() % WIDTH;
        drops[i].y = rand() % HEIGHT;
        drops[i].speed = 0.5f + ((float)rand() / RAND_MAX) * 1.5f;
        drops[i].symbol = '|';
    }

    printf("\033[2J\033[?25l"); // Clear screen and hide cursor

    while (1) {
        pthread_mutex_lock(&g_stats.lock);
        long cap = g_stats.packets_captured;
        long drop = g_stats.packets_dropped;
        pthread_mutex_unlock(&g_stats.lock);

        // Calculate packet loss percentage to drive storm intensity
        float loss_rate = (cap > 0) ? ((float)drop / (float)cap) * 100.0f : 0.0f;
        float storm_intensity = fminf(1.0f, loss_rate / 30.0f); // Max storm at 30% loss

        char grid[HEIGHT][WIDTH];

        // 1. Generate ASCII Archipelago terrain
        for (int y = 0; y < HEIGHT; y++) {
            for (int x = 0; x < WIDTH; x++) {
                float elevation = fbm(x * 0.08f, y * 0.15f);
                if (elevation < 0.42f) grid[y][x] = ' ';       // Deep Ocean
                else if (elevation < 0.48f) grid[y][x] = '.'; // Shallow Water / Coast
                else if (elevation < 0.58f) grid[y][x] = 'm'; // Lowland
                else if (elevation < 0.70f) grid[y][x] = 'A'; // Hills
                else grid[y][x] = '^';                       // Mountain Peaks
            }
        }

        // 2. Render Storm & Weather Layer based on packet metrics
        int active_drops = (int)(storm_intensity * NUM_DROPS);
        for (int i = 0; i < active_drops; i++) {
            drops[i].y += drops[i].speed;
            drops[i].x += (storm_intensity > 0.5f) ? 0.3f : 0.0f; // Wind turbulence

            if (drops[i].y >= HEIGHT) {
                drops[i].y = 0;
                drops[i].x = rand() % WIDTH;
            }

            int rx = (int)drops[i].x % WIDTH;
            int ry = (int)drops[i].y % HEIGHT;

            if (storm_intensity > 0.7f) drops[i].symbol = '/'; // Heavy Wind
            else if (storm_intensity > 0.3f) drops[i].symbol = '|'; // Moderate Rain
            else drops[i].symbol = '\''; // Light Drizzle

            grid[ry][rx] = drops[i].symbol;
        }

        // 3. Draw Frame to Terminal
        printf("\033[H"); // Reset cursor to top-left
        printf("=== ARCHIPELAGO WEATHER MONITOR === [Captured: %ld | Dropped: %ld | Loss: %.1f%%]\n", cap, drop, loss_rate);
        for (int y = 0; y < HEIGHT; y++) {
            for (int x = 0; x < WIDTH; x++) {
                char c = grid[y][x];
                // Colorize terrain and dynamic rain
                if (c == '/' || c == '|' || c == '\'') printf("\033[1;36m%c\033[0m", c); // Cyan Rain
                else if (c == '^' || c == 'A') printf("\033[1;37m%c\033[0m", c);         // White Mountains
                else if (c == 'm') printf("\033[0;32m%c\033[0m", c);                     // Green Land
                else if (c == '.') printf("\033[0;33m%c\033[0m", c);                     // Yellow Coast
                else printf("%c", c);
            }
            putchar('\n');
        }

        usleep(50000); // ~20 FPS render loop
    }

    return 0;
}