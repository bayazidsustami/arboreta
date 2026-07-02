#include <SDL2/SDL.h>
#include <cmath>
#include <vector>
#include <algorithm>
#include <cstdint>
#include <chrono>

/*--------------------------------------------------------------
  Simple real‑to‑real FFT (Cooley‑Tukey, power‑of‑2 size)
--------------------------------------------------------------*/
static void fft(std::vector<float>& real, std::vector<float>& imag) {
    const size_t n = real.size();
    const double PI = std::acos(-1);
    // bit reversal
    size_t j = 0;
    for (size_t i = 1; i < n; ++i) {
        size_t bit = n >> 1;
        while (j & bit) { j ^= bit; bit >>= 1; }
        j ^= bit;
        if (i < j) {
            std::swap(real[i], real[j]);
            std::swap(imag[i], imag[j]);
        }
    }
    // butterfly
    for (size_t len = 2; len <= n; len <<= 1) {
        double ang = -2 * PI / len;
        double wlen_cos = std::cos(ang);
        double wlen_sin = std::sin(ang);
        for (size_t i = 0; i < n; i += len) {
            double w_cos = 1.0, w_sin = 0.0;
            for (size_t j = 0; j < len / 2; ++j) {
                size_t u = i + j;
                size_t v = i + j + len / 2;
                double tcos = w_cos * real[v] - w_sin * imag[v];
                double tsin = w_cos * imag[v] + w_sin * real[v];
                real[v] = real[u] - (float)tcos;
                imag[v] = imag[u] - (float)tsin;
                real[u] += (float)tcos;
                imag[u] += (float)tsin;
                double nxt_w_cos = w_cos * wlen_cos - w_sin * wlen_sin;
                double nxt_w_sin = w_cos * wlen_sin + w_sin * wlen_cos;
                w_cos = nxt_w_cos; w_sin = nxt_w_sin;
            }
        }
    }
}

/*--------------------------------------------------------------
  Audio capture (SDL2). 16‑bit mono at 44.1kHz, 1024 samples fifo.
--------------------------------------------------------------*/
constexpr int SAMPLE_RATE = 44100;
constexpr int BUFFER_SIZE = 1024;

struct AudioBuffer {
    std::vector<float> samples;
    SDL_mutex* mutex;
    AudioBuffer() : samples(BUFFER_SIZE, 0.0f), mutex(SDL_CreateMutex()) {}
    ~AudioBuffer() { SDL_DestroyMutex(mutex); }
};

static void audioCallback(void* userdata, Uint8* stream, int len) {
    AudioBuffer* buf = static_cast<AudioBuffer*>(userdata);
    int16_t* src = reinterpret_cast<int16_t*>(stream);
    int count = len / sizeof(int16_t);
    SDL_LockMutex(buf->mutex);
    for (int i = 0; i < count && i < BUFFER_SIZE; ++i)
        buf->samples[i] = src[i] / 32768.0f;          // normalize to [-1,1]
    SDL_UnlockMutex(buf->mutex);
}

/*--------------------------------------------------------------
  Map frequency to hue (0‑360). Simple harmonic wheel:
  hue = (freq / base) * 360 % 360, where base = 440Hz (A4).
--------------------------------------------------------------*/
static float freqToHue(float freq) {
    const float base = 440.0f;
    float hue = std::fmod((freq / base) * 360.0f, 360.0f);
    if (hue < 0) hue += 360.0f;
    return hue;
}

/*--------------------------------------------------------------
  Convert HSV to RGB (0‑255).
--------------------------------------------------------------*/
static SDL_Color hsvToRgb(float h, float s, float v) {
    float c = v * s;
    float x = c * (1 - std::fabsf(std::fmodf(h / 60.0f, 2) - 1));
    float m = v - c;
    float rp=0,gp=0,bp=0;
    if (h < 60) { rp=c; gp=x; }
    else if (h < 120) { rp=x; gp=c; }
    else if (h < 180) { gp=c; bp=x; }
    else if (h < 240) { gp=x; bp=c; }
    else if (h < 300) { rp=c; bp=x; }
    else { rp=x; bp=c; }
    SDL_Color col;
    col.r = Uint8((rp+m)*255);
    col.g = Uint8((gp+m)*255);
    col.b = Uint8((bp+m)*255);
    col.a = 255;
    return col;
}

/*--------------------------------------------------------------
  Fractal point iteration (Mandelbrot‑like) driven by hue.
--------------------------------------------------------------*/
static void drawFractal(SDL_Renderer* rend, float hue, int w, int h) {
    const int maxIter = 100;
    // map hue to complex constant c = re + i*im
    float angle = hue * M_PI / 180.0f;
    float cRe = 0.4f * std::cos(angle);
    float cIm = 0.4f * std::sin(angle);
    // center and scale
    float scale = 1.5f;
    for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
            float zx = (x - w/2) * (scale / w);
            float zy = (y - h/2) * (scale / h);
            int iter = 0;
            while (zx*zx + zy*zy < 4.0f && iter < maxIter) {
                float tmp = zx*zx - zy*zy + cRe;
                zy = 2*zx*zy + cIm;
                zx = tmp;
                ++iter;
            }
            float norm = (float)iter / maxIter;
            // hue shifts with iteration for a kaleidoscopic feel
            SDL_Color col = hsvToRgb(std::fmod(hue + norm*360.0f,360.0f), 0.8f, norm);
            SDL_SetRenderDrawColor(rend, col.r, col.g, col.b, 255);
            SDL_RenderDrawPoint(rend, x, y);
        }
    }
}

/*--------------------------------------------------------------
  Main: initialise audio+video, loop, compute dominant freq each sec.
--------------------------------------------------------------*/
int main(int argc, char* argv[]) {
    if (SDL_Init(SDL_INIT_AUDIO | SDL_INIT_VIDEO) < 0) return -1;

    // audio setup
    AudioBuffer audioBuf;
    SDL_AudioSpec want{}, have{};
    want.freq = SAMPLE_RATE;
    want.format = AUDIO_S16SYS;
    want.channels = 1;
    want.samples = BUFFER_SIZE;
    want.callback = audioCallback;
    want.userdata = &audioBuf;
    if (SDL_OpenAudio(&want, &have) != 0) { SDL_Quit(); return -1; }
    SDL_PauseAudio(0);

    // video setup
    const int WIN_W = 640, WIN_H = 480;
    SDL_Window* win = SDL_CreateWindow("Audio‑Driven Kaleidoscope",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, WIN_W, WIN_H, 0);
    SDL_Renderer* rend = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);

    auto lastTick = std::chrono::steady_clock::now();
    float currentHue = 0.0f;

    bool quit = false;
    SDL_Event e;
    while (!quit) {
        while (SDL_PollEvent(&e)) if (e.type == SDL_QUIT) quit = true;

        // each second compute dominant frequency
        auto now = std::chrono::steady_clock::now();
        if (std::chrono::duration_cast<std::chrono::seconds>(now - lastTick).count() >= 1) {
            std::vector<float> window(BUFFER_SIZE);
            SDL_LockMutex(audioBuf.mutex);
            std::copy(audioBuf.samples.begin(), audioBuf.samples.end(), window.begin());
            SDL_UnlockMutex(audioBuf.mutex);

            // apply Hann window
            for (size_t i = 0; i < window.size(); ++i)
                window[i] *= 0.5f * (1 - std::cos(2 * M_PI * i / (window.size() - 1)));

            std::vector<float> imag(window.size(), 0.0f);
            fft(window, imag);

            // magnitude spectrum
            size_t peakIdx = 1;
            float peakMag = 0.0f;
            for (size_t i = 1; i < window.size() / 2; ++i) {
                float mag = std::sqrt(window[i]*window[i] + imag[i]*imag[i]);
                if (mag > peakMag) { peakMag = mag; peakIdx = i; }
            }
            float freq = (float)peakIdx * SAMPLE_RATE / (float)window.size();
            currentHue = freqToHue(freq);
            lastTick = now;
        }

        // render fractal with current hue
        drawFractal(rend, currentHue, WIN_W, WIN_H);
        SDL_RenderPresent(rend);
        SDL_Delay(16); // ~60 FPS
    }

    SDL_CloseAudio();
    SDL_DestroyRenderer(rend);
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 0;
}