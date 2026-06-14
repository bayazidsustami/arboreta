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

/* ---------- Global structures ---------- */
typedef struct {
    double freq;          // fundamental frequency for a note
    double pan;           // -1.0 left .. 1.0 right
    double amp;           // amplitude
    double phase;         // for synthesis
} Note;

#define MAX_NOTES 64
static Note notes[MAX_NOTES];
static int noteCount = 0;
static pthread_mutex_t notesMutex = PTHREAD_MUTEX_INITIALIZER;

/* ---------- Audio callback (sine synthesis) ---------- */
static int audioCallback(const void *inputBuffer, void *outputBuffer,
                         unsigned long framesPerBuffer,
                         const PaStreamCallbackTimeInfo* timeInfo,
                         PaStreamCallbackFlags statusFlags,
                         void *userData) {
    float *out = (float*)outputBuffer;
    (void)inputBuffer; (void)timeInfo; (void)statusFlags; (void)userData;

    pthread_mutex_lock(&notesMutex);
    for (unsigned long i = 0; i < framesPerBuffer; ++i) {
        float sample = 0.0f;
        for (int n = 0; n < noteCount; ++n) {
            Note *nt = &notes[n];
            sample += (float)(nt->amp * sin(nt->phase));
            nt->phase += 2.0 * M_PI * nt->freq / 44100.0;
        }
        /* simple stereo panning */
        out[2*i]   = sample * (float)(0.5 * (1.0 - notes[0].pan)); // left
        out[2*i+1] = sample * (float)(0.5 * (1.0 + notes[0].pan)); // right
    }
    pthread_mutex_unlock(&notesMutex);
    return paContinue;
}

/* ---------- MIDI output helper ---------- */
static RtMidiOut *midiout = NULL;
static void sendMidiNoteOn(int channel, int pitch, int velocity) {
    std::vector<unsigned char> msg;
    msg.push_back(0x90 | (channel & 0x0F));
    msg.push_back(pitch & 0x7F);
    msg.push_back(velocity & 0x7F);
    midiout->sendMessage(&msg);
}
static void sendMidiNoteOff(int channel, int pitch, int velocity) {
    std::vector<unsigned char> msg;
    msg.push_back(0x80 | (channel & 0x0F));
    msg.push_back(pitch & 0x7F);
    msg.push_back(velocity & 0x7F);
    midiout->sendMessage(&msg);
}

/* ---------- Fractal lattice drawing ---------- */
static void drawFractal(SDL_Renderer *rend, int width, int height, double time) {
    SDL_SetRenderDrawColor(rend, 0, 0, 0, 255);
    SDL_RenderClear(rend);
    SDL_SetRenderDrawColor(rend, 0, 255, 255, 255);
    int steps = 8;
    for (int i = 0; i < steps; ++i) {
        double angle = time + i * M_PI/4;
        int x = (int)(width/2 + (width/3) * cos(angle));
        int y = (int)(height/2 + (height/3) * sin(angle));
        SDL_RenderDrawLine(rend, width/2, height/2, x, y);
    }
    SDL_RenderPresent(rend);
}

/* ---------- Vision thread: webcam -> notes ---------- */
static void *visionThread(void *arg) {
    VideoCapture cap(0);
    if (!cap.isOpened()) return NULL;

    Mat prev, gray;
    while (true) {
        Mat frame;
        cap >> frame;
        if (frame.empty()) break;

        cvtColor(frame, gray, COLOR_BGR2GRAY);
        if (!prev.empty()) {
            Mat flow;
            calcOpticalFlowFarneback(prev, gray, flow, 0.5, 3, 15, 3, 5, 1.2, 0);
            // Estimate motion magnitude
            double motion = norm(flow);
            // Map motion to pitch (C3..C5)
            int pitch = 48 + (int)(motion/10.0) % 24;
            // Map average brightness to velocity
            Scalar avg = mean(frame);
            int velocity = (int)(avg[2] / 255.0 * 127);

            // Create a note
            pthread_mutex_lock(&notesMutex);
            if (noteCount < MAX_NOTES) {
                notes[noteCount].freq = 440.0 * pow(2.0, (pitch-69)/12.0);
                notes[noteCount].pan  = ((double)rand()/RAND_MAX)*2.0-1.0;
                notes[noteCount].amp  = velocity/127.0;
                notes[noteCount].phase= 0.0;
                ++noteCount;
                sendMidiNoteOn(0, pitch, velocity);
            }
            pthread_mutex_unlock(&notesMutex);
        }
        prev = gray.clone();
        SDL_Delay(30);
    }
    return NULL;
}

/* ---------- Main ---------- */
int main(int argc, char *argv[]) {
    (void)argc; (void)argv;

    /* Init MIDI */
    try {
        midiout = new RtMidiOut();
        if (midiout->getPortCount() == 0) {
            fprintf(stderr, "No MIDI ports available.\n");
            delete midiout;
            midiout = NULL;
        } else {
            midiout->openPort(0);
        }
    } catch (RtMidiError &error) {
        error.printMessage();
        return 1;
    }

    /* Init PortAudio */
    Pa_Initialize();
    PaStream *stream;
    Pa_OpenDefaultStream(&stream, 0, 2, paFloat32, 44100,
                         256, audioCallback, NULL);
    Pa_StartStream(stream);

    /* Init SDL */
    SDL_Init(SDL_INIT_VIDEO);
    SDL_Window *win = SDL_CreateWindow("Fractal Soundscape",
                       SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                       800, 600, 0);
    SDL_Renderer *rend = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);

    /* Start vision thread */
    pthread_t vidThread;
    pthread_create(&vidThread, NULL, visionThread, NULL);

    /* Main loop: draw fractal driven by music harmonic content */
    Uint32 start = SDL_GetTicks();
    bool running = true;
    while (running) {
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) running = false;
        }
        double t = (SDL_GetTicks() - start) / 1000.0;
        drawFractal(rend, 800, 600, t);
        SDL_Delay(16);
    }

    /* Cleanup */
    Pa_StopStream(stream);
    Pa_CloseStream(stream);
    Pa_Terminate();

    if (midiout) {
        // send all notes off
        for (int i=0;i<128;i++) sendMidiNoteOff(0,i,0);
        delete midiout;
    }

    SDL_DestroyRenderer(rend);
    SDL_DestroyWindow(win);
    SDL_Quit();

    pthread_cancel(vidThread);
    pthread_join(vidThread, NULL);
    return 0;
}