#include <iostream>
#include <vector>
#include <complex>
#include <cmath>
#include <thread>
#include <atomic>
#include <mutex>
#include <condition_variable>
#include <chrono>
#include <sstream>
#include <fstream>
#include <map>

// PortAudio for microphone input
#include <portaudio.h>

// FFTW for spectral analysis
#include <fftw3.h>

// SDL2 for real‑time rendering
#include <SDL2/SDL.h>

// ------------------------------------------------------------
// Configuration constants (can be tweaked at runtime via UI)
static const int SAMPLE_RATE      = 48000;
static const int FRAMES_PER_BUF   = 1024;
static const int FFT_SIZE         = 1024;
static const int NUM_BANDS        = 32;          // number of frequency bands
static const int WINDOW_WIDTH     = 800;
static const int WINDOW_HEIGHT    = 800;

// ------------------------------------------------------------
// Global shared state
std::vector<double> gMagnitudes(NUM_BANDS, 0.0);
std::mutex gMutex;
std::atomic<bool> gRunning(true);

// ------------------------------------------------------------
// Simple UI parameters (adjustable via keyboard)
struct UIParams {
    double hueShift = 0.0;          // color rotation
    double scale    = 1.0;          // glyph size
    double rotation = 0.0;          // overall rotation
} gUI;

// ------------------------------------------------------------
// Helper: map a frequency band index to a Unicode glyph
static const std::vector<std::wstring> glyphs = {
    L"✿",L"✶",L"✧",L"❂",L"✪",L"✫",L"✩",L"❁",
    L"❀",L"✈",L"✂",L"✈",L"❖",L"➳",L"☼",L"☽",
    L"✦",L"✤",L"✥",L"✢",L"✱",L"✲",L"✳",L"✴",
    L"✵",L"✶",L"✷",L"✸",L"✹",L"✺",L"✻",L"✼"
};

inline std::wstring bandToGlyph(int band) {
    return glyphs[band % glyphs.size()];
}

// ------------------------------------------------------------
// Audio callback (PortAudio)
static int audioCallback(const void* input, void*, unsigned long frameCount,
                         const PaStreamCallbackTimeInfo*, PaStreamCallbackFlags,
                         void*) {
    const float* in = static_cast<const float*>(input);
    static std::vector<double> circularBuffer(FFT_SIZE,0.0);
    static size_t writePos = 0;

    // copy samples into circular buffer
    for (unsigned i=0;i<frameCount;++i) {
        circularBuffer[writePos] = in[i];
        writePos = (writePos+1)%FFT_SIZE;
    }

    // When we have enough new data, run an FFT
    static size_t samplesSinceFFT = 0;
    samplesSinceFFT += frameCount;
    if (samplesSinceFFT >= FRAMES_PER_BUF) {
        // copy contiguous window for FFT
        std::vector<double> window(FFT_SIZE);
        for (size_t i=0;i<FFT_SIZE;++i)
            window[i]=circularBuffer[(writePos+i)%FFT_SIZE]*0.5*(1.0-cos(2*M_PI*i/(FFT_SIZE-1))); // Hann

        // FFTW plan (reuse)
        static fftw_plan plan = fftw_plan_r2r_1d(FFT_SIZE, window.data(),
                                                window.data(), FFTW_R2HC, FFTW_ESTIMATE);
        fftw_execute(plan);

        // compute magnitude per band
        std::vector<double> mags(NUM_BANDS,0.0);
        int binsPerBand = (FFT_SIZE/2)/NUM_BANDS;
        for (int b=0;b<NUM_BANDS;++b) {
            double sum=0;
            for (int k=0;k<binsPerBand;++k) {
                int idx = b*binsPerBand + k;
                double re = (idx==0)? window[0] : window[idx];
                double im = (idx==0)? 0.0 : window[FFT_SIZE-idx];
                sum += sqrt(re*re+im*im);
            }
            mags[b]=sum/(binsPerBand+1e-6);
        }

        // store results
        {
            std::lock_guard<std::mutex> lk(gMutex);
            gMagnitudes.swap(mags);
        }

        samplesSinceFFT = 0;
    }

    return paContinue;
}

// ------------------------------------------------------------
// Render one frame using SDL2
void renderFrame(SDL_Renderer* renderer, double timeSec) {
    // background
    SDL_SetRenderDrawColor(renderer,0,0,0,255);
    SDL_RenderClear(renderer);

    // fetch current magnitudes
    std::vector<double> mags;
    {
        std::lock_guard<std::mutex> lk(gMutex);
        mags = gMagnitudes;
    }

    // draw mandala glyphs
    for (int i=0;i<NUM_BANDS;++i) {
        double amp = mags[i];
        double radius = (i+1)*(WINDOW_HEIGHT/2.0/NUM_BANDS) * gUI.scale;
        double angle = gUI.rotation + 2*M_PI*i/NUM_BANDS + timeSec*0.5;
        double x = WINDOW_WIDTH/2 + radius*cos(angle);
        double y = WINDOW_HEIGHT/2 + radius*sin(angle);

        // colour based on amplitude and hueShift
        Uint8 hue = static_cast<Uint8>(fmod(gUI.hueShift + amp*30, 256));
        Uint8 r = (hue*3)%256, g = (hue*5)%256, b = (hue*7)%255;
        SDL_SetRenderDrawColor(renderer,r,g,b,255);

        // render glyph as textured text (using SDL_ttf would be ideal, but we keep it simple)
        // Here we just render a small filled circle representing the glyph.
        for (int dx=-2;dx<=2;++dx)
            for (int dy=-2;dy<=2;++dy)
                SDL_RenderDrawPoint(renderer, (int)x+dx, (int)y+dy);
    }

    SDL_RenderPresent(renderer);
}

// ------------------------------------------------------------
// Export frames to animated SVG (very simple – each frame is a group)
void exportSVG(const std::vector<std::vector<double>>& frames, const std::string& filename) {
    std::ofstream out(filename);
    out<<"<?xml version=\"1.0\" standalone=\"no\"?>\n";
    out<<"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\""<<WINDOW_WIDTH<<"\" height=\""<<WINDOW_HEIGHT<<"\" version=\"1.1\">\n";

    double frameDur = 0.04; // 25 FPS
    for (size_t f=0; f<frames.size(); ++f) {
        out<<"<g visibility=\"hidden\">\n";
        const auto& mags = frames[f];
        for (int i=0;i<NUM_BANDS;++i) {
            double amp = mags[i];
            double radius = (i+1)*(WINDOW_HEIGHT/2.0/NUM_BANDS) * gUI.scale;
            double angle = gUI.rotation + 2*M_PI*i/NUM_BANDS + f*frameDur*0.5;
            double x = WINDOW_WIDTH/2 + radius*cos(angle);
            double y = WINDOW_HEIGHT/2 + radius*sin(angle);
            Uint8 hue = static_cast<Uint8>(fmod(gUI.hueShift + amp*30, 256));
            Uint8 r = (hue*3)%256, g = (hue*5)%256, b = (hue*7)%255;
            std::stringstream ss;
            ss<<"#"<<std::hex<<((r<<16)|(g<<8)|b);
            out<<"<text x=\""<<x<<"\" y=\""<<y<<"\" font-size=\"12\" fill=\""<<ss.str()<<"\">"<<bandToGlyph(i).c_str()<<"</text>\n";
        }
        out<<"</g>\n";
    }

    // simple animation using SMIL
    out<<"<animate attributeName=\"visibility\" values=\"visible;hidden\" dur=\""<<frameDur<<"s\" repeatCount=\"indefinite\"/>\n";
    out<<"</svg>\n";
}

// ------------------------------------------------------------
int main() {
    // initialise PortAudio
    Pa_Initialize();
    PaStream* stream;
    PaStreamParameters inParam{};
    inParam.device = Pa_GetDefaultInputDevice();
    inParam.channelCount = 1;
    inParam.sampleFormat = paFloat32;
    inParam.suggestedLatency = Pa_GetDeviceInfo(inParam.device)->defaultLowInputLatency;
    Pa_OpenStream(&stream,&inParam,nullptr,SAMPLE_RATE,FRAMES_PER_BUF,
                  paClipOff,audioCallback,nullptr);
    Pa_StartStream(stream);

    // initialise SDL
    SDL_Init(SDL_INIT_VIDEO);
    SDL_Window* win = SDL_CreateWindow("Sonic Mandala",SDL_WINDOWPOS_CENTERED,SDL_WINDOWPOS_CENTERED,
                                       WINDOW_WIDTH,WINDOW_HEIGHT,SDL_WINDOW_SHOWN);
    SDL_Renderer* ren = SDL_CreateRenderer(win,-1,SDL_RENDERER_ACCELERATED);

    // main loop
    std::vector<std::vector<double>> recordedFrames;
    auto start = std::chrono::steady_clock::now();
    while (gRunning) {
        // handle events
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type==SDL_QUIT) gRunning=false;
            else if (e.type==SDL_KEYDOWN) {
                switch(e.key.keysym.sym){
                    case SDLK_ESCAPE: gRunning=false; break;
                    case SDLK_UP:    gUI.hueShift+=10; break;
                    case SDLK_DOWN:  gUI.hueShift-=10; break;
                    case SDLK_LEFT:  gUI.scale*=0.9; break;
                    case SDLK_RIGHT: gUI.scale*=1.1; break;
                    case SDLK_a:     gUI.rotation-=0.1; break;
                    case SDLK_d:     gUI.rotation+=0.1; break;
                }
            }
        }

        // render
        double t = std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count();
        renderFrame(ren,t);

        // record a copy for SVG export (optional, limit to 200 frames)
        {
            std::lock_guard<std::mutex> lk(gMutex);
            recordedFrames.push_back(gMagnitudes);
            if (recordedFrames.size()>200) recordedFrames.erase(recordedFrames.begin());
        }

        SDL_Delay(16); // ~60 FPS
    }

    // export SVG
    exportSVG(recordedFrames,"mandala.svg");
    std::cout<<"Exported mandala.svg\n";

    // cleanup
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    Pa_StopStream(stream);
    Pa_CloseStream(stream);
    Pa_Terminate();
    return 0;
}