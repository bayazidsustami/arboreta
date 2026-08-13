#include <iostream>
#include <vector>
#include <cmath>
#include <chrono>
#include <thread>
#include <string>
#include <algorithm>
#include <random>

// Platform-specific audio output setup
#if defined(_WIN32)
    #include <windows.h>
    #include <mmeapi.h>
    #pragma comment(lib, "winmm.lib")
#elif defined(__APPLE__)
    #include <AudioToolbox/AudioToolbox.h>
#else
    // Linux ALSA / Standard Fallback
    #include <alsa/asoundlib.h>
#endif

// --- CONFIGURATION ---
constexpr int GRID_WIDTH = 32;
constexpr int GRID_HEIGHT = 16;
constexpr int SAMPLE_RATE = 44100;
constexpr int BPM = 120;
constexpr double TICK_DURATION = 60.0 / BPM / 2.0; // 8th-note steps (~250ms)

// Pentatonic / Ambient Harmonic Scale (MIDI note numbers across 4 octaves)
const std::vector<int> HARMONIC_SCALE = {
    36, 38, 40, 43, 45,  // C2, D2, E2, G2, A2 (Bass)
    48, 50, 52, 55, 57,  // C3, D3, E3, G3, A3
    60, 62, 64, 67, 69,  // C4, D4, E4, G4, A4 (Mid)
    72, 74, 76, 79, 81,  // C5, D5, E5, G5, A5 (High)
    84, 86, 88, 91, 93   // C6, D6, E6, G6, A6
};

// Converts MIDI pitch to frequency in Hertz
double midiToFreq(int midi) {
    return 440.0 * std::pow(2.0, (midi - 69) / 12.0);
}

// --- CELLULAR AUTOMATON GRID ---
struct Cell {
    bool alive = false;
    int age = 0;
};

class CellularAutomaton {
public:
    std::vector<std::vector<Cell>> grid;

    CellularAutomaton() : grid(GRID_HEIGHT, std::vector<Cell>(GRID_WIDTH)) {
        seedRandom();
    }

    void seedRandom() {
        std::mt19937 rng(1337); // Seeded for deterministic yet complex evolution
        std::uniform_int_distribution<int> dist(0, 3);
        for (int r = 0; r < GRID_HEIGHT; ++r) {
            for (int c = 0; c < GRID_WIDTH; ++c) {
                grid[r][c].alive = (dist(rng) == 0);
                grid[r][c].age = grid[r][c].alive ? 1 : 0;
            }
        }
    }

    int countNeighbors(int r, int c) const {
        int count = 0;
        for (int dr = -1; dr <= 1; ++dr) {
            for (int dc = -1; dc <= 1; ++dc) {
                if (dr == 0 && dc == 0) continue;
                int nr = (r + dr + GRID_HEIGHT) % GRID_HEIGHT;
                int nc = (c + dc + GRID_WIDTH) % GRID_WIDTH;
                if (grid[nr][nc].alive) count++;
            }
        }
        return count;
    }

    void step() {
        auto nextGrid = grid;
        for (int r = 0; r < GRID_HEIGHT; ++r) {
            for (int c = 0; c < GRID_WIDTH; ++c) {
                int neighbors = countNeighbors(r, c);
                if (grid[r][c].alive) {
                    if (neighbors == 2 || neighbors == 3) {
                        nextGrid[r][c].alive = true;
                        nextGrid[r][c].age = std::min(grid[r][c].age + 1, 30);
                    } else {
                        nextGrid[r][c].alive = false;
                        nextGrid[r][c].age = 0;
                    }
                } else {
                    if (neighbors == 3) {
                        nextGrid[r][c].alive = true;
                        nextGrid[r][c].age = 1;
                    }
                }
            }
        }
        grid = nextGrid;
    }
};

// --- AUDIO SYNTHESIS & RENDERER ---
class AudioEngine {
#if defined(_WIN32)
    HWAVEOUT hWaveOut;
    WAVEHDR waveHeader[2];
    std::vector<short> buffers[2];
#elif defined(__APPLE__)
    AudioQueueRef queue;
    AudioQueueBufferRef buffers[2];
#else
    snd_pcm_t *pcmHandle = nullptr;
#endif

public:
    AudioEngine() {
        initAudio();
    }

    ~AudioEngine() {
        closeAudio();
    }

    void initAudio() {
#if defined(_WIN32)
        WAVEFORMATEX wfx = {WAVE_FORMAT_PCM, 1, SAMPLE_RATE, SAMPLE_RATE * 2, 2, 16, 0};
        waveOutOpen(&hWaveOut, WAVE_MAPPER, &wfx, 0, 0, CALLBACK_NULL);
#elif defined(__APPLE__)
        AudioStreamBasicDescription fmt = { (double)SAMPLE_RATE, kAudioFormatLinearPCM, kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked, 2, 1, 2, 1, 16, 0 };
        AudioQueueNewOutput(&fmt, nullptr, nullptr, nullptr, nullptr, 0, &queue);
#else
        snd_pcm_open(&pcmHandle, "default", SND_PCM_STREAM_PLAYBACK, 0);
        snd_pcm_set_params(pcmHandle, SND_PCM_FORMAT_S16_LE, SND_PCM_ACCESS_RW_INTERLEAVED, 1, SAMPLE_RATE, 1, 500000);
#endif
    }

    void closeAudio() {
#if defined(_WIN32)
        waveOutClose(hWaveOut);
#elif defined(__APPLE__)
        AudioQueueDispose(queue, true);
#else
        if (pcmHandle) snd_pcm_close(pcmHandle);
#endif
    }

    void playBuffer(const std::vector<short>& samples) {
#if defined(_WIN32)
        WAVEHDR header = { (LPSTR)samples.data(), (DWORD)(samples.size() * sizeof(short)), 0, 0, 0, 0, NULL, 0 };
        waveOutPrepareHeader(hWaveOut, &header, sizeof(WAVEHDR));
        waveOutWrite(hWaveOut, &header, sizeof(WAVEHDR));
        while (!(header.dwFlags & WHDR_DONE)) std::this_thread::sleep_for(std::chrono::milliseconds(1));
        waveOutUnprepareHeader(hWaveOut, &header, sizeof(WAVEHDR));
#elif defined(__APPLE__)
        AudioQueueBufferRef buffer;
        AudioQueueAllocateBuffer(queue, samples.size() * sizeof(short), &buffer);
        std::copy(samples.begin(), samples.end(), (short*)buffer->mAudioData);
        buffer->mAudioDataByteSize = samples.size() * sizeof(short);
        AudioQueueEnqueueBuffer(queue, buffer, 0, nullptr);
        AudioQueueStart(queue, nullptr);
        std::this_thread::sleep_for(std::chrono::milliseconds((int)(TICK_DURATION * 1000)));
        AudioQueueFreeBuffer(queue, buffer);
#else
        if (pcmHandle) {
            snd_pcm_writei(pcmHandle, samples.data(), samples.size());
        }
#endif
    }
};

// Visualizes grid to ANSI console with aging colors
void renderConsole(const CellularAutomaton& ca) {
    std::string buffer = "\033[H"; // Reset cursor home
    buffer += "╔" + std::string(GRID_WIDTH * 2, '═') + "╗\n";
    
    for (int r = 0; r < GRID_HEIGHT; ++r) {
        buffer += "║";
        for (int c = 0; c < GRID_WIDTH; ++c) {
            const auto& cell = ca.grid[r][c];
            if (cell.alive) {
                // Color transition based on cell age: Cyan -> Green -> Yellow -> Red
                if (cell.age == 1) buffer += "\033[36m██\033[0m";       // Cyan
                else if (cell.age < 5) buffer += "\033[32m██\033[0m";  // Green
                else if (cell.age < 12) buffer += "\033[33m██\033[0m"; // Yellow
                else buffer += "\033[31m██\033[0m";                    // Red
            } else {
                buffer += "  ";
            }
        }
        buffer += "║\n";
    }
    buffer += "╚" + std::string(GRID_WIDTH * 2, '═') + "╝\n";
    buffer += "Polyphonic Cellular Automaton - Generative Audio Engine\n";
    std::cout << buffer << std::flush;
}

int main() {
    CellularAutomaton ca;
    AudioEngine audio;

    std::cout << "\033[2J\033[?25l"; // Clear screen and hide cursor

    int bufferSize = static_cast<int>(SAMPLE_RATE * TICK_DURATION);
    std::vector<short> audioBuffer(bufferSize, 0);

    while (true) {
        renderConsole(ca);

        // Synthesize audio dynamically from current state
        std::fill(audioBuffer.begin(), audioBuffer.end(), 0);
        int activeVoiceCount = 0;

        for (int r = 0; r < GRID_HEIGHT; ++r) {
            for (int c = 0; c < GRID_WIDTH; ++c) {
                const auto& cell = ca.grid[r][c];
                if (!cell.alive) continue;

                activeVoiceCount++;

                // Topological & Age Pitch Mapping:
                // Column determines region in harmonic scale, age shifts octave, neighbors adjust timbre/index
                int neighbors = ca.countNeighbors(r, c);
                int baseIndex = (c * HARMONIC_SCALE.size()) / GRID_WIDTH;
                int pitchOffset = (cell.age % 4) * 2 + (neighbors % 3);
                int scaleIndex = std::clamp(baseIndex + pitchOffset, 0, (int)HARMONIC_SCALE.size() - 1);

                double freq = midiToFreq(HARMONIC_SCALE[scaleIndex]);
                
                // Add additive synthesis with envelope decay
                for (int t = 0; t < bufferSize; ++t) {
                    double time = static_cast<double>(t) / SAMPLE_RATE;
                    
                    // Simple ADSR-like decay envelope
                    double env = std::pow(1.0 - (static_cast<double>(t) / bufferSize), 1.5);
                    
                    // Sine + subtle triangle overtone based on age
                    double wave = std::sin(2.0 * M_PI * freq * time);
                    if (cell.age > 3) {
                        wave += 0.25 * std::sin(4.0 * M_PI * freq * time); // Add 2nd Harmonic
                    }

                    // Soft clipping and polyphonic gain normalization
                    double sample = wave * env * 2500.0;
                    audioBuffer[t] = std::clamp<int>(audioBuffer[t] + static_cast<int>(sample), -32000, 32000);
                }
            }
        }

        // Output audio frame synchronously with visual tick
        audio.playBuffer(audioBuffer);

        // Evolve system to next generation
        ca.step();
    }

    std::cout << "\033[?25h"; // Restore cursor
    return 0;
}