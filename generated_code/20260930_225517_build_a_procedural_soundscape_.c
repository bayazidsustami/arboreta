#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <sys/select.h>
#include <sys/time.h>

#define SAMPLE_RATE 44100
#define CHUNK_SIZE 512
#define PI 3.14159265358979323846

// Microtonal frequency ratios (just intonation / compiler dream harmonics)
static const double base_freqs[] = {
    130.81, // C3
    138.59, // C#3 (Microtonal shift)
    146.83, // D3
    164.81, // E3
    174.61, // F3
    196.00, // G3
    220.00, // A3
    246.94  // B3
};
#define NUM_FREQS 8

typedef struct {
    struct termios orig_termios;
    int mouse_fd;
    double typing_activity; // Decays over time, surges on keystroke
    double mouse_jitter;    // Decays over time, surges on mouse movement
    double phase[4];
    double target_freq[4];
    double current_freq[4];
    unsigned long long sample_count;
} DreamEngine;

// Restore terminal settings on exit
static struct termios g_orig_termios;
static int g_terminal_set = 0;

void reset_terminal(void) {
    if (g_terminal_set) {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &g_orig_termios);
    }
}

void init_terminal(void) {
    struct termios raw;
    if (tcgetattr(STDIN_FILENO, &g_orig_termios) < 0) return;
    raw = g_orig_termios;
    raw.c_lflag &= ~(ECHO | ICANON);
    raw.c_cc[VMIN] = 0;
    raw.c_cc[VTIME] = 0;
    if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) < 0) return;
    g_terminal_set = 1;
    atexit(reset_terminal);
}

double get_time_sec(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec + tv.tv_usec / 1000000.0;
}

int main(int argc, char *argv[]) {
    //fprintf(stderr, "=== The Sleeping Compiler's Dreamscape ===\n");
    //fprintf(stderr, "Pipe output to player: ./compiler_lullaby | aplay -r 44100 -f S16_LE\n");
    //fprintf(stderr, "Type keys or move mouse/generate input to shape the dream...\n\n");

    init_terminal();

    // Attempt to open mouse input on Linux systems
    int mouse_fd = -1;
    #ifdef __linux__
    mouse_fd = open("/dev/input/mice", O_RDONLY | O_NONBLOCK);
    #endif

    DreamEngine engine;
    engine.mouse_fd = mouse_fd;
    engine.typing_activity = 0.0;
    engine.mouse_jitter = 0.0;
    engine.sample_count = 0;

    for (int i = 0; i < 4; i++) {
        engine.phase[i] = 0.0;
        engine.target_freq[i] = base_freqs[i % NUM_FREQS];
        engine.current_freq[i] = engine.target_freq[i];
    }

    short audio_buffer[CHUNK_SIZE];
    double last_key_time = get_time_sec();

    // Main synthesis and interaction loop
    while (1) {
        double current_time = get_time_sec();

        // Check for keyboard activity (non-blocking)
        fd_set set;
        struct timeval timeout;
        FD_ZERO(&set);
        FD_SET(STDIN_FILENO, &set);
        timeout.tv_sec = 0;
        timeout.tv_usec = 0;

        if (select(STDIN_FILENO + 1, &set, NULL, NULL, &timeout) > 0) {
            char buf[32];
            int n = read(STDIN_FILENO, buf, sizeof(buf));
            if (n > 0) {
                double dt = current_time - last_key_time;
                last_key_time = current_time;
                // Typing speed surge: faster typing increases activity
                engine.typing_activity = fmin(5.0, engine.typing_activity + 1.2);
                
                // Shift target frequencies based on key input entropy
                int idx = (unsigned char)buf[0] % NUM_FREQS;
                engine.target_freq[0] = base_freqs[idx];
                engine.target_freq[1] = base_freqs[(idx + 2) % NUM_FREQS];
            }
        }

        // Check for mouse activity if available
        if (engine.mouse_fd >= 0) {
            char mbuf[3];
            int mread = read(engine.mouse_fd, mbuf, sizeof(mbuf));
            if (mread > 0) {
                // Movement detected in mouse packet
                double movement = abs(mbuf[1]) + abs(mbuf[2]);
                if (movement > 0) {
                    engine.mouse_jitter = fmin(5.0, engine.mouse_jitter + 0.5 * movement);
                }
            }
        }

        // Natural exponential decay of user interaction metrics (dream state settling)
        engine.typing_activity *= 0.992;
        engine.mouse_jitter *= 0.985;

        // Generate audio chunk (16-bit PCM mono)
        for (int i = 0; i < CHUNK_SIZE; i++) {
            engine.sample_count++;
            double t = (double)engine.sample_count / SAMPLE_RATE;

            // Evolving microtonal drone modulation
            // Typing speed alters filter/detune width; mouse jitter adds cosmic microtonal shimmer
            for (int v = 0; v < 4; v++) {
                double target = engine.target_freq[v] * (1.0 + 0.05 * sin(t * 0.2 + v));
                // Smooth frequency interpolation (compiler thought transition)
                engine.current_freq[v] += (target - engine.current_freq[v]) * 0.001;

                // Add jitter/typing micro-pitch bending
                double bend = 1.0 + (engine.mouse_jitter * 0.02 * sin(t * 15.0 + v)) + 
                                    (engine.typing_activity * 0.01 * cos(t * 8.0));
                
                engine.phase[v] += 2.0 * PI * (engine.current_freq[v] * bend) / SAMPLE_RATE;
                if (engine.phase[v] >= 2.0 * PI) engine.phase[v] -= 2.0 * PI;
            }

            // Lullaby additive synthesis with warm harmonics and soft sine layering
            double sample = 0.0;
            sample += sin(engine.phase[0]) * 0.4;
            sample += sin(engine.phase[1] * 1.5) * 0.25; // Perfect fifth / microtonal
            sample += sin(engine.phase[2] * 2.0) * 0.15; // Octave shimmer
            sample += sin(engine.phase[3] * 0.5) * 0.2;  // Sub-bass dream pulse

            // Breathing amplitude envelope modulated by typing activity and sleep rhythm
            double sleep_breath = 0.5 + 0.5 * sin(t * 0.5);
            double activity_boost = 1.0 + 0.5 * engine.typing_activity;
            double envelope = sleep_breath * activity_boost;

            // Simple feedback delay / reverberation simulation ring buffer approximation
            double filtered_sample = sample * envelope * 8000.0;

            // Clamp sample to 16-bit signed integer range
            if (filtered_sample > 32767.0) filtered_sample = 32767.0;
            if (filtered_sample < -32768.0) filtered_sample = -32768.0;

            audio_buffer[i] = (short)filtered_sample;
        }

        // Write raw PCM audio chunk to stdout
        if (fwrite(audio_buffer, sizeof(short), CHUNK_SIZE, stdout) != CHUNK_SIZE) {
            break;
        }
        fflush(stdout);

        // Sleep briefly to match real-time sample rate pacing (~11.6ms per chunk)
        usleep(10000);
    }

    if (mouse_fd >= 0) close(mouse_fd);
    return 0;
}