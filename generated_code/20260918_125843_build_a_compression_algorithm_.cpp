#include <iostream>
#include <string>
#include <vector>
#include <algorithm>

// Define the vocabulary for our procedural botanical grammar
enum class FloraCommand { RootAnchor, StemBranch, FernLeaf, BlossomFlower, VineTwist };

// Instruction structure representing a single botanical operation
struct GrowthInstruction {
    FloraCommand command;
    int parameter; // e.g., angle, scale, or color index
    char origin_char;
};

// Encodes plain text bytes into a sequence of procedural botanical instructions
std::vector<GrowthInstruction> encodeToFlora(const std::string& plaintext) {
    std::vector<GrowthInstruction> instructions;
    instructions.reserve(plaintext.size());
    
    for (char c : plaintext) {
        FloraCommand cmd = static_cast<FloraCommand>(static_cast<unsigned char>(c) % 5);
        int param = (static_cast<unsigned char>(c) * 13) % 360;
        instructions.push_back({cmd, param, c});
    }
    
    return instructions;
}

// Renders the virtual terrarium to the console based on the growth instructions
void renderVirtualTerrarium(const std::vector<GrowthInstruction>& instructions) {
    std::cout << "========================================" << std::endl;
    std::cout << "      VIRTUAL TERRARIUM ECOSYSTEM       " << std::endl;
    std::cout << "========================================" << std::endl;
    std::cout << "Decoding " << instructions.size() << " botanical instructions...\n" << std::endl;

    int indentation = 0;
    for (const auto& inst : instructions) {
        // Print indentation to reflect spatial hierarchy
        for (int i = 0; i < indentation; ++i) {
            std::cout << "  ";
        }

        switch (inst.command) {
            case FloraCommand::RootAnchor:
                std::cout << "[~] Deep root anchors soil (Char: '" << inst.origin_char << "')" << std::endl;
                indentation = std::max(0, indentation - 1);
                break;
            case FloraCommand::StemBranch:
                std::cout << "/|\\ Stem branches at " << inst.parameter << "° (Char: '" << inst.origin_char << "')" << std::endl;
                indentation++;
                break;
            case FloraCommand::FernLeaf:
                std::cout << " (v) Fern frond unfurls with scale " << (inst.parameter % 10 + 1) << " (Char: '" << inst.origin_char << "')" << std::endl;
                break;
            case FloraCommand::BlossomFlower:
                std::cout << "  * Rare blossom opens, color spectrum index " << (inst.parameter % 7) << " (Char: '" << inst.origin_char << "')" << std::endl;
                break;
            case FloraCommand::VineTwist:
                std::cout << " ~/~ Tendril spirals upward (" << inst.parameter << " units) (Char: '" << inst.origin_char << "')" << std::endl;
                break;
        }
    }

    std::cout << "\n[Terrarium growth cycle complete. Ecosystem thriving.]" << std::endl;
}

int main() {
    // Sample plain text file payload to be compressed into a botanical terrarium
    std::string plaintext = "The quiet forest breathes in green harmony and digital life.";
    
    // Step 1: Compress / Encode text into botanical instructions
    auto growth_instructions = encodeToFlora(plaintext);
    
    // Step 2: Execute instructions to render the unique virtual terrarium
    renderVirtualTerrarium(growth_instructions);
    
    return 0;
}