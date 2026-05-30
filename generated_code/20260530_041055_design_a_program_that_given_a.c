#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <math.h>
#include <pthread.h>
#include <unistd.h>
#include <opencv2/opencv.hpp>
#include <fftw3.h>

// Simple placeholder for a "neural net" – just a random weight matrix.
#define GEN_SIZE   64
#define DISC_SIZE  64
static float G[GEN_SIZE][GEN_SIZE];
static float D[DISC_SIZE][DISC_SIZE];

// Shared canvas where paint strokes are accumulated.
static cv::Mat canvas;

// Mutex for thread‑safe access to the canvas and GAN weights.
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

// -------------------------------------------------------------------
// Utility: map a pixel (hue, sat, val) to a MIDI note (0‑127)
// -------------------------------------------------------------------
static int hue_to_midi(float h) {
    return (int)(h / 360.0f * 127.0f);
}

// -------------------------------------------------------------------
// Simple "audio" placeholder – prints note information to stdout.
// In a real system you would feed this to a synthesiser library.
// -------------------------------------------------------------------
static void play_note(int midi, float velocity) {
    printf("NOTE ON  %3d  vel=%.2f\n", midi, velocity);
}

// -------------------------------------------------------------------
// Generate a brushstroke based on motion vector (dx,dy) and colour.
// The stroke is a short line drawn onto the canvas.
// -------------------------------------------------------------------
static void draw_brushstroke(cv::Mat *img, int x, int y, float dx, float dy,
                             const cv::Scalar &col) {
    int x2 = (int)round(x + dx * 5);
    int y2 = (int)round(y + dy * 5);
    cv::line(*img, cv::Point(x, y), cv::Point(x2, y2), col, 2, cv::LINE_AA);
}

// -------------------------------------------------------------------
// Very tiny GAN‑like training step.
// G and D are mere matrices; we perform a single gradient‑like update.
// -------------------------------------------------------------------
static void train_gan_step() {
    pthread_mutex_lock(&lock);
    for (int i = 0; i < GEN_SIZE; ++i) {
        for (int j = 0; j < GEN_SIZE; ++j) {
            // fake loss: push G towards random noise, D towards opposing sign
            float noise = ((float)rand() / RAND_MAX) * 0.02f - 0.01f;
            G[i][j] += noise - 0.001f * D[i % DISC_SIZE][j % DISC_SIZE];
            D[i][j] += -noise - 0.001f * G[i % GEN_SIZE][j % GEN_SIZE];
        }
    }
    pthread_mutex_unlock(&lock);
}

// -------------------------------------------------------------------
// Thread that continuously trains the GAN on the current canvas.
// -------------------------------------------------------------------
static void *trainer_thread(void *arg) {
    (void)arg;
    while (true) {
        train_gan_step();
        usleep(20000); // 50 Hz training rate
    }
    return NULL;
}

// -------------------------------------------------------------------
// Main loop: capture webcam, interpret colour/motion, play notes, paint.
// -------------------------------------------------------------------
int main() {
    // Initialise random seed and GAN weights.
    srand((unsigned)time(NULL));
    for (int i = 0; i < GEN_SIZE; ++i)
        for (int j = 0; j < GEN_SIZE; ++j)
            G[i][j] = ((float)rand() / RAND_MAX) * 0.1f - 0.05f;
    for (int i = 0; i < DISC_SIZE; ++i)
        for (int j = 0; j < DISC_SIZE; ++j)
            D[i][j] = ((float)rand() / RAND_MAX) * 0.1f - 0.05f;

    // Start training thread.
    pthread_t tid;
    pthread_create(&tid, NULL, trainer_thread, NULL);

    // Open default camera.
    cv::VideoCapture cap(0);
    if (!cap.isOpened()) {
        fprintf(stderr, "Cannot open webcam\n");
        return 1;
    }

    // Prepare canvas (same size as video frames).
    cv::Mat frame, prev;
    cap >> frame;
    if (frame.empty()) return 1;
    canvas = cv::Mat::zeros(frame.size(), frame.type());

    // Main processing loop.
    while (true) {
        cap >> frame;
        if (frame.empty()) break;

        // Convert to HSV for colour‑to‑note mapping.
        cv::Mat hsv;
        cv::cvtColor(frame, hsv, cv::COLOR_BGR2HSV);

        // Compute optical flow between previous and current frames.
        cv::Mat flow;
        if (!prev.empty()) {
            cv::calcOpticalFlowFarneback(prev, frame, flow,
                                         0.5, 3, 15, 3, 5, 1.2, 0);
        }
        prev = frame.clone();

        // Iterate over a subsampled grid for performance.
        for (int y = 0; y < frame.rows; y += 16) {
            for (int x = 0; x < frame.cols; x += 16) {
                cv::Vec3b hsvpix = hsv.at<cv::Vec3b>(y, x);
                float hue = hsvpix[0] * 2.0f;          // OpenCV hue: 0‑180
                float sat = hsvpix[1] / 255.0f;
                float val = hsvpix[2] / 255.0f;

                // Map hue to MIDI, velocity to brightness.
                int midi = hue_to_midi(hue);
                float vel = val;

                play_note(midi, vel);

                // Motion vector (dx,dy) from optical flow.
                cv::Point2f vec(0,0);
                if (!flow.empty()) {
                    const cv::Point2f &f = flow.at<cv::Point2f>(y, x);
                    vec = f;
                }

                // Draw a brushstroke whose colour matches the pixel.
                cv::Scalar col(frame.at<cv::Vec3b>(y, x)[0],
                               frame.at<cv::Vec3b>(y, x)[1],
                               frame.at<cv::Vec3b>(y, x)[2]);
                pthread_mutex_lock(&lock);
                draw_brushstroke(&canvas, x, y, vec.x, vec.y, col);
                pthread_mutex_unlock(&lock);
            }
        }

        // Blend canvas with live video for visual feedback.
        cv::Mat display;
        pthread_mutex_lock(&lock);
        cv::addWeighted(frame, 0.6, canvas, 0.4, 0, display);
        pthread_mutex_unlock(&lock);

        cv::imshow("Symphonic Painting", display);
        if (cv::waitKey(1) == 27) break; // ESC to quit
    }

    // Cleanup.
    pthread_cancel(tid);
    pthread_join(tid, NULL);
    return 0;
}