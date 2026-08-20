#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * Lossless Binary-to-Epic-Poetry Engine
 * 
 * Maps 4-bit nibbles (0-15) to 16 rhyming Iambic Tetrameter (8-syllable) verses.
 * Verse pair i and j form an AABB rhyme scheme per byte:
 *   High Nibble -> Line 1 (Rhyme A)
 *   Low Nibble  -> Line 2 (Rhyme A)
 *   High Nibble -> Line 3 (Rhyme B)
 *   Low Nibble  -> Line 4 (Rhyme B)
 *
 * Reconstruction exactness: The poem maps deterministically back to bytes.
 */

static const char *A_LINES[16] = {
    "The shadow falls upon the stone",  // 0
    "A lonely traveler walks alone",   // 1
    "The ancient secrets now are known",// 2
    "A seed of destiny is sown",       // 3
    "The silent wind begins to moan",  // 4
    "The king ascends his golden throne",// 5
    "The dragon rests behind the zone",// 6
    "A heavy sword of iron grown",     // 7
    "The night has cast its icy tone", // 8
    "A sacred power long overthrown", // 9
    "The path of fate is overblown",   // 10
    "Through shattered glass the light has shone", // 11
    "The mystic crystal starts to groan", // 12
    "A fallen titan left alone",       // 13
    "The herald blows a horn of bone",  // 14
    "The dark realm claims another zone"  // 15
};

static const char *B_LINES[16] = {
    "The fires burn with steady light", // 0
    "And push away the endless night", // 1
    "The warriors gather for the fight",// 2
    "They battle with heroic might",   // 3
    "The stars above are shining bright",// 4
    "The eagle takes its soaring flight",// 5
    "The dawn reveals a glorious sight",// 6
    "The truth appears in black and white", // 7
    "The shadows fade before our sight",// 8
    "The heavy armor shines so bright",// 9
    "The spell is cast to hold it tight",// 10
    "A spirit ascends to the height",  // 11
    "The realm is saved from evil blight",// 12
    "The sacred vows are sworn aright",// 13
    "The golden sun bestows its light", // 14
    "The darkness breaks and all is right" // 15
};

int lookup_nibble(const char *line, const char *table[]) {
    for (int i = 0; i < 16; i++) {
        if (strcmp(line, table[i]) == 0) return i;
    }
    return -1;
}

void compress(FILE *in, FILE *out) {
    int byte;
    while ((byte = fgetc(in)) != EOF) {
        int high = (byte >> 4) & 0x0F;
        int low = byte & 0x0F;
        
        /* Write 4 lines per byte forming an AABB epic stanza */
        fprintf(out, "%s\n", A_LINES[high]);
        fprintf(out, "%s\n", A_LINES[low]);
        fprintf(out, "%s\n", B_LINES[high]);
        fprintf(out, "%s\n", B_LINES[low]);
        fprintf(out, "\n"); /* Stanza separator */
    }
}

void decompress(FILE *in, FILE *out) {
    char line1[256], line2[256], line3[256], line4[256];
    
    while (fgets(line1, sizeof(line1), in)) {
        /* Strip newlines */
        line1[strcspn(line1, "\r\n")] = 0;
        if (strlen(line1) == 0) continue; /* Skip stanza spacing */

        if (!fgets(line2, sizeof(line2), in) ||
            !fgets(line3, sizeof(line3), in) ||
            !fgets(line4, sizeof(line4), in)) {
            break;
        }

        line2[strcspn(line2, "\r\n")] = 0;
        line3[strcspn(line3, "\r\n")] = 0;
        line4[strcspn(line4, "\r\n")] = 0;

        int high = lookup_nibble(line1, A_LINES);
        int low  = lookup_nibble(line2, A_LINES);

        if (high != -1 && low != -1) {
            fputc((high << 4) | low, out);
        }
    }
}

int main(int argc, char **argv) {
    if (argc < 4) {
        printf("Usage:\n  %s -c <input_binary> <output_epic.txt>\n  %s -d <input_epic.txt> <output_binary>\n", argv[0], argv[0]);
        return 1;
    }

    FILE *in = fopen(argv[2], "rb");
    FILE *out = fopen(argv[3], "wb");

    if (!in || !out) {
        perror("File opening failed");
        return 1;
    }

    if (strcmp(argv[1], "-c") == 0) {
        compress(in, out);
    } else if (strcmp(argv[1], "-d") == 0) {
        decompress(in, out);
    } else {
        printf("Unknown flag: %s\n", argv[1]);
    }

    fclose(in);
    fclose(out);
    return 0;
}