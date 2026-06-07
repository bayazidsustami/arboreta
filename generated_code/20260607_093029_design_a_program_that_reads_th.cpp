#include <iostream>
#include <thread>
#include <chrono>
#include <random>
#include <vector>
#include <string>
#include <sstream>
#include <mutex>
#include <queue>
#include <cmath>

// ---------- Minimal MIDI output (RtMidi) ----------
#include "RtMidi.h"          // Requires RtMidi library (https://github.com/thestk/rtmidi)

class MidiOut {
public:
    MidiOut() {
        try { midi = new RtMidiOut(); }
        catch (RtMidiError &error) { error.printMessage(); std::exit(EXIT_FAILURE); }
        std::vector<unsigned char> message;
        unsigned int ports = midi->getPortCount();
        if (ports) midi->openPort(0);
        else midi->openVirtualPort("StockMidi");
    }
    ~MidiOut() { delete midi; }

    void noteOn(int note, int velocity) {
        std::vector<unsigned char> msg = {0x90, static_cast<unsigned char>(note & 0x7F), static_cast<unsigned char>(velocity & 0x7F)};
        midi->sendMessage(&msg);
    }
    void noteOff(int note) {
        std::vector<unsigned char> msg = {0x80, static_cast<unsigned char>(note & 0x7F), 0};
        midi->sendMessage(&msg);
    }
private:
    RtMidiOut *midi;
};

// ---------- Simple SVG generator ----------
class SvgCanvas {
public:
    SvgCanvas(int w, int h) : width(w), height(h) {
        svg << "<svg xmlns='http://www.w3.org/2000/svg' width='" << w << "' height='" << h << "'>\n";
    }
    void addHexagon(double cx, double cy, double r, const std::string& fill, double stroke, const std::string& strokeColor) {
        const double sqrt3 = std::sqrt(3.0);
        std::ostringstream path;
        for (int i = 0; i < 6; ++i) {
            double angle = M_PI/6 + i*M_PI/3;
            double x = cx + r*std::cos(angle);
            double y = cy + r*std::sin(angle);
            if (i==0) path << "M";
            else    path << "L";
            path << x << " " << y << " ";
        }
        path << "Z";
        svg << "<path d='" << path.str()
            << "' fill='" << fill
            << "' stroke='" << strokeColor
            << "' stroke-width='" << stroke << "'/>\n";
    }
    std::string str() const { return svg.str() + "</svg>"; }
private:
    int width, height;
    std::ostringstream svg;
};

// ---------- Mock stock data generator ----------
struct StockInfo {
    std::string symbol;
    double price;
    double change;          // price delta
    double volume;          // normalized [0,1]
    double marketCap;       // in billions
    int sectorId;           // 0..5
    double sentiment;      // -1..1
};

class StockFeed {
public:
    StockFeed() : gen(rd()), distPrice(-0.5,0.5), distVol(0,1), distSent(-1,1) {
        symbols = {"AAA","BBB","CCC","DDD","EEE","FFF"};
        for (size_t i=0;i<symbols.size();++i){
            StockInfo s;
            s.symbol=symbols[i];
            s.price=100.0+10*i;
            s.change=0;
            s.volume=0.5;
            s.marketCap=5.0+ i*2;
            s.sectorId=i%6;
            s.sentiment=0;
            state.push_back(s);
        }
    }
    StockInfo next() {
        std::uniform_int_distribution<int> idxDist(0, state.size()-1);
        int idx = idxDist(gen);
        StockInfo &s = state[idx];
        double delta = distPrice(gen);
        s.change = delta;
        s.price += delta;
        s.volume = distVol(gen);
        s.sentiment = distSent(gen);
        return s;
    }
private:
    std::random_device rd;
    std::mt19937 gen;
    std::uniform_real_distribution<double> distPrice, distVol, distSent;
    std::vector<std::string> symbols;
    std::vector<StockInfo> state;
};

// ---------- Mapping functions ----------
int priceToMidiNote(double price) {
    int base = 60; // middle C
    int note = base + static_cast<int>(std::round(price)) % 24; // two octaves
    return std::clamp(note, 0, 127);
}
int sentimentToVelocity(double sentiment) {
    int vel = static_cast<int>((sentiment+1.0)*63.5); // 0..127
    return std::clamp(vel, 0, 127);
}
std::string sectorToColor(int sector) {
    static const std::string cols[] = {"#e6194b","#3cb44b","#ffe119","#0082c8","#f58231","#911eb4"};
    return cols[sector%6];
}
double volumeToStroke(double vol) { return 0.5 + vol*3.0; }

// ---------- Main orchestration ----------
int main() {
    MidiOut midi;
    SvgCanvas canvas(800,600);
    StockFeed feed;

    std::mutex mtx;
    std::queue<StockInfo> q;
    bool running = true;

    // Producer: mock live feed
    std::thread producer([&](){
        while(running){
            StockInfo s = feed.next();
            {
                std::lock_guard<std::mutex> lk(mtx);
                q.push(s);
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(200));
        }
    });

    // Consumer: audio + visual
    std::thread consumer([&](){
        double hexR = 20;
        double x=hexR, y=hexR;
        int colCount = 0;
        while(running){
            StockInfo s;
            {
                std::lock_guard<std::mutex> lk(mtx);
                if(q.empty()){
                    std::this_thread::sleep_for(std::chrono::milliseconds(10));
                    continue;
                }
                s = q.front(); q.pop();
            }

            // MIDI mapping
            int note = priceToMidiNote(s.price);
            int vel  = sentimentToVelocity(s.sentiment);
            midi.noteOn(note, vel);
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
            midi.noteOff(note);

            // SVG hexagon placement (simple left‑to‑right, wrap)
            canvas.addHexagon(x, y, hexR,
                sectorToColor(s.sectorId),
                volumeToStroke(s.volume),
                "#000000");

            x += 2*hexR*0.9;
            ++colCount;
            if (x > canvas.str().size() || colCount>30){
                x = hexR;
                y += hexR*1.5;
                colCount=0;
            }
        }
    });

    // Run for 30 seconds then stop
    std::this_thread::sleep_for(std::chrono::seconds(30));
    running = false;
    producer.join();
    consumer.join();

    // Output SVG
    std::cout << canvas.str() << std::endl;
    return 0;
}