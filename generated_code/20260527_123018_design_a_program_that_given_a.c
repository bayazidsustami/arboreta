#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdint.h>
#include <stdbool.h>
#include <time.h>
#include <unistd.h>
#include <opencv2/opencv.hpp>
#include <SDL2/SDL.h>
#include <portaudio.h>

using namespace cv;

// ---------- Audio ----------

#define SAMPLE_RATE (44100)
#define FRAMES_PER_BUFFER (512)
#define NUM_NOTES 8

static float noteFreq[NUM_NOTES] = {261.63f, 293.66f, 329.63f, 349.23f,
                                    392.00f, 440.00f, 493.88f, 523.25f};

typedef struct {
    float phase;
    float freq;
    float amplitude;
} SynthVoice;

static SynthVoice voice = {0.0f, 440.0f, 0.0f};

static int audioCallback(const void *inputBuffer, void *outputBuffer,
                         unsigned long framesPerBuffer,
                         const PaStreamCallbackTimeInfo* timeInfo,
                         PaStreamCallbackFlags statusFlags,
                         void *userData)
{
    float *out = (float*)outputBuffer;
    for (unsigned long i = 0; i < framesPerBuffer; ++i) {
        float sample = voice.amplitude * sinf(2.0f * M_PI * voice.phase);
        voice.phase += voice.freq / SAMPLE_RATE;
        if (voice.phase >= 1.0f) voice.phase -= 1.0f;
        *out++ = sample; // mono
    }
    return paContinue;
}

// ---------- Voronoi ----------

typedef struct {
    int x, y;
    uint8_t r, g, b;
} Site;

static Uint32 rgbToPixel(SDL_PixelFormat *fmt, Uint8 r, Uint8 g, Uint8 b) {
    return SDL_MapRGB(fmt, r, g, b);
}

// Very naive nearest‑site Voronoi
static void renderVoronoi(SDL_Renderer *ren, Site *sites, int nSites,
                          int width, int height)
{
    SDL_Surface *surf = SDL_CreateRGBSurface(0, width, height, 32,
                                             0x00FF0000,
                                             0x0000FF00,
                                             0x000000FF,
                                             0xFF000000);
    Uint32 *pixels = (Uint32*)surf->pixels;
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            int best = -1;
            int bestDist = INT_MAX;
            for (int i = 0; i < nSites; ++i) {
                int dx = x - sites[i].x;
                int dy = y - sites[i].y;
                int d = dx*dx + dy*dy;
                if (d < bestDist) {
                    bestDist = d;
                    best = i;
                }
            }
            Uint32 col = rgbToPixel(surf->format,
                                    sites[best].r,
                                    sites[best].g,
                                    sites[best].b);
            pixels[y*width + x] = col;
        }
    }
    SDL_Texture *tex = SDL_CreateTextureFromSurface(ren, surf);
    SDL_RenderCopy(ren, tex, NULL, NULL);
    SDL_DestroyTexture(tex);
    SDL_FreeSurface(surf);
}

// ---------- Main ----------

int main(int argc, char **argv)
{
    // Initialise video capture
    VideoCapture cap(0);
    if (!cap.isOpened()) {
        fprintf(stderr, "Cannot open webcam\n");
        return -1;
    }
    int camW = (int)cap.get(CAP_PROP_FRAME_WIDTH);
    int camH = (int)cap.get(CAP_PROP_FRAME_HEIGHT);

    // Initialise SDL
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        fprintf(stderr, "SDL init failed: %s\n", SDL_GetError());
        return -1;
    }
    SDL_Window *win = SDL_CreateWindow("Audio‑Visual",
                                       SDL_WINDOWPOS_CENTERED,
                                       SDL_WINDOWPOS_CENTERED,
                                       camW, camH,
                                       SDL_WINDOW_SHOWN);
    SDL_Renderer *ren = SDL_CreateRenderer(win, -1,
                                           SDL_RENDERER_ACCELERATED);
    // Initialise audio
    Pa_Initialize();
    PaStream *stream;
    Pa_OpenDefaultStream(&stream,
                         0,          // no input
                         1,          // mono output
                         paFloat32,
                         SAMPLE_RATE,
                         FRAMES_PER_BUFFER,
                         audioCallback,
                         NULL);
    Pa_StartStream(stream);

    // Main loop
    Mat frame;
    const int K = NUM_NOTES; // number of palette colours = notes
    Site sites[NUM_NOTES];
    bool quit = false;
    while (!quit) {
        if (!cap.read(frame)) break;
        cvtColor(frame, frame, COLOR_BGR2RGB);
        // ---- extract dominant colours (k‑means) ----
        Mat data;
        frame.convertTo(data, CV_32F);
        data = data.reshape(1, frame.total());
        Mat labels, centers;
        kmeans(data, K, labels,
               TermCriteria(TermCriteria::EPS+TermCriteria::MAX_ITER,10,1.0),
               3, KMEANS_PP_CENTERS, centers);
        // map centres to sites
        for (int i=0;i<K;i++) {
            Vec3f col = centers.at<Vec3f>(i);
            sites[i].r = (uint8_t)col[0];
            sites[i].g = (uint8_t)col[1];
            sites[i].b = (uint8_t)col[2];
            // random positions for visual variety
            sites[i].x = rand()%camW;
            sites[i].y = rand()%camH;
        }
        // ---- audio mapping ----
        // use average brightness of palette to set amplitude
        float avgBright = 0.0f;
        for (int i=0;i<K;i++) avgBright += (sites[i].r+sites[i].g+sites[i].b)/3.0f;
        avgBright /= (K*255.0f);
        voice.amplitude = avgBright * 0.3f; // keep below clipping
        // pick a note based on most common cluster size
        vector<int> cnt(K,0);
        for (int i=0;i<labels.rows;i++) cnt[labels.at<int>(i)]++;
        int maxIdx = max_element(cnt.begin(),cnt.end()) - cnt.begin();
        voice.freq = noteFreq[maxIdx];

        // ---- render ----
        SDL_SetRenderDrawColor(ren,0,0,0,255);
        SDL_RenderClear(ren);
        renderVoronoi(ren, sites, K, camW, camH);
        SDL_RenderPresent(ren);

        // ---- event handling ----
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) quit = true;
            if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_ESCAPE) quit = true;
        }
        SDL_Delay(16); // ~60 FPS
    }

    // cleanup
    Pa_StopStream(stream);
    Pa_CloseStream(stream);
    Pa_Terminate();
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 0;
}