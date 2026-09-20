#include <iostream>
#include <vector>
#include <string>
#include <thread>
#include <chrono>
#include <random>
#include <cmath>

// Terminal Subway Network Visualizer & ASCII Underworld for Lost Packets
// Simulates local network traffic nodes as transit stations, with lost packets as ghost trains.

struct Station {
    int x, y;
    std::string name;
    bool active;
};

struct GhostTrain {
    double x, y;
    double dx, dy;
    int symbol; // ASCII representation
};

int main() {
    const int width = 80;
    const int height = 24;

    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis_x(5, width - 6);
    std::uniform_int_distribution<> dis_y(3, height - 4);

    // Generate procedural "Transit Lines" / Network Nodes
    std::vector<Station> stations = {
        {10, 5, "Gateway-01", true},
        {30, 8, "Subnet-Alpha", true},
        {50, 5, "Local-Host", true},
        {70, 12, "DNS-Hub", false}, // Inactive/Ghost station
        {20, 18, "Firewall-Core", true},
        {60, 18, "Proxy-Node", true}
    };

    // Initialize ghost trains (lost packets echoing in the underworld)
    std::vector<GhostTrain> ghosts;
    for (int i = 0; i < 4; ++i) {
        ghosts.push_back({
            (double)dis_x(gen), (double)dis_y(gen),
            (gen() % 2 == 0 ? 0.5 : -0.5), (gen() % 2 == 0 ? 0.25 : -0.25),
            (i % 2 == 0 ? '~' : 'x')
        });
    }

    int ticks = 0;
    while (ticks < 50) { // Run for 50 frames as a demonstration
        // Clear screen using ANSI escape sequences
        std::cout << "\033[2J\033[1;1H";

        // Render buffer
        std::vector<std::string> screen(height, std::string(width, ' '));

        // Draw borders (The Underworld Bounds)
        for (int x = 0; x < width; ++x) {
            screen[0][x] = '#';
            screen[height - 1][x] = '#';
        }
        for (int y = 0; y < height; ++y) {
            screen[y][0] = '#';
            screen[y][width - 1] = '#';
        }

        // Draw subway tracks connecting stations (Procedural ASCII lines)
        for (size_t i = 0; i < stations.size() - 1; ++i) {
            int x1 = stations[i].x;
            int y1 = stations[i].y;
            int x2 = stations[i + 1].x;
            int y2 = stations[i + 1].y;

            // Simple Manhattan routing for tracks
            int cx = x1;
            while (cx != x2) {
                screen[y1][cx] = '-';
                cx += (x2 > cx) ? 1 : -1;
            }
            int cy = y1;
            while (cy != y2) {
                screen[cy][x2] = '|';
                cy += (y2 > cy) ? 1 : -1;
            }
        }

        // Draw Stations
        for (const auto& station : stations) {
            char marker = station.active ? 'O' : 'X';
            screen[station.y][station.x] = marker;
            // Print station name safely within bounds
            if (station.x + 2 + station.name.length() < width) {
                for (size_t i = 0; i < station.name.length(); ++i) {
                    screen[station.y + 1][station.x + i] = station.name[i];
                }
            }
        }

        // Update and draw Ghost Trains (Lost Packets)
        for (auto& g : ghosts) {
            g.x += g.dx;
            g.y += g.dy;

            // Bounce off walls
            if (g.x <= 1 || g.x >= width - 2) g.dx *= -1;
            if (g.y <= 1 || g.y >= height - 2) g.dy *= -1;

            int ix = static_cast<int>(g.x);
            int iy = static_cast<int>(g.y);
            if (ix > 0 && ix < width - 1 && iy > 0 && iy < height - 1) {
                screen[iy][ix] = g.symbol;
            }
        }

        // Output screen buffer
        std::cout << "=== ASCII UNDERWORLD: NETWORK TRAFFIC & LOST PACKETS ===" << std::endl;
        for (const auto& row : screen) {
            std::cout << row << "\n";
        }
        std::cout << "[Status] Packet loss echoing... Press Ctrl+C to exit." << std::endl;

        std::this_thread::sleep_for(std::chrono::milliseconds(200));
        ticks++;
    }

    return 0;
}