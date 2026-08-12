import os
import sys
import time
import math
import random
import tracemalloc

# Initialize memory tracking
tracemalloc.start()

# Visual typography glyph sets driven by thermal state / simulated fluctuation
GLYPHS = [" ", "·", "•", "░", "▒", "▓", "█", "▲", "◆", "◈", "❖", "⚡", "🔥"]
MUSICAL_NOTES = ["♩", "♪", "♫", "♬", "♭", "♮", "♯", "🎼", "🎹"]

def get_cpu_thermal_fluctuation():
    """Reads processor temperature or simulates thermal noise based on CPU load activity."""
    try:
        # Try reading Linux thermal zone if available
        if os.path.exists("/sys/class/thermal/thermal_zone0/temp"):
            with open("/sys/class/thermal/thermal_zone0/temp", "r") as f:
                return float(f.read().strip()) / 1000.0
    except Exception:
        pass
    # Fallback to simulated thermal dynamics using math & time
    base = 45.0
    noise = math.sin(time.time() * 2.5) * 12.0 + math.cos(time.time() * 0.7) * 8.0
    return base + abs(noise) + random.uniform(0, 3)

def generate_typography(temp):
    """Converts thermal fluctuations into dynamic visual typography."""
    index = int((temp - 30) / 4) % len(GLYPHS)
    density = max(1, min(40, int(temp / 2)))
    glyph = GLYPHS[index]
    return f"\033[38;5;{int(temp * 3) % 256}m" + (glyph * density) + "\033[0m"

def mutate_to_musical_score(code_line, memory_bytes):
    """Mutates a line of code into a musical score as its memory footprint grows."""
    note_count = max(1, memory_bytes // 512)
    score = []
    for i, char in enumerate(code_line):
        if i < note_count:
            note = MUSICAL_NOTES[(ord(char) + memory_bytes) % len(MUSICAL_NOTES)]
            score.append(f"\033[36m{note}\033[0m")
        else:
            score.append(char)
    return "".join(score)

def interpret_and_visualize(source_code):
    """Esoteric interpreter loop executing source lines while rendering thermal typography and audio-visual scores."""
    print("\033[2J\033[H--- ESOTERIC THERMAL-CODE INTERPRETER ACTIVATED ---")
    memory_allocator = []

    lines = source_code.strip().split("\n")
    for cycle in range(50):
        # Mutate memory footprint artificially to simulate growing code state
        memory_allocator.append(" " * (cycle * 1024))
        current_mem, _ = tracemalloc.get_traced_memory()
        
        temp = get_cpu_thermal_fluctuation()
        typo = generate_typography(temp)
        
        line_idx = cycle % len(lines)
        mutated_line = mutate_to_musical_score(lines[line_idx], current_mem)
        
        sys.stdout.write(f"\r[Temp: {temp:.1f}°C] [{typo}] | Score: {mutated_line} (Mem: {current_mem} B)\n")
        sys.stdout.flush()
        
        # Audio feedback trigger (system acoustic pulse)
        sys.stdout.write("\a")
        time.sleep(0.12)

SAMPLE_SOURCE = """def resonance_loop(energy):
    return sum([energy ** 2 for energy in range(100)])
core_temp = measure_heat()
synthesize_sound_wave(core_temp)"""

if __name__ == "__main__":
    interpret_and_visualize(SAMPLE_SOURCE)