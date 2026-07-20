#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

#define GRID_SIZE 64
#define GENERATIONS 64
#define MAX_EVENTS 10000

// Pentatonic / Hierarchical Scale: C, D, E, G, A over multiple octaves
const int SCALE[] = {36, 38, 40, 43, 45, 48, 50, 52, 55, 57, 60, 62, 64, 67, 69, 72, 74, 76, 79, 81, 84, 86, 88, 91, 93};
#define SCALE_SIZE (sizeof(SCALE)/sizeof(SCALE[0]))

typedef struct {
    uint32_t absolute_time; // in ticks
    uint8_t type;           // 0x90 = Note On, 0x80 = Note Off
    uint8_t note;
    uint8_t velocity;
} MidiEvent;

MidiEvent events[MAX_EVENTS];
int event_count = 0;

// Helper to write big-endian integers to MIDI file
void write_32_m(FILE *f, uint32_t value) {
    fputc((value >> 24) & 0xFF, f);
    fputc((value >> 16) & 0xFF, f);
    fputc((value >> 8)  & 0xFF, f);
    fputc(value         & 0xFF, f);
}

void write_16_m(FILE *f, uint16_t value) {
    fputc((value >> 8)  & 0xFF, f);
    fputc(value         & 0xFF, f);
}

// Writes MIDI variable-length quantity
void write_varlen(FILE *f, uint32_t value) {
    uint32_t buffer = value & 0x7F;
    while ((value >>= 7) > 0) {
        buffer <<= 8;
        buffer |= 0x80;
        buffer |= (value & 0x7F);
    }
    while (1) {
        fputc(buffer & 0xFF, f);
        if (buffer & 0x80) buffer >>= 8;
        else break;
    }
}

// Comparison function to sort MIDI events chronologically
int compare_events(const void *a, const void *b) {
    MidiEvent *ea = (MidiEvent *)a;
    MidiEvent *eb = (MidiEvent *)b;
    if (ea->absolute_time != eb->absolute_time)
        return (ea->absolute_time > eb->absolute_time) - (ea->absolute_time < eb->absolute_time);
    return (ea->type > eb->type) - (ea->type < eb->type); // Note Offs before Note Ons if simultaneous
}

// Schedule a note event into our buffer
void schedule_note(uint32_t start_time, uint32_t duration, uint8_t note, uint8_t velocity) {
    if (event_count + 2 >= MAX_EVENTS) return;
    
    events[event_count++] = (MidiEvent){start_time, 0x90, note, velocity};
    events[event_count++] = (MidiEvent){start_time + duration, 0x80, note, 0};
}

// Recursive function to weave the CA history into a branching fractal tree structure in time/pitch space
void weave_fractal_tree(uint8_t history[GENERATIONS][GRID_SIZE], int gen, int cell, uint32_t time, uint32_t duration, int depth, int pitch_offset) {
    if (depth <= 0 || gen >= GENERATIONS || cell < 0 || cell >= GRID_SIZE) return;

    // Check cellular state to determine musical activation
    if (history[gen][cell]) {
        int scale_index = (cell + pitch_offset) % SCALE_SIZE;
        uint8_t note = SCALE[scale_index];
        // Velocity mapped to the local spatial harmony density
        uint8_t velocity = 50 + (depth * 10) + (cell % 20);
        schedule_note(time, duration, note, velocity > 127 ? 127 : velocity);
    }

    // Binary fractal branching factor: generate child branches mirroring the spatial symmetry
    uint32_t next_duration = (duration * 3) / 4;
    if (next_duration < 20) next_duration = 20;

    // Left branch: steps backward in symmetry space, projects forward in time
    weave_fractal_tree(history, gen + 1, (cell - depth + GRID_SIZE) % GRID_SIZE, time + duration, next_duration, depth - 1, pitch_offset - 1);
    // Right branch: steps forward in symmetry space, projects forward in time
    weave_fractal_tree(history, gen + 1, (cell + depth) % GRID_SIZE, time + duration, next_duration, depth - 1, pitch_offset + 1);
}

int main() {
    uint8_t grid[GRID_SIZE];
    uint8_t next_grid[GRID_SIZE];
    uint8_t history[GENERATIONS][GRID_SIZE];

    // Initialize with a symmetrical seed (mirror symmetry around the center)
    memset(grid, 0, GRID_SIZE);
    grid[GRID_SIZE / 2] = 1;
    grid[GRID_SIZE / 2 - 1] = 1;
    memcpy(history[0], grid, GRID_SIZE);

    // Evolve Esoteric Cellular Automaton based on Local Visual Symmetry
    // A cell thrives if its neighborhoods exhibit reflective or shifting balance
    for (int g = 1; g < GENERATIONS; g++) {
        for (int i = 0; i < GRID_SIZE; i++) {
            int l2 = grid[(i - 2 + GRID_SIZE) % GRID_SIZE];
            int l1 = grid[(i - 1 + GRID_SIZE) % GRID_SIZE];
            int r1 = grid[(i + 1) % GRID_SIZE];
            int r2 = grid[(i + 2) % GRID_SIZE];

            // Symmetry-driven evolution rule
            int left_weight = l1 * 2 + l2;
            int right_weight = r1 * 2 + r2;
            
            // Cell activates if there is a balanced or perfectly inverted reflection pattern nearby
            if (left_weight == right_weight && (l1 || r1)) {
                next_grid[i] = 1;
            } else if (l1 ^ r1 ^ l2 ^ r2) {
                next_grid[i] = grid[i] ^ 1; // High entropy flip
            } else {
                next_grid[i] = 0;
            }
        }
        memcpy(grid, next_grid, GRID_SIZE);
        memcpy(history[g], grid, GRID_SIZE);
    }

    // Compile CA History matrix into a Playable Fractal Tree Structure
    // Seed branches from active states of the original generation
    for (int i = 0; i < GRID_SIZE; i++) {
        if (history[0][i]) {
            weave_fractal_tree(history, 0, i, 0, 240, 7, 0);
        }
    }

    // Sort all generated structural events to build valid sequential MIDI deltas
    qsort(events, event_count, sizeof(MidiEvent), compare_events);

    // Write MIDI File Architecture
    FILE *f = fopen("algorithmic_fractal.mid", "wb");
    if (!f) {
        printf("Error creating file.\n");
        return 1;
    }

    // Header Chunk
    fwrite("MThd", 1, 4, f);
    write_32_m(f, 6);   // Chunk size
    write_16_m(f, 0);   // Format 0 single track
    write_16_m(f, 1);   // One track
    write_16_m(f, 480); // Ticks per quarter note

    // Track Chunk Header
    fwrite("MTrk", 1, 4, f);
    
    // Temporal memory to calculate track data size dynamically
    long size_pos = ftell(f);
    write_32_m(f, 0);   // Placeholder for track length

    uint32_t current_time = 0;

    // Set Tempo Event (Microseconds per quarter note: 500,000 = 120 BPM)
    write_varlen(f, 0); // delta time 0
    fputc(0xFF, f); fputc(0x51, f); fputc(0x03, f);
    fputc(0x07, f); fputc(0xA1, f); fputc(0x20);

    // Track Instrument Selection (e.g., Celesta or Marimba for crystalline fractal textures)
    write_varlen(f, 0);
    fputc(0xC0, f); 
    fputc(12, f); // Marimba / Vibraphone space

    // Stream compiled events into track data using Delta-Times
    for (int i = 0; i < event_count; i++) {
        uint32_t delta = events[i].absolute_time - current_time;
        current_time = events[i].absolute_time;
        
        write_varlen(f, delta);
        fputc(events[i].type, f);
        fputc(events[i].note, f);
        fputc(events[i].velocity, f);
    }

    // End of Track Meta Event
    write_varlen(f, 0);
    fputc(0xFF, f); fputc(0x2F, f); fputc(0x00);

    // Calculate structural length and update MIDI Track Header
    long track_end = ftell(f);
    uint32_t track_length = (uint32_t)(track_end - size_pos - 4);
    fseek(f, size_pos, SEEK_SET);
    write_32_m(f, track_length);

    fclose(f);
    printf("Success: Esoteric CA MIDI compiled into 'algorithmic_fractal.mid'.\n");
    return 0;
}