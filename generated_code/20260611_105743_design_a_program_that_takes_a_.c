#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdbool.h>
#include <pthread.h>
#include <opencv2/opencv.hpp>
#include <SDL2/SDL.h>
#include <portaudio.h>
#include <RtMidi.h>

using namespace cv;

/* ---------- Configuration ---------- */
#define WIDTH  640
#define HEIGHT 480
#define FPS    30
#define K      5               // number of dominant colors
#define SAMPLE_RATE 44100
#define MAX_VOICES  8

/* ---------- Global shared data ---------- */
static float g_note_frequencies[MAX_VOICES];
static float g_note_amplitudes[MAX_VOICES];
static pthread_mutex_t audio_mutex = PTHREAD_MUTEX_INITIALIZER;

/* ---------- Simple k‑means for dominant colors ---------- */
static void dominant_colors(const Mat &img, Vec3b *out) {
    Mat samples = img.reshape(1, img.total());
    Mat labels, centers;
    kmeans(samples, K, labels,
           TermCriteria(TermCriteria::MAX_ITER+TermCriteria::EPS, 10, 1.0),
           3, KMEANS_PP_CENTERS, centers);
    for (int i = 0; i < K; ++i) {
        Vec3b c = centers.at<Vec3f>(i);
        out[i] = c;
    }
}

/* ---------- MIDI handling ---------- */
static RtMidiOut *midi = NULL;
static void send_midi_note(int note, int velocity, bool on) {
    std::vector<unsigned char> msg(3);
    msg[0] = (unsigned char)(on ? 0x90 : 0x80); // note on/off, channel 0
    msg[1] = (unsigned char)note;
    msg[2] = (unsigned char)velocity;
    midi->sendMessage(&msg);
}

/* ---------- Audio callback (simple additive synth) ---------- */
static int pa_callback(const void *inputBuffer, void *outputBuffer,
                       unsigned long framesPerBuffer,
                       const PaStreamCallbackTimeInfo* timeInfo,
                       PaStreamCallbackFlags statusFlags,
                       void *userData) {
    float *out = (float*)outputBuffer;
    (void) inputBuffer; (void)timeInfo; (void)statusFlags; (void)userData;
    pthread_mutex_lock(&audio_mutex);
    for (unsigned long i = 0; i < framesPerBuffer; ++i) {
        float sample = 0.0f;
        for (int v = 0; v < MAX_VOICES; ++v) {
            if (g_note_amplitudes[v] > 0.0f) {
                static double phase[MAX_VOICES] = {0};
                phase[v] += 2.0 * M_PI * g_note_frequencies[v] / SAMPLE_RATE;
                if (phase[v] > 2.0*M_PI) phase[v] -= 2.0*M_PI;
                sample += sin(phase[v]) * g_note_amplitudes[v];
            }
        }
        out[i] = sample * 0.2f; // master gain
    }
    pthread_mutex_unlock(&audio_mutex);
    return paContinue;
}

/* ---------- Visual rendering (kaleidoscopic tiles) ---------- */
static void render_kaleido(SDL_Renderer *ren, const Vec3b *palette) {
    int tileW = WIDTH / 8;
    int tileH = HEIGHT / 6;
    for (int y = 0; y < HEIGHT; y += tileH) {
        for (int x = 0; x < WIDTH; x += tileW) {
            int idx = ((x / tileW) + (y / tileH)) % K;
            SDL_SetRenderDrawColor(ren,
                palette[idx][2], palette[idx][1], palette[idx][0], 255);
            SDL_Rect r = { x, y, tileW, tileH };
            SDL_RenderFillRect(ren, &r);
        }
    }
}

/* ---------- Thread that updates audio parameters from colors ---------- */
static void *audio_updater(void *arg) {
    (void)arg;
    const double baseFreq = 220.0; // A3
    while (true) {
        // simple mapping: hue -> pitch, brightness -> amplitude
        // (implemented in main loop, just sleep here)
        Pa_Sleep(10);
    }
    return NULL;
}

/* ---------- Main ---------- */
int main(int argc, char *argv[]) {
    (void)argc; (void)argv;
    /* Init webcam */
    VideoCapture cap(0);
    if (!cap.isOpened()) { fprintf(stderr,"Cannot open webcam\n"); return -1; }
    cap.set(CAP_PROP_FRAME_WIDTH, WIDTH);
    cap.set(CAP_PROP_FRAME_HEIGHT, HEIGHT);
    cap.set(CAP_PROP_FPS, FPS);

    /* Init SDL */
    if (SDL_Init(SDL_INIT_VIDEO) != 0) { fprintf(stderr,"SDL init failed: %s\n",SDL_GetError()); return -1; }
    SDL_Window *win = SDL_CreateWindow("Synesthetic Loop", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, WIDTH, HEIGHT, 0);
    SDL_Renderer *ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
    if (!win || !ren) { fprintf(stderr,"SDL window/renderer error\n"); return -1; }

    /* Init MIDI */
    try { midi = new RtMidiOut(); }
    catch (RtMidiError &error) { error.printMessage(); return -1; }
    if (midi->getPortCount() == 0) { fprintf(stderr,"No MIDI output ports\n"); return -1; }
    midi->openPort(0);

    /* Init PortAudio */
    Pa_Initialize();
    PaStream *stream;
    Pa_OpenDefaultStream(&stream, 0, 1, paFloat32, SAMPLE_RATE, 256, pa_callback, NULL);
    Pa_StartStream(stream);

    /* Start audio updater thread */
    pthread_t upd_thread;
    pthread_create(&upd_thread, NULL, audio_updater, NULL);

    /* Main loop */
    bool quit = false;
    SDL_Event e;
    while (!quit) {
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) quit = true;
        }
        Mat frame;
        cap >> frame;
        if (frame.empty()) continue;
        cvtColor(frame, frame, COLOR_BGR2RGB);

        Vec3b palette[K];
        dominant_colors(frame, palette);

        /* Map palette to MIDI notes */
        for (int i = 0; i < K; ++i) {
            int note = 60 + i * 2; // C4 upward
            int velocity = palette[i][0] * 0.3 + palette[i][1] * 0.59 + palette[i][2] * 0.11; // luminance
            send_midi_note(note, velocity, true);
            // set audio parameters
            pthread_mutex_lock(&audio_mutex);
            g_note_frequencies[i % MAX_VOICES] = 220.0 * pow(2.0, (note-69)/12.0);
            g_note_amplitudes[i % MAX_VOICES] = velocity / 127.0f * 0.1f;
            pthread_mutex_unlock(&audio_mutex);
        }

        /* Render visual */
        SDL_SetRenderDrawColor(ren, 0,0,0,255);
        SDL_RenderClear(ren);
        render_kaleido(ren, palette);
        SDL_RenderPresent(ren);

        SDL_Delay(1000 / FPS);
    }

    /* Cleanup */
    Pa_StopStream(stream);
    Pa_CloseStream(stream);
    Pa_Terminate();
    delete midi;
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 0;
}