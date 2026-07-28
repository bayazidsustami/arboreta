// Generative Audio-Visual Synthesizer: CPU Thermal Fluid & Microtonal Ambient Soundscape
// Dependencies: SDL2 (compile with: g++ -O3 main.cpp -lSDL2 -lm)

#include <SDL2/SDL.h>
#include <cmath>
#include <fstream>
#include <iostream>
#include <vector>
#include <random>
#include <algorithm>

constexpr int WIDTH = 320;
constexpr int HEIGHT = 240;
constexpr int SCALE = 3;
constexpr int SAMPLE_RATE = 44100;
constexpr int NUM_VOICES = 5;

// Microtonal scale ratios (24-EDO / Just Intonation microtonal set)
const double MICRO_RATIOS[12] = {
    1.0, 1.0293, 1.0595, 1.0905, 1.1225, 1.1554,
    1.1892, 1.2241, 1.2599, 1.2968, 1.3348, 1.3747
};

struct AudioState {
    double phases[NUM_VOICES] = {0};
    double freqs[NUM_VOICES] = {110, 164.81, 220, 277.18, 329.63};
    double target_freqs[NUM_VOICES] = {110, 164.81, 220, 277.18, 329.63};
    double temp_celsius = 45.0;
};

// Helper to read CPU temperature (Linux thermal zone with dynamic simulation fallback)
float get_cpu_temperature() {
    std::ifstream temp_file("/sys/class/thermal/thermal_zone0/temp");
    if (temp_file.is_open()) {
        float raw_temp;
        if (temp_file >> raw_temp) {
            return raw_temp > 1000.0f ? raw_temp / 1000.0f : raw_temp;
        }
    }
    // Dynamic organic oscillator fallback if hardware thermal path is unavailable
    static float t = 0.0f;
    t += 0.02f;
    return 45.0f + 15.0f * std::sin(t) + 5.0f * std::cos(t * 2.3f);
}

// Audio Callback: Synthesizes continuous microtonal ambient drones based on CPU heat
void audio_callback(void* userdata, Uint8* stream, int len) {
    AudioState* state = static_cast<AudioState*>(userdata);
    int16_t* buffer = reinterpret_cast<int16_t*>(stream);
    int samples = len / sizeof(int16_t);

    for (int i = 0; i < samples; ++i) {
        double sample_val = 0.0;
        for (int v = 0; v < NUM_VOICES; ++v) {
            // Smooth microtonal pitch transitions
            state->freqs[v] += (state->target_freqs[v] - state->freqs[v]) * 0.0001;
            
            // Phase accumulation
            state->phases[v] += (2.0 * M_PI * state->freqs[v]) / SAMPLE_RATE;
            if (state->phases[v] > 2.0 * M_PI) state->phases[v] -= 2.0 * M_PI;

            // Soft FM synthesis with microtonal warmth
            double wave = std::sin(state->phases[v] + 0.35 * std::sin(state->phases[v] * 0.5));
            sample_val += wave * (0.15 / NUM_VOICES);
        }
        buffer[i] = static_cast<int16_t>(sample_val * 32767.0);
    }
}

// Map dynamic CPU temperature to microtonal frequencies
void update_synth_frequencies(AudioState& state, float temp) {
    state.temp_celsius = temp;
    double base_freq = 55.0 * std::pow(2.0, (temp - 30.0) / 20.0); // Thermal modulation of root pitch
    
    for (int v = 0; v < NUM_VOICES; ++v) {
        int micro_idx = static_cast<int>(temp * (v + 1)) % 12;
        double micro_multiplier = MICRO_RATIOS[micro_idx];
        state.target_freqs[v] = base_freq * (v + 1) * micro_multiplier * 0.5;
    }
}

// Spectral color mapping for fluid heat visualization
uint32_t heat_to_color(float heat) {
    heat = std::clamp(heat, 0.0f, 1.0f);
    uint8_t r = static_cast<uint8_t>(std::pow(heat, 0.7f) * 255);
    uint8_t g = static_cast<uint8_t>(std::sin(heat * M_PI) * 180);
    uint8_t b = static_cast<uint8_t>(std::cos(heat * M_PI * 0.5f) * 255 * (1.0f - heat));
    return (255 << 24) | (r << 16) | (g << 8) | b;
}

int main(int argc, char* argv[]) {
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) < 0) return 1;

    SDL_Window* window = SDL_CreateWindow("CPU Thermal Microtonal Fluid Synthesizer",
                                          SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                                          WIDTH * SCALE, HEIGHT * SCALE, SDL_WINDOW_SHOWN);
    SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    SDL_Texture* texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
                                              SDL_TEXTUREACCESS_STREAMING, WIDTH, HEIGHT);

    AudioState audio_state;
    SDL_AudioSpec wanted_spec{}, have_spec{};
    wanted_spec.freq = SAMPLE_RATE;
    wanted_spec.format = AUDIO_S16SYS;
    wanted_spec.channels = 1;
    wanted_spec.samples = 1024;
    wanted_spec.callback = audio_callback;
    wanted_spec.userdata = &audio_state;

    SDL_AudioDeviceID audio_dev = SDL_OpenAudioDevice(NULL, 0, &wanted_spec, &have_spec, 0);
    SDL_PauseAudioDevice(audio_dev, 0);

    std::vector<float> grid(WIDTH * HEIGHT, 0.0f);
    std::vector<float> next_grid(WIDTH * HEIGHT, 0.0f);
    std::vector<uint32_t> pixels(WIDTH * HEIGHT, 0);

    bool running = true;
    SDL_Event event;

    while (running) {
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) running = false;
        }

        float cpu_temp = get_cpu_temperature();
        update_synth_frequencies(audio_state, cpu_temp);

        // Inject thermal energy at dynamic hot spots mapped to temperature
        float normalized_temp = std::clamp((cpu_temp - 30.0f) / 50.0f, 0.1f, 1.0f);
        int cx = WIDTH / 2 + static_cast<int>(std::sin(SDL_GetTicks() * 0.002f) * 50);
        int cy = HEIGHT / 2 + static_cast<int>(std::cos(SDL_GetTicks() * 0.003f) * 40);
        
        if (cx >= 2 && cx < WIDTH - 2 && cy >= 2 && cy < HEIGHT - 2) {
            grid[cy * WIDTH + cx] = normalized_temp;
            grid[(cy + 1) * WIDTH + cx] = normalized_temp * 0.8f;
            grid[cy * WIDTH + cx + 1] = normalized_temp * 0.8f;
        }

        // 2D Thermal Fluid Diffusion & Decay Simulation
        for (int y = 1; y < HEIGHT - 1; ++y) {
            for (int x = 1; x < WIDTH - 1; ++x) {
                int idx = y * WIDTH + x;
                float avg = (grid[idx - 1] + grid[idx + 1] +
                             grid[idx - WIDTH] + grid[idx + WIDTH]) * 0.25f;
                // Decay rate scales dynamically with CPU thermal state
                next_grid[idx] = avg * (0.985f - (1.0f - normalized_temp) * 0.01f);
            }
        }
        grid = next_grid;

        // Render thermal fluid grid into pixel buffer
        for (int i = 0; i < WIDTH * HEIGHT; ++i) {
            pixels[i] = heat_to_color(grid[i]);
        }

        SDL_UpdateTexture(texture, NULL, pixels.data(), WIDTH * sizeof(uint32_t));
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, NULL, NULL);
        SDL_RenderPresent(renderer);

        SDL_Delay(16);
    }

    SDL_CloseAudioDevice(audio_dev);
    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}