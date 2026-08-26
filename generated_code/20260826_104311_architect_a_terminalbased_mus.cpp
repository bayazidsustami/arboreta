#include <iostream>
#include <vector>
#include <cmath>
#include <thread>
#include <chrono>
#include <atomic>
#include <random>
#include <string>
#include <sstream>
#include <memory>
#include <algorithm>

#if defined(_WIN32)
#include <windows.h>
#include <mmeapi.h>
#pragma comment(lib, "winmm.lib")
#else
#include <fcntl.h>
#include <unistd.h>
#endif

// Terminal Dimensions
constexpr int WIDTH = 80;
constexpr int HEIGHT = 24;
constexpr double PI = 3.14159265358979323846;
constexpr int SAMPLE_RATE = 44100;

// Global Atomic State for Network Traffic Simulation and Audio Data
std::atomic<double> g_networkActivity{0.0}; // Simulated incoming packet density
std::atomic<double> g_freqBase{220.0};       // Base pitch tuned by traffic patterns
std::atomic<double> g_harmonics{1.0};        // Timbre modulated by traffic burstiness

// Cross-Platform Simple PCM Audio Synthesizer Output Buffer
class AudioEngine {
public:
    AudioEngine() : running(false) {}
    ~AudioEngine() { stop(); }

    void start() {
        running = true;
        audioThread = std::thread(&AudioEngine::audioLoop, this);
    }

    void stop() {
        running = false;
        if (audioThread.joinable()) audioThread.join();
    }

private:
    std::thread audioThread;
    std::atomic<bool> running;

    void audioLoop() {
#if defined(_WIN32)
        HWAVEOUT hWaveOut;
        WAVEFORMATEX wfx = { WAVE_FORMAT_PCM, 1, SAMPLE_RATE, SAMPLE_RATE * 2, 2, 16, 0 };
        waveOutOpen(&hWaveOut, WAVE_MAPPER, &wfx, 0, 0, CALLBACK_NULL);

        const int bufferSize = 2048;
        short buffer[2][bufferSize];
        WAVEHDR header[2] = {};

        for (int i = 0; i < 2; ++i) {
            header[i].lpData = (LPSTR)buffer[i];
            header[i].dwBufferLength = bufferSize * sizeof(short);
            waveOutPrepareHeader(hWaveOut, &header[i], sizeof(WAVEHDR));
        }

        double phase1 = 0.0, phase2 = 0.0, phase3 = 0.0;
        int currentBuffer = 0;

        while (running) {
            if (header[currentBuffer].dwFlags & WHDR_DONE || !(header[currentBuffer].dwFlags & WHDR_PREPARED)) {
                double baseFreq = g_freqBase.load();
                double harm = g_harmonics.load();

                // Generate microtonal ambient frequency cluster
                double f1 = baseFreq; // Root microtonal pitch
                double f2 = baseFreq * std::pow(2.0, (3.5 + harm) / 12.0); // Microtonal third interval
                double f3 = baseFreq * std::pow(2.0, (7.1 - harm) / 12.0); // Just-tuned fifth drift

                for (int i = 0; i < bufferSize; ++i) {
                    phase1 += f1 / SAMPLE_RATE;
                    phase2 += f2 / SAMPLE_RATE;
                    phase3 += f3 / SAMPLE_RATE;

                    if (phase1 >= 1.0) phase1 -= 1.0;
                    if (phase2 >= 1.0) phase2 -= 1.0;
                    if (phase3 >= 1.0) phase3 -= 1.0;

                    // Additive synthesis with smooth sine waves
                    double sample = 0.4 * std::sin(2.0 * PI * phase1) +
                                    0.3 * std::sin(2.0 * PI * phase2) +
                                    0.2 * std::sin(2.0 * PI * phase3);

                    buffer[currentBuffer][i] = static_cast<short>(sample * 16384.0);
                }

                waveOutWrite(hWaveOut, &header[currentBuffer], sizeof(WAVEHDR));
                currentBuffer = 1 - currentBuffer;
            }

            std::this_thread::sleep_for(std::chrono::milliseconds(5));
        }

        waveOutReset(hWaveOut);
        for (int i = 0; i < 2; ++i) waveOutUnprepareHeader(hWaveOut, &header[i], sizeof(WAVEHDR));
        waveOutClose(hWaveOut);
#else
        // Fallback for non-Windows (Linux/macOS raw audio stream pipe simulation via stdout / dsp device)
        int audioFd = open("/dev/dsp", O_WRONLY);
        double phase = 0.0;
        while (running) {
            double freq = g_freqBase.load();
            phase += freq / SAMPLE_RATE;
            if (phase >= 1.0) phase -= 1.0;
            short val = static_cast<short>(std::sin(2.0 * PI * phase) * 8000.0);
            if (audioFd >= 0) {
                write(audioFd, &val, sizeof(short));
            } else {
                std::this_thread::sleep_for(std::chrono::microseconds(1000000 / SAMPLE_RATE));
            }
        }
        if (audioFd >= 0) close(audioFd);
#endif
    }
};

// Simulated Network Monitor mutating internal entropy according to network throughput bursts
void networkPacketSniffer() {
    std::mt19937 gen(1337);
    std::exponential_distribution<double> burstDist(0.15);
    std::uniform_real_distribution<double> pitchDist(110.0, 440.0);

    while (true) {
        // Simulate network traffic volume fluctuations (packet count and jitter)
        double activity = std::clamp(burstDist(gen), 0.05, 5.0);
        g_networkActivity.store(activity);

        // Map traffic bursts directly to continuous microtonal pitch variations (cents deviation)
        double microtonalPitch = 130.81 * std::pow(2.0, (activity * 1.5 + pitchDist(gen) * 0.01) / 12.0);
        g_freqBase.store(microtonalPitch);

        // Map jitter/packet variance to harmonic density
        g_harmonics.store(activity * 0.75);

        std::this_thread::sleep_for(std::chrono::milliseconds(150 + static_cast<int>(100 / activity)));
    }
}

// Visualizer: 2D Continuous-State Cellular Automata driven by network state
class CellularAutomataVisualizer {
private:
    std::vector<std::vector<double>> grid;
    std::vector<std::vector<double>> nextGrid;

public:
    CellularAutomataVisualizer() : grid(HEIGHT, std::vector<double>(WIDTH, 0.0)),
                                   nextGrid(HEIGHT, std::vector<double>(WIDTH, 0.0)) {
        // Seed initial central excitation
        grid[HEIGHT / 2][WIDTH / 2] = 1.0;
    }

    void update(double activity) {
        // Continuous reaction-diffusion cellular automaton rules
        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                double neighborSum = 0.0;
                int count = 0;

                for (int dy = -1; dy <= 1; ++dy) {
                    for (int dx = -1; dx <= 1; ++dx) {
                        if (dx == 0 && dy == 0) continue;
                        int ny = (y + dy + HEIGHT) % HEIGHT;
                        int nx = (x + dx + WIDTH) % WIDTH;
                        neighborSum += grid[ny][nx];
                        count++;
                    }
                }

                double avg = neighborSum / count;
                // Transition function modulated by network traffic inputs
                double state = grid[y][x];
                if (avg > 0.1 && avg < 0.6) {
                    nextGrid[y][x] = std::min(1.0, state + 0.2 * activity);
                } else if (avg >= 0.6) {
                    nextGrid[y][x] = std::max(0.0, state - 0.15 / activity);
                } else {
                    nextGrid[y][x] = state * 0.92; // Natural decay
                }
            }
        }

        // Network "packet drop/hit" injector: inject random pulses based on activity
        if ((rand() % 100) < static_cast<int>(activity * 30)) {
            int rx = rand() % WIDTH;
            int ry = rand() % HEIGHT;
            nextGrid[ry][rx] = 1.0;
        }

        grid = nextGrid;
    }

    void drawTerminal() {
        std::ostringstream ss;
        // Move cursor home (ANSI escape)
        ss << "\033[H";

        const std::string shades = " .:-=+*#%@";
        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                double val = std::clamp(grid[y][x], 0.0, 1.0);
                int charIdx = static_cast<int>(val * (shades.size() - 1));

                // Colorize based on cellular energy level (ANSI 256 Color scale)
                int colorCode = 16 + static_cast<int>(val * 5.0) * 36 + static_cast<int>(val * 5.0);
                ss << "\033[38;5;" << colorCode << "m" << shades[charIdx];
            }
            ss << "\n";
        }
        
        // Print real-time dashboard footer
        ss << "\033[37m[ NETWORK TRAFFIC DENSITY: " << g_networkActivity.load() 
           << " pkts/ms ] | [ BASE FREQ: " << g_freqBase.load() << " Hz ]\033[0m";

        std::cout << ss.str() << std::flush;
    }
};

int main() {
    // Hide terminal cursor and clear screen
    std::cout << "\033[?25l\033[2J";

    AudioEngine synth;
    synth.start();

    // Spawn background thread monitoring real-time network traffic patterns
    std::thread netThread(networkPacketSniffer);
    netThread.detach();

    CellularAutomataVisualizer visualizer;

    // Main animation & sound generation loop
    while (true) {
        double currentActivity = g_networkActivity.load();
        visualizer.update(currentActivity);
        visualizer.drawTerminal();

        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }

    // Restore terminal cursor (Unreachable loop exit fallback)
    std::cout << "\033[?25h";
    return 0;
}