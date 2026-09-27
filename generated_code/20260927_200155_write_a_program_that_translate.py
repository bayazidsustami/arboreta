import time
import random
import math
import os
import sys

# Mythical Archipelago Simulator driven by simulated CPU thermal fluctuations and packet drops.
# This script renders an evolving ASCII topographical map directly in your terminal.

WIDTH, HEIGHT = 50, 22

# Initialize the island grid with organic elevation values (0 to 9)
grid = [[int(max(0, 5 + 3 * math.sin(x/4.0) * math.cos(y/4.0) + random.uniform(-1, 1))) 
         for x in range(WIDTH)] for y in range(HEIGHT)]

def render_map(temp, erosion_active):
    # Clear screen for smooth real-time updates
    os.system('cls' if os.name == 'nt' else 'clear')
    print("==================================================")
    print("      ARCHIPELAGO OF AETHELGARD: LIVE TOPOGRAPHY  ")
    print(f"  CPU Thermal State: {temp:.2f}°C | Packet Status: {'CRITICAL DROP' if erosion_active else 'Stable'} ")
    print("==================================================")
    
    # Elevation character gradient from deep sea to mountain peak
    chars = " .~+*#&@"
    for row in grid:
        line = "".join(chars[min(val, len(chars)-1)] for val in row)
        print(line)
    print("==================================================")
    print("Press Ctrl+C to halt the simulation.")

def simulate():
    base_temp = 50.0
    try:
        while True:
            # Simulate real-time thermal oscillation (CPU cache load simulation)
            base_temp += random.gauss(0, 2.0)
            base_temp = max(35.0, min(90.0, base_temp))
            
            # Simulate occasional network packet loss (triggers permanent erosion)
            packet_dropped = random.random() < 0.20
            
            if packet_dropped:
                # Erosion event: carves away sections of the map permanently
                for _ in range(4):
                    rx = random.randint(0, WIDTH - 1)
                    ry = random.randint(0, HEIGHT - 1)
                    grid[ry][rx] = max(0, grid[ry][rx] - 2)
            
            # High temperatures cause tectonic uplift, low temperatures settle land
            for y in range(HEIGHT):
                for x in range(WIDTH):
                    if base_temp > 70.0 and random.random() < 0.08:
                        grid[y][x] = min(8, grid[y][x] + 1)
                    elif base_temp < 45.0 and random.random() < 0.04:
                        grid[y][x] = max(0, grid[y][x] - 1)

            render_map(base_temp, packet_dropped)
            time.sleep(0.4)
            
    except KeyboardInterrupt:
        print("\nSimulation terminated. The digital sea reclaims the remnants.")

if __name__ == "__main__":
    simulate()