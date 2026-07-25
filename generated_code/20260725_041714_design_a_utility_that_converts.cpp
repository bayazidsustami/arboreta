#include <SFML/Audio.hpp>
#include <SFML/Graphics.hpp>
#include <vector>
#include <cmath>
#include <complex>
#include <algorithm>
#include <random>

// Constants
constexpr unsigned int WIDTH = 800;
constexpr unsigned int HEIGHT = 600;
constexpr unsigned int SAMPLE_RATE = 44100;
constexpr unsigned int FFT_SIZE = 1024;
constexpr float PI = 3.14159265358979323846f;

// Simplex/Perlin-like Noise Helper for Procedural Terrain
struct Gradient2D {
    float x, y;
};

class TerrainGenerator {
private:
    std::vector<int> p;
    std::vector<Gradient2D> grads;

public:
    TerrainGenerator() {
        p.resize(256);
        std::iota(p.begin(), p.end(), 0);
        std::default_random_engine rng(1337);
        std::shuffle(p.begin(), p.end(), rng);
        p.insert(p.end(), p.begin(), p.end());

        for (int i = 0; i < 8; ++i) {
            float angle = i * PI / 4.0f;
            grads.push_back({std::cos(angle), std::sin(angle)});
        }
    }

    float fade(float t) const {
        return t * t * t * (t * (t * 6.0f - 15.0f) + 10.0f);
    }

    float lerp(float a, float b, float t) const {
        return a + t * (b - a);
    }

    float grad(int hash, float x, float y) const {
        const auto& g = grads[hash % 8];
        return g.x * x + g.y * y;
    }

    float noise(float x, float y) const {
        int X = static_cast<int>(std::floor(x)) & 255;
        int Y = static_cast<int>(std::floor(y)) & 255;

        x -= std::floor(x);
        y -= std::floor(y);

        float u = fade(x);
        float v = fade(y);

        int A = p[X] + Y, B = p[X + 1] + Y;

        return lerp(
            lerp(grad(p[A], x, y), grad(p[B], x - 1, y), u),
            lerp(grad(p[A + 1], x, y - 1), grad(p[B + 1], x - 1, y - 1), u),
            v
        );
    }

    float octaveNoise(float x, float y, int octaves, float persistence) const {
        float total = 0.0f;
        float frequency = 1.0f;
        float amplitude = 1.0f;
        float maxValue = 0.0f;

        for (int i = 0; i < octaves; ++i) {
            total += noise(x * frequency, y * frequency) * amplitude;
            maxValue += amplitude;
            amplitude *= persistence;
            frequency *= 2.0f;
        }

        return (total / maxValue + 1.0f) / 2.0f; // Normalize to [0, 1]
    }
};

// FFT Implementation for Pitch and Frequency Analysis
void fft(std::vector<std::complex<float>>& x) {
    const size_t N = x.size();
    if (N <= 1) return;

    std::vector<std::complex<float>> even(N / 2), odd(N / 2);
    for (size_t i = 0; i < N / 2; ++i) {
        even[i] = x[i * 2];
        odd[i] = x[i * 2 + 1];
    }

    fft(even);
    fft(odd);

    for (size_t k = 0; k < N / 2; ++k) {
        std::complex<float> t = std::polar(1.0f, -2.0f * PI * k / N) * odd[k];
        x[k] = even[k] + t;
        x[k + N / 2] = even[k] - t;
    }
}

// Live Audio Recorder capturing Real-time Input
class AudioAnalyzer : public sf::SoundRecorder {
private:
    std::vector<int16_t> m_buffer;
    float m_dominantPitch = 0.0f;
    float m_energyRhythm = 0.0f;
    float m_prevEnergy = 0.0f;

protected:
    virtual bool onProcessSamples(const sf::Int16* samples, std::size_t sampleCount) override {
        if (sampleCount < FFT_SIZE) return true;

        // Perform FFT on the recent audio slice
        std::vector<std::complex<float>> complexSamples(FFT_SIZE);
        float currentEnergy = 0.0f;

        for (size_t i = 0; i < FFT_SIZE; ++i) {
            float sample = static_cast<float>(samples[i]) / 32768.0f;
            // Apply Hanning Window
            float window = 0.5f * (1.0f - std::cos(2.0f * PI * i / (FFT_SIZE - 1)));
            complexSamples[i] = sample * window;
            currentEnergy += sample * sample;
        }

        fft(complexSamples);

        // Find Dominant Pitch (Peak Frequency)
        float maxMag = 0.0f;
        size_t maxIndex = 0;
        for (size_t i = 1; i < FFT_SIZE / 2; ++i) {
            float mag = std::abs(complexSamples[i]);
            if (mag > maxMag) {
                maxMag = mag;
                maxIndex = i;
            }
        }

        m_dominantPitch = static_cast<float>(maxIndex) * SAMPLE_RATE / FFT_SIZE;
        
        // Rhythm Detection via Onset/Energy Derivative
        float energyDelta = std::max(0.0f, currentEnergy - m_prevEnergy);
        m_energyRhythm = m_energyRhythm * 0.85f + energyDelta * 0.15f;
        m_prevEnergy = currentEnergy;

        return true;
    }

public:
    float getPitch() const { return m_dominantPitch; }
    float getRhythmErosion() const { return m_energyRhythm; }
};

// Converts Elevation and Pitch to Swirling Color Palette
sf::Color getTopologicalColor(float elevation, float pitchFactor, float swirlTime) {
    // Dynamically shift color spectrum based on pitch frequency
    float hue = std::fmod(elevation * 3.0f + pitchFactor * 2.0f + swirlTime * 0.2f, 1.0f);
    float sat = 0.8f;
    float val = std::clamp(elevation * 1.2f, 0.2f, 1.0f);

    // Dynamic contour highlighting (contour lines)
    float contour = std::sin(elevation * 50.0f);
    if (std::abs(contour) > 0.92f) {
        val = 1.0f;
        sat = 0.2f;
    }

    // HSV to RGB Conversion
    float c = val * sat;
    float x = c * (1.0f - std::abs(std::fmod(hue * 6.0f, 2.0f) - 1.0f));
    float m = val - c;

    float r = 0, g = 0, b = 0;
    if (hue < 1.0f / 6.0f)      { r = c; g = x; b = 0; }
    else if (hue < 2.0f / 6.0f) { r = x; g = c; b = 0; }
    else if (hue < 3.0f / 6.0f) { r = 0; g = c; b = x; }
    else if (hue < 4.0f / 6.0f) { r = 0; g = x; b = c; }
    else if (hue < 5.0f / 6.0f) { r = x; g = 0; b = c; }
    else                        { r = c; g = 0; b = x; }

    return sf::Color(
        static_cast<sf::Uint8>((r + m) * 255),
        static_cast<sf::Uint8>((g + m) * 255),
        static_cast<sf::Uint8>((b + m) * 255)
    );
}

int main() {
    // Check audio capture availability
    if (!sf::SoundRecorder::isAvailable()) {
        return -1;
    }

    sf::RenderWindow window(sf::VideoMode(WIDTH, HEIGHT), "Audio-Driven Topological Erosion Visualizer");
    window.setFramerateLimit(60);

    AudioAnalyzer analyzer;
    analyzer.start(SAMPLE_RATE);

    TerrainGenerator terrain;

    sf::Texture renderTexture;
    renderTexture.create(WIDTH, HEIGHT);
    sf::Sprite renderSprite(renderTexture);
    std::vector<sf::Uint8> pixels(WIDTH * HEIGHT * 4);

    float erosionFactor = 0.0f;
    float swirlTime = 0.0f;

    sf::Clock clock;

    while (window.isOpen()) {
        sf::Event event;
        while (window.pollEvent(event)) {
            if (event.type == sf::Event::Closed) {
                window.close();
            }
        }

        float dt = clock.restart().asSeconds();
        swirlTime += dt;

        // Fetch live metrics
        float pitch = analyzer.getPitch(); // Pitch controls elevation contour scaling
        float rhythm = analyzer.getRhythmErosion(); // Rhythm drives procedural coastline erosion

        // Smooth pitch and rhythm response
        float targetPitchFactor = std::clamp(pitch / 2000.0f, 0.1f, 3.0f);
        erosionFactor += rhythm * dt * 5.0f; // Accumulate coastal erosion based on beat impact

        // Render Topological Landscape
        #pragma omp parallel for collapse(2)
        for (unsigned int y = 0; y < HEIGHT; ++y) {
            for (unsigned int x = 0; x < WIDTH; ++x) {
                float nx = (static_cast<float>(x) / WIDTH - 0.5f) * 3.0f;
                float ny = (static_cast<float>(y) / HEIGHT - 0.5f) * 3.0f;

                // Swirl distortion driven by audio pitch
                float dist = std::sqrt(nx * nx + ny * ny);
                float angle = std::atan2(ny, nx) + std::sin(dist * 2.0f - swirlTime) * targetPitchFactor;
                float sx = std::cos(angle) * dist;
                float sy = std::sin(angle) * dist;

                // Base elevation terrain
                float elevation = terrain.octaveNoise(sx + 10.0f, sy + 10.0f, 5, 0.5f);

                // Rhythm-driven Coastline Erosion Simulation
                // Creates procedural hydraulic/coastal carving effects based on beat intensity
                float erosionPattern = terrain.octaveNoise(sx * 4.0f + erosionFactor, sy * 4.0f, 3, 0.6f);
                if (elevation < 0.5f) { // Coastal sea level threshold
                    elevation -= erosionPattern * rhythm * 0.4f;
                } else {
                    elevation += erosionPattern * rhythm * 0.15f; // Mountain carving
                }

                elevation = std::clamp(elevation, 0.0f, 1.0f);

                // Topological Color Palette mapping
                sf::Color pixelColor = getTopologicalColor(elevation, targetPitchFactor, swirlTime);

                size_t index = (y * WIDTH + x) * 4;
                pixels[index]     = pixelColor.r;
                pixels[index + 1] = pixelColor.g;
                pixels[index + 2] = pixelColor.b;
                pixels[index + 3] = 255;
            }
        }

        renderTexture.update(pixels.data());

        window.clear();
        window.draw(renderSprite);
        window.display();
    }

    analyzer.stop();
    return 0;
}