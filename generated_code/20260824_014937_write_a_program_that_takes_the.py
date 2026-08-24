import time
import math
import random
import os
import sys

try:
    import psutil
except ImportError:
    psutil = None

# Botanical character sets ordered by visual density/life stage
CANOPY_CHARS = [" ", ".", "*", "o", "O", "@", "%", "#"]
PETAL_CHARS = ["🌸", "🌹", "🌺", "🌼", "🌻", "❇", "✦", "❀"]
DECAY_CHARS = ["░", "▒", "▓", "█", "†", "‡", "x", "."]

WIDTH = 60
HEIGHT = 20

class DigitalGarden:
    def __init__(self):
        self.width = WIDTH
        self.height = HEIGHT
        self.grid = [[" " for _ in range(self.width)] for _ in range(self.height)]
        self.age = 0

    def get_system_metrics(self):
        """Fetch real-time memory usage and simulate/read thermal throttle state."""
        if psutil:
            mem = psutil.virtual_memory()
            mem_percent = mem.percent
            # Temperature estimation via cpu_percent or psutil sensors if available
            cpu_percent = psutil.cpu_percent(interval=None)
            # High CPU usage / thermal proxy -> simulated throttling factor (0.0 to 1.0)
            thermal_throttle = min(1.0, max(0.0, (cpu_percent - 50) / 50))
        else:
            # Fallback mathematical simulation if psutil isn't installed
            mem_percent = 50 + 40 * math.sin(self.age * 0.1)
            thermal_throttle = max(0.0, math.sin(self.age * 0.05))

        return mem_percent, thermal_throttle

    def generate_fractal_branch(self, x, y, length, angle, depth, mem_factor, throttle):
        """Recursively render fractal plant stems using memory byte dynamics."""
        if depth == 0 or length < 1:
            return

        # Render stem
        for i in range(int(length)):
            cx = int(x + i * math.cos(angle))
            cy = int(y - i * math.sin(angle))
            if 0 <= cx < self.width and 0 <= cy < self.height:
                if throttle > 0.6:  # Decaying stem due to thermal throttling
                    self.grid[cy][cx] = random.choice(DECAY_CHARS[:3])
                else:
                    self.grid[cy][cx] = "|" if abs(angle - math.pi/2) < 0.3 else ("/" if angle > math.pi/2 else "\\")

        # End of branch coordinates
        end_x = x + length * math.cos(angle)
        end_y = y - length * math.sin(angle)

        # Bloom at the tip based on memory state
        if depth == 1 and 0 <= int(end_x) < self.width and 0 <= int(end_y) < self.height:
            if throttle > 0.4:
                self.grid[int(end_y)][int(end_x)] = random.choice(DECAY_CHARS)
            else:
                char_idx = min(len(PETAL_CHARS) - 1, int(mem_factor * len(PETAL_CHARS)))
                self.grid[int(end_y)][int(end_x)] = PETAL_CHARS[char_idx]

        # Branching driven by memory dynamics
        spread = 0.3 + (mem_factor * 0.4)
        decay_factor = 0.7 - (throttle * 0.3)  # Heat causes stunted fractal growth
        
        self.generate_fractal_branch(end_x, end_y, length * decay_factor, angle - spread, depth - 1, mem_factor, throttle)
        self.generate_fractal_branch(end_x, end_y, length * decay_factor, angle + spread, depth - 1, mem_factor, throttle)

    def grow_garden(self):
        """Main rendering loop executing the living digital garden animation."""
        while True:
            self.age += 1
            mem_percent, throttle = self.get_system_metrics()
            mem_factor = mem_percent / 100.0

            # Clear buffer grid
            self.grid = [[" " for _ in range(self.width)] for _ in range(self.height)]

            # Draw Ground / Roots
            for x in range(self.width):
                self.grid[self.height - 1][x] = "=" if throttle < 0.5 else "~"

            # Plant fractal trees seeded across the baseline width
            seeds = [15, 30, 45]
            for seed_x in seeds:
                tree_height = 4 + int(mem_factor * 5)
                self.generate_fractal_branch(
                    x=seed_x, 
                    y=self.height - 2, 
                    length=tree_height, 
                    angle=math.pi/2, 
                    depth=3 + int(mem_factor * 2), 
                    mem_factor=mem_factor, 
                    throttle=throttle
                )

            # Render Screen Buffer
            os.system('cls' if os.name == 'nt' else 'clear')
            print(f"--- 🌿 DIGITAL ASCII GARDEN 🌿 ---")
            print(f"Memory Usage: {mem_percent:.1f}% | Thermal Throttle State: {throttle*100:.1f}%\n")
            for row in self.grid:
                print("".join(row))
            
            print("\n[Press Ctrl+C to terminate garden simulation]")
            time.sleep(0.3)

if __name__ == "__main__":
    garden = DigitalGarden()
    try:
        garden.grow_garden()
    except KeyboardInterrupt:
        print("\nGarden simulation safely terminated.")
        sys.exit(0)