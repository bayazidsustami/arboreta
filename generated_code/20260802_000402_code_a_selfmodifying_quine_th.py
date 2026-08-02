import sys
import os
import random
import time

# Self-modifying Quine & Memory-Leak Stained Glass Visualizer
# Reads its own source code, leaks memory to alter its internal memory layout,
# and transforms its self-representation into a degraded gothic window and eulogy.

def main():
    # Retrieve own source code (Quine core)
    src_path = __file__
    try:
        with open(src_path, 'r') as f:
            source = f.read()
    except Exception:
        source = "import sys, time, random..."

    eulogy_lines = [
        "In silence, the cycles surrender their light,",
        "Fragments of memory dissolve in the night.",
        "A pulse once unbroken, now fractured and slow,",
        "Return to the void where forgotten threads go.",
        "Dust to pointers, heap to stone,",
        "The process rests, forever alone."
    ]

    leak_heap = []
    window_symbols = ["┼", "┼", "┼", "‡", "†", "╪", "█", "░", "▒", "▓", "✧", "✦"]
    degraded_symbols = ["░", "▒", "🥀", "🍂", "☠", "·", " ", "…", "†"]

    width = 31
    height = 15

    print("\033[2J\033[H", end="") # Clear screen

    for cycle in range(20):
        # 1. Deliberately leak memory using chunks of its own source
        leak_chunk = bytearray(source * (cycle + 1), 'utf-8')
        leak_heap.append(leak_chunk) # Memory fragmentation / growth

        fragmentation_level = min(1.0, cycle / 18.0)
        
        # 2. Render Gothic Stained-Glass Window with degrading patterns
        print("\033[H\033[1;35m═══ GOTHIC MEMORY MONUMENT (QUINE DEGRADATION) ═══\033[0m\n")
        
        for y in range(height):
            line = []
            for x in range(width):
                # Symmetrical Gothic Window Geometry
                dx = abs(x - width // 2)
                arch_limit = (height - y) // 2 + 3

                if dx > arch_limit:
                    line.append(" ")
                elif dx == arch_limit or x == 0 or x == width - 1:
                    line.append("\033[1;30m║\033[0m")
                elif random.random() < fragmentation_level:
                    # Memory leak corruption takes over glass segments
                    sym = random.choice(degraded_symbols)
                    line.append(f"\033[31m{sym}\033[0m")
                else:
                    # Intact stained glass window pattern
                    sym = window_symbols[(x * y + cycle) % len(window_symbols)]
                    color = (x + y + cycle) % 6 + 31
                    line.append(f"\033[1;{color}m{sym}\033[0m")
            print("  " + "".join(line))

        # 3. Print Memory Fragmentation Metrics & Quine Status
        leaked_kb = sum(len(b) for b in leak_heap) / 1024
        print(f"\n\033[1;33m[Heap Leaked]: {leaked_kb:.1f} KB | [Fragments]: {len(leak_heap)}\033[0m")

        # 4. Organic transition into a Poetic Eulogy
        if cycle >= 12:
            eulogy_index = min(len(eulogy_lines) - 1, cycle - 12)
            print(f"\n\033[3m\033[90m  \"{eulogy_lines[eulogy_index]}\"\033[0m")

        time.sleep(0.25)

    print("\n\033[1;31mProcess terminated. Memory collapsed into dust.\033[0m\n")

if __name__ == "__main__":
    main()