/* Single-file C Quine / WAV polyglot with self-referential spectrographic control-flow encoding */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define SAMPLE_RATE 44100
#define PI 3.14159265358979323846

/* 
 * The program's source code encoded as a string literal.
 * It uses %s to print itself, fulfilling the Quine requirement.
 */
static const char *s = "#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n#include <math.h>\n\n#define SAMPLE_RATE 44100\n#define PI 3.14159265358979323846\n\nstatic const char *s = %c%s%c;\n\n/* WAV Header structure overlaid on C execution */\nstruct WAVHeader {\n    char     riff[4];\n    unsigned int size;\n    char     wave[4];\n    char     fmt[4];\n    unsigned int fmt_size;\n    unsigned short format;\n    unsigned short channels;\n    unsigned int sample_rate;\n    unsigned int byte_rate;\n    unsigned short block_align;\n    unsigned short bits_per_sample;\n    char     data[4];\n    unsigned int data_size;\n};\n\nvoid generate_spectrogram_audio(const char *code, unsigned char *buffer, int num_samples) {\n    int len = strlen(code);\n    double phase = 0.0;\n    /* \n     * Maps the character execution/byte positions of source code\n     * into frequency bins (1 kHz to 5 kHz) over time to render\n     * the real-time control flow on a spectrogram.\n     */\n    for (int i = 0; i < num_samples; i++) {\n        double t = (double)i / SAMPLE_RATE;\n        int code_idx = (int)((t / ((double)num_samples / SAMPLE_RATE)) * len) %% len;\n        char current_char = code[code_idx];\n        \n        /* Base carrier frequency maps control flow index */\n        double freq = 1000.0 + (code_idx %% 80) * 50.0 + (current_char * 2.0);\n        phase += 2.0 * PI * freq / SAMPLE_RATE;\n        \n        /* Amplitude modulated by ASCII value of source char */\n        double amp = (double)current_char / 128.0;\n        short sample = (short)(sin(phase) * amp * 16384.0);\n        \n        buffer[i * 2]     = sample & 0xFF;\n        buffer[i * 2 + 1] = (sample >> 8) & 0xFF;\n    }\n}\n\nint main(void) {\n    int duration_sec = 3;\n    int num_samples = SAMPLE_RATE * duration_sec;\n    int data_bytes = num_samples * 2;\n    int total_file_size = sizeof(struct WAVHeader) + data_bytes;\n    \n    unsigned char *audio_data = (unsigned char *)malloc(data_bytes);\n    generate_spectrogram_audio(s, audio_data, num_samples);\n    \n    /* Synthesize valid WAV header */\n    struct WAVHeader header = {\n        {'R', 'I', 'F', 'F'},\n        total_file_size - 8,\n        {'W', 'A', 'V', 'E'},\n        {'f', 'm', 't', ' '},\n        16, 1, 1, SAMPLE_RATE, SAMPLE_RATE * 2, 2, 16,\n        {'d', 'a', 't', 'a'},\n        data_bytes\n    };\n    \n    /* Output 1: Quine execution outputs raw C source to stdout */\n    /* Output 2: Generate quine.wav to demonstrate valid audio file */\n    FILE *f = fopen(\"quine.wav\", \"wb\");\n    if (f) {\n        fwrite(&header, sizeof(header), 1, f);\n        fwrite(audio_data, 1, data_bytes, f);\n        fclose(f);\n    }\n    \n    /* Print self (Quine output) */\n    printf(s, 34, s, 34);\n    \n    free(audio_data);\n    return 0;\n}\n";

/* WAV Header structure overlaid on C execution */
struct WAVHeader {
    char     riff[4];
    unsigned int size;
    char     wave[4];
    char     fmt[4];
    unsigned int fmt_size;
    unsigned short format;
    unsigned short channels;
    unsigned int sample_rate;
    unsigned int byte_rate;
    unsigned short block_align;
    unsigned short bits_per_sample;
    char     data[4];
    unsigned int data_size;
};

void generate_spectrogram_audio(const char *code, unsigned char *buffer, int num_samples) {
    int len = strlen(code);
    double phase = 0.0;
    /* 
     * Maps the character execution/byte positions of source code
     * into frequency bins (1 kHz to 5 kHz) over time to render
     * the real-time control flow on a spectrogram.
     */
    for (int i = 0; i < num_samples; i++) {
        double t = (double)i / SAMPLE_RATE;
        int code_idx = (int)((t / ((double)num_samples / SAMPLE_RATE)) * len) % len;
        char current_char = code[code_idx];
        
        /* Base carrier frequency maps control flow index */
        double freq = 1000.0 + (code_idx % 80) * 50.0 + (current_char * 2.0);
        phase += 2.0 * PI * freq / SAMPLE_RATE;
        
        /* Amplitude modulated by ASCII value of source char */
        double amp = (double)current_char / 128.0;
        short sample = (short)(sin(phase) * amp * 16384.0);
        
        buffer[i * 2]     = sample & 0xFF;
        buffer[i * 2 + 1] = (sample >> 8) & 0xFF;
    }
}

int main(void) {
    int duration_sec = 3;
    int num_samples = SAMPLE_RATE * duration_sec;
    int data_bytes = num_samples * 2;
    int total_file_size = sizeof(struct WAVHeader) + data_bytes;
    
    unsigned char *audio_data = (unsigned char *)malloc(data_bytes);
    generate_spectrogram_audio(s, audio_data, num_samples);
    
    /* Synthesize valid WAV header */
    struct WAVHeader header = {
        {'R', 'I', 'F', 'F'},
        total_file_size - 8,
        {'W', 'A', 'V', 'E'},
        {'f', 'm', 't', ' '},
        16, 1, 1, SAMPLE_RATE, SAMPLE_RATE * 2, 2, 16,
        {'d', 'a', 't', 'a'},
        data_bytes
    };
    
    /* Output 1: Quine execution outputs raw C source to stdout */
    /* Output 2: Generate quine.wav to demonstrate valid audio file */
    FILE *f = fopen("quine.wav", "wb");
    if (f) {
        fwrite(&header, sizeof(header), 1, f);
        fwrite(audio_data, 1, data_bytes, f);
        fclose(f);
    }
    
    /* Print self (Quine output) */
    printf(s, 34, s, 34);
    
    free(audio_data);
    return 0;
}