#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <math.h>

#define SAMPLE_RATE 8000
#define DURATION_SEC 10
#define TOTAL_SAMPLES (SAMPLE_RATE * DURATION_SEC)
#define STACK_MAX 1024

// Emotional Memory Pool
typedef struct {
    double warmth;     // Affects harmonic frequency scaling
    double intensity;  // Affects bitwise fractal scale
    double longing;    // Controls echo / resonance loop
    size_t allocated_bytes;
    int *emotion_heap;
} EmotionalMemory;

// Metaphor Call Stack
typedef struct {
    int data[STACK_MAX];
    int top;
} CallStack;

void push(CallStack *s, int val) {
    if (s->top < STACK_MAX - 1) {
        s->data[++(s->top)] = val;
    }
}

int pop(CallStack *s) {
    if (s->top >= 0) return s->data[(s->top)--];
    return 0;
}

int peek(CallStack *s) {
    if (s->top >= 0) return s->data[s->top];
    return 1;
}

// Write standard 44-byte WAV header for 8kHz 8-bit mono output
void write_wav_header(FILE *out, size_t num_samples) {
    unsigned int data_size = (unsigned int)num_samples;
    unsigned int file_size = data_size + 36;
    unsigned int sample_rate = SAMPLE_RATE;
    unsigned int byte_rate = SAMPLE_RATE;
    unsigned short block_align = 1;
    unsigned short bits_per_sample = 8;
    unsigned short audio_format = 1; // PCM
    unsigned short num_channels = 1; // Mono

    fwrite("RIFF", 1, 4, out);
    fwrite(&file_size, 4, 1, out);
    fwrite("WAVEfmt ", 1, 8, out);
    
    unsigned int subchunk1_size = 16;
    fwrite(&subchunk1_size, 4, 1, out);
    fwrite(&audio_format, 2, 1, out);
    fwrite(&num_channels, 2, 1, out);
    fwrite(&sample_rate, 4, 1, out);
    fwrite(&byte_rate, 4, 1, out);
    fwrite(&block_align, 2, 1, out);
    fwrite(&bits_per_sample, 2, 1, out);
    fwrite("data", 1, 4, out);
    fwrite(&data_size, 4, 1, out);
}

// Emotional Tone Analysis & Heap Allocation
EmotionalMemory analyze_and_allocate(const char *text) {
    EmotionalMemory mem = {0};
    char *copy = strdup(text);
    char *token = strtok(copy, " \t\n\r.,!?;:");

    while (token != NULL) {
        for (int i = 0; token[i]; i++) token[i] = (char)tolower(token[i]);

        if (strstr(token, "love") || strstr(token, "heart") || strstr(token, "passion") || strstr(token, "fire")) {
            mem.warmth += 1.5;
        } else if (strstr(token, "forever") || strstr(token, "eternal") || strstr(token, "deep") || strstr(token, "soul")) {
            mem.intensity += 2.0;
        } else if (strstr(token, "tears") || strstr(token, "shadow") || strstr(token, "dark") || strstr(token, "miss")) {
            mem.longing += 1.2;
        }
        mem.warmth += 0.05 * strlen(token);
        token = strtok(NULL, " \t\n\r.,!?;:");
    }
    free(copy);

    if (mem.warmth < 1.0) mem.warmth = 1.0;
    if (mem.intensity < 1.0) mem.intensity = 1.0;
    if (mem.longing < 1.0) mem.longing = 1.0;

    // Dynamic memory size dictated by overall emotional weight
    mem.allocated_bytes = (size_t)(mem.warmth * mem.intensity * 64);
    mem.emotion_heap = (int *)malloc(mem.allocated_bytes * sizeof(int));
    if (mem.emotion_heap) {
        for (size_t i = 0; i < mem.allocated_bytes; i++) {
            mem.emotion_heap[i] = (int)(sin(i * mem.longing) * 127 + 128);
        }
    }
    return mem;
}

// Metaphor Stack Manipulator
void process_metaphors(const char *text, CallStack *stack, EmotionalMemory *mem) {
    char *copy = strdup(text);
    char *token = strtok(copy, " \t\n\r.,!?;:");
    int val_counter = 1;

    while (token != NULL) {
        for (int i = 0; token[i]; i++) token[i] = (char)tolower(token[i]);

        // Metaphorical Language mappings to stack instructions
        if (strcmp(token, "descend") == 0 || strcmp(token, "deep") == 0 || strcmp(token, "fall") == 0) {
            push(stack, val_counter * 3);
        } else if (strcmp(token, "soar") == 0 || strcmp(token, "fly") == 0 || strcmp(token, "rise") == 0) {
            push(stack, val_counter * 7);
        } else if (strcmp(token, "echo") == 0 || strcmp(token, "mirror") == 0 || strcmp(token, "reflect") == 0) {
            int top = peek(stack);
            push(stack, top ^ 0x55);
        } else if (strcmp(token, "fade") == 0 || strcmp(token, "leave") == 0 || strcmp(token, "return") == 0) {
            pop(stack);
        } else {
            if (mem->emotion_heap && mem->allocated_bytes > 0) {
                size_t idx = val_counter % mem->allocated_bytes;
                mem->emotion_heap[idx] ^= (int)strlen(token);
            }
        }
        val_counter++;
        token = strtok(NULL, " \t\n\r.,!?;:");
    }
    free(copy);
}

// Generates fractal PCM bytebeat music influenced by emotion and stack state
unsigned char generate_fractal_sample(unsigned long t, const CallStack *stack, const EmotionalMemory *mem) {
    int s_val = peek(stack);
    if (s_val == 0) s_val = 1;

    double w = mem->warmth;
    double inst = mem->intensity;

    unsigned long freq_mod = (unsigned long)(w * 4.0);
    if (freq_mod == 0) freq_mod = 1;

    // Generative bitwise fractal equation
    unsigned long k1 = (t * s_val) >> 3;
    unsigned long k2 = (t >> (4 + ((int)inst % 4)));
    unsigned long k3 = (t * freq_mod | (t >> 7));

    unsigned char sample = (unsigned char)(((k1 & k2) | k3) ^ (s_val & 0xFF));

    // Modulate with emotional heap memory
    if (mem->emotion_heap && mem->allocated_bytes > 0) {
        size_t heap_idx = (t + s_val) % mem->allocated_bytes;
        sample = (sample + mem->emotion_heap[heap_idx]) / 2;
    }

    return sample;
}

int main(void) {
    const char *love_letter = 
        "My eternal love, as I descend into the deep silence of my heart, "
        "your passion burns like a fire. I fly through shadows and rise above time. "
        "Echoes of your voice mirror my soul forever. We soar into eternity, "
        "and return to where our heart beats as one.";

    // Parse emotional tone to dictate memory allocation
    EmotionalMemory mem = analyze_and_allocate(love_letter);

    // Initialize Metaphor Call Stack
    CallStack stack = {.top = -1};
    push(&stack, 12);

    // Process metaphorical syntax into stack operations
    process_metaphors(love_letter, &stack, &mem);

    const char *filename = "love_fractal.wav";
    FILE *wav_file = fopen(filename, "wb");
    if (!wav_file) {
        wav_file = stdout;
    } else {
        fprintf(stderr, "Parsing love letter...\n");
        fprintf(stderr, "Emotional Tone -> Warmth: %.2f, Intensity: %.2f, Longing: %.2f\n", 
                mem.warmth, mem.intensity, mem.longing);
        fprintf(stderr, "Allocated %zu bytes of emotional memory.\n", mem.allocated_bytes);
        fprintf(stderr, "Call Stack size after metaphor execution: %d\n", stack.top + 1);
        fprintf(stderr, "Streaming generative fractal music to '%s'...\n", filename);
    }

    write_wav_header(wav_file, TOTAL_SAMPLES);

    for (unsigned long t = 0; t < TOTAL_SAMPLES; t++) {
        unsigned char sample = generate_fractal_sample(t, &stack, &mem);
        fputc(sample, wav_file);
    }

    if (wav_file != stdout) {
        fclose(wav_file);
        fprintf(stderr, "Done! Audio output saved to '%s'.\n", filename);
    }

    free(mem.emotion_heap);
    return 0;
}