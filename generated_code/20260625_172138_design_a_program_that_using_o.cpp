#include <iostream>
#include <vector>
#include <deque>
#include <complex>
#include <cmath>
#include <thread>
#include <atomic>
#include <mutex>
#include <condition_variable>
#include <portaudio.h>
#include <fftw3.h>

// Constants
constexpr double SAMPLE_RATE = 44100.0;
constexpr int FRAMES_PER_BUFFER = 1024;
constexpr int FFT_SIZE = FRAMES_PER_BUFFER;
constexpr int NUM_BANDS = 8;                // number of frequency bands -> rows
constexpr int DISPLAY_WIDTH = 80;           // columns across terminal
constexpr int DISPLAY_HEIGHT = NUM_BANDS;   // one Braille row per band
constexpr int BRAILLE_DOTS = 8;             // 2x4 matrix

// Mapping from (row, column) to Braille dot index (0‑7)
inline int dotIndex(int row, int col) { return row * 2 + col; }

// Convert a column of 8 booleans to a Braille unicode character
char32_t columnToBraille(const std::array<bool, BRAILLE_DOTS>& dots) {
    uint8_t mask = 0;
    for (int i = 0; i < BRAILLE_DOTS; ++i)
        if (dots[i]) mask |= (1 << i);
    return static_cast<char32_t>(0x2800 + mask);
}

// Audio callback (fills a ring buffer)
struct RingBuffer {
    std::vector<float> data;
    size_t writePos = 0, readPos = 0;
    std::mutex mtx;
    std::condition_variable cv;
    RingBuffer(size_t size) : data(size, 0.0f) {}
    void push(const float* src, size_t n) {
        std::unique_lock<std::mutex> lk(mtx);
        for (size_t i = 0; i < n; ++i) {
            data[writePos] = src[i];
            writePos = (writePos + 1) % data.size();
            if (writePos == readPos) readPos = (readPos + 1) % data.size(); // overwrite oldest
        }
        cv.notify_one();
    }
    void pop(float* dst, size_t n) {
        std::unique_lock<std::mutex> lk(mtx);
        cv.wait(lk, [&]{ return (writePos + data.size() - readPos) % data.size() >= n; });
        for (size_t i = 0; i < n; ++i) {
            dst[i] = data[readPos];
            readPos = (readPos + 1) % data.size();
        }
    }
};

static int paCallback(const void* input, void*, unsigned long frameCount,
                      const PaStreamCallbackTimeInfo*, PaStreamCallbackFlags,
                      void* userData) {
    RingBuffer* rb = static_cast<RingBuffer*>(userData);
    const float* in = static_cast<const float*>(input);
    rb->push(in, frameCount);
    return paContinue;
}

// Thread that performs FFT and updates display buffer
void processingThread(RingBuffer& rb, std::deque<std::array<bool,BRAILLE_DOTS>>& columns,
                      std::atomic<bool>& running) {
    std::vector<float> buffer(FFT_SIZE);
    std::vector<std::complex<double>> fftIn(FFT_SIZE);
    std::vector<std::complex<double>> fftOut(FFT_SIZE);
    fftw_plan plan = fftw_plan_dft_1d(FFT_SIZE,
                                     reinterpret_cast<fftw_complex*>(fftIn.data()),
                                     reinterpret_cast<fftw_complex*>(fftOut.data()),
                                     FFTW_FORWARD, FFTW_MEASURE);
    while (running) {
        rb.pop(buffer.data(), FFT_SIZE);
        // Hann window + copy to complex array
        for (int i = 0; i < FFT_SIZE; ++i) {
            double w = 0.5 * (1 - std::cos(2 * M_PI * i / (FFT_SIZE - 1)));
            fftIn[i] = buffer[i] * w;
        }
        fftw_execute(plan);
        // Power spectrum
        std::vector<double> power(FFT_SIZE/2);
        for (int i = 0; i < FFT_SIZE/2; ++i)
            power[i] = std::norm(fftOut[i]);
        // Map to bands
        std::array<bool,BRAILLE_DOTS> colDots{};
        for (int b = 0; b < NUM_BANDS; ++b) {
            int start = b * (FFT_SIZE/2) / NUM_BANDS;
            int end   = (b+1) * (FFT_SIZE/2) / NUM_BANDS;
            double avg = 0.0;
            for (int i = start; i < end; ++i) avg += power[i];
            avg = std::sqrt(avg / (end-start));        // energy proxy
            // Simple threshold to set a dot (more sophisticated mapping possible)
            bool on = avg > 1e-6;
            // Two columns per band to fill the 2x4 matrix (rows 0‑3, cols 0‑1)
            colDots[dotIndex(b % 4, b / 4)] = on;
        }
        // Insert new column, keep width fixed
        if (columns.size() >= DISPLAY_WIDTH) columns.pop_front();
        columns.emplace_back(colDots);
    }
    fftw_destroy_plan(plan);
}

// Render deque of columns as lines of Unicode Braille
void render(const std::deque<std::array<bool,BRAILLE_DOTS>>& columns) {
    // Clear screen (ANSI)
    std::cout << "\x1b[H\x1b[2J";
    // Build each row (each row is a string of Braille chars)
    std::vector<std::u32string> rows(DISPLAY_HEIGHT);
    for (const auto& col : columns) {
        for (int r = 0; r < DISPLAY_HEIGHT; ++r) {
            std::array<bool,BRAILLE_DOTS> dotSlice{};
            // extract the two dots belonging to this row
            dotSlice[0] = col[dotIndex(r,0)];
            dotSlice[1] = col[dotIndex(r,1)];
            // pack into a Braille char (only first two bits used)
            char32_t ch = columnToBraille({dotSlice[0],dotSlice[1],false,false,false,false,false,false});
            rows[r].push_back(ch);
        }
    }
    // Output rows
    for (int r = 0; r < DISPLAY_HEIGHT; ++r) {
        std::wstring_convert<std::codecvt_utf8<char32_t>,char32_t> conv;
        std::cout << conv.to_bytes(rows[r]) << '\n';
    }
    std::cout.flush();
}

int main() {
    // Initialise PortAudio
    PaError err = Pa_Initialize();
    if (err != paNoError) return 1;
    PaStream* stream;
    RingBuffer rb(FFT_SIZE * 8);
    err = Pa_OpenDefaultStream(&stream, 1, 0, paFloat32, SAMPLE_RATE,
                               FRAMES_PER_BUFFER, paCallback, &rb);
    if (err != paNoError) return 1;
    err = Pa_StartStream(stream);
    if (err != paNoError) return 1;

    std::deque<std::array<bool,BRAILLE_DOTS>> columns;
    std::atomic<bool> running{true};
    std::thread worker(processingThread, std::ref(rb), std::ref(columns), std::ref(running));

    // Main render loop
    while (true) {
        render(columns);
        std::this_thread::sleep_for(std::chrono::milliseconds(40)); // ~25 FPS
        if (!std::cin.good()) break; // press Ctrl+D to exit
    }

    // Cleanup
    running = false;
    worker.join();
    Pa_StopStream(stream);
    Pa_CloseStream(stream);
    Pa_Terminate();
    return 0;
}