#include <iostream>
#include <vector>
#include <string>
#include <sstream>
#include <cmath>
#include <map>

// MIDI Notes & Musical Representation
struct Note {
    int pitch;    // 0-127
    int duration; // quarter notes
};

// Program state modified by harmonically valid execution
struct RuntimeState {
    int registerA = 0;
    int registerB = 0;
    int pc = 0;
    std::string danceBuffer;
};

// Helper: Get chromatic pitch class (0 = C, 1 = C#, ..., 11 = B)
int getPitchClass(int pitch) {
    return pitch % 12;
}

// Check musical interval harmony
bool isHarmonicConsonant(int pitch1, int pitch2) {
    int interval = std::abs(pitch1 - pitch2) % 12;
    // Consonant intervals: Unison (0), Minor 3rd (3), Major 3rd (4), 
    // Perfect 4th (5), Perfect 5th (7), Minor 6th (8), Major 6th (9), Octave (0)
    return (interval == 0 || interval == 3 || interval == 4 || 
            interval == 5 || interval == 7 || interval == 8 || interval == 9);
}

// Parse string representation of MIDI program: "pitch:duration pitch:duration ..."
std::vector<Note> parseMIDI(const std::string& source) {
    std::vector<Note> melody;
    std::stringstream ss(source);
    std::string token;
    while (ss >> token) {
        size_t colonPos = token.find(':');
        if (colonPos != std::string::npos) {
            int p = std::stoi(token.substr(0, colonPos));
            int d = std::stoi(token.substr(colonPos + 1));
            melody.push_back({p, d});
        }
    }
    return melody;
}

// Compiler / Validator: Checks strict counterpoint harmony rules
bool validateHarmonyAndCompile(const std::vector<Note>& stream, std::vector<std::string>& instructions) {
    if (stream.size() < 2) return false;

    for (size_t i = 1; i < stream.size(); ++i) {
        Note prev = stream[i - 1];
        Note curr = stream[i];

        // Harmonic Rule 1: Consonance between adjacent notes
        if (!isHarmonicConsonant(prev.pitch, curr.pitch)) {
            std::cerr << "Syntax Error [Harmonic Dissonance]: Note " << curr.pitch 
                      << " creates harsh dissonance against " << prev.pitch << "\n";
            return false;
        }

        // Counterpoint Map: Map musical motion/intervals to VM commands
        int interval = curr.pitch - prev.pitch;
        if (interval > 0) {
            instructions.push_back("INC_A " + std::to_string(interval));
        } else if (interval < 0) {
            instructions.push_back("INC_B " + std::to_string(std::abs(interval)));
        } else {
            instructions.push_back("SWAP");
        }

        // Rhythm Duration map to pose modifiers
        if (curr.duration >= 4) {
            instructions.push_back("POSE_SPIN");
        } else if (curr.duration == 2) {
            instructions.push_back("POSE_JUMP");
        } else {
            instructions.push_back("POSE_STEP");
        }
    }
    return true;
}

// Generative ASCII Dance Renderer based on Virtual Machine State
void renderGenerativeASCII(const RuntimeState& state) {
    // Generative ASCII choreography poses
    const std::vector<std::string> heads = {"  (o.o)  ", "  (^._.^) ", "  \\(o_o)/ ", "  ( >_< ) "};
    const std::vector<std::string> torsos = {" /|  x  |\\", " /| === |\\", "  |  o  | ", " <|  #  |>"};
    const std::vector<std::string> legs = {"  /   \\  ", "  _/__\\_ ", "   // \\\\  ", "  /|   |\\ "};

    int headIdx = std::abs(state.registerA) % heads.size();
    int torsoIdx = std::abs(state.registerB) % torsos.size();
    int legIdx = std::abs(state.registerA + state.registerB) % legs.size();

    std::cout << "--- [ Beat " << state.pc << " Choreography Frame ] ---\n";
    std::cout << heads[headIdx] << "\n";
    std::cout << torsos[torsoIdx] << "\n";
    std::cout << legs[legIdx] << "\n";
    std::cout << "Energy A: " << state.registerA << " | Energy B: " << state.registerB << "\n\n";
}

// Interpreter/VM Execution
void executeVM(const std::vector<std::string>& bytecode) {
    RuntimeState state;
    for (const auto& op : bytecode) {
        state.pc++;
        std::stringstream ss(op);
        std::string cmd;
        ss >> cmd;

        if (cmd == "INC_A") {
            int val; ss >> val;
            state.registerA += val;
        } else if (cmd == "INC_B") {
            int val; ss >> val;
            state.registerB += val;
        } else if (cmd == "SWAP") {
            std::swap(state.registerA, state.registerB);
        } else if (cmd == "POSE_SPIN") {
            state.registerA *= 2;
        } else if (cmd == "POSE_JUMP") {
            state.registerB += 5;
        } else if (cmd == "POSE_STEP") {
            state.registerA += 1;
        }

        renderGenerativeASCII(state);
    }
}

int main() {
    // Valid Harmonious MIDI Sequence: C4(60), E4(64), G4(67), C5(72), G4(67), E4(64)
    std::string validMIDIProgram = "60:1 64:2 67:1 72:4 67:2 64:1";

    std::cout << "========================================================\n";
    std::cout << " HARMONIC COUNTERPOINT COMPILER & ASCII CHOREOGRAPHER  \n";
    std::cout << "========================================================\n\n";

    std::cout << "Parsing MIDI source: \"" << validMIDIProgram << "\"\n\n";
    std::vector<Note> midiStream = parseMIDI(validMIDIProgram);

    std::vector<std::string> bytecode;
    if (validateHarmonyAndCompile(midiStream, bytecode)) {
        std::cout << ">> Syntax Validation Passed: Harmonic Counterpoint Preserved.\n";
        std::cout << ">> Generating Execution Choreography...\n\n";
        executeVM(bytecode);
    } else {
        std::cout << ">> Compilation Failed: Dissonant Counterpoint Syntax Error.\n";
    }

    return 0;
}