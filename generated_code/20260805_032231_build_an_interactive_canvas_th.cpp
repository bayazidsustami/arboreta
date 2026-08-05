#include <SFML/Graphics.hpp>
#include <vector>
#include <cmath>
#include <cstdlib>
#include <ctime>
#include <algorithm>
#include <memory>

// Simulation Constants
constexpr int WINDOW_WIDTH = 1280;
constexpr int WINDOW_HEIGHT = 720;
constexpr float PI = 3.14159265358979323846f;

// Utility for pseudo system metrics simulation
struct SystemMetrics {
    float cpuTemperature = 45.0f; // Celsius (40C to 90C range)
    int activeThreads = 120;       // Simulated active thread count

    void update(float deltaTime) {
        static float timeAcc = 0.0f;
        timeAcc += deltaTime;
        
        // Dynamic fluctuation simulating real system workload
        cpuTemperature = 55.0f + 25.0f * std::sin(timeAcc * 0.3f) + (std::rand() % 100 / 50.0f - 1.0f) * 3.0f;
        cpuTemperature = std::clamp(cpuTemperature, 35.0f, 95.0f);

        activeThreads += (std::rand() % 5) - 2;
        activeThreads = std::clamp(activeThreads, 40, 300);
    }
};

// Represents a polyp node in the growing digital coral
class CoralPolyp {
public:
    sf::Vector2f position;
    sf::Vector2f velocity;
    float radius;
    float maxRadius;
    float health = 1.0f; // 1.0 = Vibrant, 0.0 = Bleached White
    sf::Color baseColor;
    std::vector<std::shared_ptr<CoralPolyp>> children;
    int depth = 0;

    CoralPolyp(sf::Vector2f pos, sf::Vector2f vel, float rad, sf::Color col, int d = 0)
        : position(pos), velocity(vel), radius(1.0f), maxRadius(rad), baseColor(col), depth(d) {}

    void update(float deltaTime, float bleachRate) {
        // Bleaching mechanics governed by CPU Temperature
        if (bleachRate > 0.0f) {
            health = std::max(0.0f, health - bleachRate * deltaTime);
        } else {
            health = std::min(1.0f, health + 0.05f * deltaTime);
        }

        // Coral growth
        if (radius < maxRadius) {
            radius += 2.0f * deltaTime;
        }

        position += velocity * deltaTime;
        velocity *= 0.95f; // Drag

        for (auto& child : children) {
            child->update(deltaTime, bleachRate);
        }
    }

    void draw(sf::RenderWindow& window) const {
        // Interpolate color from vibrant baseColor to bleached stark white/grey
        sf::Color currentColor(
            static_cast<sf::Uint8>(baseColor.r * health + 220 * (1.0f - health)),
            static_cast<sf::Uint8>(baseColor.g * health + 225 * (1.0f - health)),
            static_cast<sf::Uint8>(baseColor.b * health + 235 * (1.0f - health)),
            200
        );

        sf::CircleShape shape(radius);
        shape.setOrigin(radius, radius);
        shape.setPosition(position);
        shape.setFillColor(currentColor);
        window.draw(shape);

        // Draw structural connections to children
        for (const auto& child : children) {
            sf::Vertex line[] = {
                sf::Vertex(position, currentColor),
                sf::Vertex(child->position, currentColor)
            };
            window.draw(line, 2, sf::Lines);
            child->draw(window);
        }
    }

    void spawnSubPolyp() {
        if (depth > 5) return; // Prevent infinite branch depth

        float angle = (std::rand() % 360) * PI / 180.0f;
        float speed = 10.0f + (std::rand() % 20);
        sf::Vector2f childVel(std::cos(angle) * speed, std::sin(angle) * speed - 15.0f);
        sf::Vector2f childPos = position + sf::Vector2f(std::cos(angle) * radius, std::sin(angle) * radius);

        // Color variation for aesthetic diversity
        sf::Color childColor = baseColor;
        childColor.r = std::clamp(baseColor.r + (std::rand() % 40 - 20), 0, 255);
        childColor.g = std::clamp(baseColor.g + (std::rand() % 40 - 20), 0, 255);

        auto newChild = std::make_shared<CoralPolyp>(childPos, childVel, maxRadius * 0.8f, childColor, depth + 1);
        children.push_back(newChild);
    }
};

int main() {
    std::srand(static_cast<unsigned>(std::time(nullptr)));

    sf::RenderWindow window(sf::VideoMode(WINDOW_WIDTH, WINDOW_HEIGHT), "System Process Digital Coral Reef Ecosystem");
    window.setFramerateLimit(60);

    SystemMetrics metrics;
    std::vector<std::shared_ptr<CoralPolyp>> reefRoots;

    // Seed initial coral structures along the seabed
    for (int i = 0; i < 7; ++i) {
        sf::Vector2f rootPos(150.0f + i * 160.0f + (std::rand() % 40), WINDOW_HEIGHT - 30.0f);
        sf::Color colorPalette[] = {
            sf::Color(255, 107, 107), // Coral Pink
            sf::Color(78, 205, 196),  // Bio Cyan
            sf::Color(255, 230, 109), // Warm Yellow
            sf::Color(149, 117, 205), // Deep Violet
            sf::Color(106, 176, 76)   // Sea Green
        };
        sf::Color rootColor = colorPalette[i % 5];
        reefRoots.push_back(std::make_shared<CoralPolyp>(rootPos, sf::Vector2f(0.0f, -5.0f), 12.0f, rootColor));
    }

    sf::Clock clock;
    int lastObservedThreads = metrics.activeThreads;

    // Load GUI Font for real-time diagnostic overlay
    sf::Font font;
    sf::Text hudText;
    bool fontLoaded = font.loadFromFile("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf");
    if (fontLoaded) {
        hudText.setFont(font);
        hudText.setCharacterSize(16);
        hudText.setFillColor(sf::Color::White);
        hudText.setPosition(20.0f, 20.0f);
    }

    while (window.isOpen()) {
        float deltaTime = clock.restart().asSeconds();

        sf::Event event;
        while (window.pollEvent(event)) {
            if (event.type == sf::Event::Closed)
                window.close();
        }

        // Update system telemetry
        metrics.update(deltaTime);

        // Bleaching Severity proportional to high CPU Temperature (> 65 C triggers thermal stress)
        float thermalStress = std::max(0.0f, metrics.cpuTemperature - 60.0f) / 35.0f; 
        float bleachRate = thermalStress * 0.25f;

        // Thread Spawning Logic: New threads trigger growth bursts in random reef branches
        if (metrics.activeThreads > lastObservedThreads) {
            int newSpawns = metrics.activeThreads - lastObservedThreads;
            for (int k = 0; k < newSpawns; ++k) {
                if (!reefRoots.empty()) {
                    int targetRootIdx = std::rand() % reefRoots.size();
                    
                    // Traverse down to a random leaf node to spawn a new polyp
                    auto current = reefRoots[targetRootIdx];
                    while (!current->children.empty() && (std::rand() % 100 > 30)) {
                        current = current->children[std::rand() % current->children.size()];
                    }
                    current->spawnSubPolyp();
                }
            }
        }
        lastObservedThreads = metrics.activeThreads;

        // Update all coral structures
        for (auto& root : reefRoots) {
            root->update(deltaTime, bleachRate);
        }

        // Render scene
        sf::Color deepOceanColor(10, 20, 35);
        window.clear(deepOceanColor);

        // Render seabed line
        sf::RectangleShape seabed(sf::Vector2f(WINDOW_WIDTH, 40.0f));
        seabed.setPosition(0.0f, WINDOW_HEIGHT - 40.0f);
        seabed.setFillColor(sf::Color(15, 28, 44));
        window.draw(seabed);

        // Render digital coral reef
        for (const auto& root : reefRoots) {
            root->draw(window);
        }

        // Draw Telemetry HUD
        if (fontLoaded) {
            hudText.setString(
                "SYSTEM TELEMETRY METRICS:\n"
                "------------------------------\n"
                "CPU Temp: " + std::to_string(static_cast<int>(metrics.cpuTemperature)) + " C " + (thermalStress > 0.2f ? "[THERMAL BLEACHING ACTIVE]" : "[OPTIMAL]") + "\n" +
                "Active Threads: " + std::to_string(metrics.activeThreads) + " (Triggers Polyp Spawning)\n"
            );
            window.draw(hudText);
        }

        window.display();
    }

    return 0;
}