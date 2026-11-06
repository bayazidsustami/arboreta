#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

// Define musical notes representing pointer identifiers
typedef enum {
    NOTE_C = 0,
    NOTE_D = 1,
    NOTE_E = 2,
    NOTE_F = 3,
    NOTE_G = 4,
    NOTE_A = 5,
    NOTE_B = 6,
    NOTE_NONE = -1
} Note;

const char* note_names[] = {"C", "D", "E", "F", "G", "A", "B"};

// Musical memory block structure
typedef struct {
    Note note;
    void *ptr;
    bool active;
} MusicalBlock;

#define MAX_BLOCKS 16
MusicalBlock heap[MAX_BLOCKS];

// Rolling buffer to track the last 3 note allocations for chord detection
Note progression[3] = {NOTE_NONE, NOTE_NONE, NOTE_NONE};

// Determines if a three-note sequence forms a harmonious chord (e.g., C Major: C-E-G or F Major: F-A-C)
bool is_harmonious(Note n1, Note n2, Note n3) {
    if (n1 == NOTE_C && n2 == NOTE_E && n3 == NOTE_G) return true; // C Major Triad
    if (n1 == NOTE_F && n2 == NOTE_A && n3 == NOTE_C) return true; // F Major Triad
    return false;
}

// Garbage Collector triggered exclusively by musical harmony
void collect_garbage() {
    printf("\n[GC CONCERT] Harmonious Chord Progression Achieved! Reclaiming all active memory...\n");
    for (int i = 0; i < MAX_BLOCKS; i++) {
        if (heap[i].active) {
            free(heap[i].ptr);
            heap[i].active = false;
            printf("[GC] Released memory block bound to note %s\n", note_names[heap[i].note]);
        }
    }
    // Reset progression buffer after collection
    progression[0] = NOTE_NONE;
    progression[1] = NOTE_NONE;
    progression[2] = NOTE_NONE;
}

// Allocates memory tied to a specific musical note
void* melody_alloc(Note note, size_t size) {
    for (int i = 0; i < MAX_BLOCKS; i++) {
        if (!heap[i].active) {
            heap[i].note = note;
            heap[i].ptr = malloc(size);
            heap[i].active = true;
            
            printf("Allocated %zu bytes at note %s (Slot %d)\n", size, note_names[note], i);

            // Shift progression window
            progression[0] = progression[1];
            progression[1] = progression[2];
            progression[2] = note;

            // Check if the new note completes a harmonious chord
            if (is_harmonious(progression[0], progression[1], progression[2])) {
                collect_garbage();
            }

            return heap[i].ptr;
        }
    }
    printf("Out of musical memory slots!\n");
    return NULL;
}

int main() {
    // Initialize memory heap
    for (int i = 0; i < MAX_BLOCKS; i++) {
        heap[i].active = false;
    }

    printf("=== Symphony of the Heap Initialized ===\n\n");

    // Play a random melody (allocations that don't trigger GC)
    melody_alloc(NOTE_D, 128);
    melody_alloc(NOTE_F, 256);
    melody_alloc(NOTE_A, 64);

    printf("\n--- Introducing Harmony to Trigger Garbage Collection ---\n");

    // Play C - E - G (C Major Triad) -> Triggers Garbage Collection!
    melody_alloc(NOTE_C, 32);
    melody_alloc(NOTE_E, 64);
    melody_alloc(NOTE_G, 512);

    printf("\n=== Symphony Completed Successfully ===\n");
    return 0;
}