import sys
import time
import math
import os
import random

# Enable ANSI escape sequences on Windows terminals if needed
if os.name == 'nt':
    os.system('')

# --- Configuration & ASCII Program Grid ---
# ASCII Grid representing the Visual Program Logic:
# Ray sources: '>' (Right), 'v' (Down), '^' (Up), '<' (Left)
# Optical elements: '/' and '\' (Mirrors), '+' (Prism Splitter), 
# 'R','G','B','Y','C','M' (Frequency Shifters), '*' (Quantum Exciter)
PROGRAM_GRID = [
    r"   /-------------------------\   ",
    r"   | >   \        /---/      |   ",
    r"   |     G        |   R   \  |   ",
    r"   |  /-----\     \---/   |  |   ",
    r"   |  |  *  |             |  |   ",
    r"   |  |  B  \-------+     Y  |   ",
    r"   |  \-----/       |     |  |   ",
    r"   |     C        /---\   /  |   ",
    r"   |     \--------| M |------/   ",
    r"   \-------------------------/   "
]

HEIGHT = len(PROGRAM_GRID)
WIDTH = max(len(row) for row in PROGRAM_GRID)

# Directions: 0: UP, 1: RIGHT, 2: DOWN, 3: LEFT
DX = [0, 1, 0, -1]
DY = [-1, 0, 1, 0]

# --- Light Frequency to RGB Mapping ---
COLOR_FREQS = {
    'R': (255, 30, 30),     # Red wavelength (~700nm)
    'G': (30, 255, 30),     # Green wavelength (~530nm)
    'B': (30, 100, 255),    # Blue wavelength (~470nm)
    'Y': (255, 220, 30),    # Yellow (~580nm)
    'C': (30, 255, 255),    # Cyan (~500nm)
    'M': (255, 30, 255),    # Magenta (~400nm)
    'DEFAULT': (200, 200, 255)
}

# --- Fluid Field Simulation Setup ---
# 2D Wave field for fluid dynamics
u_curr = [[0.0 for _ in range(WIDTH)] for _ in range(HEIGHT)]
u_prev = [[0.0 for _ in range(WIDTH)] for _ in range(HEIGHT)]
fluid_rgb = [[(0.0, 0.0, 0.0) for _ in range(WIDTH)] for _ in range(HEIGHT)]

class LightRay:
    """Simulated light ray representing thread execution state & wavelength."""
    def __init__(self, x, y, direction, rgb=(200, 200, 255), energy=1.0):
        self.x = x
        self.y = y
        self.dir = direction  # 0: UP, 1: RIGHT, 2: DOWN, 3: LEFT
        self.rgb = rgb
        self.energy = energy
        self.alive = True

def step_fluid():
    """Simulates 2D wave-based fluid dynamics with damping and diffusion."""
    global u_curr, u_prev, fluid_rgb
    c2 = 0.15      # Wave propagation speed squared
    damping = 0.965 # Energy dissipation rate

    u_next = [[0.0 for _ in range(WIDTH)] for _ in range(HEIGHT)]
    
    for y in range(1, HEIGHT - 1):
        for x in range(1, WIDTH - 1):
            # 2D discrete Laplacian for wave propagation
            laplacian = (u_curr[y+1][x] + u_curr[y-1][x] + 
                         u_curr[y][x+1] + u_curr[y][x-1] - 4 * u_curr[y][x])
            
            # Wave equation integration: u_next = 2*u - u_prev + c^2 * laplacian
            val = (2.0 * u_curr[y][x] - u_prev[y][x] + c2 * laplacian) * damping
            u_next[y][x] = val

            # Dissipate color field
            r, g, b = fluid_rgb[y][x]
            fluid_rgb[y][x] = (r * 0.92, g * 0.92, b * 0.92)

    u_prev = u_curr
    u_curr = u_next

def process_light_rays(rays):
    """Traces light rays through ASCII mirrors, manipulating variables & injecting fluid energy."""
    next_rays = []

    for ray in rays:
        if not ray.alive or ray.energy < 0.05:
            continue

        # Move ray forward
        ray.x += DX[ray.dir]
        ray.y += DY[ray.dir]

        # Bounds check
        if not (0 <= ray.x < WIDTH and 0 <= ray.y < HEIGHT):
            continue

        cell = PROGRAM_GRID[ray.y][ray.x]

        # Inject energy and color into fluid at ray position
        u_curr[ray.y][ray.x] += 1.8 * ray.energy
        cr, cg, cb = fluid_rgb[ray.y][ray.x]
        lr, lg, lb = ray.rgb
        fluid_rgb[ray.y][ray.x] = (
            min(255, cr + lr * 0.6),
            min(255, cg + lg * 0.6),
            min(255, cb + lb * 0.6)
        )

        # Mirror interactions & refraction control flow
        if cell == '/':
            # Reflect: UP(0)<->RIGHT(1), DOWN(2)<->LEFT(3)
            reflect_map = {0: 1, 1: 0, 2: 3, 3: 2}
            ray.dir = reflect_map[ray.dir]
        elif cell == '\\':
            # Reflect: UP(0)<->LEFT(3), DOWN(2)<->RIGHT(1)
            reflect_map = {0: 3, 3: 0, 1: 2, 2: 1}
            ray.dir = reflect_map[ray.dir]
        elif cell in COLOR_FREQS:
            # Frequency shifter: alters light color state
            ray.rgb = COLOR_FREQS[cell]
        elif cell == '+':
            # Prism Splitter: splits ray into two orthogonal rays
            left_dir = (ray.dir - 1) % 4
            right_dir = (ray.dir + 1) % 4
            next_rays.append(LightRay(ray.x, ray.y, left_dir, ray.rgb, ray.energy * 0.6))
            ray.dir = right_dir
            ray.energy *= 0.6
        elif cell == '*':
            # Quantum Exciter: injects randomized high-energy fluid turbulence
            u_curr[ray.y][ray.x] += random.uniform(3.0, 6.0)

        next_rays.append(ray)

    # Spawn new rays from source emitters dynamically
    for y in range(HEIGHT):
        for x in range(len(PROGRAM_GRID[y])):
            char = PROGRAM_GRID[y][x]
            if char in '>v^<':
                dir_idx = '>v^<'.index(char)
                # Align correct direction: > (1), v (2), ^ (0), < (3)
                mapped_dir = [1, 2, 0, 3][dir_idx]
                if random.random() < 0.35: # Pulsing source emission
                    next_rays.append(LightRay(x, y, mapped_dir, COLOR_FREQS['DEFAULT']))

    return next_rays

def render(rays):
    """Renders the combined grid, light rays, and live fluid dynamics using ANSI truecolor."""
    sys.stdout.write("\033[H") # Move cursor home
    
    # Active ray coordinates map for overlay
    ray_coords = {(r.x, r.y): r.rgb for r in rays if r.alive}

    # Gradient density character ramp
    RAMP = " .:-=+*#%@"

    buffer = []
    for y in range(HEIGHT):
        row_str = []
        for x in range(WIDTH):
            cell_char = PROGRAM_GRID[y][x]
            fluid_val = abs(u_curr[y][x])
            fr, fg, fb = fluid_rgb[y][x]

            # Ray overlay prioritized
            if (x, y) in ray_coords:
                rr, rg, rb = ray_coords[(x, y)]
                row_str.append(f"\033[38;2;{int(rr)};{int(rg)};{int(rb)};1m█")
            else:
                # Select visual representation
                char = cell_char if cell_char != ' ' else RAMP[min(len(RAMP) - 1, int(fluid_val * 2.5))]
                
                # Compute truecolor background/foreground blending
                intensity = min(1.0, fluid_val * 0.5)
                r = min(255, int(fr * intensity + (50 if cell_char != ' ' else 0)))
                g = min(255, int(fg * intensity + (50 if cell_char != ' ' else 0)))
                b = min(255, int(fb * intensity + (150 if cell_char != ' ' else 0)))

                if cell_char != ' ':
                    # Optical elements highlighted
                    row_str.append(f"\033[38;2;255;255;255;48;2;{r//2};{g//2};{b//2}m{char}")
                else:
                    row_str.append(f"\033[38;2;{r};{g};{b}m{char}")

        buffer.append("".join(row_str) + "\033[0m")

    sys.stdout.write("\n".join(buffer) + "\n")
    sys.stdout.flush()

def main():
    # Hide terminal cursor and clear screen
    sys.stdout.write("\033[?25l\033[2J")
    rays = []

    try:
        while True:
            step_fluid()
            rays = process_light_rays(rays)
            render(rays)
            time.sleep(0.04) # ~25 FPS runtime loop
    except KeyboardInterrupt:
        # Restore terminal cursor on exit
        sys.stdout.write("\033[?25h\033[0m\n")

if __name__ == "__main__":
    main()