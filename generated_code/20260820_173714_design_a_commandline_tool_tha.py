import asyncio
import math
import random
import sys
import os
from collections import deque

# --- CONFIGURATION & CONSTANTS ---
GRID_WIDTH = 80
GRID_HEIGHT = 22
BOTANICAL_CHARS = [" ", "·", "v", "Y", "Ψ", "❀", "✿", "❁", "❃", "❋"]
WITHERED_CHARS = ["🥀", "x", "†", "╎"]

# --- GARDEN ENGINE ---
class Flower:
    def __init__(self, x, y):
        self.x = x
        self.y = y
        self.stage = 0.0  # 0.0 (seed) to 1.0 (full bloom)
        self.health = 1.0 # 1.0 (healthy) to 0.0 (withered)
        self.bloom_hue = 0 # Visual variation index

    def update(self, bandwidth_load, loss_rate):
        # High bandwidth stimulates growth and extra blooming
        growth_rate = 0.05 + (bandwidth_load * 0.15)
        self.stage = min(1.0, self.stage + growth_rate)

        # Packet loss causes withering
        if loss_rate > 0.1:
            self.health = max(0.0, self.health - (loss_rate * 0.2))
        else:
            self.health = min(1.0, self.health + 0.05)

        self.bloom_hue = (self.bloom_hue + int(bandwidth_load * 10)) % 6

    def render(self):
        if self.health < 0.3:
            return random.choice(WITHERED_CHARS)
        
        idx = int(self.stage * (len(BOTANICAL_CHARS) - 1))
        char = BOTANICAL_CHARS[idx]

        # Apply kaleidoscope ANSI coloring based on bandwidth activity
        if self.stage > 0.7:
            colors = [31, 33, 32, 36, 34, 35]  # Red, Yellow, Green, Cyan, Blue, Magenta
            color = colors[self.bloom_hue]
            return f"\033[1;{color}m{char}\033[0m"
        elif self.health < 0.6:
            return f"\033[33m{char}\033[0m"  # Dimmer yellow for struggling plants
        else:
            return f"\033[32m{char}\033[0m"  # Standard green stem/flower

class DigitalGarden:
    def __init__(self, width, height):
        self.width = width
        self.height = height
        self.flowers = {}
        self.bandwidth_history = deque(maxlen=width)
        self.init_garden()

    def init_garden(self):
        # Seed initial flowers along the garden bed
        for _ in range(15):
            x = random.randint(0, self.width - 1)
            y = random.randint(3, self.height - 1)
            self.flowers[(x, y)] = Flower(x, y)

    def pulse(self, bandwidth, loss):
        self.bandwidth_history.append(bandwidth)

        # High activity spawns new buds
        if bandwidth > 0.5 and len(self.flowers) < 40:
            x = random.randint(0, self.width - 1)
            y = random.randint(3, self.height - 1)
            if (x, y) not in self.flowers:
                self.flowers[(x, y)] = Flower(x, y)

        # Update existing ecosystem
        for flower in list(self.flowers.values()):
            flower.update(bandwidth, loss)

    def render(self, bytes_sec, loss_rate):
        buffer = [[" " for _ in range(self.width)] for _ in range(self.height)]

        # Render Flowers
        for (x, y), flower in self.flowers.items():
            buffer[y][x] = flower.render()

        # Render Live Telemetry Header
        header = f" ✿ DIGITAL GARDEN ✿ | Traffic: {bytes_sec/1024:.1f} KB/s | Loss: {loss_rate*100:.1f}% "
        header_str = header.center(self.width, "─")
        
        # Assemble frame
        frame = [f"\033[1;36m{header_str}\033[0m"]
        for row in buffer:
            frame.append("".join(row))

        # Bottom soil line
        frame.append("\033[32m" + "▔" * self.width + "\033[0m")
        return "\n".join(frame)

# --- NETWORK SIMULATION / SENSORS ---
class NetworkMonitor:
    """Simulates real-time network activity (Bandwidth spikes & Packet loss)."""
    def __init__(self):
        self.time = 0

    async def sample(self):
        self.time += 0.2
        # Generate organic traffic waves using sine overlays + random bursts
        base_traffic = (math.sin(self.time) + 1) / 2
        burst = random.random() if random.random() > 0.8 else 0
        bandwidth = min(1.0, base_traffic * 0.6 + burst * 0.4)
        
        # Simulate occasional loss spikes
        loss = random.random() * 0.4 if random.random() > 0.85 else 0.001
        
        bytes_transferred = int(bandwidth * 1024 * 500) # Up to 500 KB/s
        return bytes_transferred, bandwidth, loss

# --- MAIN LOOP ---
async def main():
    monitor = NetworkMonitor()
    garden = DigitalGarden(GRID_WIDTH, GRID_HEIGHT)

    # Hide cursor
    sys.stdout.write("\033[?25l")
    # Clear screen
    sys.stdout.write("\033[2J")

    try:
        while True:
            bytes_sec, bandwidth, loss = await monitor.sample()
            garden.pulse(bandwidth, loss)

            # Move cursor to top left and redraw
            sys.stdout.write("\033[H")
            sys.stdout.write(garden.render(bytes_sec, loss))
            sys.stdout.flush()

            await asyncio.sleep(0.15)
    except KeyboardInterrupt:
        pass
    finally:
        # Restore cursor
        sys.stdout.write("\033[?25h\n")

if __name__ == "__main__":
    asyncio.run(main())