import Foundation

// MARK: - Paths
let sourcePath = "./SelfMod.cpp"
let binaryPath = "./selfmod"

// MARK: - C++ source generation
let cppCode = """
#include <iostream>
#include <fstream>
#include <vector>
#include <cctype>
#include <cmath>
#include <thread>
#include <chrono>
#include <sys/resource.h>
#include <unistd.h>
#include <sys/sysinfo.h>
#include <ctime>

// ---------- Helper: extract printable ASCII strings ----------
std::vector<std::string> extractStrings(const std::vector<char>& data) {
    std::vector<std::string> strings;
    std::string cur;
    for (char c : data) {
        if (isprint(static_cast<unsigned char>(c))) {
            cur += c;
            if (cur.size() >= 4) { // minimal length
                strings.push_back(cur);
            }
        } else {
            cur.clear();
        }
    }
    return strings;
}

// ---------- Helper: map char to MIDI note using golden ratio ----------
int charToMidiNote(char ch) {
    const double phi = (1 + std::sqrt(5.0)) / 2.0;
    int base = 60; // middle C
    int offset = static_cast<int>(std::fmod((static_cast<int>(ch) * phi), 12));
    return base + offset;
}

// ---------- Helper: simple moon phase approximation ----------
double moonPhase() {
    // Simple algorithm: days since known new moon (2000-01-06)
    std::time_t now = std::time(nullptr);
    const double synodicMonth = 29.53058867;
    std::tm knownNewMoon = {};
    knownNewMoon.tm_year = 100; // 2000-1900
    knownNewMoon.tm_mon = 0;
    knownNewMoon.tm_mday = 6;
    std::time_t known = std::mktime(&knownNewMoon);
    double days = std::difftime(now, known) / 86400.0;
    return std::fmod(days, synodicMonth) / synodicMonth; // 0..1
}

// ---------- Helper: current memory usage (resident set size) ----------
long getMemoryUsageKB() {
    std::ifstream statm("/proc/self/status");
    std::string line;
    while (std::getline(statm, line)) {
        if (line.rfind("VmRSS:", 0) == 0) {
            std::istringstream iss(line);
            std::string key;
            long value;
            std::string unit;
            iss >> key >> value >> unit;
            return value; // kB
        }
    }
    return 0;
}

// ---------- Helper: CPU load (average over 1 second) ----------
double getCpuLoad() {
    struct sysinfo info1, info2;
    sysinfo(&info1);
    std::this_thread::sleep_for(std::chrono::seconds(1));
    sysinfo(&info2);
    unsigned long long idle1 = info1.uptime - (info1.totalram - info1.freeram);
    unsigned long long idle2 = info2.uptime - (info2.totalram - info2.freeram);
    unsigned long long total1 = info1.uptime;
    unsigned long long total2 = info2.uptime;
    double load = 1.0 - double(idle2 - idle1) / double(total2 - total1);
    return std::max(0.0, std::min(1.0, load));
}

// ---------- Self‑modifying: append a timestamp comment ----------
void selfModify() {
    std::ofstream src(__FILE__, std::ios::app);
    if (src) {
        src << "// Modified at " << std::time(nullptr) << "\\n";
    }
}

// ---------- Main ----------
int main() {
    // Read own binary
    std::ifstream bin(__FILE__, std::ios::binary);
    std::vector<char> data((std::istreambuf_iterator<char>(bin)),
                           std::istreambuf_iterator<char>());
    // Extract strings
    auto strings = extractStrings(data);
    // Output a simple “MIDI” stream (note number and velocity)
    for (const auto& s : strings) {
        for (char ch : s) {
            int note = charToMidiNote(ch);
            // Dynamic tempo / velocity based on system state
            long mem = getMemoryUsageKB();          // kB
            double cpu = getCpuLoad();              // 0..1
            double moon = moonPhase();              // 0..1
            int tempo = 60 + static_cast<int>(cpu * 60);          // 60‑120 BPM
            int velocity = 40 + static_cast<int>(mem % 80);       // 40‑120
            int keyShift = static_cast<int>(moon * 12) - 6;       // -6..+5 semitones
            int finalNote = note + keyShift;
            std::cout << "NOTE " << finalNote << " VELOCITY " << velocity
                      << " TEMPO " << tempo << "\\n";
            std::this_thread::sleep_for(std::chrono::milliseconds(60000 / tempo));
        }
    }
    // Self‑modify before exiting
    selfModify();
    return 0;
}
"""

do {
    // Write C++ source
    try cppCode.write(toFile: sourcePath, atomically: true, encoding: .utf8)

    // Compile
    let compile = Process()
    compile.executableURL = URL(fileURLWithPath: "/usr/bin/g++")
    compile.arguments = ["-std=c++17", sourcePath, "-o", binaryPath]
    try compile.run()
    compile.waitUntilExit()
    guard compile.terminationStatus == 0 else {
        fatalError("Compilation failed")
    }

    // Execute the produced binary
    let exec = Process()
    exec.executableURL = URL(fileURLWithPath: binaryPath)
    let pipe = Pipe()
    exec.standardOutput = pipe
    try exec.run()
    exec.waitUntilExit()

    // Print the program output
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8) {
        print(output)
    }
} catch {
    print("Error: \\(error)")
}