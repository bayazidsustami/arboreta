#include <iostream>
#include <vector>
#include <string>
#include <cmath>
#include <memory>
#include <iomanip>

// Represents historical astronomical log entry
struct CelestialLog {
    std::string timestamp;
    std::string bodyName;
    double magnitude;
    char spectralType; // O, B, A, F, G, K, M
};

// Base class for interactive digital botanical structures
class BotanicalStructure {
protected:
    std::string name;
    double harmonicFrequency;
    int growthStage;

public:
    BotanicalStructure(std::string name, double frequency)
        : name(std::move(name)), harmonicFrequency(frequency), growthStage(0) {}

    virtual ~BotanicalStructure() = default;

    void evolve() { growthStage++; }

    virtual void touch() const = 0;
};

// Fern variant born from faint/cool stars
class StellarFern : public BotanicalStructure {
public:
    StellarFern(const std::string& starName, double freq)
        : BotanicalStructure("Stellar Fern [" + starName + "]", freq) {}

    void touch() const override {
        std::cout << "  [TOUCH] " << name << " sways gracefully. "
                  << "Singing fundamental frequency: " << std::fixed << std::setprecision(2)
                  << harmonicFrequency << " Hz (Rich Deep Bass Resonance)\n";
    }
};

// Orchid variant born from bright/hot stellar bodies
class CosmicOrchid : public BotanicalStructure {
public:
    CosmicOrchid(const std::string& bodyName, double freq)
        : BotanicalStructure("Cosmic Orchid [" + bodyName + "]", freq) {}

    void touch() const override {
        std::cout << "  [TOUCH] " << name << " unfolds luminous petals. "
                  << "Singing harmonic triad: " << std::fixed << std::setprecision(2)
                  << harmonicFrequency << " Hz | " << harmonicFrequency * 1.25 << " Hz | " 
                  << harmonicFrequency * 1.5 << " Hz\n";
    }
};

// Terrarium environment translating decay kinetics into living flora
class DigitalTerrarium {
private:
    std::vector<CelestialLog> logQueue;
    std::vector<std::unique_ptr<BotanicalStructure>> flora;

    // Maps magnitude and spectral class to a musical frequency (Hz)
    double calculateHarmonicFrequency(double mag, char spectrum) const {
        double baseHz = 440.0; // A4 tuning
        double semitoneShift = (3.0 - mag) * 4.0;

        switch (spectrum) {
            case 'O': semitoneShift += 12; break;
            case 'B': semitoneShift += 7;  break;
            case 'A': semitoneShift += 5;  break;
            case 'F': semitoneShift += 2;  break;
            case 'G': semitoneShift += 0;  break;
            case 'K': semitoneShift -= 4;  break;
            case 'M': semitoneShift -= 7;  break;
            default: break;
        }

        return baseHz * std::pow(2.0, semitoneShift / 12.0);
    }

public:
    void logObservation(const std::string& date, const std::string& name, double mag, char spec) {
        logQueue.push_back({date, name, mag, spec});
        std::cout << "Ingested observation log: " << name << " (" << date << ")\n";
    }

    // Process celestial decay into botanical structures
    void decayCelestialBodies() {
        std::cout << "\n--- Initiating Celestial Decay Process ---\n";
        for (const auto& log : logQueue) {
            double freq = calculateHarmonicFrequency(log.magnitude, log.spectralType);
            
            if (log.magnitude < 1.0) {
                flora.push_back(std::make_unique<CosmicOrchid>(log.bodyName, freq));
            } else {
                flora.push_back(std::make_unique<StellarFern>(log.bodyName, freq));
            }
            std::cout << "Starlight from " << log.bodyName << " collapsed and sprouted into flora.\n";
        }
        logQueue.clear();
    }

    // Advance ecological state
    void advanceEcology() {
        for (auto& plant : flora) {
            plant->evolve();
        }
    }

    // Trigger interactive harmonic singing
    void interact() const {
        std::cout << "\n--- Touching Terrarium Flora ---\n";
        for (const auto& plant : flora) {
            plant->touch();
        }
    }
};

int main() {
    DigitalTerrarium terrarium;

    // Load historical astronomical observation logs
    terrarium.logObservation("1604-10-09", "Kepler's Supernova", -2.5, 'O');
    terrarium.logObservation("1843-03-11", "Eta Carinae Outburst", -1.0, 'B');
    terrarium.logObservation("1910-05-18", "Halley's Comet", 0.0, 'A');
    terrarium.logObservation("1987-02-23", "SN 1987A", 2.9, 'K');

    // Decay starlight logs into digital botanical structures
    terrarium.decayCelestialBodies();

    // Evolve terrarium state over cycles
    terrarium.advanceEcology();

    // Touch flora to emit harmonic frequencies
    terrarium.interact();

    return 0;
}