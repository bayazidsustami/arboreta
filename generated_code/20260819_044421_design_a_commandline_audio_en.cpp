#include <iostream>
#include <vector>
#include <cmath>
#include <random>
#include <string>
#include <sstream>
#include <memory>
#include <chrono>
#include <thread>
#include <cstdlib>
#include <cstdio>
#include <array>

// Portable raw audio stream output (PCM 16-bit Mono, 44.1kHz)
constexpr int SAMPLE_RATE = 44100;
constexpr double PI = 3.14159265358979323846;

// Represents a sound generator triggered by commit churn
struct Voice {
    double frequency = 440.0;
    double phase = 0.0;
    double amplitude = 0.0;
    double decay = 0.99992; // Envelope decay rate
    
    int render() {
        if (amplitude < 0.0001) return 0;
        
        // Microtonal sine wave generation with simple decay envelope
        double sample = std::sin(phase) * amplitude;
        phase += 2.0 * PI * frequency / SAMPLE_RATE;
        if (phase >= 2.0 * PI) phase -= 2.0 * PI;
        
        amplitude *= decay; // Smooth exponential decay
        return static_cast<int>(sample * 8000.0);
    }
};

// Represents parsed data from a Git commit log entry
struct CommitData {
    int linesAdded = 0;
    int linesDeleted = 0;
    bool isMerge = false;
};

// Execute git command and read raw stream
std::vector<CommitData> fetchGitHistory(int limit = 30) {
    std::vector<CommitData> history;
    std::string command = "git log --shortstat --parents -n " + std::to_string(limit) + " 2>/dev/null";
    
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(command.c_str(), "r"), pclose);
    if (!pipe) return history;

    char buffer[128];
    CommitData currentCommit;
    bool inCommit = false;

    while (fgets(buffer, sizeof(buffer), pipe.get()) != nullptr) {
        std::string line(buffer);
        if (line.rfind("commit ", 0) == 0) {
            if (inCommit) history.push_back(currentCommit);
            currentCommit = CommitData();
            inCommit = true;
            
            // Count space-separated tokens in "commit <hash> <parent1> <parent2>..."
            std::stringstream ss(line);
            std::string token;
            int tokens = 0;
            while (ss >> token) tokens++;
            if (tokens > 2) currentCommit.isMerge = true; // More than 1 parent = Merge
        } else if (line.find("changed") != std::string::npos) {
            std::stringstream ss(line);
            std::string item;
            while (ss >> item) {
                if (item.find("insertion") != std::string::npos) {
                    // Extract previous number
                }
            }
            // Parse additions/deletions from stat line
            size_t posAdd = line.find("insertion");
            if (posAdd != std::string::npos) {
                size_t start = line.rfind(',', posAdd);
                if (start == std::string::npos) start = 0;
                currentCommit.linesAdded = std::atoi(line.substr(start, posAdd - start).c_str());
            }
            size_t posDel = line.find("deletion");
            if (posDel != std::string::npos) {
                size_t start = line.rfind(',', posDel);
                currentCommit.linesDeleted = std::atoi(line.substr(start, posDel - start).c_str());
            }
        }
    }
    if (inCommit) history.push_back(currentCommit);
    return history;
}

int main() {
    // Attempt to pull git history from local repo; fallback to procedural generation if not a git repo
    auto commits = fetchGitHistory(50);
    if (commits.empty()) {
        std::clog << "[Warning] Not a git repository or no commit history found. Generating synthetic commit landscape...\n";
        std::mt19937 rng(42);
        std::uniform_int_distribution<int> churnDist(1, 200);
        std::bernoulli_distribution mergeDist(0.2);
        
        for (int i = 0; i < 40; ++i) {
            commits.push_back({churnDist(rng), churnDist(rng), mergeDist(rng)});
        }
    }

    constexpr int NUM_VOICES = 8;
    std::array<Voice, NUM_VOICES> synthPool;
    
    // Base frequency for microtonal scale tuning (24-TET / Quarter-tone scale)
    constexpr double BASE_FREQ = 110.0; // A2
    
    std::clog << "[Audio Engine Running] Streaming 16-bit PCM Audio to stdout. Pipe output to speaker tools (e.g. `aplay -f S16_LE -c 1 -r 44100`)...\n";

    size_t commitIdx = 0;
    int sampleCounter = 0;
    constexpr int SAMPLES_PER_COMMIT = SAMPLE_RATE / 4; // Play a new commit event every ~250ms

    while (true) {
        // Trigger soundscapes periodically from commit churn events
        if (sampleCounter % SAMPLES_PER_COMMIT == 0) {
            const auto& commit = commits[commitIdx];
            int totalChurn = commit.linesAdded + commit.linesDeleted;

            // Map churn magnitude to microtonal pitch multiplier (24-Tone Equal Temperament)
            int microStep = totalChurn % 48; // 48 quarter-tones spanning 2 octaves
            double frequency = BASE_FREQ * std::pow(2.0, microStep / 24.0);

            // Activate voice in the synthesizer pool
            int voiceSlot = commitIdx % NUM_VOICES;
            synthPool[voiceSlot].frequency = frequency;
            synthPool[voiceSlot].amplitude = std::min(1.0, 0.2 + (totalChurn / 500.0));

            // Merge conflicts / merge commits inject intentional harmonic dissonance
            if (commit.isMerge) {
                int dissonanceSlot = (voiceSlot + 1) % NUM_VOICES;
                // Add a microtonal tritone shift (12 quarter-tones = 6 semitones / 600 cents)
                synthPool[dissonanceSlot].frequency = frequency * std::pow(2.0, 11.5 / 24.0); 
                synthPool[dissonanceSlot].amplitude = 0.8; 
            }

            commitIdx = (commitIdx + 1) % commits.size();
        }

        // Mix polyphonic active voice instances
        int mixedSample = 0;
        for (auto& voice : synthPool) {
            mixedSample += voice.render();
        }

        // Soft-clipping limiter to prevent digital distortion
        if (mixedSample > 32767) mixedSample = 32767;
        if (mixedSample < -32768) mixedSample = -32768;

        // Output raw 16-bit Little-Endian PCM audio byte data to stdout
        int16_t pcmOut = static_cast<int16_t>(mixedSample);
        std::cout.write(reinterpret_cast<const char*>(&pcmOut), sizeof(pcmOut));

        sampleCounter++;
    }

    return 0;
}