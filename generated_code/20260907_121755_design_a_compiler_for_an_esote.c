#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

#define SAMPLE_RATE 44100
#define PI 3.14159265358979323846

/* Synthesizer voice representation derived from SVG shapes */
typedef struct {
    double freq_start;
    double freq_end;
    double duration;
    double pan;         /* 0.0 (left) to 1.0 (right) */
    double amplitude;
    double x_pos;
} Voice;

/* Convert SVG hexadecimal color string (#RRGGBB) into a base frequency in Hz.
   Hue/brightness determine microtonal pitch spanning a fine 24-EDO scale. */
static double color_to_frequency(const char *hex) {
    unsigned int r = 128, g = 128, b = 128;
    if (hex && hex[0] == '#') {
        sscanf(hex + 1, "%02x%02x%02x", &r, &g, &b);
    }
    /* Map RGB sum and balance to a microtonal octave around A4 (440Hz) */
    double cents = ((r * 3 + g * 5 + b * 2) % 2400);
    return 440.0 * pow(2.0, (cents - 1200.0) / 1200.0);
}

/* Write a standard WAV file header to stdout */
static void write_wav_header(FILE *out, uint32_t num_samples) {
    uint32_t subchunk2_size = num_samples * 2 * sizeof(int16_t);
    uint32_t chunk_size = 36 + subchunk2_size;
    uint32_t byte_rate = SAMPLE_RATE * 2 * sizeof(int16_t);
    uint16_t block_align = 2 * sizeof(int16_t);
    uint16_t num_channels = 2;
    uint16_t audio_format = 1;
    uint16_t bits_per_sample = 16;

    fwrite("RIFF", 1, 4, out);
    fwrite(&chunk_size, 4, 1, out);
    fwrite("WAVE", 1, 4, out);
    fwrite("fmt ", 1, 4, out);
    
    uint32_t subchunk1_size = 16;
    fwrite(&subchunk1_size, 4, 1, out);
    fwrite(&audio_format, 2, 1, out);
    fwrite(&num_channels, 2, 1, out);
    
    uint32_t sample_rate = SAMPLE_RATE;
    fwrite(&sample_rate, 4, 1, out);
    fwrite(&byte_rate, 4, 1, out);
    fwrite(&block_align, 2, 1, out);
    fwrite(&bits_per_sample, 2, 1, out);
    
    fwrite("data", 1, 4, out);
    fwrite(&subchunk2_size, 4, 1, out);
}

/* Parse a primitive subset of SVG tags (<rect>, <circle>) to construct musical voices */
static int parse_svg(FILE *in, Voice *voices, int max_voices) {
    char line[1024];
    int count = 0;

    while (fgets(line, sizeof(line), in) && count < max_voices) {
        if (strstr(line, "<rect") || strstr(line, "<circle")) {
            double x = 0, y = 0, width = 100, height = 100, r = 50;
            char fill[32] = "#808080";

            /* Extract key geometric attributes */
            char *p = strstr(line, "x=\"");
            if (p) sscanf(p, "x=\"%lf\"", &x);
            
            p = strstr(line, "cx=\"");
            if (p) sscanf(p, "cx=\"%lf\"", &x);

            p = strstr(line, "y=\"");
            if (p) sscanf(p, "y=\"%lf\"", &y);
            
            p = strstr(line, "cy=\"");
            if (p) sscanf(p, "cy=\"%lf\"", &y);

            p = strstr(line, "width=\"");
            if (p) sscanf(p, "width=\"%lf\"", &width);

            p = strstr(line, "height=\"");
            if (p) sscanf(p, "height=\"%lf\"", &height);
            
            p = strstr(line, "r=\"");
            if (p) sscanf(p, "r=\"%lf\"", &r);

            p = strstr(line, "fill=\"");
            if (p) sscanf(p, "fill=\"%31[^\"]\"", fill);

            /* Map SVG geometry to musical parameters:
               - Fill color -> Base Frequency
               - X coordinate -> Stereo Panning
               - Y coordinate -> Pitch Glissando End Frequency
               - Size (Area) -> Duration & Amplitude */
            double base_freq = color_to_frequency(fill);
            double area = (strstr(line, "<circle")) ? (PI * r * r) : (width * height);
            
            voices[count].freq_start = base_freq;
            voices[count].freq_end = base_freq * pow(2.0, (y / 500.0) - 0.5); /* Microtonal drift based on Y */
            voices[count].duration = 3.0 + (area / 2000.0);                   /* Larger shapes sustain longer */
            voices[count].pan = fmax(0.0, fmin(1.0, x / 1000.0));             /* Map X 0-1000 to Left-Right */
            voices[count].amplitude = fmin(0.2, 0.02 + (area / 100000.0));
            voices[count].x_pos = x;
            count++;
        }
    }
    return count;
}

int main(int argc, char **argv) {
    FILE *in = stdin;
    if (argc > 1) {
        in = fopen(argv[1], "r");
        if (!in) {
            fprintf(stderr, "Error opening SVG file.\n");
            return 1;
        }
    }

    Voice voices[128];
    int num_voices = parse_svg(in, voices, 128);
    if (in != stdin) fclose(in);

    if (num_voices == 0) {
        /* Fallback default SVG source if no input shapes were provided */
        voices[0] = (Voice){ 220.0, 221.5, 12.0, 0.2, 0.1, 100 };
        voices[1] = (Voice){ 277.18, 275.0, 15.0, 0.8, 0.08, 800 };
        voices[2] = (Voice){ 329.63, 332.0, 10.0, 0.5, 0.12, 500 };
        num_voices = 3;
    }

    /* Determine total ambient track duration based on longest voice */
    double max_duration = 0.0;
    for (int i = 0; i < num_voices; i++) {
        if (voices[i].duration > max_duration) {
            max_duration = voices[i].duration;
        }
    }

    uint32_t total_samples = (uint32_t)(max_duration * SAMPLE_RATE);
    write_wav_header(stdout, total_samples);

    /* Render audio buffer frame by frame */
    for (uint32_t s = 0; s < total_samples; s++) {
        double t = (double)s / SAMPLE_RATE;
        double mix_l = 0.0;
        double mix_r = 0.0;

        for (int v = 0; v < num_voices; v++) {
            if (t <= voices[v].duration) {
                /* Smooth envelope fade-in and fade-out */
                double env = sin(PI * (t / voices[v].duration));
                env = pow(env, 2.0);

                /* Linear frequency interpolation for microtonal glissando */
                double progress = t / voices[v].duration;
                double current_freq = voices[v].freq_start + progress * (voices[v].freq_end - voices[v].freq_start);
                
                /* Sine oscillator with soft additive harmonics for ambient warmth */
                double phase = 2.0 * PI * current_freq * t;
                double wave = sin(phase) + 0.3 * sin(2.0 * phase) + 0.1 * sin(3.0 * phase);

                double sample = wave * env * voices[v].amplitude;
                
                /* Stereo panning */
                mix_l += sample * (1.0 - voices[v].pan);
                mix_r += sample * voices[v].pan;
            }
        }

        /* Soft clipping / master output limiting */
        mix_l = tankh_limit(mix_l);
        mix_r = tankh_limit(mix_r);

        int16_t out_l = (int16_t)(mix_l * 32767.0);
        int16_t out_r = (int16_t)(mix_r * 32767.0);

        fwrite(&out_l, sizeof(int16_t), 1, stdout);
        fwrite(&out_r, sizeof(int16_t), 1, stdout);
    }

    return 0;
}

/* Helper function for smooth audio output limiting */
static double tankh_limit(double x) {
    if (x > 1.0) return 1.0;
    if (x < -1.0) return -1.0;
    return x - (x * x * x) / 3.0;
}