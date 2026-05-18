```c
#include <SDL2/SDL.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define WINDOW_WIDTH 800
#define WINDOW_HEIGHT 600
#define GRID_SIZE 10  // Number of rows/columns in the mosaic

// Calculates entropy of input string based on character frequencies
double calculate_entropy(const char *input);

// Simulates seismic data as a random value between 0 and 1
double simulate_seismic_data(void);

// Recursively draws a fractal shape with dynamic color based on seismic intensity
void draw_fractal(SDL_Renderer *renderer, int x, int y, int depth, double intensity);

int main() {
    // Get user input for entropy analysis
    char input[1024];
    printf("Enter text for entropy analysis: ");
    fgets(input, sizeof(input), stdin);

    // Compute entropy to determine fractal recursion depth
    double entropy = calculate_entropy(input);
    int max_depth = (int)(entropy * 3); // Scale entropy to recursion depth
    max_depth = (max_depth < 1) ? 1 : max_depth; // Ensure minimum depth

    // Initialize SDL graphics system
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        fprintf(stderr, "SDL initialization failed: %s\n", SDL_GetError());
        return 1;
    }

    SDL_Window *window = SDL_CreateWindow(
        "Entropy-Based Fractal Mosaic",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        WINDOW_WIDTH, WINDOW_HEIGHT,
        SDL_WINDOW_SHOWN
    );

    SDL_Renderer *renderer = SDL_CreateRenderer(
        window, -1,
        SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC
    );

    if (!window || !renderer) {
        fprintf(stderr, "SDL object creation failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    int running = 1;
    SDL_Event event;

    // Main visualization loop
    while (running) {
        // Handle events
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) running = 0;
        }

        // Get simulated seismic data (replaces webcam API)
        double intensity = simulate_seismic_data();

        // Clear screen
        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        SDL_RenderClear(renderer);

        // Calculate cell dimensions
        int cell_w = WINDOW_WIDTH / GRID_SIZE;
        int cell_h = WINDOW_HEIGHT / GRID_SIZE;

        // Draw mosaic of fractals
        for (int row = 0; row < GRID_SIZE; row++) {
            for (int col = 0; col < GRID_SIZE; col++) {
                int center_x = col * cell_w + cell_w/2;
                int center_y = row * cell_h + cell_h/2;
                draw_fractal(renderer, center_x, center_y, max_depth, intensity);
            }
        }

        // Update display
        SDL_RenderPresent(renderer);
        SDL_Delay(50); // Control animation speed
    }

    // Cleanup resources
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 0;
}

// Shannon entropy calculation using character frequency distribution
double calculate_entropy(const char *input) {
    int freq[256] = {0};
    int len = strlen(input);
    
    for (int i = 0; i < len; i++) {
        unsigned char c = input[i];
        if (c >= 32 && c < 127) freq[c]++; // Consider printable ASCII only
    }

    double entropy = 0.0;
    for (int i = 0; i < 256; i++) {
        if (freq[i] > 0) {
            double p = (double)freq[i]/len;
            entropy -= p * log2(p);
        }
    }
    return entropy;
}

// Simulated seismic data generator (mock API)
double simulate_seismic_data(void) {
    static int seed = 0;
    seed = (seed * 1103515245 + 12345) & 0x7fffffff; // Simple LCG RNG
    return (double)seed / 0x7fffffff;
}

// Recursive fractal drawing with color mapping from seismic intensity
void draw_fractal(SDL_Renderer *renderer, int x, int y, int depth, double intensity) {
    if (depth <= 0) return;

    // Map seismic intensity to color gradient (blue to red)
    Uint8 red   = (Uint8)(255 * intensity);
    Uint8 green = 128;
    Uint8 blue  = (Uint8)(255 * (1.0 - intensity));
    SDL_SetRenderDrawColor(renderer, red, green, blue, 255);

    // Draw a circle approximation with rectangles
    int radius = depth * 5;
    SDL_Rect rect = {x - radius, y - radius, radius*2, radius*2};
    SDL_RenderFillRect(renderer, &rect);

    // Recursive calls to create fractal pattern
    draw_fractal(renderer, x - radius, y, depth-1, intensity);     // Left
    draw_fractal(renderer, x + radius, y, depth-1, intensity);     // Right
    draw_fractal(renderer, x, y - radius, depth-1, intensity);     // Up
    draw_fractal(renderer, x, y + radius, depth-1, intensity);     // Down
}
```