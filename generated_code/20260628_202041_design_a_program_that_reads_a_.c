#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <opencv2/videoio/videoio_c.h>
#include <opencv2/imgproc/imgproc_c.h>
#include <opencv2/highgui/highgui_c.h>
#include <SDL2/SDL.h>
#include <portaudio.h>

#define WIDTH  640
#define HEIGHT 480
#define SAMPLE_RATE 44100
#define FRAMES_PER_BUFFER 256
#define NUM_NOTES 12
#define PI 3.14159265358979323846

/* ---------- Audio synthesis ---------- */
typedef struct {
    float phase;
    float freq;
    float amp;
} Synth;

static int paCallback(const void *input, void *output,
                      unsigned long frameCount,
                      const PaStreamCallbackTimeInfo* timeInfo,
                      PaStreamCallbackFlags statusFlags,
                      void *userData)
{
    Synth *s = (Synth*)userData;
    float *out = (float*)output;
    for (unsigned long i = 0; i < frameCount; ++i) {
        out[i] = s->amp * sinf(2.0f * PI * s->phase);
        s->phase += s->freq / SAMPLE_RATE;
        if (s->phase >= 1.0f) s->phase -= 1.0f;
    }
    return paContinue;
}

/* Map a hue (0..360) to a note frequency (C major scale) */
static float hueToFreq(float hue)
{
    static const float baseFreq = 261.63f; // middle C
    int note = (int)(hue / 30.0f) % NUM_NOTES; // 12 semitones
    return baseFreq * powf(2.0f, note / 12.0f);
}

/* Compute dominant hue using a very cheap histogram */
static float dominantHue(const IplImage *img)
{
    int hist[360] = {0};
    for (int y = 0; y < img->height; ++y) {
        const uchar *row = (uchar*)(img->imageData + y*img->widthStep);
        for (int x = 0; x < img->width; ++x) {
            int b = row[x*3+0];
            int g = row[x*3+1];
            int r = row[x*3+2];
            float fr = r/255.0f, fg = g/255.0f, fb = b/255.0f;
            float max = fmaxf(fr, fmaxf(fg, fb));
            float min = fminf(fr, fminf(fg, fb));
            float delta = max - min;
            float hue = 0.0f;
            if (delta > 0.0001f) {
                if (max == fr) hue = 60.0f * fmodf(((fg - fb) / delta), 6.0f);
                else if (max == fg) hue = 60.0f * (((fb - fr) / delta) + 2.0f);
                else hue = 60.0f * (((fr - fg) / delta) + 4.0f);
                if (hue < 0) hue += 360.0f;
            }
            hist[(int)hue]++;
        }
    }
    int maxBin = 0;
    for (int i = 1; i < 360; ++i)
        if (hist[i] > hist[maxBin]) maxBin = i;
    return (float)maxBin;
}

/* ---------- Visual mandala ---------- */
static void drawMandala(SDL_Renderer *ren, float amplitude, float time)
{
    const int petals = 8;
    const float radius = 80.0f + 30.0f * amplitude;
    SDL_SetRenderDrawBlendMode(ren, SDL_BLENDMODE_ADD);
    for (int i = 0; i < petals; ++i) {
        float angle = 2.0f * PI * i / petals + time;
        float x = WIDTH/2 + radius * cosf(angle);
        float y = HEIGHT/2 + radius * sinf(angle);
        Uint8 alpha = (Uint8)(128 + 127 * sinf(time + i));
        SDL_SetRenderDrawColor(ren, 255, 200, 50, alpha);
        SDL_Rect rect = {(int)x-15, (int)y-15, 30, 30};
        SDL_RenderFillRect(ren, &rect);
    }
}

/* ---------- Main ---------- */
int main(void)
{
    /* initialise webcam */
    CvCapture *cap = cvCreateCameraCapture(0);
    if (!cap) { fprintf(stderr, "Cannot open camera\n"); return -1; }
    cvSetCaptureProperty(cap, CV_CAP_PROP_FRAME_WIDTH, WIDTH);
    cvSetCaptureProperty(cap, CV_CAP_PROP_FRAME_HEIGHT, HEIGHT);

    /* initialise SDL for graphics */
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        fprintf(stderr, "SDL Init error: %s\n", SDL_GetError());
        return -1;
    }
    SDL_Window *win = SDL_CreateWindow("Audio‑Visual Mandala",
                    SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                    WIDTH, HEIGHT, 0);
    SDL_Renderer *ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
    SDL_SetRenderDrawBlendMode(ren, SDL_BLENDMODE_BLEND);

    /* initialise PortAudio */
    Pa_Initialize();
    Synth synth = {0.0f, 440.0f, 0.0f};
    PaStream *stream;
    Pa_OpenDefaultStream(&stream, 0, 1, paFloat32, SAMPLE_RATE,
                         FRAMES_PER_BUFFER, paCallback, &synth);
    Pa_StartStream(stream);

    /* main loop */
    int running = 1;
    Uint32 startTick = SDL_GetTicks();
    while (running) {
        SDL_Event ev;
        while (SDL_PollEvent(&ev))
            if (ev.type == SDL_QUIT) running = 0;

        IplImage *frame = cvQueryFrame(cap);
        if (!frame) continue;

        float hue = dominantHue(frame);
        synth.freq = hueToFreq(hue);
        synth.amp = 0.2f + 0.3f * fabsf(sinf(hue * 0.1f));

        /* render */
        SDL_SetRenderDrawColor(ren, 10, 10, 30, 255);
        SDL_RenderClear(ren);
        float t = (SDL_GetTicks() - startTick) / 1000.0f;
        drawMandala(ren, synth.amp, t);
        SDL_RenderPresent(ren);
    }

    /* cleanup */
    Pa_StopStream(stream);
    Pa_CloseStream(stream);
    Pa_Terminate();
    cvReleaseCapture(&cap);
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 0;
}