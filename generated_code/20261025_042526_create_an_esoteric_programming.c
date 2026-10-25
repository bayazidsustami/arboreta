#include <stdio.h>
#include <string.h>
#include <stdlib.h>

/* 
 * ChordScript Interpreter
 * An esoteric programming language where code consists of musical chords.
 * Execution immediately halts if a dissonant interval (tritone / 6 semitones) is played.
 * 
 * Instructions:
 *   C  - Increment value at current tape pointer
 *   Dm - Decrement value at current tape pointer
 *   Em - Move tape pointer left
 *   F  - Move tape pointer right
 *   G  - Print ASCII character at current tape pointer
 *   Bdim - Contains a tritone interval (dissonant) -> Halts execution!
 */

int is_dissonant(int semitones[], int count) {
    for (int i = 0; i < count; i++) {
        for (int j = i + 1; j < count; j++) {
            int diff = abs(semitones[i] - semitones[j]) % 12;
            if (diff == 6) return 1; // Tritone found: musical dissonance!
        }
    }
    return 0;
}

int main(int argc, char *argv[]) {
    // Default program: prints "HI" using chord progression
    const char *progression = (argc > 1) ? argv[1] : 
        "C C C C C C C C C C F C C C C C C C C C C C G F C C C C C C C C C C C C C C C C G";

    unsigned char tape[30000] = {0};
    int ptr = 0;

    const char *p = progression;
    char token[64];

    while (*p) {
        while (*p == ' ' || *p == '\t' || *p == '\n') p++;
        if (!*p) break;

        int i = 0;
        while (*p && *p != ' ' && *p != '\t' && *p != '\n' && i < 63) {
            token[i++] = *p++;
        }
        token[i] = '\0';

        int semitones[4] = {0};
        int count = 3;
        int op = 0;

        if (strcmp(token, "C") == 0) {
            semitones[0] = 0; semitones[1] = 4; semitones[2] = 7;
            op = 1;
        } else if (strcmp(token, "Dm") == 0) {
            semitones[0] = 2; semitones[1] = 5; semitones[2] = 9;
            op = 2;
        } else if (strcmp(token, "Em") == 0) {
            semitones[0] = 4; semitones[1] = 7; semitones[2] = 11;
            op = 3;
        } else if (strcmp(token, "F") == 0) {
            semitones[0] = 5; semitones[1] = 9; semitones[2] = 0;
            op = 4;
        } else if (strcmp(token, "G") == 0) {
            semitones[0] = 7; semitones[1] = 11; semitones[2] = 2;
            op = 5;
        } else if (strcmp(token, "Bdim") == 0) {
            semitones[0] = 11; semitones[1] = 2; semitones[2] = 5;
            op = 0; // Triggers dissonance check
        } else {
            continue; // Ignore unknown chords
        }

        // Enforce the golden rule of harmonic execution
        if (is_dissonant(semitones, count)) {
            printf("\n[DISSONANCE HALT] Chord '%s' contains a tritone! Execution aborted.\n", token);
            break;
        }

        // Execute operation
        switch (op) {
            case 1: tape[ptr]++; break;
            case 2: tape[ptr]--; break;
            case 3: if (ptr > 0) ptr--; break;
            case 4: ptr++; break;
            case 5: putchar(tape[ptr]); fflush(stdout); break;
        }
    }

    printf("\n");
    return 0;
}