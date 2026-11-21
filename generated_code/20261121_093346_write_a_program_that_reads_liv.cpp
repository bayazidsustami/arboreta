#include <iostream>
#include <vector>
#include <string>
#include <thread>
#include <chrono>
#include <random>
#include <cmath>
#include <algorithm>

// A coastal buoy weather telemetry simulator and 1D Cellular Automaton Harp
class CoastalBuoyHarpSystem {
private:
    int stateSize = 32;
    std::vector<int> caState;
    double windSpeed = 0.0;
    double waterTemp = 0.0;
    std::mt19937 rng;

    // Simulate fetching live weather telemetry from a coastal buoy
    void fetchTelemetry() {
        std::uniform_real_distribution<double> windDist(0.0, 25.0);
        std::uniform_real_distribution<double> tempDist(10.0, 25.0);
        windSpeed = windDist(rng);
        waterTemp = tempDist(rng);
    }

    // Mutate CA based on weather parameters
    void evolveCA() {
        std::vector<int> nextState = caState;
        int rule = (static_cast<int>(windSpeed * 10) % 2 == 0) ? 30 : 110;

        for (int i = 1; i < stateSize - 1; ++i) {
            int left = caState[i - 1];
            int center = caState[i];
            int right = caState[i + 1];
            int neighborhood = (left << 2) | (center << 1) | right;

            if (rule == 30) {
                nextState[i] = (neighborhood == 1 || neighborhood == 2 || neighborhood == 3 || neighborhood == 4) ? 1 : 0;
            } else {
                nextState[i] = (neighborhood == 1 || neighborhood == 2 || neighborhood == 3 || neighborhood == 5 || neighborhood == 6) ? 1 : 0;
            }
        }
        caState = nextState;
    }

    // Pluck detuned harp strings based on active cellular automaton cells
    void pluckHarpStrings() {
        const double baseFrequency = 220.0; 
        std::cout << "\n[Buoy Telemetry] Wind: " << windSpeed << " m/s | Temp: " << waterTemp << " C\n";
        std::cout << "Harp Plucks: ";
        for (int i = 0; i < stateSize; ++i) {
            if (caState[i] == 1) {
                double detuneOffset = std::sin(waterTemp + i) * 2.5;
                double freq = baseFrequency * std::pow(2.0, (i - stateSize / 2.0) / 12.0) + detuneOffset;
                std::cout << "~(" << i << ":" << static_cast<int>(freq) << "Hz) ";
            } else {
                std::cout << ". ";
            }
        }
        std::cout << std::endl;
    }

public:
    CoastalBuoyHarpSystem() : rng(std::random_device{}()) {
        caState.resize(stateSize, 0);
        caState[stateSize / 2] = 1;
    }

    void run(int steps = 10) {
        for (int s = 0; s < steps; ++s) {
            fetchTelemetry();
            evolveCA();
            pluckHarpStrings();
            std::this_thread::sleep_for(std::chrono::milliseconds(400));
        }
    }
};

int main() {
    std::cout << "Initializing Coastal Buoy Cellular Automaton Harp...\n";
    CoastalBuoyHarpSystem system;
    system.run(15);
    return 0;
}