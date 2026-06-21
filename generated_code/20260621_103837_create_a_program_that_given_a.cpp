#include <iostream>
#include <fstream>
#include <vector>
#include <thread>
#include <chrono>
#include <random>
#include <iomanip>
#include <sstream>
#include <cstdint>

// Simple MIDI parser: extracts Note On events (channel 0, any note) with velocity
struct MidiEvent {
    uint32_t delta;   // delta‑time in ticks
    uint8_t  type;    // 0x90 = Note On, 0x80 = Note Off (after velocity 0)
    uint8_t  note;    // MIDI note number
    uint8_t  vel;     // velocity
};

std::vector<MidiEvent> parseMidi(const std::string& filename) {
    std::ifstream in(filename, std::ios::binary);
    if (!in) return {};
    // Very naïve parser – skips header, assumes format 1, 480 PPQ
    // Reads only track chunks and Note On events on channel 0.
    std::vector<MidiEvent> ev;
    auto readVarLen = [&](uint32_t& val) {
        val = 0;
        uint8_t b;
        do {
            in.read(reinterpret_cast<char*>(&b),1);
            val = (val<<7) | (b & 0x7F);
        } while (b & 0x80);
    };
    // skip header chunk (14 bytes)
    in.seekg(14, std::ios::beg);
    while (in) {
        char chunkId[4];
        uint32_t chunkSize;
        in.read(chunkId,4);
        in.read(reinterpret_cast<char*>(&chunkSize),4);
        if (in.gcount()!=4) break;
        chunkSize = __builtin_bswap32(chunkSize);
        if (std::string(chunkId,4)=="MTrk") {
            uint32_t bytesRead=0;
            uint8_t runningStatus=0;
            while (bytesRead<chunkSize) {
                uint32_t delta;
                readVarLen(delta);
                bytesRead+= (uint32_t)in.tellg() - (bytesRead? bytesRead:0);
                uint8_t status;
                in.read(reinterpret_cast<char*>(&status),1);
                ++bytesRead;
                if (status<0x80) { // running status
                    in.unget();
                    --bytesRead;
                    status = runningStatus;
                } else {
                    runningStatus = status;
                }
                uint8_t type = status & 0xF0;
                uint8_t chan = status & 0x0F;
                if (type==0x90) { // Note On
                    uint8_t note, vel;
                    in.read(reinterpret_cast<char*>(&note),1);
                    in.read(reinterpret_cast<char*>(&vel),1);
                    bytesRead+=2;
                    if (vel>0 && chan==0) {
                        ev.push_back({delta, type, note, vel});
                    }
                } else if (type==0x80) { // Note Off
                    uint8_t note, vel;
                    in.read(reinterpret_cast<char*>(&note),1);
                    in.read(reinterpret_cast<char*>(&vel),1);
                    bytesRead+=2;
                } else {
                    // skip parameters (most meta events are variable length)
                    if (status==0xFF) { // meta
                        uint8_t metaType;
                        uint32_t len;
                        in.read(reinterpret_cast<char*>(&metaType),1);
                        readVarLen(len);
                        in.ignore(len);
                        bytesRead+=1+len;
                    } else if (status==0xF0 || status==0xF7) { // SysEx
                        uint32_t len;
                        readVarLen(len);
                        in.ignore(len);
                        bytesRead+=len;
                    } else {
                        // other MIDI messages have 2 data bytes
                        in.ignore(2);
                        bytesRead+=2;
                    }
                }
            }
        } else {
            in.ignore(chunkSize);
        }
    }
    return ev;
}

// Generate a Befunge snippet whose execution path depends on velocity
std::string befungeSnippet(uint8_t vel) {
    // Simple 5x5 grid: push velocity, duplicate, add, output as ASCII char
    // The higher the velocity, the farther the instruction pointer moves before '@'
    std::ostringstream oss;
    oss << ">" << std::hex << std::setw(2) << std::setfill('0') << (int)vel << "v\n"
        << "   v\n"
        << "   @\n";
    return oss.str();
}

// Draw mandala: a 21x21 char matrix with radial pattern influenced by notes
void drawMandala(const std::vector<MidiEvent>& events, size_t idx) {
    const int SZ=21;
    char grid[SZ][SZ];
    std::fill(&grid[0][0], &grid[0][0]+SZ*SZ, ' ');
    // centre
    int cx=SZ/2, cy=SZ/2;
    // base pattern
    for (int r=0;r<10;r++) {
        for (int a=0;a<360;a+=30) {
            double rad = a*M_PI/180.0;
            int x = cx + (int)(r*cos(rad));
            int y = cy + (int)(r*sin(rad));
            if (x>=0 && x<SZ && y>=0 && y<SZ) grid[y][x]='.';
        }
    }
    // overlay recent notes (last 8)
    for (size_t i=0;i<8 && idx+ i < events.size();++i) {
        const auto& e = events[idx+i];
        double angle = (e.note%12) * M_PI/6.0; // 12 pitch classes around circle
        double radius = (e.vel/127.0) * 9.0 + 1.0;
        int x = cx + (int)(radius*cos(angle));
        int y = cy + (int)(radius*sin(angle));
        if (x>=0 && x<SZ && y>=0 && y<SZ) grid[y][x] = '#';
    }
    // clear screen
    std::cout << "\x1B[2J\x1B[H";
    // print grid with embedded Befunge snippets
    for (int y=0;y<SZ;y++) {
        for (int x=0;x<SZ;x++) {
            if (grid[y][x]=='#') {
                // embed a tiny snippet as comment in output
                std::cout << grid[y][x];
            } else {
                std::cout << grid[y][x];
            }
        }
        std::cout << "\n";
    }
    // show one snippet for demonstration
    if (idx<events.size()) {
        std::cout << "\nBefunge snippet (velocity " << (int)events[idx].vel << "):\n";
        std::cout << befungeSnippet(events[idx].vel) << "\n";
    }
}

// Main loop: plays “as if” and updates mandala in real time
int main(int argc, char*argv[]) {
    if (argc<2) {
        std::cerr<<"Usage: "<<argv[0]<<" <file.mid>\n";
        return 1;
    }
    auto events=parseMidi(argv[1]);
    if (events.empty()){
        std::cerr<<"No Note‑On events found or invalid MIDI.\n";
        return 1;
    }
    size_t ptr=0;
    const double tempoBPM=120.0; // fixed tempo for simplicity
    const double ticksPerBeat=480.0;
    double usPerTick = 60e6/(tempoBPM*ticksPerBeat);
    while (ptr<events.size()){
        drawMandala(events,ptr);
        // wait for next event delta
        uint32_t delta = events[ptr].delta;
        std::this_thread::sleep_for(std::chrono::microseconds((uint64_t)(delta*usPerTick)));
        ++ptr;
    }
    // final hold
    std::cout<<"\nEnd of piece. Press Enter to quit.";
    std::cin.get();
    return 0;
}