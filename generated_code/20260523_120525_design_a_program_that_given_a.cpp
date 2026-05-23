#include <opencv2/opencv.hpp>
#include <opencv2/objdetect.hpp>
#include <SDL2/SDL.h>
#include <vector>
#include <atomic>
#include <thread>
#include <mutex>
#include <cmath>

// ---------------------------------------------------------------------------
// Simple 2‑D cellular automaton (binary) with rule parameter that changes
// according to "emotion intensity" extracted from eye region.
// ---------------------------------------------------------------------------
class Automaton {
public:
    Automaton(int w, int h) : width(w), height(h) {
        cur.assign(h, std::vector<uint8_t>(w, 0));
        nxt = cur;
        // random seed
        cv::randu(cv::Mat(cur), 0, 2);
    }
    // update step, ruleParam in [0,1]
    void step(float ruleParam) {
        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width; ++x) {
                int nb = countNeighbors(x, y);
                // rule: survive if nb in [2,3] (like Life) but bias by ruleParam
                float prob = (nb == 2 || nb == 3) ? 0.5f + 0.5f*ruleParam
                                                  : 0.5f - 0.5f*ruleParam;
                nxt[y][x] = (std::rand() / (float)RAND_MAX) < prob ? cur[y][x] : 1 - cur[y][x];
            }
        }
        cur.swap(nxt);
    }
    // render to a BGR image using a palette that also depends on ruleParam
    cv::Mat render(float ruleParam) const {
        cv::Mat img(height, width, CV_8UC3);
        cv::Vec3b aliveColor( int(255*ruleParam), 0, int(255*(1-ruleParam)) );
        cv::Vec3b deadColor(0, int(255*(1-ruleParam)), int(255*ruleParam));
        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width; ++x) {
                img.at<cv::Vec3b>(y,x) = cur[y][x] ? aliveColor : deadColor;
            }
        }
        cv::resize(img, img, cv::Size(width*4, height*4), 0, 0, cv::INTER_NEAREST);
        return img;
    }
private:
    int countNeighbors(int x, int y) const {
        int cnt = 0;
        for (int dy=-1; dy<=1; ++dy)
            for (int dx=-1; dx<=1; ++dx)
                if (dx||dy) {
                    int nx=(x+dx+width)%width;
                    int ny=(y+dy+height)%height;
                    cnt += cur[ny][nx];
                }
        return cnt;
    }
    int width, height;
    std::vector<std::vector<uint8_t>> cur, nxt;
};

// ---------------------------------------------------------------------------
// Audio synthesis: simple sine wave whose frequency follows the emotion level.
// ---------------------------------------------------------------------------
struct AudioState {
    std::atomic<float> freq{440.0f};
    std::atomic<float> phase{0.0f};
    float sampleRate = 48000.0f;
};

void audioCallback(void* userdata, Uint8* stream, int len) {
    AudioState* as = static_cast<AudioState*>(userdata);
    float* out = reinterpret_cast<float*>(stream);
    int samples = len / sizeof(float);
    float phase = as->phase.load();
    float freq = as->freq.load();
    for (int i=0;i<samples;i++) {
        out[i] = 0.2f * std::sin(phase);
        phase += 2.0f * M_PI * freq / as->sampleRate;
        if (phase > 2.0f*M_PI) phase -= 2.0f*M_PI;
    }
    as->phase.store(phase);
}

// ---------------------------------------------------------------------------
// Emotion extraction: very rough – use average intensity change in eye ROI.
// ---------------------------------------------------------------------------
float extractEmotion(const cv::Mat& gray, const std::vector<cv::Rect>& eyes) {
    if (eyes.empty()) return 0.0f;
    double sum = 0.0;
    for (const auto& e : eyes) {
        cv::Mat eye = gray(e);
        cv::Scalar m = cv::mean(eye);
        sum += m[0] / 255.0;
    }
    return std::clamp(static_cast<float>(sum / eyes.size()), 0.0f, 1.0f);
}

// ---------------------------------------------------------------------------
// Main program
// ---------------------------------------------------------------------------
int main() {
    // Init video capture
    cv::VideoCapture cap(0);
    if (!cap.isOpened()) return -1;
    cv::CascadeClassifier faceCascade, eyeCascade;
    faceCascade.load(cv::samples::findFile("haarcascade_frontalface_default.xml"));
    eyeCascade.load(cv::samples::findFile("haarcascade_eye.xml"));

    // Init automaton
    const int caW = 64, caH = 48;
    Automaton ca(caW, caH);

    // Init audio
    SDL_Init(SDL_INIT_AUDIO);
    AudioState audioState;
    SDL_AudioSpec want{}, have{};
    want.freq = 48000;
    want.format = AUDIO_F32;
    want.channels = 1;
    want.samples = 1024;
    want.callback = audioCallback;
    want.userdata = &audioState;
    SDL_OpenAudio(&want, &have);
    SDL_PauseAudio(0);

    cv::Mat prevGray;
    while (true) {
        cv::Mat frame, gray;
        cap >> frame;
        if (frame.empty()) break;
        cv::cvtColor(frame, gray, cv::COLOR_BGR2GRAY);
        std::vector<cv::Rect> faces;
        faceCascade.detectMultiScale(gray, faces);
        std::vector<cv::Rect> eyes;
        for (const auto& f : faces) {
            cv::Mat faceROI = gray(f);
            eyeCascade.detectMultiScale(faceROI, eyes);
            for (auto& e : eyes) e = cv::Rect(e.x + f.x, e.y + f.y, e.width, e.height);
        }

        // Emotion level
        float emo = extractEmotion(gray, eyes);
        // drive CA and audio
        ca.step(emo);
        audioState.freq.store(220.0f + emo * 660.0f); // 220‑880 Hz range

        // Visual output
        cv::Mat caImg = ca.render(emo);
        cv::imshow("Cellular Portrait", caImg);
        cv::imshow("Webcam", frame);
        if (cv::waitKey(1) == 27) break; // ESC to quit
    }

    SDL_CloseAudio();
    SDL_Quit();
    return 0;
}