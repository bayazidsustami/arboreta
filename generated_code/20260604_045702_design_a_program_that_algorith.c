#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <opencv2/opencv.hpp>
#include "RtMidi.h"

using namespace cv;

/* Simple helper: map value from one range to another */
static inline double map(double v, double a, double b, double c, double d) {
    return c + (v - a) * (d - c) / (b - a);
}

/* Generate a random color palette for Voronoi cells */
static Vec3b random_color() {
    return Vec3b(rand()%256, rand()%256, rand()%256);
}

/* Approximate Voronoi tessellation by assigning each pixel to the nearest seed */
void voronoi(Mat& src, Mat& dst, const std::vector<Point>& seeds, const std::vector<Vec3b>& colors) {
    dst.create(src.size(), src.type());
    for (int y=0; y<dst.rows; ++y) {
        for (int x=0; x<dst.cols; ++x) {
            int best = 0;
            double bestd = 1e9;
            for (size_t i=0;i<seeds.size();++i) {
                double dx = x - seeds[i].x;
                double dy = y - seeds[i].y;
                double d = dx*dx + dy*dy;
                if (d < bestd) { bestd = d; best = i; }
            }
            dst.at<Vec3b>(y,x) = colors[best];
        }
    }
}

/* Main */
int main(int argc, char** argv) {
    /* Initialize webcam */
    VideoCapture cap(0);
    if (!cap.isOpened()) {
        fprintf(stderr, "Cannot open webcam\n");
        return -1;
    }
    cap.set(CAP_PROP_FRAME_WIDTH, 640);
    cap.set(CAP_PROP_FRAME_HEIGHT, 480);

    /* Initialize MIDI out */
    RtMidiOut midi;
    if (midi.getPortCount() == 0) {
        fprintf(stderr, "No MIDI ports available\n");
        return -1;
    }
    midi.openPort(0);

    /* Prepare recursion buffer */
    Mat prevFrame;
    bool first = true;

    /* Seed data for Voronoi */
    const int NSEEDS = 30;
    std::vector<Point> seeds(NSEEDS);
    std::vector<Vec3b> colors(NSEEDS);
    srand((unsigned)time(NULL));
    for (int i=0;i<NSEEDS;++i) {
        seeds[i] = Point(rand()%640, rand()%480);
        colors[i] = random_color();
    }

    /* Main loop */
    while (true) {
        Mat frame;
        cap >> frame;
        if (frame.empty()) break;

        /* Resize for faster processing */
        resize(frame, frame, Size(320,240));

        /* Convert to HSV for easier hue/brightness extraction */
        Mat hsv;
        cvtColor(frame, hsv, COLOR_BGR2HSV);

        /* Analyze a subset of pixels to drive MIDI */
        double avgHue=0, avgVal=0;
        int cnt=0;
        for (int y=0; y<hsv.rows; y+=8) {
            for (int x=0; x<hsv.cols; x+=8) {
                Vec3b pix = hsv.at<Vec3b>(y,x);
                avgHue += pix[0];
                avgVal += pix[2];
                ++cnt;
            }
        }
        avgHue /= cnt;
        avgVal /= cnt;

        /* Map hue to MIDI pitch (0-127) */
        int pitch = (int)map(avgHue, 0, 179, 40, 100);
        /* Map brightness to velocity */
        int vel   = (int)map(avgVal, 0, 255, 30, 127);
        /* Map motion (simple frame diff) to duration */
        static Mat grayPrev;
        Mat gray, diff;
        cvtColor(frame, gray, COLOR_BGR2GRAY);
        if (!grayPrev.empty()) {
            absdiff(gray, grayPrev, diff);
        } else diff = Mat::zeros(gray.size(), gray.type());
        double motion = mean(diff)[0];
        int dur = (int)map(motion, 0, 30, 100, 800); // ms

        /* Send Note On */
        std::vector<unsigned char> msg;
        msg.push_back(0x90);          // Note On, channel 0
        msg.push_back(pitch & 0x7F);
        msg.push_back(vel & 0x7F);
        midi.sendMessage(&msg);
        /* Note Off after duration (simple blocking wait) */
        cv::waitKey(dur);
        msg[0] = 0x80;                // Note Off
        midi.sendMessage(&msg);

        /* Visual feedback: Voronoi tessellation */
        Mat vor;
        voronoi(frame, vor, seeds, colors);

        /* Blend with previous frame for recursion effect */
        if (!first) {
            addWeighted(vor, 0.6, prevFrame, 0.4, 0, vor);
        }
        first = false;
        prevFrame = vor.clone();

        /* Show result */
        imshow("Audio‑Visual Recursion", vor);
        if (waitKey(1) == 27) break; // ESC to quit

        /* Slightly jitter seeds to keep patterns moving */
        for (auto &p: seeds) {
            p.x = (p.x + (rand()%3-1) + vor.cols) % vor.cols;
            p.y = (p.y + (rand()%3-1) + vor.rows) % vor.rows;
        }
    }

    midi.closePort();
    return 0;
}