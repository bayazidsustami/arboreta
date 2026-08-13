/*
 * Git Repository Ambient Synthesizer
 * ----------------------------------
 * Ingests a git repository/source folder and translates code complexity into sound:
 * - Variable identifiers hash to scale notes, setting oscillator frequencies.
 * - Control flow constructs (if, for, while, switch) trigger rhythmic drum beats.
 * - Commit count (git log) controls Schroeder hall reverb decay time.
 *
 * Compilation: gcc -O2 -o gitsynth gitsynth.c -lm
 * Execution:   ./gitsynth [path_to_repo] > ambient.wav
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <ctype.h>

#define SAMPLE_RATE 44100
#define DURATION_SEC 12
#define TOTAL_SAMPLES (SAMPLE_RATE * DURATION_SEC)
#define PI 3.14159265358979323846f
#define MAX_OSC 32
#define MAX_BEATS 128
#define COMB_COUNT 4
#define ALLPASS_COUNT 2

/* A-Minor / Lydian Ambient Scale Frequencies (Hz) */
static const float SCALE_FREQ[] = {
    110.00f, 130.81f, 146.83f, 164.81f, 196.00f,
    220.00f, 261.63f, 293.66f, 329.63f, 392.00f,
    440.00f, 523.25f, 587.33f, 659.25f, 783.99f
};
#define SCALE_SIZE (sizeof(SCALE_FREQ)/sizeof(SCALE_FREQ[0]))

typedef struct {
    float *buffer;
    int size;
    int idx;
    float feedback;
} DelayFilter;

/* Hash function for mapping variable names to scale tones */
static unsigned int hash_string(const char *str) {
    unsigned int hash = 5381;
    int c;
    while ((c = *str++)) {
        hash = ((hash << 5) + hash) + c;
    }
    return hash;
}

/* Check if identifier is a control flow keyword */
static int is_control_flow(const char *w) {
    const char *kw[] = {"if", "else", "for", "while", "switch", "case", "do", "break", "return", "try", "catch"};
    for (size_t i = 0; i < sizeof(kw)/sizeof(kw[0]); i++) {
        if (strcmp(w, kw[i]) == 0) return 1;
    }
    return 0;
}

/* Output standard 16-bit PCM mono WAV header */
static void write_wav_header(FILE *out, int total_samples) {
    int data_size = total_samples * 2;
    int file_size = 36 + data_size;
    int sample_rate = SAMPLE_RATE;
    int byte_rate = SAMPLE_RATE * 2;
    short format = 1, channels = 1, bits_per_sample = 16, block_align = 2;
    int subchunk1_size = 16;

    fwrite("RIFF", 1, 4, out);
    fwrite(&file_size, 4, 1, out);
    fwrite("WAVEfmt ", 1, 8, out);
    fwrite(&subchunk1_size, 4, 1, out);
    fwrite(&format, 2, 1, out);
    fwrite(&channels, 2, 1, out);
    fwrite(&sample_rate, 4, 1, out);
    fwrite(&byte_rate, 4, 1, out);
    fwrite(&block_align, 2, 1, out);
    fwrite(&bits_per_sample, 2, 1, out);
    fwrite("data", 1, 4, out);
    fwrite(&data_size, 4, 1, out);
}

int main(int argc, char **argv) {
    const char *repo_path = (argc > 1) ? argv[1] : ".";
    char cmd[512];

    /* 1. Commit History Controls Reverb Decay Time */
    snprintf(cmd, sizeof(cmd), "git -C \"%s\" rev-list --count HEAD 2>/dev/null", repo_path);
    FILE *pcmd = popen(cmd, "r");
    int commit_count = 10;
    if (pcmd) {
        if (fscanf(pcmd, "%d", &commit_count) != 1) commit_count = 10;
        pclose(pcmd);
    }
    if (commit_count < 1) commit_count = 1;

    /* Reverb decay factor increases asymptotically with commit density */
    float reverb_feedback = 0.70f + 0.26f * (1.0f - expf(-commit_count / 40.0f));

    /* 2. Ingest Source Code for Variable Frequencies & Rhythmic Control Flow Beats */
    float freqs[MAX_OSC];
    int num_osc = 0;
    float beat_times[MAX_BEATS];
    int num_beats = 0;

    snprintf(cmd, sizeof(cmd), "find \"%s\" -type f \\( -name \"*.c\" -o -name \"*.h\" -o -name \"*.py\" -o -name \"*.js\" -o -name \"*.cpp\" \\) -exec cat {} + 2>/dev/null", repo_path);
    FILE *fcode = popen(cmd, "r");
    if (!fcode) fcode = stdin;

    char buf[1024];
    int token_count = 0;

    while (fgets(buf, sizeof(buf), fcode)) {
        char *ptr = buf;
        while (*ptr) {
            if (isalpha(*ptr) || *ptr == '_') {
                char word[128];
                int len = 0;
                while ((isalnum(*ptr) || *ptr == '_') && len < 127) {
                    word[len++] = *ptr++;
                }
                word[len] = '\0';
                token_count++;

                if (is_control_flow(word)) {
                    /* Control flow branches drive rhythmic beats */
                    if (num_beats < MAX_BEATS) {
                        float beat_time = (float)(token_count % 128) / 128.0f * DURATION_SEC;
                        beat_times[num_beats++] = beat_time;
                    }
                } else if (len > 2) {
                    /* Variable names set oscillator frequencies */
                    if (num_osc < MAX_OSC) {
                        unsigned int h = hash_string(word);
                        freqs[num_osc++] = SCALE_FREQ[h % SCALE_SIZE];
                    }
                }
            } else {
                ptr++;
            }
        }
    }
    if (fcode != stdin) pclose(fcode);

    /* Fallback tone generators if input repo is small or empty */
    if (num_osc == 0) {
        freqs[0] = 220.00f; freqs[1] = 293.66f; freqs[2] = 329.63f;
        num_osc = 3;
    }
    if (num_beats == 0) {
        for (int i = 0; i < 16; i++) beat_times[num_beats++] = i * (DURATION_SEC / 16.0f);
    }

    /* 3. Initialize Schroeder Hall Reverb Filters */
    int comb_delays[COMB_COUNT] = {1116, 1188, 1277, 1356};
    DelayFilter combs[COMB_COUNT];
    for (int i = 0; i < COMB_COUNT; i++) {
        combs[i].size = comb_delays[i];
        combs[i].buffer = (float *)calloc(combs[i].size, sizeof(float));
        combs[i].idx = 0;
        combs[i].feedback = reverb_feedback;
    }

    int allpass_delays[ALLPASS_COUNT] = {225, 556};
    DelayFilter allpasses[ALLPASS_COUNT];
    for (int i = 0; i < ALLPASS_COUNT; i++) {
        allpasses[i].size = allpass_delays[i];
        allpasses[i].buffer = (float *)calloc(allpasses[i].size, sizeof(float));
        allpasses[i].idx = 0;
        allpasses[i].feedback = 0.5f;
    }

    /* 4. Synthesize Audio Signal and Output PCM WAV Stream */
    write_wav_header(stdout, TOTAL_SAMPLES);
    float osc_phases[MAX_OSC] = {0};

    for (int s = 0; s < TOTAL_SAMPLES; s++) {
        float t = (float)s / SAMPLE_RATE;

        /* Ambient Oscillator Drone (Variable Names) */
        float synth_signal = 0.0f;
        for (int o = 0; o < num_osc; o++) {
            osc_phases[o] += 2.0f * PI * freqs[o] / SAMPLE_RATE;
            if (osc_phases[o] >= 2.0f * PI) osc_phases[o] -= 2.0f * PI;

            /* LFO slow amplitude modulation */
            float lfo = 0.5f + 0.5f * sinf(2.0f * PI * (0.08f + 0.015f * o) * t);
            synth_signal += sinf(osc_phases[o]) * lfo;
        }
        synth_signal = (synth_signal / num_osc) * 0.35f;

        /* Rhythmic Percussion Strikes (Control Flow Branches) */
        float beat_signal = 0.0f;
        for (int b = 0; b < num_beats; b++) {
            float dt = t - beat_times[b];
            if (dt >= 0.0f && dt < 0.18f) {
                float env = expf(-dt * 28.0f);
                float kick = sinf(2.0f * PI * (65.0f * expf(-dt * 25.0f)) * dt);
                float noise = ((float)rand() / RAND_MAX - 0.5f) * 0.25f;
                beat_signal += (kick * 0.75f + noise * 0.25f) * env;
            }
        }
        beat_signal *= 0.25f;

        float dry = synth_signal + beat_signal;

        /* Schroeder Reverb Processing (Commit History Reverb Decay) */
        float comb_out = 0.0f;
        for (int c = 0; c < COMB_COUNT; c++) {
            float delayed = combs[c].buffer[combs[c].idx];
            comb_out += delayed;
            combs[c].buffer[combs[c].idx] = dry + delayed * combs[c].feedback;
            combs[c].idx = (combs[c].idx + 1) % combs[c].size;
        }
        comb_out /= COMB_COUNT;

        float wet = comb_out;
        for (int a = 0; a < ALLPASS_COUNT; a++) {
            float buf_val = allpasses[a].buffer[allpasses[a].idx];
            float out_val = -wet + buf_val;
            allpasses[a].buffer[allpasses[a].idx] = wet + (out_val * allpasses[a].feedback);
            allpasses[a].idx = (allpasses[a].idx + 1) % allpasses[a].size;
            wet = out_val;
        }

        /* Final Audio Mix and Clipping Guard */
        float output = dry * 0.55f + wet * 0.45f;
        if (output > 1.0f) output = 1.0f;
        if (output < -1.0f) output = -1.0f;

        short pcm = (short)(output * 32767.0f);
        fwrite(&pcm, sizeof(short), 1, stdout);
    }

    /* Clean Up Filter Buffers */
    for (int i = 0; i < COMB_COUNT; i++) free(combs[i].buffer);
    for (int i = 0; i < ALLPASS_COUNT; i++) free(allpasses[i].buffer);

    return 0;
}