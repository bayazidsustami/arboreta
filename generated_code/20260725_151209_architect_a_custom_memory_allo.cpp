/*
 * Microtonal Memory Sonifier
 *
 * A custom C++ heap allocator that maps real-time memory fragmentation metrics
 * to a 44.1kHz 16-bit PCM microtonal audio composition streamed to stdout.
 *
 * Low fragmentation -> Pure harmonic chord overtones (Just Intonation triads).
 * High fragmentation -> Microtonal frequency detuning, tritone extensions, and jazz dissonance.
 *
 * Pipe output directly to an audio player, e.g.:
 * g++ -O3 -std=c++17 main.cpp -o sonifier && ./sonifier | aplay -f cd
 * OR: ./sonifier | ffplay -f s16le -ar 44100 -ac 1 -
 */

#include <iostream>
#include <vector>
#include <cmath>
#include <random>
#include <cstdint>
#include <algorithm>

constexpr int SAMPLE_RATE = 44100;
constexpr double PI = 3.14159265358979323846;
constexpr size_t POOL_SIZE = 1024; // Total size of custom heap memory pool in bytes

// Block descriptor for free-list tracking
struct MemoryBlock {
    size_t offset;
    size_t size;
    bool is_free;
};

// Custom Allocator that measures contiguity vs. fragmentation
class MicrotonalHeap {
private:
    uint8_t memory_pool[POOL_SIZE];
    std::vector<MemoryBlock> blocks;

public:
    MicrotonalHeap() {
        blocks.push_back({0, POOL_SIZE, true});
    }

    // First-fit allocation strategy
    void* allocate(size_t size) {
        for (auto it = blocks.begin(); it != blocks.end(); ++it) {
            if (it->is_free && it->size >= size) {
                size_t remaining = it->size - size;
                size_t offset = it->offset;

                it->is_free = false;
                it->size = size;

                if (remaining > 0) {
                    blocks.insert(it + 1, {offset + size, remaining, true});
                }
                return memory_pool + offset;
            }
        }
        return nullptr; // Heap full or fragmented beyond fit
    }

    // Free block and coalesce adjacent free regions
    void deallocate(void* ptr) {
        if (!ptr) return;
        size_t offset = static_cast<uint8_t*>(ptr) - memory_pool;

        for (size_t i = 0; i < blocks.size(); ++i) {
            if (blocks[i].offset == offset) {
                blocks[i].is_free = true;
                break;
            }
        }

        // Coalesce free blocks to heal fragmentation
        for (size_t i = 0; i + 1 < blocks.size(); ) {
            if (blocks[i].is_free && blocks[i + 1].is_free) {
                blocks[i].size += blocks[i + 1].size;
                blocks.erase(blocks.begin() + i + 1);
            } else {
                ++i;
            }
        }
    }

    // Calculates fragmentation index [0.0 = completely clean/contiguous, 1.0 = severely fragmented]
    double get_fragmentation_factor() const {
        size_t total_free_bytes = 0;
        size_t max_free_contiguous_block = 0;

        for (const auto& block : blocks) {
            if (block.is_free) {
                total_free_bytes += block.size;
                max_free_contiguous_block = std::max(max_free_contiguous_block, block.size);
            }
        }

        if (total_free_bytes == 0 || total_free_bytes == POOL_SIZE) return 0.0;

        double contiguity_ratio = static_cast<double>(max_free_contiguous_block) / total_free_bytes;
        return 1.0 - contiguity_ratio;
    }
};

// Microtonal Audio Synthesizer Engine
class AudioSynthesizer {
private:
    double phases[4] = {0.0, 0.0, 0.0, 0.0};

    // Frequency calculation with continuous microtonal pitch bending
    double midi_to_freq(double note) {
        return 440.0 * std::pow(2.0, (note - 69.0) / 12.0);
    }

public:
    // Render PCM audio frames corresponding to current memory fragmentation state
    void synthesize_state(double fragmentation, double duration_seconds) {
        int total_samples = static_cast<int>(SAMPLE_RATE * duration_seconds);
        double root_note = 60.0; // Fundamental note C4

        // Clean heap -> Pure C Major triad harmonics (Root, Maj3, 5th, Octave)
        // Fragmented heap -> Devolves into dissonant microtonal jazz cluster (Root, b9, Tritone, Maj7 with detuning)
        double note1 = root_note + (fragmentation * 1.15); 
        double note2 = root_note + (fragmentation < 0.35 ? 4.0 : 3.0) + (fragmentation * 3.73);
        double note3 = root_note + (fragmentation < 0.35 ? 7.0 : 6.0) + (fragmentation * 5.41);
        double note4 = root_note + (fragmentation < 0.35 ? 12.0 : 11.0) + (fragmentation * 8.89);

        double freqs[4] = {
            midi_to_freq(note1),
            midi_to_freq(note2),
            midi_to_freq(note3),
            midi_to_freq(note4)
        };

        for (int i = 0; i < total_samples; ++i) {
            double mixed_sample = 0.0;

            for (int k = 0; k < 4; ++k) {
                phases[k] += 2.0 * PI * freqs[k] / SAMPLE_RATE;
                if (phases[k] >= 2.0 * PI) phases[k] -= 2.0 * PI;

                // Higher fragmentation adds FM frequency modulation chaos
                double modulation = (k > 0) ? (fragmentation * 0.4 * std::sin(phases[0])) : 0.0;
                mixed_sample += std::sin(phases[k] + modulation);
            }

            // Attenuate and convert to 16-bit signed integer sample
            mixed_sample *= 0.20;
            int16_t pcm_16 = static_cast<int16_t>(mixed_sample * 32767.0);

            // Stream raw 16-bit PCM audio directly to standard output
            std::cout.write(reinterpret_cast<const char*>(&pcm_16), sizeof(pcm_16));
        }
    }
};

int main() {
    MicrotonalHeap heap;
    AudioSynthesizer synth;
    std::mt19937 rng(1337);
    std::vector<void*> allocations;

    // Phase 1: Sequential allocations -> Pure harmonic contiguity
    for (int i = 0; i < 20; ++i) {
        void* ptr = heap.allocate(24);
        if (ptr) allocations.push_back(ptr);
        synth.synthesize_state(heap.get_fragmentation_factor(), 0.12);
    }

    // Phase 2: Punch random holes in memory -> Induce fragmentation & trigger dissonant microtonal jazz
    std::uniform_int_distribution<size_t> size_gen(8, 48);
    for (int step = 0; step < 100; ++step) {
        if (!allocations.empty() && (step % 2 == 0 || rng() % 3 == 0)) {
            size_t idx = rng() % allocations.size();
            heap.deallocate(allocations[idx]);
            allocations.erase(allocations.begin() + idx);
        } else {
            void* ptr = heap.allocate(size_gen(rng));
            if (ptr) allocations.push_back(ptr);
        }

        synth.synthesize_state(heap.get_fragmentation_factor(), 0.10);
    }

    // Phase 3: Gradual memory cleanup -> Coalesces heap and resolves dissonance back into harmony
    while (!allocations.empty()) {
        heap.deallocate(allocations.back());
        allocations.pop_back();
        synth.synthesize_state(heap.get_fragmentation_factor(), 0.15);
    }

    return 0;
}