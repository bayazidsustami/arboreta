#include <iostream>
#include <vector>
#include <string>
#include <map>
#include <cmath>
#include <fstream>
#include <cstdint>
#include <algorithm>
#include <numeric>
#include <random>

// WAV File Header structure for standard 16-bit PCM Audio
struct WAVHeader {
    char chunkID[4] = {'R', 'I', 'F', 'F'};
    uint32_t chunkSize;
    char format[4] = {'W', 'A', 'V', 'E'};
    char subchunk1ID[4] = {'f', 'm', 't', ' '};
    uint32_t subchunk1Size = 16;
    uint16_t audioFormat = 1; // PCM
    uint16_t numChannels = 1;  // Mono
    uint32_t sampleRate = 44100;
    uint32_t byteRate = 44100 * 2;
    uint16_t blockAlign = 2;
    uint16_t bitsPerSample = 16;
    char subchunk2ID[4] = {'d', 'a', 't', 'a'};
    uint32_t subchunk2Size;
};

// Represents a Git commit raw metric
struct Commit {
    std::string author;
    int additions;
    int deletions;
};

// Generates simulated git commit history data for demonstration
std::vector<Commit> generateMockCommitHistory() {
    return {
        {"Alice", 120, 10}, {"Bob", 15, 80}, {"Alice", 45, 5},
        {"Charlie", 300, 250}, {"Alice", 80, 20}, {"Bob", 5, 5},
        {"Diana", 50, 0}, {"Charlie", 12, 100}, {"Alice", 200, 150},
        {"Bob", 90, 40}, {"Diana", 110, 10}, {"Alice", 30, 2}
    };
}

// Pentagon/Harmonic minor musical scale frequencies (Hz)
const std::vector<double> SCALE = {220.0, 246.94, 261.63, 293.66, 329.63, 349.23, 392.00, 440.00};

int main() {
    const int SAMPLE_RATE = 44100;
    const double BEAT_DURATION = 0.25; // Seconds per commit event step
    const size_t SAMPLES_PER_BEAT = static_cast<size_t>(SAMPLE_RATE * BEAT_DURATION);

    std::vector<Commit> history = generateMockCommitHistory();

    // Map unique developers to specific synth voice parameters
    std::map<std::string, double> authorFrequencies;
    std::map<std::string, double> authorPhase;
    std::mt19937 rng(42);

    int scaleIdx = 0;
    for (const auto& commit : history) {
        if (authorFrequencies.find(commit.author) == authorFrequencies.end()) {
            authorFrequencies[commit.author] = SCALE[scaleIdx % SCALE.size()];
            authorPhase[commit.author] = 0.0;
            scaleIdx += 2; // Assign distinct musical intervals
        }
    }

    std::vector<int16_t> audioBuffer;

    // Synthesize audio track-by-track driven by commit history metrics
    for (const auto& commit : history) {
        double baseFreq = authorFrequencies[commit.author];
        int netDelta = commit.additions - commit.deletions;
        int totalChurn = commit.additions + commit.deletions;

        // Line deltas modulate note pitch dynamically
        double pitchMod = 1.0 + (netDelta / 500.0);
        double currentFreq = baseFreq * std::clamp(pitchMod, 0.5, 2.0);

        // High churn increases oscillator harmonic richness (FM modulation intensity)
        double modIndex = std::min(10.0, totalChurn / 20.0);

        // Render samples for the current beat
        for (size_t i = 0; i < SAMPLES_PER_BEAT; ++i) {
            double t = static_cast<double>(i) / SAMPLE_RATE;
            
            // Envelope (ADSR - fast attack, exponential decay for rhythmic feel)
            double envelope = std::exp(-5.0 * (t / BEAT_DURATION));

            // Frequency Modulation Synthesis
            double modulator = std::sin(2.0 * M_PI * (currentFreq * 0.5) * t) * modIndex;
            double carrier = std::sin(2.0 * M_PI * currentFreq * t + modulator);

            // Sub-bass rhythmic pulse driven by additions
            double kickPulse = (commit.additions > 100) ? std::sin(2.0 * M_PI * 55.0 * t) * std::exp(-15.0 * t) : 0.0;

            double sample = (carrier * envelope * 0.6) + (kickPulse * 0.4);

            // Soft clipping to keep audio output clean
            sample = std::tanh(sample);

            // Convert to 16-bit PCM integer
            int16_t pcmSample = static_cast<int16_t>(sample * 28000.0);
            audioBuffer.push_back(pcmSample);
        }
    }

    // Write WAV audio output file
    WAVHeader header;
    header.subchunk2Size = static_cast<uint32_t>(audioBuffer.size() * sizeof(int16_t));
    header.chunkSize = 36 + header.subchunk2Size;

    std::ofstream outFile("code_composition.wav", std::ios::binary);
    outFile.write(reinterpret_cast<const char*>(&header), sizeof(WAVHeader));
    outFile.write(reinterpret_cast<const char*>(audioBuffer.data()), audioBuffer.size() * sizeof(int16_t));
    outFile.close();

    std::cout << "Successfully rendered commit history into 'code_composition.wav'.\n";
    return 0;
}