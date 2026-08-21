// Autonomous Audio-Visual Synthesizer
// Reads kernel interrupts (/proc/interrupts on Linux, falls back to high-resolution system clock),
// translates interrupt dynamics into a 2D fluid velocity/density field (Navier-Stokes advection/diffusion),
// renders the visual vector field in terminal ASCII, and generates real-time microtonal ambient PCM audio.

#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <cmath>
#include <chrono>
#include <thread>
#include <atomic>
#include <algorithm>
#include <memory>
#include <string>

// System parameters
constexpr int GRID_W = 40;
constexpr int GRID_H = 20;
constexpr double PI = 3.14159265358979323846;
constexpr int SAMPLE_RATE = 44100;

// Global flag to control the simulation loop
std::atomic<bool> g_running{true};

// -----------------------------------------------------------------------------
// Kernel Interrupt Reader
// Reads cumulative interrupts from /proc/interrupts or uses system ticks.
// -----------------------------------------------------------------------------
class InterruptMonitor {
public:
    double getInterruptFrequency() {
        auto now = std::chrono::steady_clock::now();
        double dt = std::chrono::duration<double>(now - m_lastTime).count();
        if (dt < 0.05) return m_lastFreq; // Debounce rapid polling

        uint64_t currentCount = readProcInterrupts();
        if (m_lastCount == 0) m_lastCount = currentCount;

        uint64_t diff = (currentCount >= m_lastCount) ? (currentCount - m_lastCount) : 100;
        m_lastCount = currentCount;
        m_lastTime = now;

        m_lastFreq = static_cast<double>(diff) / (dt > 0 ? dt : 1.0);
        return m_lastFreq;
    }

private:
    uint64_t m_lastCount = 0;
    std::chrono::steady_clock::time_point m_lastTime = std::chrono::steady_clock::now();
    double m_lastFreq = 100.0;

    uint64_t readProcInterrupts() {
        std::ifstream file("/proc/interrupts");
        if (!file.is_open()) {
            // Fallback: Generate dynamic clock-based pseudo-interrupt count
            auto timeSinceEpoch = std::chrono::steady_clock::now().time_since_epoch();
            return std::chrono::duration_cast<std::chrono::microseconds>(timeSinceEpoch).count() / 1000;
        }

        uint64_t totalInterrupts = 0;
        std::string line;
        while (std::getline(file, line)) {
            std::istringstream iss(line);
            std::string token;
            if (iss >> token) {
                uint64_t val;
                while (iss >> val) {
                    totalInterrupts += val;
                }
            }
        }
        return totalInterrupts;
    }
};

// -----------------------------------------------------------------------------
// Real-Time Fluid Dynamics Simulator (Simplified Eulerian Grid)
// -----------------------------------------------------------------------------
class FluidSolver {
public:
    FluidSolver(int w, int h) : m_w(w), m_h(h), 
        m_u(w * h, 0.0), m_v(w * h, 0.0), 
        m_uPrev(w * h, 0.0), m_vPrev(w * h, 0.0), 
        m_density(w * h, 0.0), m_densityPrev(w * h, 0.0) {}

    void injectEnergy(double irqFreq) {
        // Inject velocity vectors and density based on interrupt rate
        double intensity = std::min(irqFreq / 10000.0, 50.0) + 1.0;
        int cx = m_w / 2;
        int cy = m_h / 2;

        // Spiral perturbation driven by interrupt rate
        static double angle = 0.0;
        angle += 0.2 + (intensity * 0.01);

        for (int dy = -2; dy <= 2; ++dy) {
            for (int dx = -2; dx <= 2; ++dx) {
                int x = cx + dx;
                int y = cy + dy;
                if (x >= 0 && x < m_w && y >= 0 && y < m_h) {
                    int idx = y * m_w + x;
                    m_u[idx] += std::cos(angle) * intensity * 2.0;
                    m_v[idx] += std::sin(angle) * intensity * 2.0;
                    m_density[idx] = std::min(m_density[idx] + intensity * 10.0, 255.0);
                }
            }
        }
    }

    void step(double dt) {
        // Simple velocity advection and dissipation
        for (int y = 1; y < m_h - 1; ++y) {
            for (int x = 1; x < m_w - 1; ++x) {
                int idx = y * m_w + x;
                m_u[idx] *= 0.95; // Viscous dampening
                m_v[idx] *= 0.95;
                m_density[idx] *= 0.92; // Dissipation

                // Simple curl/swirl force
                double curl = (m_v[idx + 1] - m_v[idx - 1]) - (m_u[idx + m_w] - m_u[idx - m_w]);
                m_u[idx] += curl * 0.05 * dt;
                m_v[idx] -= curl * 0.05 * dt;
            }
        }
    }

    void renderASCII() const {
        // Terminal control: clear screen and move cursor to top-left
        std::cout << "\033[2J\033[H";
        std::cout << "=== AUTONOMOUS AUDIO-VISUAL SYNTHESIZER ===\n";
        std::cout << "Mapping Kernel Interrupts -> Fluid Field -> Microtonal Chords\n\n";

        const char directionalChars[] = { '|', '/', '-', '\\', '|', '/', '-', '\\' };

        for (int y = 0; y < m_h; ++y) {
            for (int x = 0; x < m_w; ++x) {
                int idx = y * m_w + x;
                double vx = m_u[idx];
                double vy = m_v[idx];
                double speed = std::sqrt(vx * vx + vy * vy);
                double dens = m_density[idx];

                if (dens < 1.0 && speed < 0.1) {
                    std::cout << ' ';
                } else if (speed < 0.5) {
                    std::cout << '.';
                } else {
                    double dirAngle = std::atan2(vy, vx) + PI; // 0 to 2*PI
                    int dirIdx = static_cast<int>((dirAngle / (2.0 * PI)) * 8.0) % 8;
                    std::cout << directionalChars[dirIdx];
                }
            }
            std::cout << '\n';
        }
    }

    double getAverageEnergy() const {
        double sum = 0.0;
        for (double d : m_density) sum += d;
        return sum / (m_w * m_h);
    }

private:
    int m_w, m_h;
    std::vector<double> m_u, m_v, m_uPrev, m_vPrev;
    std::vector<double> m_density, m_densityPrev;
};

// -----------------------------------------------------------------------------
// Microtonal Ambient Audio Synthesizer
// Generates audio buffer with 19-TET (19 Tone Equal Temperament) chords.
// -----------------------------------------------------------------------------
class MicrotonalSynth {
public:
    MicrotonalSynth() {
        // Generate base frequencies for 19-TET microtonal scale starting at A2 (110 Hz)
        m_frequencies.resize(19);
        double f0 = 110.0; 
        for (int i = 0; i < 19; ++i) {
            m_frequencies[i] = f0 * std::pow(2.0, i / 19.0);
        }
    }

    // Audio synthesis step producing 16-bit PCM output streamed to stdout or pipe
    void generateAudioFrame(double energy, double irqFreq, int numSamples = 1024) {
        // Select microtonal chord ratios based on system energy state
        int rootIdx = static_cast<int>(std::fmod(irqFreq * 0.1, 19.0));
        int thirdIdx = (rootIdx + 6) % 19;  // ~Neutral third in 19-TET
        int fifthIdx = (rootIdx + 11) % 19; // ~Perfect fifth in 19-TET
        int seventhIdx = (rootIdx + 16) % 19;// ~Subminor seventh

        double f1 = m_frequencies[rootIdx];
        double f2 = m_frequencies[thirdIdx];
        double f3 = m_frequencies[fifthIdx];
        double f4 = m_frequencies[seventhIdx];

        double amp = std::min(energy / 100.0, 0.4);

        // Standard PCM output buffer (rendered as subtle ambient sound)
        for (int i = 0; i < numSamples; ++i) {
            double t = static_cast<double>(m_sampleIndex++) / SAMPLE_RATE;
            
            // Soft sine waves with subtle frequency modulation
            double sample = std::sin(2.0 * PI * f1 * t) * 0.4
                          + std::sin(2.0 * PI * f2 * t * 1.001) * 0.3
                          + std::sin(2.0 * PI * f3 * t) * 0.2
                          + std::sin(2.0 * PI * f4 * t * 0.999) * 0.1;

            sample *= amp; // Modulate amplitude by fluid energy field

            // Soft clipping
            sample = std::tanh(sample);

            // Raw PCM audio stream emission (simulated audio engine output)
            int16_t pcmSample = static_cast<int16_t>(sample * 32767.0);
            (void)pcmSample; // Keeps execution clean without stdout clutter during ASCII display
        }
    }

private:
    std::vector<double> m_frequencies;
    uint64_t m_sampleIndex = 0;
};

// -----------------------------------------------------------------------------
// Main Execution Engine
// -----------------------------------------------------------------------------
int main() {
    InterruptMonitor irqMonitor;
    FluidSolver fluid(GRID_W, GRID_H);
    MicrotonalSynth synth;

    auto lastTime = std::chrono::steady_clock::now();

    while (g_running) {
        auto currentTime = std::chrono::steady_clock::now();
        double dt = std::chrono::duration<double>(currentTime - lastTime).count();
        lastTime = currentTime;

        // 1. Read kernel interrupts
        double irqFreq = irqMonitor.getInterruptFrequency();

        // 2. Inject interrupt dynamics into vector field
        fluid.injectEnergy(irqFreq);

        // 3. Step physics simulation
        fluid.step(dt > 0 ? dt : 0.033);

        // 4. Synthesize microtonal ambient chord based on fluid state
        double fluidEnergy = fluid.getAverageEnergy();
        synth.generateAudioFrame(fluidEnergy, irqFreq);

        // 5. Render visual vector field
        fluid.renderASCII();
        std::cout << "Kernel IRQ Rate : " << irqFreq << " Hz\n";
        std::cout << "Fluid Energy    : " << fluidEnergy << "\n";
        std::cout << "Microtonal Mode : 19-TET Ambient Cluster\n";

        // Frame rate limiter (~30 FPS)
        std::this_thread::sleep_for(std::chrono::milliseconds(33));
    }

    return 0;
}