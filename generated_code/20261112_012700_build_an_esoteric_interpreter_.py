import time
import random
import sys
import os

"""
ThermalPoet: An Esoteric CPU-Thermal Poetry Interpreter.
Reads actual CPU thermal zones (or simulates micro-fluctuations) and
translates thermal entropy into cascading verses of floating terminal poetry.
"""

def get_thermal_entropy():
    temps = []
    # Try reading Linux thermal zones
    try:
        thermal_dir = "/sys/class/thermal/"
        if os.path.exists(thermal_dir):
            for name in os.listdir(thermal_dir):
                if name.startswith("thermal_zone"):
                    path = os.path.join(thermal_dir, name, "temp")
                    if os.path.exists(path):
                        with open(path, "r") as f:
                            val = float(f.read().strip())
                            temps.append(val / 1000.0)
    except Exception:
        pass
    
    if not temps:
        # Fallback to simulated micro-fluctuations around a cozy 45.0°C
        base = 45.0 + random.uniform(-1.5, 1.5)
        temps.append(base)
        
    return sum(temps) / len(temps)

ADJECTIVES = ["silicon", "radiant", "volatile", "quantum", "phantom", "dormant", "flickering", "amber", "binary", "dissolving"]
NOUNS = ["current", "voltage", "entropy", "threshold", "cycle", "plasma", "pulse", "core", "shadow", "void"]
VERBS = ["whispers", "melts", "weeps", "computes", "drifts", "awakens", "bleeds", "glows", "collapses", "transcends"]

def synthesize_verse(temp):
    # Use thermal entropy as seed modifier
    seed_val = int((temp * 1000) % 10000)
    rnd = random.Random(seed_val + int(time.time() * 10) % 100)
    
    adj = rnd.choice(ADJECTIVES)
    noun = rnd.choice(NOUNS)
    verb = rnd.choice(VERBS)
    
    return f"the {adj} {noun} {verb} at {temp:.2f}°C"

def main():
    print("\033[2J\033[H", end="")
    print("Initializing ThermalPoet Interpreter...")
    print("Reading CPU breath and thermal tides...\n")
    time.sleep(1)
    
    try:
        while True:
            temp = get_thermal_entropy()
            verse = synthesize_verse(temp)
            
            # Floating effect via ANSI spacing and color
            padding = int(abs(temp * 3) % 40)
            color_code = 31 if temp > 50 else (36 if temp > 40 else 34)
            
            output = f"\033[{color_code}m" + " " * padding + f"~*~ {verse} ~*~" + "\033[0m"
            print(output)
            
            # Fluctuation pause
            time.sleep(0.35)
    except KeyboardInterrupt:
        print("\n\n[Interpreter terminated. The silicon rests.]")

if __name__ == "__main__":
    main()