#include <opencv2/opencv.hpp>
#include <iostream>
#include <vector>
#include <cmath>
#include <thread>
#include <atomic>
#include <mutex>

// RtAudio for real‑time audio output (single‑header version can be embedded if needed)
#include "RtAudio.h"

// ------------------------------------------------------------
// Helper: map hue (0‑360) to a note index in the circle of fifths
// ------------------------------------------------------------
int hueToNote(double hue) {
    // Circle of fifths order starting from C (index 0)
    static const int circle[12] = {0,7,2,9,4,11,6,1,8,3,10,5}; // semitone offsets
    int sector = static_cast<int>(hue / 30.0) % 12;          // 12 hue sectors
    return circle[sector];
}

// ------------------------------------------------------------
// Audio synthesis: simple polyphonic sine‑wave generator
// ------------------------------------------------------------
struct Synth {
    RtAudio dac;
    unsigned int sampleRate = 48000;
    std::vector<double> phases;          // one phase per active note
    std::vector<double> freqs;           // frequencies of active notes
    std::mutex mtx;
    std::atomic<bool> running{true};

    static int rtCallback(void *outputBuffer, void *, unsigned int nBufferFrames,
                          double, RtAudioStreamStatus, void *userData) {
        Synth *self = static_cast<Synth*>(userData);
        float *buf = static_cast<float*>(outputBuffer);
        std::lock_guard<std::mutex> lock(self->mtx);
        for (unsigned int i = 0; i < nBufferFrames; ++i) {
            double sample = 0.0;
            for (size_t k = 0; k < self->freqs.size(); ++k) {
                sample += sin(self->phases[k]) * 0.2; // simple amplitude scaling
                self->phases[k] += 2.0 * M_PI * self->freqs[k] / self->sampleRate;
                if (self->phases[k] > 2.0 * M_PI) self->phases[k] -= 2.0 * M_PI;
            }
            buf[2*i] = buf[2*i+1] = static_cast<float>(sample); // stereo
        }
        return 0;
    }

    void start() {
        RtAudio::StreamParameters oParams;
        oParams.deviceId = dac.getDefaultOutputDevice();
        oParams.nChannels = 2;
        unsigned int bufferFrames = 256;
        dac.openStream(&oParams, nullptr, RTAUDIO_FLOAT32, sampleRate,
                       &bufferFrames, &Synth::rtCallback, this);
        dac.startStream();
    }

    void stop() {
        if (dac.isStreamOpen()) {
            dac.stopStream();
            dac.closeStream();
        }
    }

    // Replace current notes with new set derived from frame hues
    void setNotes(const std::vector<int>& midiNotes) {
        std::lock_guard<std::mutex> lock(mtx);
        freqs.clear(); phases.clear();
        for (int n : midiNotes) {
            double f = 440.0 * pow(2.0, (n - 69) / 12.0);
            freqs.push_back(f);
            phases.push_back(0.0);
        }
    }
};

// ------------------------------------------------------------
// Fractal renderer: simple Mandelbrot zoom driven by audio amplitude
// ------------------------------------------------------------
class Fractal {
public:
    cv::Mat img;
    double zoom = 1.0;
    double offsetX = -0.5, offsetY = 0.0;

    Fractal(int w, int h) { img = cv::Mat::zeros(h, w, CV_8UC3); }

    void draw(double amp) {
        zoom = 0.5 + 0.5 * amp; // zoom reacts to amplitude
        const int maxIter = 100;
        int h = img.rows, w = img.cols;
        for (int y = 0; y < h; ++y) {
            for (int x = 0; x < w; ++x) {
                double cx = (x - w/2.0) * (4.0/(w*zoom)) + offsetX;
                double cy = (y - h/2.0) * (4.0/(h*zoom)) + offsetY;
                double zx = 0, zy = 0;
                int iter = 0;
                while (zx*zx + zy*zy < 4.0 && iter < maxIter) {
                    double tmp = zx*zx - zy*zy + cx;
                    zy = 2*zx*zy + cy;
                    zx = tmp;
                    ++iter;
                }
                int col = static_cast<int>(255.0 * iter / maxIter);
                img.at<cv::Vec3b>(y,x) = cv::Vec3b(col, col/2, 255-col);
            }
        }
    }
};

// ------------------------------------------------------------
// Main loop: capture webcam, extract hues, drive synth & fractal,
// overlay fractal onto video and display.
// ------------------------------------------------------------
int main() {
    cv::VideoCapture cap(0);
    if (!cap.isOpened()) {
        std::cerr << "Cannot open webcam\n";
        return -1;
    }

    int w = static_cast<int>(cap.get(cv::CAP_PROP_FRAME_WIDTH));
    int h = static_cast<int>(cap.get(cv::CAP_PROP_FRAME_HEIGHT));

    Synth synth;
    synth.start();

    Fractal fract(w, h);
    std::vector<int> midiNotes;

    while (true) {
        cv::Mat frame;
        if (!cap.read(frame)) break;

        // Convert to HSV and collect dominant hue per pixel block
        cv::Mat hsv;
        cv::cvtColor(frame, hsv, cv::COLOR_BGR2HSV);
        std::vector<int> notes;
        notes.reserve(w*h/64);
        for (int y = 0; y < h; y += 8) {
            for (int x = 0; x < w; x += 8) {
                cv::Vec3b pixel = hsv.at<cv::Vec3b>(y,x);
                double hue = pixel[0] * 2.0; // OpenCV hue 0‑179 → 0‑358
                notes.push_back(60 + hueToNote(hue)); // base MIDI C4 = 60
            }
        }
        synth.setNotes(notes);

        // Estimate audio amplitude from number of active notes (proxy)
        double amplitude = std::min(1.0, notes.size() / 1000.0);
        fract.draw(amplitude);

        // Blend fractal onto current video frame
        cv::Mat resizedFract;
        cv::resize(fract.img, resizedFract, frame.size());
        cv::addWeighted(frame, 0.7, resizedFract, 0.3, 0, frame);

        cv::imshow("Audio‑Visual Loop", frame);
        if (cv::waitKey(1) == 27) break; // ESC to quit
    }

    synth.stop();
    return 0;
}