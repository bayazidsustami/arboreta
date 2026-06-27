#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdbool.h>
#include <unistd.h>
#include <pthread.h>
#include <opencv2/opencv.hpp>
#include <SDL2/SDL.h>
#include <portaudio.h>

using namespace cv;

/* -------------------- Audio synthesis -------------------- */
#define SAMPLE_RATE 44100
#define FRAMES_PER_BUFFER 256
#define MAX_NOTES 12

typedef struct {
    float phase;
    float freq;
    float amp;
    bool  active;
} Note;

static Note notes[MAX_NOTES];
static pthread_mutex_t notesMutex = PTHREAD_MUTEX_INITIALIZER;

/* simple sine wave generator */
static int paCallback(const void *input, void *output,
                      unsigned long frameCount,
                      const PaStreamCallbackTimeInfo* timeInfo,
                      PaStreamCallbackFlags statusFlags,
                      void *userData) {
    float *out = (float*)output;
    (void)input; (void)timeInfo; (void)statusFlags; (void)userData;
    pthread_mutex_lock(&notesMutex);
    for (unsigned long i=0;i<frameCount;i++) {
        float sample = 0.0f;
        for (int n=0;n<MAX_NOTES;n++) if (notes[n].active) {
            sample += notes[n].amp * sinf(notes[n].phase);
            notes[n].phase += 2.0f * M_PI * notes[n].freq / SAMPLE_RATE;
            if (notes[n].phase > 2.0f*M_PI) notes[n].phase -= 2.0f*M_PI;
        }
        out[i] = sample * 0.2f; // master gain
    }
    pthread_mutex_unlock(&notesMutex);
    return paContinue;
}

/* trigger a note (simple harmonic scale) */
static void trigger_note(int idx, float freq) {
    pthread_mutex_lock(&notesMutex);
    notes[idx].freq = freq;
    notes[idx].amp = 0.5f;
    notes[idx].phase = 0.0f;
    notes[idx].active = true;
    pthread_mutex_unlock(&notesMutex);
}

/* release a note */
static void release_note(int idx) {
    pthread_mutex_lock(&notesMutex);
    notes[idx].active = false;
    pthread_mutex_unlock(&notesMutex);
}

/* -------------------- Helper: map color to frequency -------------------- */
static float color_to_freq(Vec3b color) {
    // map hue (0-179) to one octave (C4=261.63Hz)
    Mat hsv;
    Mat bgr(1,1,CV_8UC3,color);
    cvtColor(bgr, hsv, COLOR_BGR2HSV);
    int hue = hsv.at<Vec3b>(0,0)[0]; // 0-179
    float base = 261.63f; // C4
    float ratio = powf(2.0f, hue/179.0f); // within one octave
    return base * ratio;
}

/* -------------------- Main -------------------- */
int main(int argc, char *argv[]) {
    /* Init video capture */
    VideoCapture cap(0);
    if (!cap.isOpened()) { fprintf(stderr,"Cannot open camera\n"); return -1; }

    /* Init SDL for drawing */
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        fprintf(stderr,"SDL Init error: %s\n", SDL_GetError());
        return -1;
    }
    SDL_Window *win = SDL_CreateWindow("Audio‑Visual Tapestry",
                        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                        800, 600, SDL_WINDOW_SHOWN);
    SDL_Renderer *ren = SDL_CreateRenderer(win, -1,
                        SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    if (!win || !ren) { fprintf(stderr,"SDL create error\n"); return -1; }

    /* Init PortAudio */
    Pa_Initialize();
    PaStream *stream;
    Pa_OpenDefaultStream(&stream, 0, 1, paFloat32, SAMPLE_RATE,
                         FRAMES_PER_BUFFER, paCallback, NULL);
    Pa_StartStream(stream);

    bool quit = false;
    SDL_Event e;
    int mouseX=0, mouseY=0;

    while (!quit) {
        /* Poll SDL events */
        while (SDL_PollEvent(&e)) {
            if (e.type==SDL_QUIT) quit=true;
            else if (e.type==SDL_MOUSEMOTION) {
                mouseX = e.motion.x;
                mouseY = e.motion.y;
            }
        }

        /* Capture frame */
        Mat frame;
        cap >> frame;
        if (frame.empty()) continue;
        resize(frame, frame, Size(200,150)); // speed up

        /* Find dominant color with k‑means (k=1) */
        Mat data;
        frame.convertTo(data, CV_32F);
        data = data.reshape(1, frame.total());
        Mat labels, centers;
        kmeans(data, 1, labels,
               TermCriteria(TermCriteria::EPS+TermCriteria::COUNT,10,1.0),
               1, KMEANS_PP_CENTERS, centers);
        Vec3b dominant;
        dominant[0] = (uchar)centers.at<float>(0,0);
        dominant[1] = (uchar)centers.at<float>(0,1);
        dominant[2] = (uchar)centers.at<float>(0,2);

        /* Map to frequency and trigger note */
        float freq = color_to_freq(dominant);
        trigger_note(0, freq);
        /* simple note decay */
        static Uint32 lastNoteTime = 0;
        Uint32 now = SDL_GetTicks();
        if (now - lastNoteTime > 200) { release_note(0); lastNoteTime = now; }

        /* Draw */
        SDL_SetRenderDrawColor(ren, 0, 0, 0, 255);
        SDL_RenderClear(ren);

        // brush stroke driven by audio waveform (simple sinusoidal radius)
        float radius = 20.0f + 10.0f * sinf(now * 0.005f);
        SDL_SetRenderDrawColor(ren,
                dominant[2], dominant[1], dominant[0], 255);
        for (int angle=0; angle<360; angle+=10) {
            float rad = angle * M_PI/180.0f;
            int x = mouseX + (int)(radius * cosf(rad));
            int y = mouseY + (int)(radius * sinf(rad));
            SDL_RenderDrawLine(ren, mouseX, mouseY, x, y);
        }

        SDL_RenderPresent(ren);
        SDL_Delay(16); // ~60 FPS
    }

    /* Cleanup */
    Pa_StopStream(stream);
    Pa_CloseStream(stream);
    Pa_Terminate();

    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();

    cap.release();
    return 0;
}