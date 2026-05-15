#include <iostream>
#include <vector>
#include <string>
#include <fstream>
#include <cmath>
#include <algorithm>
#include <ctime>

/**
 * This program converts text into a MIDI file.
 * It maps ASCII values to MIDI note numbers.
 * It uses a basic MIDI file structure (Format 0).
 */

// MIDI Constants
const int MIDI_FILENAME_MAX = 256;
const int MIDI_HEADER_SIZE = 44;

// Structure to represent a MIDI event (Note On/Off)
struct MidiEvent {
    int delta_time; // Time since last event (in ticks)
    int status;     // MIDI status byte (Note On, Note Off, etc.)
    int data1;      // Note number
    int data2;      // Velocity/Value
};

// Helper function to write 14-bit MIDI variable length quantities (VLQ)
// Used for delta times in MIDI files.
void writeVarLen(std::vector<unsigned char>& buffer, int value) {
    unsigned char bytes[4];
    int i = 0;
    bytes[i++] = value & 0x7F;
    while ((value >>= 7) > 0) {
        bytes[i++] = (value & 0x7F) | 0x80;
    }
    for (int j = i - 1; j >= 0; --j) {
        buffer.push_back(bytes[j]);
    }
}

// Helper to write 16-bit little endian
void write16(std::vector<unsigned char>& buffer, uint16_t value) {
    buffer.push_back(value & 0xFF);
    buffer.push_back((value >> 8) & 0xFF);
}

// Helper to write 32-bit big endian (used in MIDI headers)
void write32(std::vector<unsigned char>& buffer, uint32_t value) {
    buffer.push_back((value >> 24) & 0xFF);
    buffer.push_back((value >> 16) & 0xFF);
    buffer.push_back((value >> 8) & 0xFF);
    buffer.push_back(value & 0xFF);
}

int main() {
    std::string input;
    std::cout << "Enter text to convert to MIDI: ";
    std::getline(std::cin, input);

    if (input.empty()) {
        std::cerr << "Input is empty." << std::endl;
        return 1;
    }

    // MIDI configuration
    int ticks_per_quarter = 480;
    int velocity = 80;
    int duration_ticks = ticks_per_quarter / 2; // Eighth notes

    std::vector<MidiEvent> events;

    for (char c : input) {
        // Map ASCII to a MIDI note range (e.g., 48-84)
        // We use modulo to keep notes within a musical range
        int note = 48 + (static_cast<unsigned char>(c) % 36);

        // Note On event
        events.push_back({0, 0x90, note, velocity});
        // Note Off event (after duration_ticks)
        events.push_back({duration_ticks, 0x80, note, 0});
        // Add a small rest between notes
        events.push_back({ticks_per_quarter / 4, 0x80, 0, 0}); 
    }

    // Re-calculate delta times for the MIDI stream
    // Currently, events are stored with absolute durations in the 'delta_time' field
    // We need to convert them to relative deltas for the actual file format
    std::vector<MidiEvent> processed_events;
    int current_delta = 0;
    for (size_t i = 0; i < events.size(); ++i) {
        int delta = events[i].delta_time;
        // If the event is a Note On, it's relative to the previous Note Off
        // We adjust based on the logic of the loop
        if (i > 0 && events[i].status == 0x90) {
            // This is a simplification: we treat the 'delta_time' as the time 
            // passed since the last event in the vector.
        }
        processed_events.push_back(events[i]);
    }

    // Correcting the delta logic: 
    // The events vector currently contains "time since start of note" or "duration".
    // Let's rebuild the delta sequence.
    std::vector<MidiEvent> final_events;
    int last_time = 0;
    for (size_t i = 0; i < events.size(); ++i) {
        int absolute_time = 0;
        // In our logic above:
        // Event 0: NoteOn at 0
        // Event 1: NoteOff at duration
        // Event 2: Rest (effectively a gap) at duration + gap
        // This is tricky. Let's simplify the event generation.
    }

    // RE-DOING EVENT GENERATION FOR CLARITY
    std::vector<MidiEvent> clean_events;
    int running_time = 0;
    for (char c : input) {
        int note = 48 + (static_cast<unsigned char>(c) % 36);
        
        // Note On
        clean_events.push_back({running_time, 0x90, note, velocity});
        running_time += duration_ticks;
        
        // Note Off
        clean_events.push_back({running_time, 0x80, note, 0});
        running_time += ticks_per_quarter / 4; // Gap
    }

    // Convert absolute running_time to delta_times
    std::vector<MidiEvent> delta_events;
    int prev_time = 0;
    for (auto& e : clean_events) {
        int delta = e.delta_time - prev_time;
        delta_events.push_back({delta, e.status, e.data1, e.data2});
        prev_time = e.delta_time;
    }

    // Build MIDI File
    std::vector<unsigned char> midi_data;

    // 1. Header Chunk
    write32(midi_data, 0x4D544844); // "MThd"
    write32(midi_data, 6);          // Header length
    write16(midi_data, 0);          // Format 0
    write16(midi_data, 1);          // One track
    write16(midi_data, ticks_per_quarter);

    // 2. Track Chunk
    write32(midi_data, 0x4D54726B); // "MTrk"
    
    // We need to calculate the track length first, but for a simple script,
    // we'll write to a buffer and then prepend the length.
    std::vector<unsigned char> track_data;
    for (auto& e : delta_events) {
        writeVarLen(track_data, e.delta_time);
        track_data.push_back(static_cast<unsigned char>(e.status));
        track_data.push_back(static_cast<unsigned char>(e.data1));
        track_data.push_back(static_cast<unsigned char>(e.data2));
    }
    // End of Track event
    writeVarLen(track_data, 0);
    track_data.push_back(0xFF);
    track_data.push_back(0x2F);
    track_data.push_back(0x00);

    // Prepend track length to midi_data
    write32(midi_data, static_cast<uint32_t>(track_data.size()));
    midi_data.insert(midi_data.end(), track_data.begin(), track_data.end());

    // Write to file
    std::string filename = "output.mid";
    std::ofstream outfile(filename, std::ios::binary);
    if (!outfile) {
        std::cerr << "Could not create file." << std::endl;
        return 1;
    }
    outfile.write(reinterpret_cast<const char*>(midi_data.data()), midi_data.size());
    outfile.close();

    std::cout << "Success! MIDI file saved as " << filename << std::endl;

    return 0;
}