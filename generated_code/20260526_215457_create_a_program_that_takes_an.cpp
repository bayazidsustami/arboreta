#include <iostream>
#include <vector>
#include <string>
#include <cmath>
#include <thread>
#include <chrono>

// ---- Mock MIDI structures -------------------------------------------------
struct Note {
    int pitch;       // MIDI note number
    float start;     // seconds
    float dur;       // seconds
    int velocity;    // 0-127
};

struct MidiTrack {
    std::vector<Note> notes;
};

struct MidiFile {
    float tempo;               // beats per minute
    std::vector<MidiTrack> tracks;
};

// ---- Simple MIDI parser (placeholder) ------------------------------------
MidiFile loadMidi(const std::string& path) {
    // In a real program you would parse the file.
    // Here we generate a tiny demo melody.
    MidiFile mf;
    mf.tempo = 120.0f;
    MidiTrack t;
    t.notes = {
        {60, 0.0f, 0.5f, 100},
        {62, 0.5f, 0.5f, 100},
        {64, 1.0f, 0.5f, 100},
        {65, 1.5f, 0.5f, 100},
        {67, 2.0f, 1.0f, 100},
        {65, 3.0f, 0.5f, 80},
        {64, 3.5f, 0.5f, 80},
        {62, 4.0f, 0.5f, 80},
        {60, 4.5f, 1.0f, 80}
    };
    mf.tracks.push_back(t);
    return mf;
}

// ---- Geometry primitives --------------------------------------------------
struct Vec3 {
    float x, y, z;
    Vec3 operator+(const Vec3& o) const { return {x+o.x, y+o.y, z+o.z}; }
    Vec3 operator*(float s) const { return {x*s, y*s, z*s}; }
};

struct Vertex {
    Vec3 pos;
    Vec3 normal;
    // color could be added for gradient texture
};

struct Mesh {
    std::vector<Vertex> vertices;
    std::vector<unsigned> indices;
};

// ---- Mapping functions ----------------------------------------------------
float pitchToHeight(int pitch) {
    // Map MIDI pitch (21-108) to height range [0,10]
    return (pitch - 21) / 87.0f * 10.0f;
}

float velocityToRadius(int vel) {
    // Map velocity to tube radius [0.1,0.5]
    return 0.1f + vel / 127.0f * 0.4f;
}

float timeToAngle(float t, float tempo) {
    // One beat = 60/tempo seconds, map beats to radians
    float beats = t * tempo / 60.0f;
    return beats * 2.0f * M_PI;
}

// Create a simple helical tube for each note
void addNoteToMesh(const Note& n, const MidiFile& mf, Mesh& mesh) {
    const int segs = 12;
    float r = velocityToRadius(n.velocity);
    float h = pitchToHeight(n.pitch);
    float startAng = timeToAngle(n.start, mf.tempo);
    float endAng   = timeToAngle(n.start + n.dur, mf.tempo);
    int startIdx = mesh.vertices.size();

    for (int i = 0; i <= segs; ++i) {
        float t = (float)i / segs;
        float ang = startAng + t * (endAng - startAng);
        float x = std::cos(ang) * r;
        float y = std::sin(ang) * r;
        float z = h + t * n.dur * 2.0f; // stretch along z for duration
        Vec3 pos = {x, y, z};
        mesh.vertices.push_back({pos, {x, y, 0}});
    }
    // Connect consecutive points with a line strip (indices)
    for (int i = 0; i < segs; ++i) {
        mesh.indices.push_back(startIdx + i);
        mesh.indices.push_back(startIdx + i + 1);
    }
}

// ---- Simple STL exporter (for 3‑D printing) -------------------------------
void exportSTL(const Mesh& mesh, const std::string& filename) {
    // Very naive: write each line segment as a thin triangular prism.
    // For demonstration we just output vertex count.
    std::cout << "Exporting STL (" << mesh.vertices.size()
              << " vertices, " << mesh.indices.size()/2 << " edges) to "
              << filename << "\n";
    // Real implementation would write binary STL.
}

// ---- Mock AR rendering ----------------------------------------------------
void renderAR(const Mesh& mesh, const MidiFile& mf) {
    std::cout << "Starting mock AR session. Press Ctrl+C to quit.\n";
    // Simulate walking through: advance a virtual cursor along time.
    float duration = 0.0f;
    for (const auto& tr : mf.tracks)
        for (const auto& n : tr.notes)
            duration = std::max(duration, n.start + n.dur);

    const float step = 0.05f; // seconds per frame
    for (float t = 0.0f; t < duration; t += step) {
        // In a real AR app you would update camera position and play audio
        // synchronized to t.
        std::cout << "\rTime: " << t << " s  ";
        std::cout.flush();
        std::this_thread::sleep_for(std::chrono::milliseconds(30));
    }
    std::cout << "\nAR session ended.\n";
}

// ---- Main -----------------------------------------------------------------
int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <midi-file>\n";
        return 1;
    }
    std::string midiPath = argv[1];
    MidiFile mf = loadMidi(midiPath);

    Mesh sculpture;
    for (const auto& tr : mf.tracks)
        for (const auto& n : tr.notes)
            addNoteToMesh(n, mf, sculpture);

    exportSTL(sculpture, "output.stl");
    renderAR(sculpture, mf);
    return 0;
}