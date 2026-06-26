#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <opencv2/opencv.hpp>
#include <SDL2/SDL.h>
#include <portaudio.h>

#define WIDTH  640
#define HEIGHT 480
#define PALETTE_SIZE 5
#define SAMPLE_RATE 44100
#define FRAMES_PER_BUFFER 512
#define MAX_AMPLITUDE 0.2

// Simple note frequencies (C major scale, one octave)
static const double note_freq[8] = {261.63,293.66,329.63,349.23,392.00,440.00,493.88,523.25};

typedef struct {
    double phase;
    double freq;
    double amp;
} Oscillator;

typedef struct {
    Oscillator osc[4];
    int active;
} Chord;

// Global chord to be played
static Chord currentChord;

// Audio callback
static int audioCallback(const void *inputBuffer, void *outputBuffer,
                         unsigned long framesPerBuffer,
                         const PaStreamCallbackTimeInfo* timeInfo,
                         PaStreamCallbackFlags statusFlags,
                         void *userData) {
    float *out = (float*)outputBuffer;
    (void) inputBuffer; (void)timeInfo; (void)statusFlags; (void)userData;
    for (unsigned long i=0;i<framesPerBuffer;i++) {
        double sample = 0.0;
        for (int k=0;k<4;k++) {
            Oscillator *o = &currentChord.osc[k];
            sample += o->amp * sin(2.0*M_PI*o->phase);
            o->phase += o->freq / SAMPLE_RATE;
            if (o->phase >= 1.0) o->phase -= 1.0;
        }
        sample *= MAX_AMPLITUDE;
        *out++ = (float)sample; // left
        *out++ = (float)sample; // right
    }
    return paContinue;
}

// Map a color (BGR) to a note index using hue
static int colorToNote(const cv::Vec3b &color) {
    cv::Mat rgb(1,1,CV_8UC3);
    rgb.at<cv::Vec3b>(0,0) = color;
    cv::Mat hsv;
    cv::cvtColor(rgb,hsv,cv::COLOR_BGR2HSV);
    int hue = hsv.at<cv::Vec3b>(0,0)[0]; // 0-179
    return (hue * 8) / 180; // 0-7
}

// Build a chord from palette colors
static void buildChord(const std::vector<cv::Vec3b> &palette) {
    currentChord.active = 0;
    for (size_t i=0;i<palette.size() && i<4;i++) {
        int note = colorToNote(palette[i]);
        currentChord.osc[i].freq = note_freq[note];
        currentChord.osc[i].amp = 0.25 / (i+1);
        currentChord.osc[i].phase = 0.0;
        currentChord.active++;
    }
}

// Compute visual entropy as standard deviation of luminance
static double computeEntropy(const cv::Mat &frame) {
    cv::Mat gray;
    cv::cvtColor(frame,gray,cv::COLOR_BGR2GRAY);
    cv::Scalar mean, stddev;
    cv::meanStdDev(gray,mean,stddev);
    return stddev[0];
}

// Recursive fractal tile drawing
static void drawTile(SDL_Renderer *ren, int x, int y, int size, double hueShift, double entropy) {
    if (size < 8) return;
    // Color based on hueShift
    Uint8 h = (Uint8)((int)hueShift % 256);
    SDL_SetRenderDrawColor(ren, h, 255-h, (Uint8)(entropy*2), 255);
    SDL_Rect r = {x, y, size, size};
    SDL_RenderFillRect(ren, &r);
    // Subdivide
    int newSize = size/2;
    double newShift = hueShift + entropy*5;
    drawTile(ren, x, y, newSize, newShift, entropy);
    drawTile(ren, x+newSize, y, newSize, newShift+30, entropy);
    drawTile(ren, x, y+newSize, newSize, newShift+60, entropy);
    drawTile(ren, x+newSize, y+newSize, newSize, newShift+90, entropy);
}

int main() {
    // Initialise OpenCV capture
    cv::VideoCapture cap(0);
    if(!cap.isOpened()){
        fprintf(stderr,"Cannot open webcam\n");
        return -1;
    }
    cap.set(cv::CAP_PROP_FRAME_WIDTH, WIDTH);
    cap.set(cv::CAP_PROP_FRAME_HEIGHT, HEIGHT);

    // Initialise SDL
    if(SDL_Init(SDL_INIT_VIDEO|SDL_INIT_AUDIO)!=0){
        fprintf(stderr,"SDL Init error: %s\n",SDL_GetError());
        return -1;
    }
    SDL_Window *win = SDL_CreateWindow("Synesthetic Fractal",SDL_WINDOWPOS_CENTERED,SDL_WINDOWPOS_CENTERED,WIDTH,HEIGHT,0);
    SDL_Renderer *ren = SDL_CreateRenderer(win,-1,SDL_RENDERER_ACCELERATED);
    if(!win||!ren){
        fprintf(stderr,"SDL Create error: %s\n",SDL_GetError());
        return -1;
    }

    // Initialise PortAudio
    Pa_Initialize();
    PaStream *stream;
    Pa_OpenDefaultStream(&stream,0,2,paFloat32,SAMPLE_RATE,FRAMES_PER_BUFFER,audioCallback,NULL);
    Pa_StartStream(stream);

    cv::Mat frame;
    std::vector<cv::Vec3b> palette(PALETTE_SIZE);
    bool running = true;
    Uint32 lastTick = SDL_GetTicks();

    while(running){
        // Event handling
        SDL_Event e;
        while(SDL_PollEvent(&e)){
            if(e.type==SDL_QUIT) running = false;
        }

        // Capture frame
        cap>>frame;
        if(frame.empty()) continue;

        // K-means to find dominant colors
        cv::Mat samples(frame.rows*frame.cols,3,CV_32F);
        for(int y=0;y<frame.rows;y++)
            for(int x=0;x<frame.cols;x++)
                for(int z=0;z<3;z++)
                    samples.at<float>(y*frame.cols+x,z)=frame.at<cv::Vec3b>(y,x)[z];
        cv::Mat labels;
        cv::Mat centers;
        cv::kmeans(samples,PALETTE_SIZE,labels,
                   cv::TermCriteria(cv::TermCriteria::MAX_ITER+cv::TermCriteria::EPS,10,1.0),
                   3,cv::KMEANS_PP_CENTERS,centers);
        for(int i=0;i<PALETTE_SIZE;i++){
            cv::Vec3b col;
            for(int z=0;z<3;z++) col[z]=(uchar)centers.at<float>(i,z);
            palette[i]=col;
        }

        // Build chord from palette
        buildChord(palette);

        // Compute entropy
        double entropy = computeEntropy(frame);

        // Render fractal mosaic
        SDL_SetRenderDrawColor(ren,0,0,0,255);
        SDL_RenderClear(ren);
        drawTile(ren,0,0,WIDTH,entropy*10,entropy);
        SDL_RenderPresent(ren);

        // Simple frame rate limit
        Uint32 now = SDL_GetTicks();
        if(now-lastTick<30) SDL_Delay(30-(now-lastTick));
        lastTick = now;
    }

    // Cleanup
    Pa_StopStream(stream);
    Pa_CloseStream(stream);
    Pa_Terminate();
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    cap.release();
    return 0;
}