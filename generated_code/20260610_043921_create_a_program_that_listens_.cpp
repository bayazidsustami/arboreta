#include <bits/stdc++.h>
#include <chrono>
#include <thread>
#include <random>
#include <sstream>
#include <fstream>

// Simple L‑system implementation
struct LSystem {
    std::string axiom;
    std::unordered_map<char, std::string> rules;
    std::string current;

    LSystem(const std::string& a) : axiom(a), current(a) {}

    void addRule(char pred, const std::string& repl) { rules[pred] = repl; }

    // one iteration
    void iterate() {
        std::string next;
        for (char c : current) {
            auto it = rules.find(c);
            next += (it != rules.end()) ? it->second : std::string(1, c);
        }
        current.swap(next);
    }
};

// Tiny FFT placeholder – returns random magnitudes
std::vector<double> fakeFFT(size_t bins) {
    static std::mt19937 rng((unsigned)std::chrono::system_clock::now().time_since_epoch().count());
    std::uniform_real_distribution<double> dist(0.0, 1.0);
    std::vector<double> mags(bins);
    for (auto& v : mags) v = dist(rng);
    return mags;
}

// Fake sentiment analysis – maps a random word to a hue
int fakeSentimentHue() {
    static const std::vector<std::string> moods = {"happy","sad","angry","calm"};
    static std::mt19937 rng((unsigned)std::chrono::system_clock::now().time_since_epoch().count());
    std::uniform_int_distribution<int> dist(0, moods.size()-1);
    int idx = dist(rng);
    // map to hue 0..360
    return idx * 90;
}

// Convert L‑system string to SVG path (simple turtle graphics)
std::string lsystemToPath(const std::string& seq, double step, double angleDeg) {
    std::ostringstream out;
    double x=0, y=0;
    double angle = 0; // radians
    const double rad = M_PI/180.0;
    out << "M0,0 ";
    for(char c:seq){
        if(c=='F'){
            x += step * cos(angle);
            y += step * sin(angle);
            out << "L" << x << "," << y << " ";
        }else if(c=='+'){
            angle += angleDeg*rad;
        }else if(c=='-'){
            angle -= angleDeg*rad;
        }
    }
    return out.str();
}

// Write one SVG frame
void writeSVG(const std::string& pathData, int hue, int frame) {
    std::ostringstream fname;
    fname << "frame_" << std::setw(4) << std::setfill('0') << frame << ".svg";
    std::ofstream f(fname.str());
    f << "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    f << "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"800\" height=\"800\" viewBox=\"-400 -400 800 800\">\n";
    f << "<defs><linearGradient id=\"grad\" x1=\"0%\" y1=\"0%\" x2=\"100%\" y2=\"0%\">\n";
    f << "<stop offset=\"0%\" stop-color=\"hsl("<<hue<<",80%,50%)\"/>\n";
    f << "<stop offset=\"100%\" stop-color=\"hsl("<<(hue+180)%360<<",80%,50%)\"/>\n";
    f << "</linearGradient></defs>\n";
    f << "<path d=\"" << pathData << "\" stroke=\"url(#grad)\" fill=\"none\" stroke-width=\"1\"/>\n";
    f << "</svg>\n";
}

// Main loop – synthesises audio -> L‑system -> SVG
int main() {
    // Initialise a basic L‑system (Koch curve)
    LSystem ls("F");
    ls.addRule('F',"F+F--F+F");

    const size_t fftBins = 64;
    const double baseStep = 5.0;
    const double baseAngle = 60.0;

    for(int frame=0; frame<200; ++frame){
        // 1) audio spectrum (mock)
        auto mags = fakeFFT(fftBins);
        double avgMag = std::accumulate(mags.begin(), mags.end(), 0.0) / mags.size();

        // 2) drive L‑system parameters from audio
        int iters = std::clamp(int(avgMag * 10), 1, 5);
        double step = baseStep * (0.5 + avgMag);
        double angle = baseAngle * (0.5 + avgMag);

        // 3) sentiment hue (mock)
        int hue = fakeSentimentHue();

        // 4) iterate L‑system
        ls.current = ls.axiom;
        for(int i=0;i<iters;++i) ls.iterate();

        // 5) render to SVG
        std::string path = lsystemToPath(ls.current, step, angle);
        writeSVG(path, hue, frame);

        // simple pacing
        std::this_thread::sleep_for(std::chrono::milliseconds(30));
    }
    return 0;
}