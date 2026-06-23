#include <iostream>
#include <vector>
#include <complex>
#include <cmath>
#include <thread>
#include <atomic>
#include <mutex>
#include <condition_variable>

// ----- External libraries (must be linked) -----
// PortAudio for audio capture
#include <portaudio.h>
// FFTW for fast Fourier transform
#include <fftw3.h>
// SDL2 for graphics
#include <SDL2/SDL.h>

// ----- Configuration constants -----
const double SAMPLE_RATE = 48000.0;
const int FRAMES_PER_BUFFER = 1024;          // audio block size
const int FFT_SIZE = 1024;                   // must be power of two
const int NUM_BINS = FFT_SIZE / 2;           // positive frequency bins
const int WINDOW_W = 800;
const int WINDOW_H = 600;
const int GUTTER = 2;                        // vertical spacing between glyph rows
const int MAX_GLYPH_AGE = 120;               // frames before a glyph disappears

// ----- Simple alphabet (Unicode glyphs) -----
const std::vector<std::u32string> ALPHABET = {
    U"\u2600", U"\u2601", U"\u2602", U"\u2603", U"\u2604",
    U"\u2605", U"\u2606", U"\u2607", U"\u2608", U"\u2609",
    U"\u2610", U"\u2611", U"\u2612", U"\u2613", U"\u2614",
    U"\u2615", U"\u2616", U"\u2617", U"\u2618", U"\u2619"
};

// ----- Glyph structure -----
struct Glyph {
    int x;                  // column
    int y;                  // row (age)
    uint32_t codepoint;     // Unicode value
    double size;            // pixel height
    SDL_Color hue;          // color (RGB)
    double curvature;       // used to skew rendering (placeholder)
};

// ----- Thread‑safe circular audio buffer -----
class AudioRing {
public:
    AudioRing() : writePos(0), readPos(0) {
        data.resize(FFT_SIZE);
    }
    void push(const float *src, int cnt) {
        std::lock_guard<std::mutex> lock(mtx);
        for (int i = 0; i < cnt; ++i) {
            data[writePos] = src[i];
            writePos = (writePos + 1) % FFT_SIZE;
            if (writePos == readPos) readPos = (readPos + 1) % FFT_SIZE; // overwrite oldest
        }
        cv.notify_one();
    }
    // Wait until enough samples are available, then copy them
    void fetch(std::vector<float>& out) {
        std::unique_lock<std::mutex> lock(mtx);
        cv.wait(lock, [&]{ return available() >= FFT_SIZE; });
        out.resize(FFT_SIZE);
        for (int i = 0; i < FFT_SIZE; ++i) {
            out[i] = data[readPos];
            readPos = (readPos + 1) % FFT_SIZE;
        }
    }
private:
    std::vector<float> data;
    int writePos, readPos;
    std::mutex mtx;
    std::condition_variable cv;
    int available() const {
        if (writePos >= readPos) return writePos - readPos;
        return FFT_SIZE - (readPos - writePos);
    }
};

// ----- PortAudio callback -----
static int paCallback(const void *inputBuffer, void *, unsigned long framesPerBuffer,
                      const PaStreamCallbackTimeInfo*, PaStreamCallbackFlags, void *userData) {
    AudioRing *ring = static_cast<AudioRing*>(userData);
    const float *in = static_cast<const float*>(inputBuffer);
    ring->push(in, framesPerBuffer);
    return paContinue;
}

// ----- Helper: map frequency bin to glyph index -----
int binToGlyph(int bin) {
    // Simple linear mapping across the alphabet
    return (bin * static_cast<int>(ALPHABET.size())) / NUM_BINS;
}

// ----- Helper: convert Unicode codepoint to SDL texture (using SDL_ttf) -----
SDL_Texture* renderGlyph(SDL_Renderer* ren, uint32_t cp, double size, SDL_Color col) {
    // To keep dependencies minimal we draw a filled rect shaped like the glyph.
    // In a full implementation you would use SDL_ttf with a custom font.
    int px = static_cast<int>(size);
    SDL_Texture* tex = SDL_CreateTexture(ren, SDL_PIXELFORMAT_RGBA8888,
                                         SDL_TEXTUREACCESS_TARGET, px, px);
    SDL_SetTextureBlendMode(tex, SDL_BLENDMODE_BLEND);
    SDL_SetRenderTarget(ren, tex);
    SDL_SetRenderDrawColor(ren, col.r, col.g, col.b, 255);
    SDL_Rect r{0,0,px,px};
    SDL_RenderFillRect(ren, &r);
    SDL_SetRenderTarget(ren, nullptr);
    return tex;
}

// ----- Main -----
int main(int argc, char* argv[]) {
    // ----- Init PortAudio -----
    PaError err = Pa_Initialize();
    if (err != paNoError) { std::cerr << "PortAudio init error\n"; return 1; }

    AudioRing audioRing;
    PaStream *stream;
    PaStreamParameters inParam{};
    inParam.device = Pa_GetDefaultInputDevice();
    if (inParam.device == paNoDevice) { std::cerr << "No input device\n"; return 1; }
    const PaDeviceInfo *devInfo = Pa_GetDeviceInfo(inParam.device);
    inParam.channelCount = 1;
    inParam.sampleFormat = paFloat32;
    inParam.suggestedLatency = devInfo->defaultLowInputLatency;
    inParam.hostApiSpecificStreamInfo = nullptr;

    err = Pa_OpenStream(&stream, &inParam, nullptr, SAMPLE_RATE,
                        FRAMES_PER_BUFFER, paClipOff, paCallback, &audioRing);
    if (err != paNoError) { std::cerr << "Failed to open stream\n"; return 1; }
    Pa_StartStream(stream);

    // ----- Init SDL -----
    if (SDL_Init(SDL_INIT_VIDEO) != 0) { std::cerr << "SDL init error\n"; return 1; }
    SDL_Window *win = SDL_CreateWindow("Audio Glyph Waterfall",
                    SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                    WINDOW_W, WINDOW_H, SDL_WINDOW_SHOWN);
    SDL_Renderer *ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
    SDL_SetRenderDrawBlendMode(ren, SDL_BLENDMODE_BLEND);

    // ----- FFTW plans -----
    std::vector<double> inBuf(FFT_SIZE);
    std::vector<std::complex<double>> outBuf(FFT_SIZE);
    fftw_plan fftPlan = fftw_plan_dft_r2c_1d(FFT_SIZE, inBuf.data(),
                                            reinterpret_cast<fftw_complex*>(outBuf.data()),
                                            FFTW_MEASURE);

    // ----- Glyph storage -----
    std::vector<Glyph> activeGlyphs;
    std::vector<SDL_Texture*> glyphTextures;

    bool quit = false;
    SDL_Event ev;
    while (!quit) {
        while (SDL_PollEvent(&ev)) {
            if (ev.type == SDL_QUIT) quit = true;
        }

        // ----- Acquire audio block and compute FFT -----
        std::vector<float> audioBlock;
        audioRing.fetch(audioBlock);
        for (int i = 0; i < FFT_SIZE; ++i) inBuf[i] = (i < audioBlock.size()) ? audioBlock[i] : 0.0;

        fftw_execute(fftPlan);

        // ----- Analyze magnitude, rhythm, tension -----
        std::vector<double> mags(NUM_BINS);
        double maxMag = 0.0;
        for (int i = 0; i < NUM_BINS; ++i) {
            mags[i] = std::abs(outBuf[i]);
            if (mags[i] > maxMag) maxMag = mags[i];
        }
        // Simple rhythm density: count bins above a threshold
        double threshold = maxMag * 0.3;
        int activeBins = 0;
        for (double m : mags) if (m > threshold) ++activeBins;
        double rhythmFactor = static_cast<double>(activeBins) / NUM_BINS; // 0..1

        // ----- Create new glyphs for this frame -----
        for (int bin = 0; bin < NUM_BINS; ++bin) {
            double mag = mags[bin];
            if (mag < threshold) continue; // ignore quiet bins
            Glyph g{};
            g.x = (bin * WINDOW_W) / NUM_BINS;
            g.y = 0; // will be rendered at the top
            g.codepoint = static_cast<uint32_t>(ALPHABET[binToGlyph(bin)][0]); // only first codepoint
            // Size encodes magnitude (logarithmic)
            g.size = 8.0 + 24.0 * std::log10(1 + mag);
            // Hue encodes pitch (higher bins -> warmer colors)
            Uint8 hue = static_cast<Uint8>(255.0 * bin / NUM_BINS);
            g.hue = { hue, Uint8(255 - hue), Uint8((hue + 128) % 256), 255 };
            // Curvature encodes rhythm density (placeholder)
            g.curvature = rhythmFactor * 1.0;
            activeGlyphs.push_back(g);
        }

        // ----- Age and prune glyphs -----
        for (auto &g : activeGlyphs) ++g.y;
        activeGlyphs.erase(
            std::remove_if(activeGlyphs.begin(), activeGlyphs.end(),
                [](const Glyph& g){ return g.y > MAX_GLYPH_AGE; }),
            activeGlyphs.end());

        // ----- Render -----
        SDL_SetRenderDrawColor(ren, 0, 0, 0, 255);
        SDL_RenderClear(ren);

        // Clean old textures
        for (SDL_Texture* tex : glyphTextures) SDL_DestroyTexture(tex);
        glyphTextures.clear();

        // Draw each glyph as a colored square (placeholder for real typographic shape)
        for (const Glyph& g : activeGlyphs) {
            SDL_Texture* tex = renderGlyph(ren, g.codepoint, g.size, g.hue);
            glyphTextures.push_back(tex);
            int px = static_cast<int>(g.size);
            SDL_Rect dst{ g.x, g.y * (px + GUTTER), px, px };
            SDL_RenderCopy(ren, tex, nullptr, &dst);
        }

        SDL_RenderPresent(ren);
        SDL_Delay(16); // ~60 FPS
    }

    // ----- Cleanup -----
    for (SDL_Texture* tex : glyphTextures) SDL_DestroyTexture(tex);
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();

    fftw_destroy_plan(fftPlan);
    Pa_StopStream(stream);
    Pa_CloseStream(stream);
    Pa_Terminate();

    return 0;
}