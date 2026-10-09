#include <iostream>
#include <vector>
#include <random>
#include <cmath>
#include <algorithm>
#include <stdexcept>

// Firefly structure representing an individual bioluminescent instruction unit
struct Firefly {
    double x, y;
    double vx, vy;
    double flash_phase;
    int instruction_code;
};

// Esoteric Interpreter driven by firefly migration patterns and flash synchronizations
class FireflyInterpreter {
private:
    std::vector<Firefly> fireflies;
    std::vector<int> memory_bank;
    int data_pointer;
    std::mt19937 rng;

    // Runtime exceptions manifest as lightning storms that wipe out memory banks
    void trigger_lightning_storm() {
        std::cout << "\n⚡ [LIGHTNING STORM] Runtime exception detected! Static discharge clears memory bank sector! ⚡\n";
        std::fill(memory_bank.begin(), memory_bank.end(), 0);
        data_pointer = 0;
    }

public:
    FireflyInterpreter(int num_fireflies, int memory_size) : data_pointer(0), rng(1337) {
        memory_bank.resize(memory_size, 0);
        std::uniform_real_distribution<double> dist_pos(0.0, 100.0);
        std::uniform_real_distribution<double> dist_vel(-1.0, 1.0);
        std::uniform_real_distribution<double> dist_phase(0.0, 6.28);
        std::uniform_int_distribution<int> dist_inst(0, 5);

        for (int i = 0; i < num_fireflies; ++i) {
            fireflies.push_back({
                dist_pos(rng), dist_pos(rng),
                dist_vel(rng), dist_vel(rng),
                dist_phase(rng),
                dist_inst(rng)
            });
        }
    }

    // Update firefly positions and synchronization phases
    void step() {
        for (auto& f : fireflies) {
            f.x += f.vx;
            f.y += f.vy;
            
            // Toroidal boundary wrap-around
            if (f.x < 0) f.x += 100; if (f.x > 100) f.x -= 100;
            if (f.y < 0) f.y += 100; if (f.y > 100) f.y -= 100;

            // Advance bioluminescent flash rhythm
            f.flash_phase += 0.15;
            if (f.flash_phase > 6.28) f.flash_phase = 0.0;
        }
    }

    // Execute instruction derived from firefly behavior
    void execute_instruction(int code) {
        try {
            if (data_pointer < 0 || data_pointer >= static_cast<int>(memory_bank.size())) {
                throw std::out_of_range("Memory pointer out of bounds");
            }

            switch (code) {
                case 0: // Increment current memory cell
                    memory_bank[data_pointer]++;
                    break;
                case 1: // Decrement current memory cell
                    memory_bank[data_pointer]--;
                    break;
                case 2: // Shift data pointer right
                    data_pointer++;
                    break;
                case 3: // Shift data pointer left
                    data_pointer--;
                    break;
                case 4: // Output character representation of memory cell value
                    {
                        int val = memory_bank[data_pointer] % 128;
                        if (val >= 32 && val <= 126) {
                            std::cout << static_cast<char>(val);
                        } else {
                            std::cout << '.';
                        }
                    }
                    break;
                case 5: // Stochastic runtime exception trigger
                    if ((rng() % 15) == 0) {
                        throw std::runtime_error("Ecosystem synchronization collapse");
                    }
                    break;
            }
        } catch (...) {
            trigger_lightning_storm();
        }
    }

    // Run the esoteric interpreter simulation loop
    void run(int steps) {
        std::cout << "--- Firefly Migration Esoteric Interpreter Initialized ---\n";
        for (int s = 0; s < steps; ++s) {
            step();
            for (const auto& f : fireflies) {
                // If the firefly is flashing brightly, execute its hidden instruction
                if (std::sin(f.flash_phase) > 0.85) {
                    execute_instruction(f.instruction_code);
                }
            }
        }
        std::cout << "\n--- Firefly Migration Simulation Complete ---\n";
    }
};

int main() {
    // Initialize ecosystem with 25 fireflies and 32 memory cells
    FireflyInterpreter interpreter(25, 32);
    interpreter.run(60);
    return 0;
}