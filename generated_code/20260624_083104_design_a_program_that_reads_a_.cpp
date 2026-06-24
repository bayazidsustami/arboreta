#include <iostream>
#include <vector>
#include <thread>
#include <atomic>
#include <cmath>
#include <chrono>
#include <mutex>
#include <fstream>
#include <opencv2/opencv.hpp>
#include <GLFW/glfw3.h>
#include <rtaudio/RtAudio.h>

// ---------- Audio synthesis (simple sine wave) ----------
struct AudioEngine {
    RtAudio dac;
    unsigned int sampleRate = 48000;
    unsigned int bufferFrames = 256;
    std::atomic<bool> running{false};
    std::mutex noteMtx;
    std::vector<double> activeFreqs;   // frequencies currently sounding
    double phase = 0.0;

    static int rtCallback(void *outputBuffer, void *, unsigned int nBufferFrames,
                          double , RtAudioStreamStatus , void *userData) {
        AudioEngine *engine = static_cast<AudioEngine*>(userData);
        float *out = static_cast<float*>(outputBuffer);
        std::lock_guard<std::mutex> lock(engine->noteMtx);
        for (unsigned int i = 0; i < nBufferFrames; ++i) {
            double sample = 0.0;
            for (double f : engine->activeFreqs) {
                sample += sin(engine->phase * f * 2.0 * M_PI / engine->sampleRate);
            }
            sample /= (engine->activeFreqs.empty() ? 1 : engine->activeFreqs.size());
            out[i] = static_cast<float>(sample * 0.2); // gentle volume
            engine->phase += 1.0;
        }
        return 0;
    }

    void start() {
        if (running) return;
        RtAudio::StreamParameters oParams;
        oParams.deviceId = dac.getDefaultOutputDevice();
        oParams.nChannels = 1;
        dac.openStream(&oParams, nullptr, RTAUDIO_FLOAT32,
                       sampleRate, &bufferFrames, &rtCallback, this);
        dac.start();
        running = true;
    }

    void stop() {
        if (!running) return;
        dac.stop();
        dac.closeStream();
        running = false;
    }

    void setFrequencies(const std::vector<double> &freqs) {
        std::lock_guard<std::mutex> lock(noteMtx);
        activeFreqs = freqs;
    }
};

// ---------- Just‑intonation scale ----------
static const std::vector<double> JUST_RATIOS = {
    1.0,          // unison
    9.0/8.0,      // major second
    5.0/4.0,      // major third
    4.0/3.0,      // perfect fourth
    3.0/2.0,      // perfect fifth
    5.0/3.0,      // major sixth
    15.0/8.0      // major seventh
};

double hueToFreq(double hue, double baseFreq = 261.63) { // base C4
    // map hue [0,360) to scale degree
    int degree = static_cast<int>(hue / 360.0 * JUST_RATIOS.size()) % JUST_RATIOS.size();
    return baseFreq * JUST_RATIOS[degree];
}

// ---------- Particle system ----------
struct Particle {
    glm::vec2 pos;
    glm::vec2 vel;
    glm::vec3 color;
    float age = 0.0f;
};

class ParticleField {
public:
    std::vector<Particle> particles;
    int count;
    ParticleField(int n) : count(n) {
        particles.resize(count);
        reset();
    }
    void reset() {
        for (auto &p : particles) {
            p.pos = glm::vec2(((float)rand()/RAND_MAX)*2.0f-1.0f,
                             ((float)rand()/RAND_MAX)*2.0f-1.0f);
            p.vel = glm::vec2(0.0f);
            p.color = glm::vec3(1.0f);
            p.age = 0.0f;
        }
    }
    void update(const cv::Scalar &meanHSV, const std::vector<double> &freqs, float dt) {
        // hue influences direction, saturation influences speed, value influences color brightness
        double hue = meanHSV[0];        // 0-180 in OpenCV (multiply by 2 for 0-360)
        double sat = meanHSV[1] / 255.0;
        double val = meanHSV[2] / 255.0;
        double angle = hue * 2.0 * M_PI / 180.0;
        float speed = static_cast<float>(sat * 2.0);
        glm::vec2 dir = glm::vec2(cos(angle), sin(angle));

        // audio envelope (simple RMS of frequencies)
        double amp = 0.0;
        for (double f : freqs) amp += 1.0; // each tone contributes equally
        amp = std::min(amp / freqs.size(), 1.0);

        for (auto &p : particles) {
            p.vel = dir * speed * static_cast<float>(amp);
            p.pos += p.vel * dt;
            // wrap around
            if (p.pos.x > 1.0f) p.pos.x = -1.0f;
            if (p.pos.x < -1.0f) p.pos.x = 1.0f;
            if (p.pos.y > 1.0f) p.pos.y = -1.0f;
            if (p.pos.y < -1.0f) p.pos.y = -1.0f;
            p.age += dt;
            // colour fades with age
            p.color = glm::vec3(val, 1.0f - val, 0.5f);
        }
    }
};

// ---------- Main ----------
int main() {
    // open webcam
    cv::VideoCapture cap(0);
    if (!cap.isOpened()) {
        std::cerr << "Cannot open webcam\n";
        return -1;
    }

    // init OpenGL window
    if (!glfwInit()) return -1;
    GLFWwindow* win = glfwCreateWindow(800, 600, "Audio‑Visual Sync", nullptr, nullptr);
    if (!win) { glfwTerminate(); return -1; }
    glfwMakeContextCurrent(win);
    glEnable(GL_POINT_SMOOTH);
    glPointSize(3.0f);

    // particle field
    ParticleField field(2000);

    // audio engine
    AudioEngine audio;
    audio.start();

    // seed saving
    std::ofstream seedFile("seed.txt");

    // main loop
    auto lastTime = std::chrono::high_resolution_clock::now();
    while (!glfwWindowShouldClose(win)) {
        // capture frame
        cv::Mat frame;
        cap >> frame;
        if (frame.empty()) break;
        cv::Mat hsv;
        cv::cvtColor(frame, hsv, cv::COLOR_BGR2HSV);
        cv::Scalar meanHSV = cv::mean(hsv);

        // map hue to frequencies (use three nearest notes)
        double baseHue = meanHSV[0] * 2.0; // convert OpenCV hue to 0‑360
        std::vector<double> freqs;
        for (int i = -1; i <= 1; ++i) {
            double h = fmod(baseHue + i * 30.0 + 360.0, 360.0);
            freqs.push_back(hueToFreq(h));
        }
        audio.setFrequencies(freqs);

        // update particles
        auto now = std::chrono::high_resolution_clock::now();
        float dt = std::chrono::duration<float>(now - lastTime).count();
        lastTime = now;
        field.update(meanHSV, freqs, dt);

        // render
        int w, h;
        glfwGetFramebufferSize(win, &w, &h);
        glViewport(0,0,w,h);
        glClearColor(0,0,0,1);
        glClear(GL_COLOR_BUFFER_BIT);
        glBegin(GL_POINTS);
        for (const auto &p : field.particles) {
            glColor3f(p.color.r, p.color.g, p.color.b);
            glVertex2f(p.pos.x, p.pos.y);
        }
        glEnd();
        glfwSwapBuffers(win);
        glfwPollEvents();

        // simple seed recording (frame count, mean HSV)
        static int frameIdx = 0;
        seedFile << frameIdx++ << ' '
                 << meanHSV[0] << ' '
                 << meanHSV[1] << ' '
                 << meanHSV[2] << '\n';
    }

    // cleanup
    audio.stop();
    seedFile.close();
    glfwDestroyWindow(win);
    glfwTerminate();
    return 0;
}