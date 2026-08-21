/* Celestial Map ASCII Diagram & Terminal Visualizer / Reverse Score Generator */
/* Visual layout forms a stylized constellation map (Orion/Cassiopeia pattern). */
/* RUN DIRECTLY: Renders a dynamic terminal visualization of starlight interference. */
/* REVERSE EXECUTION: Passing '-r' (or running binary name reversed) parses the source */
/* code layout into a generative ambient musical score (MIDI/ANSI frequency notes).    */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

#if defined(_WIN32)
#include <windows.h>
#define SLEEP_MS(x) Sleep(x)
#else
#include <unistd.h>
#define SLEEP_MS(x) usleep((x) * 1000)
#endif

/*
                      . *  .  +  *   .   *   .
                       / \     *   +   .  *
                      /   \   .   *   .    +
                     *-----*     +    . *   .
                    /|  |  |\   .  *   .   *
                   * |  |  | *    .   +   .
                    \|  |  |/   *   .   *
                     *-----*     .   +    .
                    /   |   \   +  *   . *
                   * .  *  . *    .   +   .
*/

static const char *SRC_MAP = 
"                      . *  .  +  *   .   *   .\n"
"                       / \\     *   +   .  *\n"
"                      /   \\   .   *   .    +\n"
"                     *-----*     +    . *   .\n"
"                    /|  |  |\\   .  *   .   *\n"
"                   * |  |  | *    .   +   .\n"
"                    \\|  |  |/   *   .   *\n"
"                     *-----*     .   +    .\n"
"                    /   |   \\   +  *   . *\n"
"                   * .  *  . *    .   +   .\n";

/* Visualizer: Simulates wave interference patterns across starlight coordinates */
void render_starlight_interference(void) {
    int width = 60, height = 20;
    double t = 0.0;
    
    printf("\033[2J\033[?25l"); /* Clear screen and hide cursor */
    
    for (int frame = 0; frame < 150; ++frame) {
        printf("\033[H"); /* Reset cursor to top-left */
        printf("--- CELESTIAL STARLIGHT INTERFERENCE PATTERN ---\n");
        
        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width; ++x) {
                double cx = (x - width / 2.0) * 0.1;
                double cy = (y - height / 2.0) * 0.2;
                
                /* Superposition of three celestial light wave sources */
                double w1 = sin(sqrt((cx - 2) * (cx - 2) + (cy - 1) * (cy - 1)) - t);
                double w2 = sin(sqrt((cx + 2) * (cx + 2) + (cy + 2) * (cy + 2)) - 1.5 * t);
                double w3 = cos(sqrt(cx * cx + cy * cy) + 0.8 * t);
                
                double amp = (w1 + w2 + w3) / 3.0;
                
                if (amp > 0.6)      printf("\033[36m*\033[0m");
                else if (amp > 0.3) printf("\033[33m+\033[0m");
                else if (amp > 0.0) printf("\033[32m.\033[0m");
                else if (amp > -0.4)printf("\033[34m:\033[0m");
                else                printf(" ");
            }
            printf("\n");
        }
        t += 0.2;
        SLEEP_MS(60);
    }
    printf("\033[?25h"); /* Restore cursor */
}

/* Reverse Mode: Parses celestial map geometry into ambient audio frequencies */
void generate_reverse_score(void) {
    int len = (int)strlen(SRC_MAP);
    double pentatonic_scale[] = {261.63, 293.66, 329.63, 392.00, 440.00, 523.25};
    
    printf("=== GENERATING AMBIENT MUSICAL SCORE FROM REVERSED MAP LAYOUT ===\n\n");
    printf("Pos  | Symbol | Freq (Hz) | Ambient Note Pitch Visualizer\n");
    printf("-----|--------|-----------|------------------------------\n");

    /* Traverses the ASCII diagram in reverse order to map spatial nodes to notes */
    for (int i = len - 1; i >= 0; --i) {
        char ch = SRC_MAP[i];
        if (ch == ' ' || ch == '\n') continue;

        int scale_idx = ((unsigned char)ch + i) % 6;
        double freq = pentatonic_scale[scale_idx];
        
        printf("[%03d] |    '%c'   | %7.2fHz | ", i, ch, freq);
        int bar_length = (int)(freq / 20.0);
        for (int b = 0; b < bar_length; ++b) printf("=");
        printf("o\n");
        
        SLEEP_MS(40);
    }
    printf("\nScore generation complete.\n");
}

int main(int argc, char *argv[]) {
    /* Check if executed with '-r' or reversed binary invocation */
    if (argc > 1 && strcmp(argv[0] + strlen(argv[0]) - 2, "-r") == 0) {
        generate_reverse_score();
        return 0;
    }
    
    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "-r") == 0 || strcmp(argv[i], "--reverse") == 0) {
            generate_reverse_score();
            return 0;
        }
    }

    render_starlight_interference();
    return 0;
}