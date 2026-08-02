/* 
 * Self-Reading Microtonal Memory Soundscape & ASCII Synthesizer
 * Interprets executable process binary code layout as microtonal audio frequencies,
 * computing wave superposition and rendering harmonic interference patterns in ASCII.
 */

#define _POSIX_C_SOURCE 199309L
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <time.h>
#include <unistd.h>

#define WIDTH 80
#define HEIGHT 24
#define VOICE_COUNT 16
#define TWO_PI 6.28318530717958647692

/* ASCII luminance density map */
static const char DENSITY[] = " .':-~+=*xX%#@";
static const int DENSITY_LEN = 13;

int main(void) {
    /* Read raw binary machine instructions directly from process memory */
    const uint8_t *mem_ptr = (const uint8_t *)(uintptr_t)&main;
    
    /* Extract microtonal frequency set from raw memory byte values */
    double freqs[VOICE_COUNT];
    for (int i = 0; i < VOICE_COUNT; i++) {
        uint8_t byte = mem_ptr[i * 3];
        /* Map byte (0-255) across a microtonal logarithmic pitch scale (110Hz-880Hz) */
        freqs[i] = 110.0 * pow(2.0, (double)byte / 85.0);
    }

    double time_step = 0.0;
    
    /* Hide cursor and clear terminal screen */
    printf("\033[2J\033[?25l");
    
    while (1) {
        printf("\033[H"); /* Reset cursor to top-left */
        
        /* Render spatial-temporal harmonic interference matrix */
        for (int y = 0; y < HEIGHT; y++) {
            for (int x = 0; x < WIDTH; x++) {
                double interference = 0.0;
                
                /* Superimpose microtonal voice waveforms */
                for (int v = 0; v < VOICE_COUNT; v++) {
                    double phase = (freqs[v] * 0.0008 * time_step) + (x * 0.07) + (y * 0.11);
                    interference += sin(phase * TWO_PI);
                }
                
                /* Normalize interference wave amplitude [-VOICE_COUNT, +VOICE_COUNT] -> [0.0, 1.0] */
                double amplitude = (interference / VOICE_COUNT + 1.0) * 0.5;
                if (amplitude < 0.0) amplitude = 0.0;
                if (amplitude > 1.0) amplitude = 1.0;
                
                /* Quantize amplitude to ASCII character density map */
                int idx = (int)(amplitude * (DENSITY_LEN - 1));
                putchar(DENSITY[idx]);
            }
            putchar('\n');
        }
        
        /* Traverse memory layout dynamically to evolve the visual harmonic structure */
        time_step += 0.05;
        if ((int)(time_step * 10) % 200 == 0) {
            mem_ptr += 8;
            for (int i = 0; i < VOICE_COUNT; i++) {
                freqs[i] = 110.0 * pow(2.0, (double)mem_ptr[i * 3] / 85.0);
            }
        }
        
        fflush(stdout);
        usleep(33000); /* ~30 FPS frame rate */
    }
    
    return 0;
}