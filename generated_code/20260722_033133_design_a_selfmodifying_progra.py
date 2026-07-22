import sys
import os
import time
import math
import random
import ctypes

# Initialize canvas dimensions and setup terminal display
WIDTH, HEIGHT = 60, 28
os.system('cls' if os.name == 'nt' else 'clear')
sys.stdout.write("\033[?25l")  # Hide terminal cursor

# Vibrant 256-color palette for generative stained glass
PALETTE = [19, 21, 27, 33, 39, 45, 51, 82, 118, 154, 190, 202, 208, 220, 226, 198, 162, 126, 90, 54]

class HeapCanvas:
    """Translates real heap memory addresses and fragmentation into a Voronoi stained-glass visual."""
    def __init__(self, width, height):
        self.w = width
        self.h = height
        self.seeds = []       # Store (x, y, color) generated from real heap addresses
        self.allocations = [] # Hold heap references to manipulate garbage collection & fragmentation

    def allocate_and_fragment(self, step):
        # Allocate dynamic byte arrays to claim real memory blocks
        size = random.randint(256, 8192)
        buf = bytearray(size)
        address = id(buf)  # Unique heap pointer address

        # Self-modify memory byte contents based on execution state
        for i in range(min(16, size)):
            buf[i] = (step * 31 + i * 7) % 256

        # Map raw memory pointer address bits to 2D spatial coordinates
        x = (address >> 4) % self.w
        y = (address >> 9) % self.h
        color = PALETTE[(address ^ step) % len(PALETTE)]

        self.seeds.append((x, y, color))
        self.allocations.append(buf)

        # Intentionally induce heap fragmentation by releasing non-contiguous memory chunks
        if len(self.allocations) > 6 and random.random() > 0.35:
            target = random.randint(0, len(self.allocations) - 2)
            del self.allocations[target]

    def render(self):
        # Render Voronoi glass cells with dark leaded borders (lead came)
        if not self.seeds:
            return

        active_seeds = self.seeds[-35:] # Track current memory frontier
        output = []

        for y in range(self.h):
            row = []
            for x in range(self.w):
                d1, d2 = float('inf'), float('inf')
                closest_color = 0

                # Compute distance to closest memory seed points
                for sx, sy, sc in active_seeds:
                    dist = (x - sx)**2 + (y - sy)**2
                    if dist < d1:
                        d2 = d1
                        d1 = dist
                        closest_color = sc
                    elif dist < d2:
                        d2 = dist

                # Draw dark border lead lines on Voronoi boundaries
                if math.sqrt(d2) - math.sqrt(d1) < 0.75:
                    row.append("\033[48;5;233m\033[38;5;238m┼\033[0m")
                else:
                    row.append(f"\033[48;5;{closest_color}m \033[0m")

            output.append("".join(row))

        # Redraw canvas frame-buffer
        sys.stdout.write("\033[H" + "\n".join(output))
        sys.stdout.flush()

def execute_self_modifying_code(cycle):
    # Dynamically generate, compile, and execute mutated code blocks at runtime
    code_body = f"def dynamic_kernel(c): return (c * {cycle % 13 + 3}) ^ 0xAF"
    namespace = {}
    exec(code_body, namespace)
    return namespace['dynamic_kernel'](cycle)

def trigger_artful_crash(depth, canvas):
    # Infinite recursive call designed to overflow stack memory with visual flair
    if depth > 0:
        trigger_artful_crash(depth + 1, canvas)

def main():
    canvas = HeapCanvas(WIDTH, HEIGHT)
    step = 0

    try:
        while True:
            step += 1
            canvas.allocate_and_fragment(step)
            _ = execute_self_modifying_code(step)
            canvas.render()
            time.sleep(0.04)

            # Initiate critical memory threshold condition for graceful terminal crash
            if step >= 75:
                trigger_artful_crash(1, canvas)

    except (RecursionError, KeyboardInterrupt, Exception) as err:
        # Graceful, artful termination display
        sys.stdout.write("\033[?25h\033[0m\n\n")
        border = "═" * (WIDTH + 2)
        print(f"\033[1;33m╔{border}╗\033[0m")
        print(f"\033[1;33m║\033[0m  \033[1;31mARTFUL CRASH ENCOUNTERED\033[0m: Memory Topology Transformed{' ' * (WIDTH - 55)}\033[1;33m║\033[0m")
        print(f"\033[1;33m║\033[0m  Exception: {type(err).__name__:<18} | Allocations: {len(canvas.seeds):<5}{' ' * (WIDTH - 49)}\033[1;33m║\033[0m")
        print(f"\033[1;33m╚{border}╝\033[0m")

if __name__ == "__main__":
    main()