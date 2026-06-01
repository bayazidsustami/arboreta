#include <iostream>
#include <vector>
#include <string>
#include <map>
#include <chrono>
#include <thread>
#include <random>
#include <cmath>
#include <mutex>
#include <condition_variable>

// --- MIDI handling (RtMidi) ----------------------------------------------
#include "RtMidi.h"

struct MidiEvent {
    double timestamp;   // seconds since start
    int    pitch;       // 0‑127
    int    velocity;    // 0‑127
    bool   noteOn;      // true = on, false = off
};

class MidiInput {
public:
    MidiInput() : midi(nullptr), startTime(std::chrono::steady_clock::now()) {
        try { midi = new RtMidiIn(); }
        catch (RtMidiError &e) { e.printMessage(); std::exit(EXIT_FAILURE); }

        if (midi->getPortCount() == 0) {
            std::cerr << "No MIDI ports available.\n";
            std::exit(EXIT_FAILURE);
        }
        midi->openPort(0);
        midi->ignoreTypes(false, false, false);
        midi->setCallback(&MidiInput::callback, this);
    }

    ~MidiInput() { delete midi; }

    // Thread‑safe queue of events
    std::vector<MidiEvent> popEvents() {
        std::lock_guard<std::mutex> lk(mtx);
        std::vector<MidiEvent> out = std::move(buffer);
        buffer.clear();
        return out;
    }

private:
    static void callback(double deltatime, std::vector<unsigned char> *msg, void *userData) {
        MidiInput *self = static_cast<MidiInput*>(userData);
        if (msg->size() < 3) return;
        unsigned char status = msg->at(0);
        bool noteOn = (status & 0xF0) == 0x90 && msg->at(2) > 0;
        int pitch = msg->at(1);
        int vel   = msg->at(2);
        double ts = std::chrono::duration<double>(std::chrono::steady_clock::now() - self->startTime).count();

        {
            std::lock_guard<std::mutex> lk(self->mtx);
            self->buffer.push_back({ts, pitch, vel, noteOn});
        }
    }

    RtMidiIn *midi;
    std::chrono::steady_clock::time_point startTime;
    std::mutex mtx;
    std::vector<MidiEvent> buffer;
};

// --- Simple harmonic analysis ---------------------------------------------
struct HarmonicContext {
    double tonic;        // just a placeholder pitch class
    double mode;         // 0‑major, 1‑minor etc.
};

HarmonicContext analyze(const std::vector<MidiEvent> &events) {
    // Very naive: average pitch decides tonic, velocity decides mode
    if (events.empty()) return {0,0};
    double sum = 0; double velSum = 0;
    for (auto &e: events) { sum += e.pitch; velSum += e.velocity; }
    double avgPitch = sum / events.size();
    double avgVel   = velSum / events.size();
    return { fmod(avgPitch,12), avgVel>64 ? 0 : 1 };
}

// --- L‑system core ---------------------------------------------------------
class LSystem {
public:
    LSystem(const std::string& axiom) : current(axiom) {}

    void setRules(const std::map<char,std::string>& r) { rules=r; }

    void iterate() {
        std::string next;
        for (char c: current) {
            auto it = rules.find(c);
            next += (it!=rules.end()) ? it->second : std::string(1,c);
        }
        current.swap(next);
    }

    const std::string& get() const { return current; }

private:
    std::string current;
    std::map<char,std::string> rules;
};

// --- Visualisation (minimal OpenGL using GLFW) -----------------------------
#include <GLFW/glfw3.h>

class Renderer {
public:
    Renderer(int w,int h) : width(w), height(h) {
        if (!glfwInit()) std::exit(EXIT_FAILURE);
        glfwWindowHint(GLFW_RESIZABLE,GL_FALSE);
        window = glfwCreateWindow(width,height,"L‑system visualiser",nullptr,nullptr);
        if (!window) { glfwTerminate(); std::exit(EXIT_FAILURE); }
        glfwMakeContextCurrent(window);
        glClearColor(0,0,0,1);
    }
    ~Renderer(){ glfwDestroyWindow(window); glfwTerminate(); }

    void draw(const std::string& seq, double time) {
        glClear(GL_COLOR_BUFFER_BIT);
        glPushMatrix();
        glScaled(0.8,0.8,1);
        double x=0,y=0,angle=0;
        for (char c: seq) {
            switch(c) {
                case 'F': {
                    double nx = x + cos(angle);
                    double ny = y + sin(angle);
                    glColor3d(0.5+0.5*sin(time+angle),0.5+0.5*cos(time),0.5+0.5*sin(time*0.7));
                    glBegin(GL_LINES);
                    glVertex2d(x/width*2-1, y/height*2-1);
                    glVertex2d(nx/width*2-1, ny/height*2-1);
                    glEnd();
                    x=nx; y=ny;
                    break;
                }
                case '+': angle+=0.3; break;
                case '-': angle-=0.3; break;
                case '[': stack.emplace_back(x,y,angle); break;
                case ']': std::tie(x,y,angle)=stack.back(); stack.pop_back(); break;
                default: break;
            }
        }
        glPopMatrix();
        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    bool shouldClose() const { return glfwWindowShouldClose(window); }

private:
    GLFWwindow* window;
    int width,height;
    std::vector<std::tuple<double,double,double>> stack;
};

// --- Poetic stanza generator -----------------------------------------------
std::string generatePoem(const HarmonicContext& hc, const std::string& seq) {
    // Very simple: choose words based on tonic and mode, rhyme by last character
    const std::vector<std::string> majorWords={"bright","light","flight","night"};
    const std::vector<std::string> minorWords={"dark","spark","ark","mark"};
    const auto& dict = hc.mode==0 ? majorWords : minorWords;

    std::mt19937 rng(static_cast<unsigned>(std::chrono::system_clock::now().time_since_epoch().count()));
    std::uniform_int_distribution<> d(0,dict.size()-1);

    std::string line1 = "From " + dict[d(rng)] + " we hear a tone,";
    std::string line2 = "The pitch of " + std::to_string(int(hc.tonic)) + " does roam,";
    std::string line3 = "A sequence " + std::to_string(seq.size()) + " long,";
    std::string line4 = "In hologram's ever‑changing song.";
    return line1+"\n"+line2+"\n"+line3+"\n"+line4+"\n";
}

// --- Main -------------------------------------------------------------------
int main() {
    MidiInput midi;
    LSystem lsys("F");
    Renderer rend(800,600);
    double lastIter=0, iterInterval=0.5; // seconds per L‑system iteration
    std::string poem;

    while (!rend.shouldClose()) {
        auto events = midi.popEvents();
        if (!events.empty()) {
            HarmonicContext hc = analyze(events);
            // Dynamically rewrite rules: pitch influences turn angle, velocity influences branching
            std::map<char,std::string> rules;
            char turn = (hc.tonic<6)? '+' : '-';
            char branch = (hc.mode==0)? '[' : ']';
            rules['F'] = std::string(1,turn) + "F" + std::string(1,branch) + "F";
            lsys.setRules(rules);
            poem = generatePoem(hc, lsys.get());
            std::cout << "\033[2J\033[H" << poem << std::flush; // clear console & print poem
        }

        double now = std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count();
        if (now - lastIter > iterInterval) {
            lsys.iterate();
            lastIter = now;
        }

        rend.draw(lsys.get(), now);
        std::this_thread::sleep_for(std::chrono::milliseconds(16));
    }
    return 0;
}