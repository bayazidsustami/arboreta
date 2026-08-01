#include <iostream>
#include <vector>
#include <cstdint>
#include <fstream>
#include <random>

// Cellular Automaton Driven by Bytecode Execution
// Each cell extracts RGB color bytes from its 3x3 neighborhood into a 27-byte instruction stream.
// A virtual machine interprets this bytecode to update the cell's color state across generations.

const int WIDTH = 128;
const int HEIGHT = 128;
const int FRAMES = 100;

struct RGB {
    uint8_t r, g, b;
};

// Virtual Machine executing neighborhood-derived instructions
struct VM {
    uint8_t reg[4] = {0};
    uint8_t stack[16] = {0};
    uint8_t sp = 0;

    void execute(const uint8_t* bytecode, size_t len) {
        size_t ip = 0;
        int max_steps = 64; // Prevent infinite execution loops
        
        while (ip < len && max_steps-- > 0) {
            uint8_t op = bytecode[ip++];
            uint8_t arg1 = (ip < len) ? bytecode[ip++] : 0;
            uint8_t arg2 = (ip < len) ? bytecode[ip++] : 0;

            switch (op % 12) {
                case 0:  // SET reg[arg1] = arg2
                    reg[arg1 % 4] = arg2;
                    break;
                case 1:  // ADD reg[arg1] += reg[arg2]
                    reg[arg1 % 4] += reg[arg2 % 4];
                    break;
                case 2:  // XOR reg[arg1] ^= reg[arg2]
                    reg[arg1 % 4] ^= reg[arg2 % 4];
                    break;
                case 3:  // ROTATE RIGHT reg[arg1]
                    reg[arg1 % 4] = (reg[arg1 % 4] >> 1) | (reg[arg1 % 4] << 7);
                    break;
                case 4:  // PUSH reg[arg1]
                    if (sp < 16) stack[sp++] = reg[arg1 % 4];
                    break;
                case 5:  // POP reg[arg1]
                    if (sp > 0) reg[arg1 % 4] = stack[--sp];
                    break;
                case 6:  // CONDITIONAL JUMP
                    if (reg[0] > 128 && arg1 < len) ip = arg1;
                    break;
                case 7:  // NAND reg[arg1] = ~(reg[arg1] & reg[arg2])
                    reg[arg1 % 4] = ~(reg[arg1 % 4] & reg[arg2 % 4]);
                    break;
                case 8:  // INCREMENT reg[arg1]
                    reg[arg1 % 4]++;
                    break;
                case 9:  // SWAP reg[arg1], reg[arg2]
                    std::swap(reg[arg1 % 4], reg[arg2 % 4]);
                    break;
                case 10: // MULTIPLY reg[arg1] *= odd_factor
                    reg[arg1 % 4] *= (arg2 | 1);
                    break;
                case 11: // NOP / PASS
                default:
                    break;
            }
        }
    }
};

int main() {
    std::vector<RGB> grid(WIDTH * HEIGHT);
    std::vector<RGB> next_grid(WIDTH * HEIGHT);

    // Seed initial state with pseudo-random RGB noise
    std::mt19937 rng(1337);
    for (auto& cell : grid) {
        cell.r = static_cast<uint8_t>(rng());
        cell.g = static_cast<uint8_t>(rng());
        cell.b = static_cast<uint8_t>(rng());
    }

    // Run automaton simulation loop
    for (int frame = 0; frame < FRAMES; ++frame) {
        char filename[64];
        snprintf(filename, sizeof(filename), "frame_%03d.ppm", frame);
        std::ofstream out(filename, std::ios::binary);
        out << "P6\n" << WIDTH << " " << HEIGHT << "\n255\n";

        for (int y = 0; y < HEIGHT; ++y) {
            for (int x = 0; x < WIDTH; ++x) {
                // Read 3x3 surrounding RGB values into 27-byte bytecode array
                uint8_t bytecode[27];
                int idx = 0;
                for (int dy = -1; dy <= 1; ++dy) {
                    for (int dx = -1; dx <= 1; ++dx) {
                        int nx = (x + dx + WIDTH) % WIDTH;
                        int ny = (y + dy + HEIGHT) % HEIGHT;
                        RGB neighbor = grid[ny * WIDTH + nx];
                        bytecode[idx++] = neighbor.r;
                        bytecode[idx++] = neighbor.g;
                        bytecode[idx++] = neighbor.b;
                    }
                }

                // Prepare VM with current cell's state and spatial coordinates
                VM vm;
                RGB current = grid[y * WIDTH + x];
                vm.reg[0] = current.r;
                vm.reg[1] = current.g;
                vm.reg[2] = current.b;
                vm.reg[3] = static_cast<uint8_t>(x ^ y);

                // Execute bytecode extracted from spatial context
                vm.execute(bytecode, 27);

                // Derive new RGB color from VM execution output
                RGB next;
                next.r = vm.reg[0] ^ vm.reg[1];
                next.g = vm.reg[1] ^ vm.reg[2];
                next.b = vm.reg[2] ^ vm.reg[3];

                next_grid[y * WIDTH + x] = next;

                // Write pixel color to binary PPM frame
                out.put(next.r);
                out.put(next.g);
                out.put(next.b);
            }
        }
        grid = next_grid;
    }

    std::cout << "Generated " << FRAMES << " frame PPM images." << std::endl;
    return 0;
}