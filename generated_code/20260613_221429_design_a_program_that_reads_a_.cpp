#include <opencv2/opencv.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/highgui.hpp>
#include <SDL2/SDL.h>
#include <SDL2/SDL_audio.h>
#include <vector>
#include <array>
#include <cmath>
#include <cstdint>
#include <mutex>
#include <thread>
#include <condition_variable>
#include <atomic>
#include <random>

// ------------------------------------------------------------
// Simple 8‑bit chiptune synthesizer (square wave + noise)
// ------------------------------------------------------------
struct Synth {
    static constexpr int SampleRate = 44100;
    static constexpr int BufferSize = 512;

    struct Voice {
        float freq;
        float phase;
        float amp;
        bool   active;
    };

    std::array<Voice, 4> voices{};
    std::mutex mtx;
    std::vector<float> audioBuffer;
    std::condition_variable cv;
    std::atomic<bool> running{true};

    Synth() {
        audioBuffer.reserve(BufferSize * 4);
        std::thread([this] { audioThread(); }).detach();
    }

    // map a hue (0‑360) to a musical note (C‑B in 2 octaves)
    static float hueToFreq(float h) {
        static const float base = 261.63f; // C4
        int note = static_cast<int>(std::round(h / 30.0f)) % 12;
        int octave = (static_cast<int>(h / 360.0f) + 1);
        static const float ratios[12] = {
            1.0f, 1.0595f, 1.1225f, 1.1892f, 1.2599f,
            1.3348f, 1.4142f, 1.4983f, 1.5874f, 1.6818f,
            1.7818f, 1.8877f
        };
        return base * ratios[note] * std::pow(2.0f, octave);
    }

    void noteOn(float hue, float amp = 0.3f) {
        std::lock_guard<std::mutex> lk(mtx);
        for (auto& v : voices) if (!v.active) {
            v.freq = hueToFreq(hue);
            v.phase = 0.0f;
            v.amp = amp;
            v.active = true;
            break;
        }
    }

    void noteOffAll() {
        std::lock_guard<std::mutex> lk(mtx);
        for (auto& v : voices) v.active = false;
    }

    void audioThread() {
        SDL_AudioSpec want{}, have{};
        want.freq = SampleRate;
        want.format = AUDIO_F32SYS;
        want.channels = 1;
        want.samples = BufferSize;
        want.callback = audioCallbackStatic;
        want.userdata = this;
        if (SDL_OpenAudio(&want, &have) < 0) return;
        SDL_PauseAudio(0);
        while (running) {
            std::unique_lock<std::mutex> lk(mtx);
            cv.wait(lk, [&]{ return audioBuffer.size() >= BufferSize; });
            audioBuffer.erase(audioBuffer.begin(), audioBuffer.begin() + BufferSize);
            lk.unlock();
        }
        SDL_CloseAudio();
    }

    static void audioCallbackStatic(void* userdata, Uint8* stream, int len) {
        reinterpret_cast<Synth*>(userdata)->audioCallback(stream, len);
    }

    void audioCallback(Uint8* stream, int len) {
        std::lock_guard<std::mutex> lk(mtx);
        int samples = len / sizeof(float);
        float* out = reinterpret_cast<float*>(stream);
        for (int i = 0; i < samples; ++i) {
            float sample = 0.0f;
            for (auto& v : voices) if (v.active) {
                sample += v.amp * std::sin(2.0f * M_PI * v.phase);
                v.phase += v.freq / SampleRate;
                if (v.phase >= 1.0f) v.phase -= 1.0f;
            }
            out[i] = sample * 0.2f; // master gain
        }
    }
};

// ------------------------------------------------------------
// Cellular automaton visualizer
// ------------------------------------------------------------
class Automaton {
public:
    Automaton(int w, int h) : cols(w), rows(h) {
        cells.resize(rows * cols);
        nextCells.resize(rows * cols);
        std::random_device rd;
        rng.seed(rd());
        std::uniform_int_distribution<int> d(0, 1);
        for (auto& c : cells) c = d(rng);
    }

    void step(const cv::Scalar& audioLevel, const cv::Scalar& colorHist) {
        for (int y = 0; y < rows; ++y) {
            for (int x = 0; x < cols; ++x) {
                int idx = y * cols + x;
                int alive = cells[idx];
                int neighbors = countNeighbors(x, y);
                // simple B3/S23 rule modulated by audio amplitude
                float amp = audioLevel[0];
                if (alive) {
                    nextCells[idx] = (neighbors == 2 || neighbors == 3) ? 1 : 0;
                } else {
                    nextCells[idx] = (neighbors == 3 && amp > 0.1f) ? 1 : 0;
                }
                // colour influence: bias towards cells where recent hue peaks
                float hueBias = colorHist[0] / 180.0f;
                if (std::rand() / (float)RAND_MAX < hueBias) {
                    nextCells[idx] = 1;
                }
            }
        }
        cells.swap(nextCells);
    }

    cv::Mat render(int cellSize = 4) const {
        cv::Mat img(rows * cellSize, cols * cellSize, CV_8UC3, cv::Scalar(0,0,0));
        for (int y = 0; y < rows; ++y) {
            for (int x = 0; x < cols; ++x) {
                if (cells[y*cols + x]) {
                    cv::rectangle(img,
                        cv::Point(x*cellSize, y*cellSize),
                        cv::Point((x+1)*cellSize-1, (y+1)*cellSize-1),
                        cv::Scalar(0,255,0), cv::FILLED);
                }
            }
        }
        return img;
    }

private:
    int cols, rows;
    std::vector<uint8_t> cells, nextCells;
    std::mt19937 rng;

    int countNeighbors(int x, int y) const {
        int cnt = 0;
        for (int dy=-1; dy<=1; ++dy) for (int dx=-1; dx<=1; ++dx) {
            if (dx==0 && dy==0) continue;
            int nx = (x+dx+cols)%cols;
            int ny = (y+dy+rows)%rows;
            cnt += cells[ny*cols+nx];
        }
        return cnt;
    }
};

// ------------------------------------------------------------
// Helper: dominant colour extraction (k‑means with k=3)
// ------------------------------------------------------------
cv::Scalar dominantHue(const cv::Mat& frame) {
    cv::Mat hsv;
    cv::cvtColor(frame, hsv, cv::COLOR_BGR2HSV);
    cv::Mat resh = hsv.reshape(1, hsv.total());
    cv::Mat labels, centers;
    cv::kmeans(resh, 3, labels,
        cv::TermCriteria(cv::TermCriteria::EPS+cv::TermCriteria::MAX_ITER,10,1.0),
        3, cv::KMEANS_PP_CENTERS, centers);
    // pick the largest cluster
    std::vector<int> cnt(3,0);
    for (int i=0;i<labels.rows;i++) cnt[labels.at<int>(i)]++;
    int idx = std::distance(cnt.begin(), std::max_element(cnt.begin(), cnt.end()));
    cv::Vec3f hue = centers.at<cv::Vec3f>(idx);
    return cv::Scalar(hue[0], hue[1], hue[2]); // H,S,V
}

// ------------------------------------------------------------
// Main loop
// ------------------------------------------------------------
int main() {
    cv::VideoCapture cap(0);
    if (!cap.isOpened()) return -1;

    const int automatonW = 80, automatonH = 60;
    Automaton ca(automatonW, automatonH);
    Synth synth;

    cv::Mat frame, resized;
    cv::namedWindow("AV Poem", cv::WINDOW_AUTOSIZE);

    while (true) {
        cap >> frame;
        if (frame.empty()) break;
        cv::resize(frame, resized, cv::Size(automatonW*4, automatonH*4));

        // colour analysis
        cv::Scalar dom = dominantHue(resized);
        float hue = dom[0]; // 0‑179 in OpenCV

        // trigger a note for each new dominant hue
        static float lastHue = -1;
        if (std::abs(hue - lastHue) > 20) {
            synth.noteOn(hue);
            lastHue = hue;
        }

        // audio level estimation (simple RMS of recent buffer)
        cv::Scalar audioLevel;
        {
            std::lock_guard<std::mutex> lk(synth.mtx);
            if (!synth.audioBuffer.empty()) {
                float sum = 0;
                for (float s : synth.audioBuffer) sum += s*s;
                audioLevel[0] = std::sqrt(sum / synth.audioBuffer.size());
            }
        }

        // step automaton with both influences
        ca.step(audioLevel, dom);
        cv::Mat caImg = ca.render(4);

        // overlay
        cv::addWeighted(resized, 0.6, caImg, 0.4, 0, resized);
        cv::imshow("AV Poem", resized);

        if (cv::waitKey(1) == 27) break; // ESC
    }

    synth.running = false;
    cv::destroyAllWindows();
    return 0;
}