import { writeFileSync, unlinkSync } from "fs";
import { execSync } from "child_process";

// 1. Generate the C code string that acts as both source code and frequency spectrum data
const cSourceCode = `#include <stdio.h>
#include <math.h>

#define SAMPLE_RATE 44100
#define PI 3.14159265358979323846

int main() {
    // Source code string used for self-sonification
    const char *src = "ARCHITECT_ZERO_DEP_AUDIO_SYNTHESIZER_C_PARSER_FREQ_SPECTRUM_SELF_SONIFYING_AMBIENT_SOUNDSCAPE";
    
    // Calculate total character count to step through frequency bins
    int len = 0;
    while (src[len] != '\\0') len++;

    // Generate 10 seconds of raw PCM 16-bit stereo audio stream
    int total_samples = SAMPLE_RATE * 10;
    for (int t = 0; t < total_samples; t++) {
        double time = (double)t / SAMPLE_RATE;
        double sample_l = 0.0;
        double sample_r = 0.0;

        // Overlay harmonics based on character ASCII values
        for (int i = 0; i < len; i += 2) {
            double base_freq = 55.0 + (src[i] % 48) * 12.0; // Map ASCII to scale frequencies
            double modulation = sin(2.0 * PI * (0.1 + (i * 0.01)) * time);
            
            // Add fundamental frequency and subtle harmonic shifts
            sample_l += sin(2.0 * PI * base_freq * time) * 0.05 * (1.0 + modulation);
            
            if (i + 1 < len) {
                double sub_freq = 55.0 + (src[i + 1] % 48) * 12.0;
                sample_r += sin(2.0 * PI * sub_freq * time) * 0.05 * (1.0 - modulation);
            }
        }

        // Apply global amplitude envelope to smooth soundscape transitions
        double envelope = sin(PI * time / 10.0);
        sample_l *= envelope;
        sample_r *= envelope;

        // Convert double samples (-1.0 to 1.0) to 16-bit signed integers
        short out_l = (short)(sample_l * 32767.0);
        short out_r = (short)(sample_r * 32767.0);

        // Output raw PCM bytes to stdout
        putchar(out_l & 0xFF);
        putchar((out_l >> 8) & 0xFF);
        putchar(out_r & 0xFF);
        putchar((out_r >> 8) & 0xFF);
    }
    return 0;
}
`;

// 2. Write the raw C code to a temporary file
const cFilePath = "./synth.c";
const executablePath = "./synth";
const pcmOutputPath = "./output.pcm";

writeFileSync(cFilePath, cSourceCode, "utf8");

try {
  // 3. Compile the generated C audio synthesizer using gcc
  execSync(`gcc -O2 ${cFilePath} -o ${executablePath} -lm`);

  // 4. Run the executable and capture stdout directly into a PCM audio file
  execSync(`${executablePath} > ${pcmOutputPath}`);

  console.log(`Successfully generated self-sonifying soundscape: ${pcmOutputPath}`);
} catch (error) {
  console.error("Error executing dynamic C synthesizer generation:", error);
} finally {
  // Cleanup temporary C build artifacts
  try { unlinkSync(cFilePath); } catch {}
  try { unlinkSync(executablePath); } catch {}
}