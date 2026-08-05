/*
 * Sonified Garbage Collector & Generative Ambient Composition
 *
 * Compiles: gcc -O2 main.c -lm -o gc_synth
 * Run:      ./gc_synth | aplay -f cd  (or redirect to raw file/ffplay)
 *
 * Description:
 * Implements a custom mark-and-sweep garbage collector managing a dynamic object graph.
 * As memory allocation and GC cycles execute, real-time heap telemetry (pause times,
 * reclamation ratios, fragmentation, live object count) modulates a 4-voice ambient synthesizer:
 *   - Voice 1 (Sub-Drone): Root frequency governed by total live heap volume.
 *   - Voice 2 (Ambient Pad): Generates harmonic chord intervals scaled by GC cycle durations.
 *   - Voice 3 (Arp/Pluck): Sequenced notes triggered by individual object allocations.
 *   - Voice 4 (Reclaim Burst/Texture): Noise/percussive bursts synthesized during GC sweep phase.
 *
 * Audio output: 44.1 kHz, 16-bit Signed LPCM Stereo to STDOUT.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <string.h>
#include <time.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

#define SAMPLE_RATE 44100
#define MAX_OBJECTS 128
#define HEAP_THRESHOLD 90
#define DELAY_LINE_LEN 22050

// Object structure in custom GC
typedef struct Object {
    uint8_t marked;
    size_t size;
    struct Object* ref_a;
    struct Object* ref_b;
    uint32_t payload;
} Object;

// Virtual Machine / Heap State
typedef struct {
    Object* objects[MAX_OBJECTS];
    size_t num_objects;
    Object* roots[16];
    size_t num_roots;
    
    // Telemetry for audio synthesis
    double last_gc_duration;
    double live_bytes_ratio;
    uint32_t last_alloc_addr;
    int gc_trigger_flag;
    int sweep_trigger_flag;
} GC_VM;

static GC_VM vm;

// Synthesizer State
typedef struct {
    double phase_v1, phase_v2, phase_v3, phase_v4;
    double env_v3, env_v4;
    double target_freq_v1, current_freq_v1;
    double target_freq_v2, current_freq_v2;
    double freq_v3;
    float delay_buffer[DELAY_LINE_LEN];
    int delay_ptr;
} Synth;

static Synth synth;

// Pentatonic scale helper
static const double SCALE_PENTATONIC[] = { 130.81, 146.83, 164.81, 196.00, 220.00, 261.63, 293.66, 329.63, 392.00, 440.00 };

// --- Garbage Collector Core ---

void gc_mark(Object* obj) {
    if (!obj || obj->marked) return;
    obj->marked = 1;
    gc_mark(obj->ref_a);
    gc_mark(obj->ref_b);
}

void gc_collect(void) {
    clock_t start = clock();
    vm.gc_trigger_flag = 1;

    // Mark Phase
    for (size_t i = 0; i < vm.num_roots; i++) {
        gc_mark(vm.roots[i]);
    }

    // Sweep Phase
    size_t live_count = 0;
    size_t reclaimed_bytes = 0;
    vm.sweep_trigger_flag = 1;

    for (size_t i = 0; i < vm.num_objects; i++) {
        if (vm.objects[i] != NULL) {
            if (!vm.objects[i]->marked) {
                reclaimed_bytes += vm.objects[i]->size;
                free(vm.objects[i]);
                vm.objects[i] = NULL;
            } else {
                vm.objects[i]->marked = 0; // Reset mark bit
                live_count++;
            }
        }
    }

    // Compact pointer array
    size_t write_idx = 0;
    for (size_t i = 0; i < vm.num_objects; i++) {
        if (vm.objects[i] != NULL) {
            vm.objects[write_idx++] = vm.objects[i];
        }
    }
    vm.num_objects = write_idx;

    clock_t end = clock();
    vm.last_gc_duration = (double)(end - start) / CLOCKS_PER_SEC;
    vm.live_bytes_ratio = (double)vm.num_objects / MAX_OBJECTS;
    
    // Modulate synthesizer base parameters based on GC metrics
    synth.target_freq_v1 = SCALE_PENTATONIC[(int)(vm.live_bytes_ratio * 4)];
    synth.target_freq_v2 = synth.target_freq_v1 * (1.5 + 0.5 * sin(vm.last_gc_duration * 1000.0));
    synth.env_v4 = 1.0; // Trigger noise burst on sweep
}

Object* gc_alloc(size_t size) {
    if (vm.num_objects >= HEAP_THRESHOLD) {
        gc_collect();
    }

    Object* obj = (Object*)malloc(sizeof(Object) + size);
    if (!obj) {
        gc_collect(); // Force collection if allocation fails
        obj = (Object*)malloc(sizeof(Object) + size);
        if (!obj) return NULL;
    }

    obj->marked = 0;
    obj->size = size;
    obj->ref_a = NULL;
    obj->ref_b = NULL;
    obj->payload = (uint32_t)rand();

    vm.objects[vm.num_objects++] = obj;
    vm.last_alloc_addr = (uint32_t)(uintptr_t)obj;

    // Trigger voice 3 pluck on allocation
    synth.freq_v3 = SCALE_PENTATONIC[obj->payload % 10] * 2.0;
    synth.env_v3 = 0.8;

    return obj;
}

// Mutator: Simulates program activity generating heap references & garbage
void mutator_step(void) {
    // Random allocation
    size_t alloc_size = (rand() % 64) + 16;
    Object* new_obj = gc_alloc(alloc_size);

    if (new_obj && vm.num_objects > 1) {
        // Build graph topology
        int r_idx = rand() % vm.num_objects;
        if (vm.objects[r_idx]) {
            if (rand() % 2) new_obj->ref_a = vm.objects[r_idx];
            else new_obj->ref_b = vm.objects[r_idx];
        }
    }

    // Mutate roots periodically
    if (rand() % 100 < 15 || vm.num_roots == 0) {
        size_t root_slot = rand() % 16;
        if (vm.num_objects > 0) {
            vm.roots[root_slot] = vm.objects[rand() % vm.num_objects];
            if (root_slot >= vm.num_roots) vm.num_roots = root_slot + 1;
        }
    }

    // Sever root references to produce garbage
    if (rand() % 100 < 10 && vm.num_roots > 0) {
        vm.roots[rand() % vm.num_roots] = NULL;
    }
}

// --- Generative Audio Engine ---

void render_audio_frame(int16_t* left_out, int16_t* right_out) {
    // Smooth frequency transitions
    synth.current_freq_v1 += (synth.target_freq_v1 - synth.current_freq_v1) * 0.001;
    synth.current_freq_v2 += (synth.target_freq_v2 - synth.current_freq_v2) * 0.002;

    // Voice 1: Sub Drone (Warm Sine with Soft Clipping)
    synth.phase_v1 += 2.0 * M_PI * (synth.current_freq_v1 / 2.0) / SAMPLE_RATE;
    if (synth.phase_v1 >= 2.0 * M_PI) synth.phase_v1 -= 2.0 * M_PI;
    double v1 = tanh(sin(synth.phase_v1) * 1.5) * 0.35;

    // Voice 2: Ambient Pad (Dual Osc Harmonization modulated by live ratio)
    synth.phase_v2 += 2.0 * M_PI * synth.current_freq_v2 / SAMPLE_RATE;
    if (synth.phase_v2 >= 2.0 * M_PI) synth.phase_v2 -= 2.0 * M_PI;
    double v2 = sin(synth.phase_v2) * sin(synth.phase_v2 * 0.501) * 0.25;

    // Voice 3: Allocation Pluck (Damped Triangle Wave)
    synth.phase_v3 += 2.0 * M_PI * synth.freq_v3 / SAMPLE_RATE;
    if (synth.phase_v3 >= 2.0 * M_PI) synth.phase_v3 -= 2.0 * M_PI;
    double tri = (2.0 / M_PI) * asin(sin(synth.phase_v3));
    double v3 = tri * synth.env_v3 * 0.2;
    synth.env_v3 *= 0.9998; // Exponential decay

    // Voice 4: Sweep Noise Burst (Filtered Noise)
    double noise = ((double)rand() / RAND_MAX) * 2.0 - 1.0;
    double v4 = noise * synth.env_v4 * 0.15;
    synth.env_v4 *= 0.9992; // Decay sweep sound

    // Mix dry signals
    double mix_left = v1 + v2 * 0.7 + v3 * 0.8 + v4 * 0.5;
    double mix_right = v1 + v2 * 0.7 + v3 * 0.2 + v4 * 0.5;

    // Stereo Delay/Reverb Effect
    float delay_in = (float)(mix_left + mix_right) * 0.5f;
    float delay_out = synth.delay_buffer[synth.delay_ptr];
    synth.delay_buffer[synth.delay_ptr] = delay_in + delay_out * 0.45f;
    synth.delay_ptr = (synth.delay_ptr + 1) % DELAY_LINE_LEN;

    mix_left += delay_out * 0.35;
    mix_right += delay_out * 0.25;

    // Soft Master Limiter
    mix_left = tanh(mix_left);
    mix_right = tanh(mix_right);

    *left_out = (int16_t)(mix_left * 30000.0);
    *right_out = (int16_t)(mix_right * 30000.0);
}

int main(void) {
    srand((unsigned int)time(NULL));

    // Initialize state
    synth.current_freq_v1 = synth.target_freq_v1 = 130.81;
    synth.current_freq_v2 = synth.target_freq_v2 = 196.00;
    
    // Output 60 seconds of generative audio (44100 samples/sec * 60)
    size_t total_samples = SAMPLE_RATE * 60;
    int16_t buffer[2];

    for (size_t s = 0; s < total_samples; s++) {
        // Run workload mutator periodically every ~200 samples
        if (s % 200 == 0) {
            mutator_step();
        }

        render_audio_frame(&buffer[0], &buffer[1]);
        fwrite(buffer, sizeof(int16_t), 2, stdout);
    }

    return 0;
}