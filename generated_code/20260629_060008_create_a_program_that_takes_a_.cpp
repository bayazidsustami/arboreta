#include <opencv2/opencv.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/highgui.hpp>
#include <vector>
#include <array>
#include <thread>
#include <atomic>
#include <mutex>
#include <condition_variable>
#include <cmath>
#include <chrono>
#include <random>
#include "RtAudio.h"                     // RtAudio must be available

// ---------- Audio synthesis ----------
struct Synth {
    RtAudio dac;
    unsigned int sampleRate = 48000;
    std::atomic<bool> running{true};
    std::mutex mtx;
    std::condition_variable cv;
    std::vector<std::array<float,2>> notes;   // {frequency, amplitude}
    static int callback(void *outputBuffer, void * /*inputBuffer*/, unsigned int nBufferFrames,
                        double /*streamTime*/, RtAudioStreamStatus status, void *userData) {
        if (status) std::cerr<<"Stream underflow!\n";
        float *out = static_cast<float*>(outputBuffer);
        auto *self = static_cast<Synth*>(userData);
        std::lock_guard<std::mutex> lock(self->mtx);
        for (unsigned int i=0;i<nBufferFrames;i++) {
            float sample = 0.f;
            for (auto &note : self->notes) {
                static double phase = 0.0;
                double freq = note[0];
                double amp  = note[1];
                sample += amp * std::sin(2*M_PI*freq*phase/self->sampleRate);
                phase += 1.0;
                if (phase>=self->sampleRate) phase-=self->sampleRate;
            }
            out[2*i] = out[2*i+1] = sample * 0.1f; // stereo
        }
        return 0;
    }
    void start() {
        RtAudio::StreamParameters sp;
        sp.deviceId = dac.getDefaultOutputDevice();
        sp.nChannels = 2;
        dac.openStream(&sp, nullptr, RTAUDIO_FLOAT32, sampleRate, nullptr, &Synth::callback, this);
        dac.startStream();
    }
    void stop() {
        running = false;
        dac.stopStream();
        dac.closeStream();
    }
    void setNotes(const std::vector<std::array<float,2>>& n) {
        std::lock_guard<std::mutex> lock(mtx);
        notes = n;
    }
};

// ---------- Helper ----------
float hue2freq(float h) {                     // map hue [0,180] to audible range 200-1200Hz
    return 200.f + (h/180.f)*1000.f;
}
float sat2amp(float s) {                     // saturation [0,255] to amplitude [0,0.5]
    return (s/255.f)*0.5f;
}
int val2waveform(float v) {                  // brightness selects simple waveform (ignored, we use sine)
    return 0;
}

// ---------- Main ----------
int main() {
    cv::VideoCapture cap(0);
    if(!cap.isOpened()) return -1;
    cap.set(cv::CAP_PROP_FRAME_WIDTH, 320);
    cap.set(cv::CAP_PROP_FRAME_HEIGHT,240);

    Synth synth;
    synth.start();

    std::vector<std::array<float,2>> curNotes;
    std::atomic<bool> quit{false};

    std::thread audioThread([&](){
        while(synth.running) {
            synth.setNotes(curNotes);
            std::this_thread::sleep_for(std::chrono::milliseconds(30));
        }
    });

    cv::Mat frame, hsv, mosaic;
    std::mt19937 rng(std::random_device{}());

    while(!quit) {
        if(!cap.read(frame)) break;
        cv::cvtColor(frame, hsv, cv::COLOR_BGR2HSV);

        // k‑means to find 4 dominant colours
        cv::Mat samples = hsv.reshape(1, hsv.total());
        samples.convertTo(samples, CV_32F);
        cv::Mat labels, centers;
        cv::kmeans(samples, 4, labels,
                   cv::TermCriteria(cv::TermCriteria::EPS+cv::TermCriteria::MAX_ITER,10,1.0),
                   3, cv::KMEANS_PP_CENTERS, centers);
        centers = centers.reshape(3, centers.rows); // back to HSV

        // Build notes from palette
        curNotes.clear();
        for(int i=0;i<centers.rows;i++) {
            float h = centers.at<float>(i,0);
            float s = centers.at<float>(i,1);
            float v = centers.at<float>(i,2);
            float freq = hue2freq(h);
            float amp  = sat2amp(s);
            curNotes.push_back({freq,amp});
        }

        // Create kaleidoscopic mosaic
        mosaic = cv::Mat::zeros(frame.size(), frame.type());
        int tiles = 6;
        for(int t=0;t<tiles;t++) {
            double angle = (2*M_PI/tiles)*t;
            cv::Mat rot;
            cv::Point2f ctr(frame.cols/2.f, frame.rows/2.f);
            cv::Mat R = cv::getRotationMatrix2D(ctr, angle*180/M_PI, 1.0);
            cv::warpAffine(frame, rot, R, frame.size(),
                           cv::INTER_LINEAR, cv::BORDER_REPLICATE);
            cv::Mat mask = cv::Mat::zeros(frame.size(), CV_8U);
            cv::ellipse(mask, ctr, cv::Size(frame.cols/2, frame.rows/2),
                        angle*180/M_PI, 0, 360/tiles, cv::Scalar(255), -1);
            rot.copyTo(mosaic, mask);
        }

        // blend original for feedback
        cv::addWeighted(mosaic, 0.6, frame, 0.4, 0, mosaic);
        cv::imshow("Kaleido‑Music", mosaic);
        if(cv::waitKey(1)==27) quit=true;
    }

    synth.stop();
    audioThread.join();
    return 0;
}