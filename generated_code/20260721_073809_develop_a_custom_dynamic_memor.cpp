#include <iostream>
#include <fstream>
#include <vector>
#include <cmath>
#include <cstdint>
#include <algorithm>
#include <cstring>
#include <random>

constexpr uint32_t SAMPLE_RATE = 44100;
constexpr double PI = 3.14159265358979323846;

// Standard WAV Header structure for binary audio export
#pragma pack(push, 1)
struct WAVHeader {
    char riff[4] = {'R', 'I', 'F', 'F'};
    uint32_t chunkSize = 0;
    char wave[4] = {'W', 'A', 'V', 'E'};
    char fmt[4] = {'f', 'm', 't', ' '};
    uint32_t subchunk1Size = 16;
    uint16_t audioFormat = 1; // PCM
    uint16_t numChannels = 1; // Mono
    uint32_t sampleRate = SAMPLE_RATE;
    uint32_t byteRate = SAMPLE_RATE * 2;
    uint16_t blockAlign = 2;
    uint16_t bitsPerSample = 16;
    char data[4] = {'d', 'a', 't', 'a'};
    uint32_t subchunk2Size = 0;
};
#pragma pack(pop)

// Dynamic Audio Synthesizer & Memory Manager
class MusicalMemoryManager {
private:
    static constexpr size_t ARENA_SIZE = 1024 * 64; // 64 KB heap arena
    alignas(16) uint8_t arena[ARENA_SIZE];

    struct Block {
        size_t offset;
        size_t size;
        bool is_free;
        double frequency;
    };

    std::vector<Block> blocks;
    std::vector<int16_t> audio_buffer;

    // Maps heap offset/address to musical frequencies in a C Pentatonic scale
    double offsetToFrequency(size_t offset) {
        static const double pentatonic_ratios[] = {1.0, 1.125, 1.25, 1.5, 1.6875}; // C, D, E, G, A
        size_t note_idx = (offset / 128) % 5;
        size_t octave = 2 + ((offset / 640) % 4); // Octaves 2 through 5
        double base_freq = 130.81; // C3
        return base_freq * std::pow(2.0, static_cast<double>(octave - 2)) * pentatonic_ratios[note_idx];
    }

    // Synthesizes polyphonic audio frames representing active heap memory layout
    void renderAudioSegment(double duration_sec, double glitch_intensity = 0.0) {
        size_t total_samples = static_cast<size_t>(SAMPLE_RATE * duration_sec);

        for (size_t s = 0; s < total_samples; ++s) {
            double mixed_sample = 0.0;
            int active_count = 0;

            // Polyphonic additive synthesis of all allocated memory blocks
            for (const auto& block : blocks) {
                if (!block.is_free) {
                    double time = audio_buffer.size() / static_cast<double>(SAMPLE_RATE);
                    double phase = 2.0 * PI * block.frequency * time;
                    
                    // Timbre modulation based on block size
                    double wave = std::sin(phase) + 0.25 * std::sin(phase * 2.0);
                    mixed_sample += wave * 0.15;
                    active_count++;
                }
            }

            // Synthesize noisy glitch timbre during GC defragmentation sweeps
            if (glitch_intensity > 0.0) {
                mixed_sample += glitch_intensity * ((std::rand() % 1000) / 1000.0 - 0.5);
            }

            // Dynamic gain normalization to prevent audio clipping
            if (active_count > 0) {
                mixed_sample /= std::sqrt(static_cast<double>(active_count));
            }
            mixed_sample = std::clamp(mixed_sample, -0.9, 0.9);

            audio_buffer.push_back(static_cast<int16_t>(mixed_sample * 32767.0));
        }
    }

public:
    MusicalMemoryManager() {
        // Initialize memory arena with a single contiguous free block
        blocks.push_back({0, ARENA_SIZE, true, offsetToFrequency(0)});
    }

    // Custom Allocate: Maps address space offset to a musical pitch tone
    void* allocate(size_t size) {
        for (auto it = blocks.begin(); it != blocks.end(); ++it) {
            if (it->is_free && it->size >= size) {
                size_t remainder = it->size - size;
                size_t offset = it->offset;

                it->size = size;
                it->is_free = false;
                it->frequency = offsetToFrequency(offset);

                if (remainder > 0) {
                    blocks.insert(it + 1, {offset + size, remainder, true, offsetToFrequency(offset + size)});
                }

                // Play sound event upon allocation
                renderAudioSegment(0.12);
                return static_cast<void*>(arena + offset);
            }
        }
        return nullptr; // Out of memory
    }

    // Custom Deallocate: Removes frequency component from the polyphonic mixture
    void deallocate(void* ptr) {
        if (!ptr) return;
        size_t offset = static_cast<uint8_t*>(ptr) - arena;

        for (auto& block : blocks) {
            if (block.offset == offset) {
                block.is_free = true;
                break;
            }
        }
        // Play acoustic transition upon freeing memory
        renderAudioSegment(0.08);
    }

    // Garbage Collection & Defragmentation Sweep: Creates rapid pitch sweep & timbre shift
    void defragment() {
        std::cout << "[GC] Executing Defragmentation Sweep...\n";

        size_t current_offset = 0;
        std::vector<Block> new_blocks;

        for (auto& block : blocks) {
            if (!block.is_free) {
                size_t old_offset = block.offset;
                block.offset = current_offset;
                block.frequency = offsetToFrequency(current_offset);

                // Physical memory compaction relocation
                std::memmove(arena + current_offset, arena + old_offset, block.size);
                current_offset += block.size;

                new_blocks.push_back(block);

                // Render glissando sweep during GC compaction
                renderAudioSegment(0.04, 0.25);
            }
        }

        if (current_offset < ARENA_SIZE) {
            new_blocks.push_back({current_offset, ARENA_SIZE - current_offset, true, offsetToFrequency(current_offset)});
        }

        blocks = std::move(new_blocks);
        renderAudioSegment(0.25); // Chord resolution upon GC completion
    }

    // Export generated polyphonic audio composition to a standard WAV file
    void exportWAV(const std::string& filename) {
        WAVHeader header;
        header.subchunk2Size = static_cast<uint32_t>(audio_buffer.size() * sizeof(int16_t));
        header.chunkSize = 36 + header.subchunk2Size;

        std::ofstream file(filename, std::ios::binary);
        file.write(reinterpret_cast<const char*>(&header), sizeof(header));
        file.write(reinterpret_cast<const char*>(audio_buffer.data()), header.subchunk2Size);
        std::cout << "Polyphonic Memory Composition written to: " << filename << "\n";
    }
};

int main() {
    MusicalMemoryManager memory_composer;
    std::vector<void*> allocations;
    std::mt19937 rng(1337);

    std::cout << "Starting Polyphonic Memory Composition...\n";

    // Movement 1: Rapid Allocation Cascade
    for (int i = 0; i < 24; ++i) {
        size_t sz = 256 + (rng() % 1536);
        allocations.push_back(memory_composer.allocate(sz));
    }

    // Movement 2: Interleaved Deallocation (Creating Fragmentation)
    for (size_t i = 0; i < allocations.size(); i += 2) {
        memory_composer.deallocate(allocations[i]);
        allocations[i] = nullptr;
    }

    // Movement 3: Allocating into Fragmented Gaps
    for (int i = 0; i < 12; ++i) {
        size_t sz = 128 + (rng() % 512);
        allocations.push_back(memory_composer.allocate(sz));
    }

    // Movement 4: Real-time Garbage Collection & Defragmentation Sweep
    memory_composer.defragment();

    // Movement 5: Final Cleanup
    for (void* ptr : allocations) {
        if (ptr) memory_composer.deallocate(ptr);
    }

    // Output rendered polyphonic audio file
    memory_composer.exportWAV("memory_symphony.wav");

    return 0;
}