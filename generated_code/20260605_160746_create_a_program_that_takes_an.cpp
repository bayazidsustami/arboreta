#include <SDL2/SDL.h>
#include <fftw3.h>
#include <complex>
#include <vector>
#include <chrono>
#include <cmath>
#include <thread>
#include <mutex>

// Simple audio capture (stereo 16‑bit) using SDL2
#define SAMPLE_RATE 48000
#define FFT_SIZE    1024

struct AudioBuffer {
    std::vector<double> samples;
    std::mutex mtx;
    AudioBuffer() : samples(FFT_SIZE,0.0) {}
} audioBuf;

// Callback fills audio buffer (ring buffer style)
void audioCallback(void* userdata, Uint8* stream, int len) {
    std::lock_guard<std::mutex> lock(audioBuf.mtx);
    int16_t* src = reinterpret_cast<int16_t*>(stream);
    int samples = len / sizeof(int16_t);
    for (int i = 0; i < samples && i < FFT_SIZE; ++i) {
        audioBuf.samples[i] = src[i] / 32768.0; // normalize
    }
}

// Compute magnitude spectrum (log scaled)
void computeSpectrum(const std::vector<double>& in, std::vector<double>& out) {
    static fftw_plan p = nullptr;
    static std::vector<double> inBuf(FFT_SIZE);
    static std::vector<std::complex<double>> outBuf(FFT_SIZE/2+1);
    if (!p) {
        p = fftw_plan_dft_r2c_1d(FFT_SIZE, inBuf.data(),
                                 reinterpret_cast<fftw_complex*>(outBuf.data()),
                                 FFTW_MEASURE);
    }
    std::copy(in.begin(), in.end(), inBuf.begin());
    fftw_execute(p);
    out.resize(FFT_SIZE/2);
    for (int i = 0; i < FFT_SIZE/2; ++i) {
        double mag = std::abs(outBuf[i]);
        out[i] = std::log10(mag+1e-6);
    }
}

// Mandelbrot iteration count influenced by audio spectrum
int mandelbrot(double cx, double cy, double power, const std::vector<double>& spec) {
    double x = 0.0, y = 0.0;
    int iter = 0, maxIter = 128;
    // map low frequencies to power modulation
    double audioFactor = 1.0 + 0.5 * spec[1]; // use second bin as example
    double maxPower = 2.0 + audioFactor;
    power = std::min(power, maxPower);
    while (x*x + y*y <= 4.0 && iter < maxIter) {
        // z = z^power + c  (approximate using polar form)
        double r = std::sqrt(x*x + y*y);
        double theta = std::atan2(y, x);
        double rp = std::pow(r, power);
        double thetap = theta * power;
        x = rp * std::cos(thetap) + cx;
        y = rp * std::sin(thetap) + cy;
        ++iter;
    }
    return iter;
}

// map iteration to color using spectrum
Uint32 colormap(int iter, const std::vector<double>& spec, SDL_PixelFormat* fmt) {
    double t = (double)iter / 128.0;
    // Use low/mid frequencies as hue, high as brightness
    double hue = std::fmod( spec[5] * 360.0, 360.0 ); // arbitrary bin
    double sat = 0.6 + 0.4 * std::sin(t * M_PI);
    double val = 0.3 + 0.7 * t;
    // HSV to RGB
    double c = val * sat;
    double x = c * (1 - std::fabs(std::fmod(hue/60.0,2)-1));
    double m = val - c;
    double r=0,g=0,b=0;
    if (hue<60){r=c;g=x;}
    else if (hue<120){r=x;g=c;}
    else if (hue<180){g=c;b=x;}
    else if (hue<240){g=x;b=c;}
    else if (hue<300){r=x;b=c;}
    else {r=c;b=x;}
    Uint8 R = Uint8((r+m)*255);
    Uint8 G = Uint8((g+m)*255);
    Uint8 B = Uint8((b+m)*255);
    return SDL_MapRGB(fmt, R, G, B);
}

int main(int argc, char* argv[]) {
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) != 0) {
        return -1;
    }

    // Create window and renderer
    const int W=800, H=600;
    SDL_Window* win = SDL_CreateWindow("Audio‑Driven Mandelbrot",
                                       SDL_WINDOWPOS_CENTERED,
                                       SDL_WINDOWPOS_CENTERED,
                                       W, H, SDL_WINDOW_SHOWN);
    SDL_Renderer* ren = SDL_CreateRenderer(win, -1,
                                           SDL_RENDERER_ACCELERATED);
    SDL_Texture* tex = SDL_CreateTexture(ren,
                                         SDL_PIXELFORMAT_RGB24,
                                         SDL_TEXTUREACCESS_STREAMING,
                                         W, H);
    // Audio setup
    SDL_AudioSpec want{}, have{};
    want.freq = SAMPLE_RATE;
    want.format = AUDIO_S16SYS;
    want.channels = 1;
    want.samples = FFT_SIZE;
    want.callback = audioCallback;
    SDL_AudioDeviceID dev = SDL_OpenAudioDevice(nullptr, 1, &want, &have, 0);
    if (dev == 0) {
        SDL_Quit();
        return -1;
    }
    SDL_PauseAudioDevice(dev, 0); // start capture

    double zoom = 1.5;
    double offsetX = -0.5, offsetY = 0.0;
    double zoomSpeed = 0.998;
    double power = 2.0;

    bool quit = false;
    SDL_Event e;
    std::vector<double> spectrum;

    while (!quit) {
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) quit = true;
        }

        // copy audio data safely
        std::vector<double> audioCopy;
        {
            std::lock_guard<std::mutex> lock(audioBuf.mtx);
            audioCopy = audioBuf.samples;
        }
        computeSpectrum(audioCopy, spectrum);

        // modify zoom and power by audio
        double low = spectrum.empty()?0:spectrum[2];
        zoom *= (zoomSpeed + 0.0005*low);
        power = 2.0 + low*0.5;

        // render fractal
        void* pixels;
        int pitch;
        SDL_LockTexture(tex, nullptr, &pixels, &pitch);
        Uint8* dst = static_cast<Uint8*>(pixels);
        SDL_PixelFormat* fmt = SDL_AllocFormat(SDL_PIXELFORMAT_RGB24);
        for (int y = 0; y < H; ++y) {
            for (int x = 0; x < W; ++x) {
                double cx = (x - W/2.0) * (4.0/zoom) / W + offsetX;
                double cy = (y - H/2.0) * (4.0/zoom) / H + offsetY;
                int it = mandelbrot(cx, cy, power, spectrum);
                Uint32 col = colormap(it, spectrum, fmt);
                Uint8* p = dst + y * pitch + x * 3;
                SDL_GetRGB(col, fmt, &p[0], &p[1], &p[2]);
            }
        }
        SDL_UnlockTexture(tex);
        SDL_FreeFormat(fmt);

        SDL_RenderClear(ren);
        SDL_RenderCopy(ren, tex, nullptr, nullptr);
        SDL_RenderPresent(ren);

        // limit frame rate
        std::this_thread::sleep_for(std::chrono::milliseconds(16));
    }

    SDL_CloseAudioDevice(dev);
    SDL_DestroyTexture(tex);
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 0;
}