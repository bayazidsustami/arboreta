#include <iostream>
#include <vector>
#include <thread>
#include <atomic>
#include <mutex>
#include <complex>
#include <cmath>
#include <condition_variable>

// OpenCV for video/canvas and webcam
#include <opencv2/opencv.hpp>

// RtAudio for audio capture
#include "RtAudio.h"

// FFTW for spectral analysis
#include <fftw3.h>

using namespace std;
using namespace cv;

// ------------ Global shared data -----------------
const int SAMPLE_RATE = 44100;
const int FFT_SIZE = 1024;
const int NUM_BANDS = FFT_SIZE/2;
const int CELL_ROWS = 64;
const int CELL_COLS = 64;
atomic<bool> running(true);
vector<float> audioBuffer(FFT_SIZE);
mutex audioMtx;
condition_variable audioCv;

// cellular automaton state per band
struct Automaton {
    vector<uint8_t> cells;          // 0 or 1
    int rule;                       // 0-255
    Automaton() : cells(CELL_ROWS*CELL_COLS,0), rule(30) {}
};
vector<Automaton> autos(NUM_BANDS);

// ------------ Audio callback -----------------
int audioCallback(void *outputBuffer, void *inputBuffer, unsigned int nBufferFrames,
                  double /*streamTime*/, RtAudioStreamStatus status, void * /*userData*/)
{
    if (status) cerr << "Audio overflow!" << endl;
    const float *in = static_cast<const float*>(inputBuffer);
    unique_lock<mutex> lk(audioMtx);
    for (unsigned int i=0;i<nBufferFrames && i<FFT_SIZE;i++) audioBuffer[i]=in[i];
    lk.unlock();
    audioCv.notify_one();
    return 0;
}

// ------------ Simple 1‑D CA step (wrap) ---------------
void caStep(Automaton &a)
{
    vector<uint8_t> next(a.cells.size());
    for (int y=0; y<CELL_ROWS; ++y) {
        for (int x=0; x<CELL_COLS; ++x) {
            int idx = y*CELL_COLS + x;
            // neighbourhood: left, self, right (wrap horizontally)
            int left  = a.cells[y*CELL_COLS + (x-1+CELL_COLS)%CELL_COLS];
            int self  = a.cells[idx];
            int right = a.cells[y*CELL_COLS + (x+1)%CELL_COLS];
            int pattern = (left<<2)|(self<<1)|right;
            next[idx] = (a.rule >> pattern) & 1;
        }
    }
    a.cells.swap(next);
}

// ------------ Main ------------------------------------
int main()
{
    // ---- Init audio ----
    RtAudio adc;
    if (adc.getDeviceCount() < 1) { cerr<<"No audio devices!\n"; return 1; }
    RtAudio::StreamParameters iParams;
    iParams.deviceId = adc.getDefaultInputDevice();
    iParams.nChannels = 1;
    unsigned int bufferFrames = FFT_SIZE;
    adc.openStream(nullptr,&iParams, RTAUDIO_FLOAT32, SAMPLE_RATE,
                   &bufferFrames, &audioCallback, nullptr);
    adc.startStream();

    // ---- Init webcam ----
    VideoCapture cam(0);
    if (!cam.isOpened()) { cerr<<"Cannot open webcam\n"; return 1; }

    // ---- Prepare FFT ----
    vector<double> fftIn(FFT_SIZE);
    vector<fftw_complex> fftOut(FFT_SIZE/2+1);
    fftw_plan plan = fftw_plan_dft_r2c_1d(FFT_SIZE, fftIn.data(),
                                          fftOut.data(), FFTW_MEASURE);

    // ---- Visualization canvas ----
    const int CELL_SIZE = 4;
    Mat canvas(CELL_ROWS*CELL_SIZE, NUM_BANDS*CELL_COLS*CELL_SIZE, CV_8UC3, Scalar::all(0));

    // ---- Main loop ----
    while (running) {
        // 1) Grab webcam frame (used for user motion)
        Mat frame;
        cam>>frame;
        if (frame.empty()) break;
        // simple motion magnitude (average intensity)
        Mat gray;
        cvtColor(frame, gray, COLOR_BGR2GRAY);
        double motion = mean(gray)[0]/255.0;

        // 2) Wait for new audio data
        {
            unique_lock<mutex> lk(audioMtx);
            audioCv.wait(lk);
            for (int i=0;i<FFT_SIZE;i++) fftIn[i]=audioBuffer[i];
        }

        // 3) Compute magnitude spectrum
        fftw_execute(plan);
        vector<double> mags(NUM_BANDS);
        for (int i=0;i<NUM_BANDS;i++) {
            double re = fftOut[i][0];
            double im = fftOut[i][1];
            mags[i] = sqrt(re*re+im*im);
        }

        // 4) Map each band to a CA rule (e.g., proportional to magnitude)
        for (int b=0;b<NUM_BANDS;b++) {
            int rule = static_cast<int>( (mags[b]/(FFT_SIZE)) * 255.0 );
            autos[b].rule = rule & 0xFF;
        }

        // 5) Step all automata
        for (auto &a: autos) caStep(a);

        // 6) Render collage
        canvas.setTo(Scalar::all(0));
        for (int b=0;b<NUM_BANDS;b++) {
            const Automaton &a = autos[b];
            for (int y=0;y<CELL_ROWS;y++) {
                for (int x=0;x<CELL_COLS;x++) {
                    uint8_t v = a.cells[y*CELL_COLS+x];
                    // colour encode rule intensity and user motion
                    Vec3b col( (v?255:0),
                               (autos[b].rule),
                               static_cast<uchar>(motion*255) );
                    Rect r(b*CELL_COLS*CELL_SIZE + x*CELL_SIZE,
                           y*CELL_SIZE, CELL_SIZE, CELL_SIZE);
                    rectangle(canvas, r, Scalar(col), FILLED);
                }
            }
        }

        imshow("Audio‑CA Collage", canvas);
        if (waitKey(1) == 27) running = false; // ESC to quit
    }

    // ---- Cleanup ----
    adc.stopStream();
    if (adc.isStreamOpen()) adc.closeStream();
    fftw_destroy_plan(plan);
    return 0;
}