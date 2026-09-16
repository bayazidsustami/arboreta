import os
import sys
import time
import random
import math
import shutil

# Ensure proper ANSI color support across platforms
if os.name == 'nt':
    os.system('')

def get_terminal_dimensions():
    cols, rows = shutil.get_terminal_size(fallback=(80, 24))
    return cols, rows

class PsychedelicFungiEngine:
    def __init__(self):
        self.cols, self.rows = get_terminal_dimensions()
        self.grid_width = max(40, self.cols // 2)
        self.grid_height = max(15, self.rows - 5)
        self.grid = [[0.0 for _ in range(self.grid_width)] for _ in range(self.grid_height)]
        self.packet_loss = 5.0
        self.tick = 0
        
    def update_packet_loss(self):
        # Simulate volatile network packet loss via a stochastic random walk
        delta = random.uniform(-5.0, 5.0)
        self.packet_loss = max(0.0, min(100.0, self.packet_loss + delta))
        
    def step(self):
        self.tick += 1
        self.update_packet_loss()
        
        # Adapt dynamically to terminal window resizing
        cols, rows = get_terminal_dimensions()
        target_w = max(40, cols // 2)
        target_h = max(15, rows - 5)
        if target_w != self.grid_width or target_h != self.grid_height:
            self.grid_width = target_w
            self.grid_height = target_h
            self.grid = [[0.0 for _ in range(self.grid_width)] for _ in range(self.grid_height)]

        # Decay existing fungal biomass
        new_grid = [[max(0.0, val - 0.04) for val in row] for row in self.grid]
        
        # Inject new digital spores proportional to packet loss severity
        spore_count = int(1 + (self.packet_loss / 8.0))
        for _ in range(spore_count):
            rx = random.randint(0, self.grid_width - 1)
            ry = random.randint(0, self.grid_height - 1)
            new_grid[ry][rx] = min(12.0, new_grid[ry][rx] + 4.0)

        # Mycelial growth simulation: spread energy to adjacent nodes
        for y in range(self.grid_height):
            for x in range(self.grid_width):
                val = self.grid[y][x]
                if val > 0.4:
                    for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, 1), (-1, 1), (1, -1)]:
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < self.grid_width and 0 <= ny < self.grid_height:
                            new_grid[ny][nx] = min(12.0, new_grid[ny][nx] + val * 0.12)
                            
        self.grid = new_grid

    def render(self):
        output = []
        # Clear screen and move cursor to top-left
        output.append("\033[H\033[3J")
        output.append(f"\033[1;35m🍄 DIGITAL MYCELIUM ENGINE 🍄\033[0m [Simulated Packet Loss: \033[1;31m{self.packet_loss:05.2f}%\033[0m] [Tick: {self.tick}]\n")
        
        chars = " .·:=+*#%@█"
        center_x = self.grid_width / 2.0
        center_y = self.grid_height / 2.0
        
        for y in range(self.grid_height):
            line = []
            for x in range(self.grid_width):
                val = self.grid[y][x]
                if val <= 0.05:
                    line.append(" ")
                else:
                    # Calculate vibrant psychedelic 256-color patterns using trigonometric geometry
                    dist = math.hypot(x - center_x, (y - center_y) * 1.8)
                    color_code = int((math.sin(dist * 0.25 - self.tick * 0.15) + math.cos(x * 0.1 + y * 0.1)) * 80 + 128) % 232 + 16
                    char_idx = int(min(len(chars) - 1, val * 0.75))
                    char = chars[char_idx]
                    line.append(f"\033[38;5;{color_code}m{char}\033[0m")
            output.append("".join(line) + "\n")
            
        output.append("\033[1;32m[+] Consuming memory blocks & excreting geometric spores. Press Ctrl+C to exit.\033[0m")
        sys.stdout.write("".join(output))
        sys.stdout.flush()

def main():
    engine = PsychedelicFungiEngine()
    # Hide terminal cursor for smooth rendering
    sys.stdout.write("\033[?25l")
    try:
        while True:
            engine.step()
            engine.render()
            time.sleep(0.07)
    except KeyboardInterrupt:
        pass
    finally:
        # Restore terminal state
        sys.stdout.write("\033[?25h\033[0m\n")
        sys.exit(0)

if __name__ == "__main__":
    main()