#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>

/* Dimensions for the ASCII glitch art display buffer */
#define WIDTH 64
#define HEIGHT 16
#define GLITCH_CHARS "@#$%=+:-. "
#define CHAR_COUNT 10

/* 
 * 1-D / 2-D Hybrid Cellular Automaton (Rule 30 base + feedback glitch shift).
 * Translates frame buffer visual densities directly to microtonal MIDI bytes 
 * via standard Pitch Bend and Note On messages sent directly to stdout (raw MIDI binary stream).
 */

/* Send MIDI Note On with Microtonal Pitch Bend tuning (14-bit pitch bend) */
void play_microtonal_note(int channel, int midi_note, double cents_offset) {
    /* Convert cents (-100 to +100) to 14-bit Pitch Bend value (0 to 16383, center 8192) */
    int bend = 8192 + (int)((cents_offset / 200.0) * 8192.0);
    if (bend < 0) bend = 0;
    if (bend > 16383) bend = 16383;

    unsigned char bend_lsb = bend & 0x7F;
    unsigned char bend_msb = (bend >> 7) & 0x7F;

    /* Pitch Bend Message: 0xE0 | channel */
    putchar(0xE0 | (channel & 0x0F));
    putchar(bend_lsb);
    putchar(bend_msb);

    /* Note On Message: 0x90 | channel, Velocity: 90 */
    putchar(0x90 | (channel & 0x0F));
    putchar(midi_note & 0x7F);
    putchar(90); 
    fflush(stdout);
}

/* Clear all active microtonal notes on a channel */
void silence_channel(int channel, int midi_note) {
    putchar(0x80 | (channel & 0x0F));
    putchar(midi_note & 0x7F);
    putchar(0);
    fflush(stdout);
}

int main(void) {
    unsigned char grid[HEIGHT][WIDTH] = {0};
    unsigned char next_grid[HEIGHT][WIDTH] = {0};
    
    /* Seed the automaton center */
    grid[0][WIDTH / 2] = 1;
    grid[0][(WIDTH / 2) - 1] = 1;

    /* Harmonic ratios for microtonal consonant chord generator (Just Intonation relative cents) */
    /* Root (1/1), Just Major Third (5/4: +386 cents), Just Fifth (3/2: +702 cents), Harmonic 7th (7/4: +969 cents) */
    double harmonic_cents[4] = {0.0, -13.7, 2.0, -31.2};
    int base_midi_notes[4] = {48, 52, 55, 58}; /* C3 major-seventh harmonic base */
    int active_notes[4] = {0};

    /* ANSI Clear Screen */
    printf("\033[2J\033[H");

    unsigned long frame = 0;
    while (1) {
        /* Move cursor home */
        printf("\033[H");

        /* Rule 30 Deterministic Cellular Automaton with glitch feedback */
        for (int y = 0; y < HEIGHT; y++) {
            for (int x = 0; x < WIDTH; x++) {
                int left   = grid[y][(x - 1 + WIDTH) % WIDTH];
                int center = grid[y][x];
                int right  = grid[y][(x + 1) % WIDTH];

                /* Standard Wolfram Rule 30 logic */
                int state = (left ^ (center | right));

                /* Introduce deterministic bitwise feedback glitch dependent on vertical row */
                if ((frame + y) % 7 == 0) {
                    state ^= (grid[(y + 1) % HEIGHT][x] & 1);
                }

                next_grid[y][x] = state;
            }
        }

        /* Render ASCII glitch frame buffer to stderr (so stdio binary MIDI stays clean) */
        int row_density[4] = {0};
        for (int y = 0; y < HEIGHT; y++) {
            for (int x = 0; x < WIDTH; x++) {
                int val = grid[y][x];
                char ch = val ? GLITCH_CHARS[(y + x + frame) % CHAR_COUNT] : ' ';
                fputc(ch, stderr);

                /* Compute visual density profile split across 4 visual quadrants */
                if (val) {
                    row_density[y / (HEIGHT / 4)]++;
                }
            }
            fputc('\n', stderr);
        }

        /* Map visual densities to microtonal consonant chord progression */
        for (int i = 0; i < 4; i++) {
            if (active_notes[i]) {
                silence_channel(i, active_notes[i]);
            }

            /* Calculate pitch shift derived deterministically from CA frame density */
            int micro_shift = (row_density[i] % 12);
            int midi_pitch = base_midi_notes[i] + micro_shift;
            double cents = harmonic_cents[i];

            play_microtonal_note(i, midi_pitch, cents);
            active_notes[i] = midi_pitch;
        }

        /* Copy back frame buffer */
        for (int y = 0; y < HEIGHT; y++) {
            for (int x = 0; x < WIDTH; x++) {
                grid[y][x] = next_grid[y][x];
            }
        }

        frame++;
        usleep(100000); /* 100ms refresh rate (~10 FPS) */
    }

    return 0;
}