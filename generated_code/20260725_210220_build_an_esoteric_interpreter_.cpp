#include <iostream>
#include <vector>
#include <cmath>
#include <numeric>
#include <random>
#include <string>

// --- Esoteric Language Specifications (ThunderScript) ---
// Frequency Spectrum Analysis -> Decodes Acoustic Signature
// Lightning Stroke Interval   -> Decodes Instruction Payload / Data Shift

enum class OpCode {
    NOOP,       // Ambient rain
    INC,        // Low rumble / Cloud-to-Ground (< 100 Hz)
    DEC,        // Mid-range rumble (100 - 250 Hz)
    PRINT_CHAR, // High-frequency crackle/pop (> 250 Hz)
    JMP_IF_ZERO // Sudden power surge / Intracloud flash
};

struct Instruction {
    OpCode op;
    int operand;
};

// Represents audio signal features extracted from a thunderstorm recording
struct ThunderAudioFrame {
    double dominant_frequency_hz; // Frequency signature
    double peak_amplitude_db;     // Acoustic energy
    double interval_to_next_sec;  // Time delta to next lightning stroke
};

class ThunderInterpreter {
private:
    std::vector<int> memory;
    size_t ptr = 0;

public:
    ThunderInterpreter(size_t tape_size = 256) : memory(tape_size, 0) {}

    // Transpile acoustic signatures into executable bytecode instructions
    Instruction decode_acoustic_signature(const ThunderAudioFrame& frame) {
        Instruction instr{OpCode::NOOP, 0};

        // Determine value modifier/jump length from timing interval
        int interval_val = static_cast<int>(std::round(frame.interval_to_next_sec * 10.0));
        if (interval_val == 0) interval_val = 1;

        // Classify acoustic signature by dominant frequency spectrum
        if (frame.dominant_frequency_hz < 100.0) {
            instr.op = OpCode::INC;
            instr.operand = interval_val;
        } else if (frame.dominant_frequency_hz >= 100.0 && frame.dominant_frequency_hz < 250.0) {
            instr.op = OpCode::DEC;
            instr.operand = interval_val;
        } else if (frame.dominant_frequency_hz >= 250.0 && frame.dominant_frequency_hz < 1000.0) {
            instr.op = OpCode::PRINT_CHAR;
            instr.operand = 0;
        } else {
            instr.op = OpCode::JMP_IF_ZERO;
            instr.operand = interval_val;
        }

        return instr;
    }

    void execute(const std::vector<ThunderAudioFrame>& recording) {
        std::cout << "[ThunderScript Interpreter Initialized]\nExec Output: ";
        
        size_t pc = 0;
        while (pc < recording.size()) {
            Instruction instr = decode_acoustic_signature(recording[pc]);

            switch (instr.op) {
                case OpCode::INC:
                    memory[ptr] = (memory[ptr] + instr.operand) % 256;
                    break;
                case OpCode::DEC:
                    memory[ptr] = (memory[ptr] - instr.operand + 256) % 256;
                    break;
                case OpCode::PRINT_CHAR:
                    std::cout << static_cast<char>(memory[ptr]) << std::flush;
                    break;
                case OpCode::JMP_IF_ZERO:
                    if (memory[ptr] == 0) {
                        pc += instr.operand;
                        continue;
                    }
                    break;
                case OpCode::NOOP:
                default:
                    break;
            }

            // Move memory pointer based on amplitude modulation
            ptr = (ptr + static_cast<size_t>(frame_to_shift(recording[pc]))) % memory.size();
            pc++;
        }
        std::cout << "\n[Execution Complete]\n";
    }

private:
    int frame_to_shift(const ThunderAudioFrame& frame) {
        return static_cast<int>(frame.peak_amplitude_db) % 3; // Shift tape index 0..2 positions
    }
};

// Generates synthetic thunderstorm audio feature data encoding "THUNDER!"
std::vector<ThunderAudioFrame> synthesize_thunderstorm_data() {
    std::vector<ThunderAudioFrame> stream;
    
    auto add_char = [&](char target) {
        // Target value via low-freq rumbles (< 100 Hz)
        stream.push_back({45.0, 80.0, static_cast<double>(target) / 10.0});
        // Print action via high-freq acoustic crackle (> 250 Hz)
        stream.push_back({350.0, 95.0, 0.5});
        // Clear memory cell via mid-freq rumble (100 - 250 Hz)
        stream.push_back({180.0, 75.0, static_cast<double>(target) / 10.0});
    };

    std::string msg = "THUNDER!";
    for (char c : msg) {
        add_char(c);
    }

    return stream;
}

int main() {
    // Load recorded atmospheric audio signatures
    std::vector<ThunderAudioFrame> storm_audio = synthesize_thunderstorm_data();

    // Execute esoteric program
    ThunderInterpreter interpreter;
    interpreter.execute(storm_audio);

    return 0;
}