import os
import sys
import time
import math
import random

# Enable ANSI escape sequences on Windows terminals
os.system('')

# Determine terminal size dynamically with safe fallbacks
WIDTH, HEIGHT = 80, 24
try:
    columns, rows = os.get_terminal_size()
    WIDTH, HEIGHT = max(40, columns - 1), max(15, rows - 3)
except Exception:
    pass

class Firefly:
    """Represents a glowing ASCII firefly navigating the terminal void."""
    def __init__(self, x, y):
        self.x = float(x)
        self.y = float(y)
        self.vx = random.uniform(-0.4, 0.4)
        self.vy = random.uniform(-0.4, 0.4)
        self.glow = random.random()
        self.decay = random.uniform(0.03, 0.09)

    def update(self, pulse, dna):
        # Apply self-modifying behavioral DNA influenced by system telemetry
        self.vx += random.uniform(-dna['chaos'], dna['chaos']) + math.sin(time.time() * 2.0 + self.y) * 0.05
        self.vy += random.uniform(-dna['chaos'], dna['chaos']) + math.cos(time.time() * 2.0 + self.x) * 0.05
        
        # Velocity dampening for organic movement
        self.vx *= 0.85
        self.vy *= 0.85

        self.x = (self.x + self.vx) % WIDTH
        self.y = (self.y + self.vy) % HEIGHT

        # Respond to erratic heartbeat pulses (simulated cache misses)
        if pulse > 0.65:
            self.glow = 1.0
            self.vx += random.uniform(-1.5, 1.5) * pulse
            self.vy += random.uniform(-1.5, 1.5) * pulse
        else:
            self.glow = max(0.05, self.glow - self.decay)

def get_cache_miss_proxy():
    """Measures high-frequency jitter to proxy erratic CPU cache miss spikes."""
    t0 = time.perf_counter_ns()
    # Lightweight computation loop to induce subtle execution variance
    _ = sum(i * i for i in range(8000))
    t1 = time.perf_counter_ns()
    delta = (t1 - t0) / 1000000.0
    
    base = (delta * 3.5) % 1.0
    spike = 1.0 if random.random() < 0.12 else 0.0
    return min(1.0, base * 0.6 + spike * random.uniform(0.4, 1.0))

def main():
    # Initialize swarm
    fireflies = [Firefly(random.randint(0, WIDTH - 1), random.randint(0, HEIGHT - 1)) for _ in range(40)]
    
    # Self-modifying architectural DNA state
    dna = {'chaos': 0.15, 'mutation_rate': 0.008}
    
    # Hide terminal cursor for smooth rendering
    sys.stdout.write("\x1b[?25l")
    sys.stdout.flush()

    try:
        while True:
            pulse = get_cache_miss_proxy()
            
            # Self-modification: mutate internal chaos based on pulse intensity
            dna['chaos'] = max(0.05, min(0.6, dna['chaos'] + (pulse - 0.5) * dna['mutation_rate']))
            
            # Construct render buffer
            buffer = [[' ' for _ in range(WIDTH)] for _ in range(HEIGHT)]
            
            for f in fireflies:
                f.update(pulse, dna)
                ix, iy = int(f.x) % WIDTH, int(f.y) % HEIGHT
                
                # Map glow intensity to ASCII gradient
                chars = " .·:;*#@?"
                idx = int(f.glow * (len(chars) - 1))
                buffer[iy][ix] = chars[idx]

            # Render frame with ANSI colors
            output = ["\x1b[H"]  # Reset cursor to top-left
            border = "+" + "-" * WIDTH + "+"
            output.append(border + "\n")
            
            for row in buffer:
                line = "|"
                for char in row:
                    if char in "*#@?":
                        line += f"\x1b[92m{char}\x1b[0m"  # High-intensity glowing green
                    elif char in ":;·":
                        line += f"\x1b[32m{char}\x1b[0m"  # Mid-intensity green
                    else:
                        line += char
                line += "|\n"
                output.append(line)
            
            output.append(border + f"\n[DNA Chaos: {dna['chaos']:.3f} | Pulse: {pulse:.2f}] (Press Ctrl+C to exit)")
            
            sys.stdout.write("".join(output))
            sys.stdout.flush()
            time.sleep(0.04)
            
    except KeyboardInterrupt:
        pass
    finally:
        # Restore terminal cursor
        sys.stdout.write("\x1b[?25h\n")
        sys.stdout.flush()

if __name__ == "__main__":
    main()