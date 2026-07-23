/* 
 * Self-Ingesting Executable-to-Audio Synthesizer
 * Maps raw executable binary entropy into a polyphonic score and outputs output.wav.
 * Simulates memory leaks via un-freed heap echo blocks that dynamically decay into reverb.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>

#define SAMPLE_RATE 44100
#define SAMPLES_PER_BYTE 2205  // 50ms per byte
#define LEAK_POOL_SIZE 8820    // Reverb feedback delay (~200ms)
#define PI 3.14159265358979323846

// Standard 44.1kHz 16-bit Mono WAV header struct
typedef struct {
    char     riff[4];
    uint32_t chunk_size;
    char     wave[4];
    char     fmt_label[4];
    uint32_t fmt_size;
    uint16_t format;
    uint16_t channels;
    uint32_t sample_rate;
    uint32_t byte_rate;
    uint16_t block_align;
    uint16_t bits_per_sample;
    char     data_label[4];
    uint32_t data_size;
} WavHeader;

// Polyphonic scale base frequencies
static const float SCALE[] = {
    130.81f, 146.83f, 164.81f, 174.61f, 196.00f, 
    220.00f, 246.94f, 261.63f, 293.66f, 329.63f, 
    349.23f, 392.00f, 440.00f, 493.88f, 523.25f
};

int main(int argc, char *argv[]) {
    // Ingest executable binary
    const char *self_path = (argc > 0 && argv[0]) ? argv[0] : "a.out";
    FILE *exe = fopen(self_path, "rb");
    if (!exe) return 1;

    fseek(exe, 0, SEEK_END);
    long exe_size = ftell(exe);
    fseek(exe, 0, SEEK_SET);

    if (exe_size <= 0) { fclose(exe); return 1; }

    unsigned char *exe_data = (unsigned char *)malloc(exe_size);
    if (!exe_data) { fclose(exe); return 1; }
    fread(exe_data, 1, exe_size, exe);
    fclose(exe);

    // Prepare target WAV file
    FILE *wav = fopen("output.wav", "wb");
    if (!wav) { free(exe_data); return 1; }

    uint32_t total_samples = (uint32_t)(exe_size * SAMPLES_PER_BYTE + LEAK_POOL_SIZE * 10);
    uint32_t data_bytes = total_samples * sizeof(int16_t);

    WavHeader header = {
        {'R', 'I', 'F', 'F'}, 36 + data_bytes, {'W', 'A', 'V', 'E'},
        {'f', 'm', 't', ' '}, 16, 1, 1, SAMPLE_RATE,
        SAMPLE_RATE * sizeof(int16_t), sizeof(int16_t), 16,
        {'d', 'a', 't', 'a'}, data_bytes
    };
    fwrite(&header, sizeof(WavHeader), 1, wav);

    // Memory Leak Simulator: Dynamically allocated unfreed feedback buffers
    float *leak_pool = (float *)calloc(LEAK_POOL_SIZE, sizeof(float));
    size_t leak_idx = 0;

    double phase_root = 0.0, phase_harmony = 0.0, phase_sub = 0.0;

    for (uint32_t s = 0; s < total_samples; s++) {
        long byte_offset = s / SAMPLES_PER_BYTE;
        float sample = 0.0f;

        if (byte_offset < exe_size) {
            unsigned char b = exe_data[byte_offset];

            // Extract multi-voice polyphony from raw byte entropy
            float f_root    = SCALE[b % 15];
            float f_harmony = SCALE[(b >> 3) % 15] * 1.25f; // Major third offset
            float f_sub     = SCALE[(b ^ 0xAA) % 15] * 0.5f; // Sub-octave base

            phase_root    += 2.0 * PI * f_root / SAMPLE_RATE;
            phase_harmony += 2.0 * PI * f_harmony / SAMPLE_RATE;
            phase_sub     += 2.0 * PI * f_sub / SAMPLE_RATE;

            // Synthesis: Mix fundamental sine, triangle, and sub-square waves
            float v1 = sin(phase_root);
            float v2 = (fabs(fmod(phase_harmony / PI, 2.0) - 1.0) - 0.5f) * 2.0f;
            float v3 = (sin(phase_sub) >= 0.0f) ? 0.3f : -0.3f;

            sample = (v1 * 0.4f) + (v2 * 0.3f) + (v3 * 0.2f);
        }

        // Memory Leak Reverb Engine: Accumulated feedback from uncleaned heap space
        float leaked_reverb = leak_pool[leak_idx] * 0.72f; 
        sample += leaked_reverb;

        // "Leaking" output sample back into the feedback heap ring
        leak_pool[leak_idx] = sample;
        leak_idx = (leak_idx + 1) % LEAK_POOL_SIZE;

        // Hard limiting / Soft clipping output audio
        if (sample > 1.0f) sample = 1.0f;
        if (sample < -1.0f) sample = -1.0f;

        int16_t pcm_sample = (int16_t)(sample * 32767.0f);
        fwrite(&pcm_sample, sizeof(int16_t), 1, wav);
    }

    // Intentionally omit free(leak_pool) to complete the memory leak concept
    free(exe_data);
    fclose(wav);

    return 0;
}