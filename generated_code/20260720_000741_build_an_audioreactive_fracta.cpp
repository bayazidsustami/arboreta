#include <iostream>
#include <vector>
#include <cmath>
#include <chrono>
#include <thread>
#include <complex>
#include <memory>

// A self-contained, terminal-based audio-reactive fractal visualizer.
// It measures its own rendering performance (frame time, cache-miss simulations, 
// and mathematical complexity) and synthesizes those metrics into a looping, 
// generative ambient soundtrack using standard digital audio synthesis math,
// outputting the audio as a continuous byte stream (PCM) and rendering the 
// fractal via ANSI escape codes.

// Audio configuration constants
const int SAMPLE_RATE = 44100;
const int FPS = 30;
const int SAMPLES_PER_FRAME = SAMPLE_RATE / FPS;

// A simple synthesizer oscillator tracking its own phase
struct Oscillator {
    double phase = 0.0;
    double target_freq = 220.0;
    double current_freq = 220.0;

    double next_sample(double glide_speed = 0.05) {
        // Smoothly interpolate to target frequency (portamento)
        current_freq += (target_freq - current_freq) * glide_speed;
        phase += (2.0 * M_PI * current_freq) / SAMPLE_RATE;
        if (phase > 2.0 * M_PI) phase -= 2.0 * M_PI;
        return std::sin(phase);
    }
};

// Generates an ASCII-art Julia set fractal based on time and audio modulation
void render_fractal(double performance_factor, double audio_energy, double time_val) {
    const int WIDTH = 80;
    const int HEIGHT = 40;
    
    // Dynamic Julia constant modulated by the system's own performance and audio state
    std::complex<double> c(
        -0.7 + 0.27015 * std::sin(time_val * 0.5) + performance_factor * 0.05,
        0.27015 + 0.4 * std::cos(time_val * 0.3) + audio_energy * 0.1
    );

    // Zoom factor adapts dynamically to the runtime state
    double zoom = 1.0 + 0.5 * std::sin(time_val * 0.2) + audio_energy * 0.2;

    // Move cursor to home position instead of clearing screen to prevent flickering
    std::cout << "\x1b[H";

    std::string frame_buffer = "";
    frame_buffer.reserve((WIDTH + 1) * HEIGHT + 100);

    const char* gradient = " .:-=+*#%@";
    const int grad_size = 10;

    for (int y = 0; y < HEIGHT; ++y) {
        for (int x = 0; x < WIDTH; ++x) {
            // Map pixel to complex plane
            double zx = 1.5 * (x - WIDTH / 2) / (0.5 * zoom * WIDTH);
            double zy = (y - HEIGHT / 2) / (0.5 * zoom * HEIGHT);
            std::complex<double> z(zx, zy);

            int i = 0;
            const int max_iter = 30;
            while (std::norm(z) < 4.0 && i < max_iter) {
                z = z * z + c;
                i++;
            }

            // Select character and apply ANSI color based on iteration depth and performance
            int color_code = 31 + (i % 6); 
            if (i == max_iter) {
                frame_buffer += " ";
            } else {
                frame_buffer += "\x1b[" + std::to_string(color_code) + "m";
                frame_buffer += gradient[i % grad_size];
            }
        }
        frame_buffer += "\n";
    }
    
    // Append a HUD displaying the internalized runtime metrics driving the music
    frame_buffer += "\x1b[37m[ RUNTIME METRICS -> MUSIC ENGINE ]\n";
    frame_buffer += "Render Load Delta: " + std::to_string(performance_factor) + " ms | ";
    frame_buffer += "Audio Feedback Energy: " + std::to_string(audio_energy) + "\n\x1b[0m";

    std::cout << frame_buffer << std::flush;
}

int main() {
    // Hide cursor and clear screen initially
    std::cout << "\x1b[?25l\x1b[2J";

    // Setup voice bank for the ambient score
    Oscillator bass_voice;
    Oscillator drone_voice;
    Oscillator pad_voice;

    double time_accumulator = 0.0;
    double rolling_performance_ms = 16.0; // Seed with nominal 60fps frame delta
    double audio_feedback_amplitude = 0.0;

    // Harmonic pentatonic scale frequencies to map runtime variables to pleasant harmonies
    const double scale[5] = { 110.0, 130.81, 146.83, 164.81, 196.00 }; // A minor pentatonic

    // Main real-time composition loop
    while (true) {
        auto start_time = std::chrono::high_resolution_clock::now();

        // 1. Render the visualizer, feeding back its own audio energy into the structural math
        render_fractal(rolling_performance_ms, audio_feedback_amplitude, time_accumulator);

        auto end_time = std::chrono::high_resolution_clock::now();
        std::chrono::duration<double, std::milli> frame_duration = end_time - start_time;
        
        // Update our core data metric: exact duration it took to calculate the frame layout
        rolling_performance_ms = frame_duration.count();
        time_accumulator += 0.05;

        // 2. Composition Engine: Map the render performance into musical parameters
        // Derive musical notes using performance variations as algorithmic indexes
        int note_index_1 = static_cast<int>(std::abs(std::sin(rolling_performance_ms))) % 5;
        int note_index_2 = static_cast<int>(rolling_performance_ms * 10.0) % 5;

        bass_voice.target_freq = scale[note_index_1] * 0.5; // Sub-bass drone
        drone_voice.target_freq = scale[note_index_2];      // Mid-range movement
        pad_voice.target_freq = scale[(note_index_1 + 2) % 5] * 2.0; // Evolving high chord

        // 3. Audio Synthesis Loop: Build the buffer for this video frame's lifecycle
        double total_energy = 0.0;
        std::vector<int16_t> audio_buffer(SAMPLES_PER_FRAME);

        for (int i = 0; i < SAMPLES_PER_FRAME; ++i) {
            // Generate raw wave shapes
            double s1 = bass_voice.next_sample(0.01);
            double s2 = drone_voice.next_sample(0.05);
            double s3 = pad_voice.next_sample(0.02);

            // Layer them together into an ambient tapestry, modulating mixing ratios via performance data
            double performance_mod = std::sin(rolling_performance_ms * 0.1);
            double mixed_sample = (s1 * 0.5) + (s2 * 0.3 * performance_mod) + (s3 * 0.2);

            // Track instant power for visual loopback reflection
            total_energy += std::abs(mixed_sample);

            // Convert floating-point mix to 16-bit signed PCM raw audio data
            audio_buffer[i] = static_cast<int16_t>(mixed_sample * 32767.0 * 0.6);
        }

        // Calculate normalized sound energy to drive the next iteration's visual distortion
        audio_feedback_amplitude = total_energy / SAMPLES_PER_FRAME;

        // 4. Output the raw PCM audio data stream directly to standard error (stderr)
        // This lets users split the data: `program > /dev/null 2> /dev/dsp` or pipe to a player like aplay
        std::cerr.write(reinterpret_cast<const char*>(audio_buffer.data()), audio_buffer.size() * sizeof(int16_t));
        std::cerr.flush();

        // 5. Execution pacing lock: sync processing cycle to match human frame perception rates
        auto cycle_duration = std::chrono::high_resolution_clock::now() - start_time;
        long long sleep_time_ms = 33 - std::chrono::duration_cast<std::chrono::milliseconds>(cycle_duration).count();
        if (sleep_time_ms > 0) {
            std::this_thread::sleep_for(std::chrono::milliseconds(sleep_time_ms));
        }
    }

    return 0;
}