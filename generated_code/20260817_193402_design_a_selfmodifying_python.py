import sys
import time
import math
import random
import os

def run_fluid_code():
    # Read self source code
    try:
        with open(__file__, "r") as f:
            source = f.read()
    except Exception:
        source = "def self_modifying_fluid(): pass # fluid simulation code execution error"

    # Tokenize/split source code into readable visual characters
    chars = [c for c in source if c not in ('\r', '\t')]
    if not chars:
        chars = list("print('Fluid Code')")

    # Screen dimensions
    width = 80
    height = 24
    num_particles = min(len(chars), width * height // 3)

    # Grid for fluid simulation (Navier-Stokes style / grid velocity field)
    grid_w, grid_h = 40, 20
    u = [[0.0 for _ in range(grid_h)] for _ in range(grid_w)]
    v = [[0.0 for _ in range(grid_h)] for _ in range(grid_w)]
    density = [[0.0 for _ in range(grid_h)] for _ in range(grid_w)]

    # Particle properties (representing code tokens/syntax elements)
    particles = []
    for i in range(num_particles):
        particles.append({
            'char': chars[i % len(chars)],
            'x': random.uniform(2, width - 3),
            'y': random.uniform(2, height - 3),
            'vx': random.uniform(-0.5, 0.5),
            'vy': random.uniform(-0.5, 0.5)
        })

    # Clear terminal once
    os.system('cls' if os.name == 'nt' else 'clear')

    # Run real-time dynamic ASCII fluid simulation loop
    frames = 60
    for frame in range(frames):
        # Time-varying forces / vortex drive
        t = frame * 0.1
        vortex_x = (math.sin(t) * 0.3 + 0.5) * width
        vortex_y = (math.cos(t * 0.7) * 0.3 + 0.5) * height

        # Update velocity grid & particles
        screen = [[' ' for _ in range(width)] for _ in range(height)]

        for p in particles:
            # Distance to central force
            dx = vortex_x - p['x']
            dy = vortex_y - p['y']
            dist = math.sqrt(dx*dx + dy*dy) + 0.1

            # Rotational / fluid force (vortex + gravity)
            fx = -dy / dist * 0.8 + math.sin(t + p['y']*0.1) * 0.2
            fy =  dx / dist * 0.8 + 0.1 # light gravity

            p['vx'] = (p['vx'] + fx * 0.2) * 0.95
            p['vy'] = (p['vy'] + fy * 0.2) * 0.95

            # Collisions & boundary reflection
            p['x'] += p['vx']
            p['y'] += p['vy']

            if p['x'] < 1:
                p['x'] = 1
                p['vx'] *= -0.8
            elif p['x'] >= width - 1:
                p['x'] = width - 2
                p['vx'] *= -0.8

            if p['y'] < 1:
                p['y'] = 1
                p['vy'] *= -0.8
            elif p['y'] >= height - 1:
                p['y'] = height - 2
                p['vy'] *= -0.8

            # Particle particle reaction/repulsion
            ix, iy = int(p['x']), int(p['y'])
            if 0 <= ix < width and 0 <= iy < height:
                screen[iy][ix] = p['char']

        # Render frame
        buffer = []
        buffer.append("\033[H") # Reset cursor position
        buffer.append(f"=== SELF-SIMULATING CODE FLUID [Frame {frame+1}/{frames}] ===\n")
        buffer.append("+" + "-" * (width - 2) + "+\n")
        for row in screen[1:-1]:
            buffer.append("|" + "".join(row[1:-1]) + "|\n")
        buffer.append("+" + "-" * (width - 2) + "+\n")

        sys.stdout.write("".join(buffer))
        sys.stdout.flush()
        time.sleep(0.04)

    print("\n[Execution complete: Code fluid stabilized without breaking syntax integrity.]")

if __name__ == "__main__":
    run_fluid_code()