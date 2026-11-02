#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <unistd.h>

#define WIDTH 80
#define HEIGHT 35

// Neural network parameters for audio/network traffic feature processing
typedef struct {
    float w1, w2, bias;
    float pulse;
} NeuralNet;

// Pixel structure holding RGB color and character glyph
typedef struct {
    unsigned char r, g, b;
    char ch;
} Pixel;

Pixel canvas[HEIGHT][WIDTH];

// Reset terminal canvas background gradient
void clear_canvas() {
    for(int y = 0; y < HEIGHT; y++) {
        for(int x = 0; x < WIDTH; x++) {
            canvas[y][x].r = 10;
            canvas[y][x].g = 12;
            canvas[y][x].b = 20;
            canvas[y][x].ch = ' ';
        }
    }
}

// Recursive fractal bonsai branch generator modulated by neural pulse
void draw_branch(float x0, float y0, float angle, float length, int depth, float pulse, int r_base, int g_base, int b_base) {
    if (depth == 0 || length < 1.0f) return;

    float x1 = x0 + cosf(angle) * length;
    float y1 = y0 + sinf(angle) * length;

    int steps = (int)(length * 2);
    for(int i = 0; i <= steps; i++) {
        float t = (steps > 0) ? (float)i / (float)steps : 0.0f;
        int cx = (int)(x0 + (x1 - x0) * t);
        int cy = (int)(y0 + (y1 - y0) * t);

        if (cx >= 0 && cx < WIDTH && cy >= 0 && cy < HEIGHT) {
            canvas[cy][cx].ch = (depth > 2) ? '#' : (depth == 1 ? '*' : '+');
            // Dynamic color gradient based on neural network pulse and tree depth
            canvas[cy][cx].r = (unsigned char)(fminf(255, r_base + pulse * 70 + depth * 15));
            canvas[cy][cx].g = (unsigned char)(fminf(255, g_base + (1.0f - pulse) * 90 + depth * 12));
            canvas[cy][cx].b = (unsigned char)(fminf(255, b_base + pulse * 120));
        }
    }

    float spread = 0.45f + 0.15f * sinf(pulse * 3.14159f);
    float length_scale = 0.68f + 0.07f * cosf(pulse);
    
    draw_branch(x1, y1, angle - spread, length * length_scale, depth - 1, pulse, r_base, g_base, b_base);
    draw_branch(x1, y1, angle + spread, length * length_scale, depth - 1, pulse, r_base, g_base, b_base);
}

// Render canvas to terminal using ANSI truecolor escape sequences
void render_frame() {
    printf("\x1b[H");
    for(int y = 0; y < HEIGHT; y++) {
        for(int x = 0; x < WIDTH; x++) {
            Pixel p = canvas[y][x];
            printf("\x1b[38;2;%d;%d;%dm%c", p.r, p.g, p.b, p.ch);
        }
        printf("\n");
    }
    fflush(stdout);
}

int main() {
    // Hide cursor for smooth animation
    printf("\x1b[?25l");
    clear_canvas();

    NeuralNet nn = {1.8f, -1.2f, 0.2f, 0.0f};

    // Interactive sound/network sculpture loop
    for(int frame = 0; frame < 150; frame++) {
        // Simulate incoming network traffic metrics (packet rate and jitter)
        float net_packet_rate = sinf(frame * 0.15f) * 2.5f;
        float net_jitter = cosf(frame * 0.25f) * 1.5f;

        // Neural network forward pass with Sigmoid activation
        float z = net_packet_rate * nn.w1 + net_jitter * nn.w2 + nn.bias;
        nn.pulse = 1.0f / (1.0f + expf(-z));

        clear_canvas();

        // Grow fractal bonsai sculpture from the bottom center
        draw_branch(WIDTH / 2.0f, HEIGHT - 2.0f, -1.5708f, 9.0f + nn.pulse * 5.0f, 6, nn.pulse, 70, 45, 35);

        render_frame();
        usleep(80000); // 80ms per frame refresh
    }

    // Restore cursor and terminal color
    printf("\x1b[?25h\x1b[0m\n");
    return 0;
}