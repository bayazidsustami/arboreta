#include <iostream>
#include <vector>
#include <string>
#include <cmath>
#include <random>
#include <sstream>
#include <iomanip>
#include <algorithm>

struct Star {
    std::string commit_hash;
    std::string message;
    char spectral_class;
    std::string color_hex;
    double temperature_k;
    double magnitude;
    double orbital_radius;
    double current_angle;
    double angular_velocity;
};

struct OrbitingBranch {
    std::string branch_name;
    double semi_major_axis;
    double eccentricity;
    std::vector<Star> stars;
};

class ConstellationEngine {
private:
    std::vector<OrbitingBranch> constellation;
    std::mt19937 rng;

    std::size_t hash_string(const std::string& str) {
        std::hash<std::string> hasher;
        return hasher(str);
    }

    // Maps commit message entropy/hash to Morgan-Keenan spectral classification
    void classify_spectral_star(const std::string& msg, Star& star) {
        std::size_t val = hash_string(msg);
        char classes[] = {'O', 'B', 'A', 'F', 'G', 'K', 'M'};
        
        // Use hash bits to determine spectral class
        int class_idx = val % 7;
        star.spectral_class = classes[class_idx];

        switch (star.spectral_class) {
            case 'O': star.color_hex = "#9bb0ff"; star.temperature_k = 33000.0; star.magnitude = -4.0; break;
            case 'B': star.color_hex = "#aabfff"; star.temperature_k = 15000.0; star.magnitude = -1.5; break;
            case 'A': star.color_hex = "#cad7ff"; star.temperature_k = 8500.0;  star.magnitude = 0.5;  break;
            case 'F': star.color_hex = "#f8f7ff"; star.temperature_k = 6500.0;  star.magnitude = 2.5;  break;
            case 'G': star.color_hex = "#fff4ea"; star.temperature_k = 5500.0;  star.magnitude = 4.8;  break;
            case 'K': star.color_hex = "#ffd2a1"; star.temperature_k = 4000.0;  star.magnitude = 6.5;  break;
            case 'M': star.color_hex = "#ffcc6f"; star.temperature_k = 3000.0;  star.magnitude = 9.0;  break;
        }

        // Modulate magnitude based on message length (longer commits -> brighter stars)
        star.magnitude -= std::min(2.0, static_cast<double>(msg.length()) / 20.0);
    }

public:
    ConstellationEngine() : rng(1337) {}

    void process_branch(const std::string& branch_name, const std::vector<std::pair<std::string, std::string>>& commits) {
        OrbitingBranch branch;
        branch.branch_name = branch_name;
        
        // Branch name determines gravitational orbit scale
        std::size_t branch_hash = hash_string(branch_name);
        branch.semi_major_axis = 10.0 + (branch_hash % 50);
        branch.eccentricity = (branch_hash % 40) / 100.0; // 0.0 to 0.39 eccentricity

        double base_radius = branch.semi_major_axis;
        double radius_offset = 0.5;

        for (const auto& [hash, msg] : commits) {
            Star star;
            star.commit_hash = hash;
            star.message = msg;
            
            classify_spectral_star(msg, star);

            std::size_t commit_val = hash_string(hash);
            star.orbital_radius = base_radius + (commit_val % 5) - 2.5;
            star.current_angle = (commit_val % 360) * (M_PI / 180.0);
            
            // Kepler's Third Law approximation: v ~ 1 / sqrt(r)
            star.angular_velocity = 0.05 / std::sqrt(star.orbital_radius);

            branch.stars.push_back(star);
            base_radius += radius_offset;
        }

        constellation.push_back(branch);
    }

    void step_simulation(double delta_time) {
        for (auto& branch : constellation) {
            for (auto& star : branch.stars) {
                star.current_angle += star.angular_velocity * delta_time;
                if (star.current_angle >= 2 * M_PI) {
                    star.current_angle -= 2 * M_PI;
                }
            }
        }
    }

    void render_frame(int frame_num) const {
        std::cout << "--- Constellation Map Frame " << std::setw(3) << frame_num << " ---\n";
        for (const auto& branch : constellation) {
            std::cout << "Orbiting Branch: [" << branch.branch_name 
                      << "] (Semi-Major Axis: " << branch.semi_major_axis << " AU)\n";
            for (const auto& star : branch.stars) {
                // Orbital mechanics coordinate translation: r = a(1 - e^2) / (1 + e*cos(theta))
                double r = (branch.semi_major_axis * (1 - branch.eccentricity * branch.eccentricity)) 
                         / (1 + branch.eccentricity * std::cos(star.current_angle));
                
                double x = r * std::cos(star.current_angle);
                double y = r * std::sin(star.current_angle);

                std::cout << "  * Star [" << star.commit_hash.substr(0, 7) << "] "
                          << "Class " << star.spectral_class << " (" << star.color_hex << ") "
                          << "| Pos: (" << std::fixed << std::setprecision(2) << std::setw(6) << x 
                          << ", " << std::setw(6) << y << ") "
                          << "| Msg: \"" << star.message << "\"\n";
            }
        }
        std::cout << "\n";
    }
};

int main() {
    ConstellationEngine engine;

    // Simulated Git commit history per branch
    std::vector<std::pair<std::string, std::string>> main_commits = {
        {"8f4a21b", "Initial commit: Core engine structure"},
        {"3c91a0e", "Fix memory leak in astronomical parser"},
        {"1a2b3c4", "Refactor orbital vector math"}
    };

    std::vector<std::pair<std::string, std::string>> feature_commits = {
        {"7e8d9f0", "Add spectral classifier for O-type stars"},
        {"2b4c6d8", "Implement Keplerian dynamic velocity scaling"},
        {"9a8b7c6", "WIP shader integration for glowing cosmic dust"}
    };

    engine.process_branch("main", main_commits);
    engine.process_branch("feature/stellar-rendering", feature_commits);

    // Run dynamic evolution simulation
    for (int frame = 1; frame <= 3; ++frame) {
        engine.render_frame(frame);
        engine.step_simulation(1.5);
    }

    return 0;
}