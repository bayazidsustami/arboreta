import time
import os
import random
import sys
import math

try:
    import psutil
except ImportError:
    psutil = None

# ANSI Color Definitions
RESET = "\033[0m"
CLEAR_SCREEN = "\033[2J\033[H"
HIDE_CURSOR = "\033[?25l"
SHOW_CURSOR = "\033[?25h"

# Bioluminescent palette (decay of systemic entropy -> vibrant coral hues)
# Deep ocean ambient -> Base coral -> Luminescent active state -> Hyper-thermal spike state
PALETTE = [
    "\033[38;5;18m",   # Very dark blue / ocean void
    "\033[38;5;24m",   # Muted teal
    "\033[38;5;30m",   # Deep cyan
    "\033[38;5;36m",   # Vibrant cyan
    "\033[38;5;43m",   # Aquamarine
    "\033[38;5;50m",   # Glowing teal
    "\033[38;5;86m",   # Bioluminescent green-cyan
    "\033[38;5;121m",  # Neon seafoam
    "\033[38;5;208m",  # Coral orange (thermal reaction)
    "\033[38;5;196m",  # Thermal red spike
]

CHAR_SET = [' ', '.', ':', '~', '=', '+', '*', '#', '%', '@']

def get_cpu_temp():
    """Retrieve current CPU temperature or simulate spike based on CPU load if unavailable."""
    if psutil and hasattr(psutil, "sensors_temperatures"):
        try:
            temps = psutil.sensors_temperatures()
            if temps:
                for name, entries in temps.items():
                    for entry in entries:
                        if entry.current:
                            return entry.current
        except Exception:
            pass
    # Fallback simulation: use CPU usage percentage scaled as pseudo-temperature
    if psutil:
        return 40.0 + (psutil.cpu_percent(interval=None) * 0.5)
    # Generic oscillatory temperature if psutil is not installed
    return 45.0 + 25.0 * math.sin(time.time() * 0.5)

def main():
    # Setup screen dimensions
    try:
        cols, rows = os.get_terminal_size()
    except OSError:
        cols, rows = 80, 24

    rows = max(10, rows - 1)
    cols = max(20, cols)

    # Cellular Automaton Grid: Holds energy/entropy states (0.0 to 1.0+)
    grid = [[0.0 for _ in range(cols)] for _ in range(rows)]
    
    # Seed initial "coral larvae" at the bottom
    for c in range(cols):
        if random.random() < 0.3:
            grid[rows - 1][c] = random.uniform(0.5, 1.0)

    print(HIDE_CURSOR, end="")

    try:
        while True:
            temp = get_cpu_temp()
            # Normalize temp around baseline 45C to high 85C
            thermal_stress = max(0.0, min(1.0, (temp - 40.0) / 45.0))
            
            new_grid = [[0.0 for _ in range(cols)] for _ in range(rows)]

            # Decay and growth rules (Cellular Automaton step)
            for r in range(rows):
                for c in range(cols):
                    # Count neighbors
                    neighbors_energy = 0.0
                    count = 0
                    for dr in (-1, 0, 1):
                        for dc in (-1, 0, 1):
                            if dr == 0 and dc == 0:
                                continue
                            nr, nc = r + dr, c + dc
                            if 0 <= nr < rows and 0 <= nc < cols:
                                neighbors_energy += grid[nr][nc]
                                count += 1

                    avg_neighbor = neighbors_energy / max(1, count)
                    current = grid[r][c]

                    # Entropy decay: cells lose energy over time unless nourished by neighbor density or thermal spikes
                    decay_rate = 0.05 * (1.0 - (thermal_stress * 0.4))
                    
                    if current > 0.1:
                        # Coral structure growth / propagation upwards
                        next_val = current - decay_rate + (avg_neighbor * 0.4)
                    else:
                        # Spontaneous bioluminescent blooming triggered by thermal energy spikes
                        if avg_neighbor > 0.25 and random.random() < (0.1 + thermal_stress * 0.4):
                            next_val = avg_neighbor + random.uniform(0.1, 0.3) + (thermal_stress * 0.3)
                        else:
                            next_val = current * 0.9

                    # Bottom layer regeneration
                    if r == rows - 1 and random.random() < (0.1 + thermal_stress * 0.3):
                        next_val = max(next_val, random.uniform(0.4, 1.0))

                    new_grid[r][c] = max(0.0, min(1.5, next_val))

            grid = new_grid

            # Render ASCII luminescence to buffer
            buffer = [CLEAR_SCREEN]
            for r in range(rows):
                line = []
                for c in range(cols):
                    val = grid[r][c]
                    if val <= 0.05:
                        line.append(' ')
                    else:
                        # Select char based on state density
                        char_idx = min(len(CHAR_SET) - 1, int(val * (len(CHAR_SET) - 1)))
                        char = CHAR_SET[char_idx]

                        # Color mapping driven by energy + thermal reaction
                        color_idx = min(len(PALETTE) - 1, int((val + thermal_stress * 0.5) * (len(PALETTE) - 1) / 1.5))
                        color = PALETTE[color_idx]

                        line.append(f"{color}{char}{RESET}")
                buffer.append("".join(line))
            
            # Status line detailing systemic entropy state
            status = f"\033[38;5;245m[SYSTEM TEMP: {temp:.1f}°C | THERMAL EXCITATION: {thermal_stress*100:.0f}%]\033[0m"
            buffer.append(status)

            sys.stdout.write("\n".join(buffer))
            sys.stdout.flush()

            time.sleep(0.08)

    except KeyboardInterrupt:
        print(SHOW_CURSOR + RESET + "\nReef simulation terminated.")

if __name__ == "__main__":
    main()