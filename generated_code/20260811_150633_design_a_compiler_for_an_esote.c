/* 
 * PolyStitch Compiler
 * Compiles musical polyrhythms into binary byte structures 
 * that form symmetric vector cross-stitch grid layouts.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

typedef struct {
    uint32_t beat_a; // Primary pulse tempo (e.g., 3 in 3:4)
    uint32_t beat_b; // Secondary pulse tempo (e.g., 4 in 3:4)
} Polyrhythm;

// Greatest Common Divisor
static uint32_t gcd(uint32_t a, uint32_t b) {
    return b == 0 ? a : gcd(b, a % b);
}

// Least Common Multiple to determine polyrhythmic cycle length
static uint32_t lcm(uint32_t a, uint32_t b) {
    if (a == 0 || b == 0) return 1;
    return (a * b) / gcd(a, b);
}

// Compiles polyrhythm into executable ELF header & cross-stitch binary matrix
void compile_polyrhythm_to_stitch(Polyrhythm poly, const char *out_filename) {
    uint32_t total_beats = lcm(poly.beat_a, poly.beat_b);
    uint32_t grid_size = total_beats < 8 ? 8 : total_beats;

    // Minimal executable header template (ELF64 structure)
    uint8_t elf_header[64] = {
        0x7F, 'E', 'L', 'F', 0x02, 0x01, 0x01, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x02, 0x00, 0x3E, 0x00, 0x01, 0x00, 0x00, 0x00,
        0x78, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x28, 0x00, 0x38, 0x00,
        0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    };

    // x86_64 machine code exit(total_beats) syscall payload
    uint8_t payload[] = {
        0x48, 0xC7, 0xC0, 0x3C, 0x00, 0x00, 0x00,                // mov rax, 60 (sys_exit)
        0x48, 0xC7, 0xC7, (uint8_t)(total_beats & 0xFF), 0x00, 0x00, 0x00, // mov rdi, beats
        0x0F, 0x05,                                             // syscall
        0x90, 0x90, 0x90, 0x90                                  // NOP alignment
    };

    FILE *f = fopen(out_filename, "wb");
    if (!f) {
        perror("Failed to open target output file");
        return;
    }

    // Write header
    fwrite(elf_header, 1, sizeof(elf_header), f);

    printf("=== PolyStitch Compiler ===\n");
    printf("Source Polyrhythm: %u:%u\n", poly.beat_a, poly.beat_b);
    printf("Pattern Grid Matrix (%ux%u):\n\n", grid_size, grid_size);

    // Map 2D rhythmic interference pattern into raw bytes
    for (uint32_t y = 0; y < grid_size; y++) {
        for (uint32_t x = 0; x < grid_size; x++) {
            uint8_t pulse_a = ((x * poly.beat_a) % total_beats) == 0;
            uint8_t pulse_b = ((y * poly.beat_b) % total_beats) == 0;

            char stitch_symbol = '.';
            uint8_t byte_val = 0x90; // Default NOP

            if (pulse_a && pulse_b) {
                stitch_symbol = 'X';  // Cross-stitch intersection
                byte_val = 0xCC;      // INT3 opcode
            } else if (pulse_a) {
                stitch_symbol = '/';  // Diagonal thread direction A
                byte_val = 0x90;      // NOP thread
            } else if (pulse_b) {
                stitch_symbol = '\\'; // Diagonal thread direction B
                byte_val = 0xF4;      // HLT thread
            }

            // Print visual cross-stitch representation
            printf("%c ", stitch_symbol);

            // Embed machine instruction payload at start of section
            uint32_t idx = y * grid_size + x;
            if (idx < sizeof(payload)) {
                byte_val = payload[idx];
            }

            fputc(byte_val, f);
        }
        printf("\n");
    }

    fclose(f);
    printf("\nCompilation complete. Saved binary: '%s'\n", out_filename);
}

int main(int argc, char *argv[]) {
    Polyrhythm poly = {3, 4}; // Default polyrhythm (3 against 4)

    if (argc >= 3) {
        poly.beat_a = (uint32_t)atoi(argv[1]);
        poly.beat_b = (uint32_t)atoi(argv[2]);
    } else {
        printf("No rhythm args provided. Defaulting to 3:4 polyrhythm.\n");
        printf("Usage: %s <beat_A> <beat_B> [out_file]\n\n", argv[0]);
    }

    const char *out_file = (argc >= 4) ? argv[3] : "polyrhythm_crossstitch.bin";
    compile_polyrhythm_to_stitch(poly, out_file);

    return 0;
}