#include <iostream>
#include <vector>
#include <complex>
#include <random>
#include <thread>
#include <chrono>
#include <atomic>
#include <mutex>
#include <condition_variable>
#include <sstream>
#include <iomanip>

// ---- Minimal external‑library stand‑ins -----------------------------------
// In a real project you would replace these with actual audio, FFT, MIDI
// and SVG libraries (e.g., RtAudio, FFTW, RtMidi, tinyxml2, etc.).
// --------------------------------------------------------------

using Sample = float;

// Fake audio capture: generates a sine wave whose frequency follows a
// slowly changing tempo value.
class AudioInput {
public:
    AudioInput() : phase(0.0), tempo(120.0) {}

    // Fill buffer with 'count' samples.
    void read(std::vector<Sample>& out, size_t count) {
        out.resize(count);
        double freq = tempoToFreq();
        for (size_t i = 0; i < count; ++i) {
            out[i] = static_cast<Sample>(std::sin(phase));
            phase += 2.0 * M_PI * freq / sampleRate;
            if (phase > 2.0 * M_PI) phase -= 2.0 * M_PI;
        }
        // Simulate tempo drift.
        tempo += ((rand() % 200) - 100) * 0.0001;
    }

    double getTempo() const { return tempo; }

private:
    double phase;
    double tempo;               // beats per minute
    static constexpr double sampleRate = 44100.0;

    double tempoToFreq() const {
        // Map tempo (BPM) to an audible frequency for demo purposes.
        return 0.5 + tempo / 240.0;
    }
};

// Very small FFT just to obtain a spectral centroid approximation.
double spectralCentroid(const std::vector<Sample>& samples) {
    size_t n = samples.size();
    if (n == 0) return 0.0;
    double sumMag = 0.0, sumFreq = 0.0;
    for (size_t k = 0; k < n; ++k) {
        double re = 0.0, im = 0.0;
        for (size_t n2 = 0; n2 < n; ++n2) {
            double angle = 2 * M_PI * k * n2 / n;
            re += samples[n2] * std::cos(angle);
            im -= samples[n2] * std::sin(angle);
        }
        double mag = std::sqrt(re * re + im * im);
        sumMag += mag;
        sumFreq += mag * k;
    }
    return sumMag ? (sumFreq / sumMag) * (44100.0 / n) : 0.0;
}

// Fake sentiment analysis: returns a value in [-1,1] that drifts slowly.
double lyricalSentiment() {
    static double s = 0.0;
    s += ((rand() % 200) - 100) * 0.0005;
    if (s > 1.0) s = 1.0;
    if (s < -1.0) s = -1.0;
    return s;
}

// Minimal MIDI output stub.
class MidiOut {
public:
    void sendNoteOn(int channel, int note, int velocity) {
        std::lock_guard<std::mutex> lk(mtx);
        std::cout << "[MIDI] Note On  ch:" << channel << " note:" << note << " vel:" << velocity << "\n";
    }
    void sendNoteOff(int channel, int note, int velocity) {
        std::lock_guard<std::mutex> lk(mtx);
        std::cout << "[MIDI] Note Off ch:" << channel << " note:" << note << " vel:" << velocity << "\n";
    }
private:
    std::mutex mtx;
};

// ---- Cellular Automaton ---------------------------------------------------
class Automaton {
public:
    Automaton(int w, int h) : width(w), height(h), cells(w * h, 0) {
        // Random seed.
        std::mt19937 rng{std::random_device{}()};
        std::uniform_int_distribution<int> dist(0, 1);
        for (auto& c : cells) c = dist(rng);
    }

    // Update using a rule table derived from music parameters.
    void step(const std::vector<int>& ruleTable) {
        std::vector<int> next(cells.size(), 0);
        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width; ++x) {
                int idx = y * width + x;
                int sum = neighborSum(x, y);
                next[idx] = ruleTable[sum];
            }
        }
        cells.swap(next);
    }

    const std::vector<int>& state() const { return cells; }

private:
    int width, height;
    std::vector<int> cells;

    // 8‑neighbour sum (including self for simplicity).
    int neighborSum(int x, int y) const {
        int sum = 0;
        for (int dy = -1; dy <= 1; ++dy) {
            for (int dx = -1; dx <= 1; ++dx) {
                int nx = (x + dx + width) % width;
                int ny = (y + dy + height) % height;
                sum += cells[ny * width + nx];
            }
        }
        return sum; // range [0,9]
    }
};

// ---- SVG renderer ---------------------------------------------------------
std::string renderSVG(const Automaton& autoRef, double hueShift) {
    const int cellSize = 10;
    const int w = 40, h = 30; // fixed geometry for demo
    std::ostringstream oss;
    oss << "<svg xmlns='http://www.w3.org/2000/svg' width='" << w*cellSize
        << "' height='" << h*cellSize << "' viewBox='0 0 " << w*cellSize << " " << h*cellSize << "'>\n";

    const auto& cells = autoRef.state();
    for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
            int val = cells[y * w + x];
            double hue = std::fmod( (val * 30.0 + hueShift), 360.0);
            oss << "<rect x='" << x*cellSize << "' y='" << y*cellSize
                << "' width='" << cellSize << "' height='" << cellSize
                << "' fill='hsl(" << hue << ",70%,50%)' />\n";
        }
    }
    oss << "</svg>\n";
    return oss.str();
}

// ---- Main loop ------------------------------------------------------------
int main() {
    const int width = 40, height = 30;
    Automaton automaton(width, height);
    AudioInput audio;
    MidiOut midi;

    std::atomic<bool> running{true};
    std::thread renderThread([&]{
        int frame = 0;
        while (running) {
            double hueShift = (frame * 2) % 360;
            std::string svg = renderSVG(automaton, hueShift);
            // For demo we just write to a file per frame.
            std::ofstream out("frame_" + std::to_string(frame) + ".svg");
            out << svg;
            ++frame;
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
        }
    });

    // Main audio‑driven loop.
    while (true) {
        std::vector<Sample> buffer;
        audio.read(buffer, 1024);
        double centroid = spectralCentroid(buffer);
        double tempo = audio.getTempo();
        double sentiment = lyricalSentiment();

        // Derive rule table (0‑9 neighbours) from audio parameters.
        std::vector<int> rule(10);
        for (int i = 0; i < 10; ++i) {
            // Example: mix centroid, tempo and sentiment into a deterministic rule.
            double mix = std::fmod(centroid * 0.1 + tempo * 0.01 + sentiment * 5.0 + i, 2.0);
            rule[i] = mix > 1.0 ? 1 : 0;
        }

        automaton.step(rule);

        // Encode rule transitions into MIDI notes.
        for (int i = 0; i < 10; ++i) {
            int note = 60 + i; // C4 .. D#4
            if (rule[i]) midi.sendNoteOn(0, note, 100);
            else        midi.sendNoteOff(0, note, 0);
        }

        // Simple exit condition for the demo.
        static int cycles = 0;
        if (++cycles > 500) break;

        std::this_thread::sleep_for(std::chrono::milliseconds(30));
    }

    running = false;
    renderThread.join();
    return 0;
}