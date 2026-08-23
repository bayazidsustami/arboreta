import math
import random
import time
import os

# --- ASCII Fluid Dynamics Simulation (Navier-Stokes Grid) ---
WIDTH, HEIGHT = 60, 20
N = WIDTH * HEIGHT

# Fluid arrays
u = [0.0] * N       # Horizontal velocity
v = [0.0] * N       # Vertical velocity
u_prev = [0.0] * N
v_prev = [0.0] * N
dens = [0.0] * N
dens_prev = [0.0] * N

def IX(x, y):
    x = max(0, min(WIDTH - 1, x))
    y = max(0, min(HEIGHT - 1, y))
    return y * WIDTH + x

def add_source(x, s, dt):
    for i in range(N):
        x[i] += dt * s[i]

def diffuse(b, x, x0, diff, dt):
    a = dt * diff * WIDTH * HEIGHT
    for _ in range(4):
        for i in range(1, WIDTH - 1):
            for j in range(1, HEIGHT - 1):
                x[IX(i, j)] = (x0[IX(i, j)] + a * (x[IX(i - 1, j)] + x[IX(i + 1, j)] +
                                                  x[IX(i, j - 1)] + x[IX(i, j + 1)])) / (1 + 4 * a)

def advect(b, d, d0, u, v, dt):
    dt0 = dt * WIDTH
    for i in range(1, WIDTH - 1):
        for j in range(1, HEIGHT - 1):
            x = i - dt0 * u[IX(i, j)]
            y = j - dt0 * v[IX(i, j)]
            x = max(0.5, min(WIDTH - 1.5, x))
            y = max(0.5, min(HEIGHT - 1.5, y))
            i0 = int(x); i1 = i0 + 1
            j0 = int(y); j1 = j0 + 1
            s1 = x - i0; s0 = 1 - s1
            t1 = y - j0; t0 = 1 - t1
            d[IX(i, j)] = s0 * (t0 * d0[IX(i0, j0)] + t1 * d0[IX(i0, j1)]) + \
                          s1 * (t0 * d0[IX(i1, j0)] + t1 * d0[IX(i1, j1)])

def fluid_step(dt=0.1, diff=0.0001, visco=0.0001):
    diffuse(1, u_prev, u, visco, dt)
    diffuse(2, v_prev, v, visco, dt)
    advect(1, u, u_prev, u_prev, v_prev, dt)
    advect(2, v, v_prev, u_prev, v_prev, dt)
    diffuse(0, dens_prev, dens, diff, dt)
    advect(0, dens, dens_prev, u, v, dt)

# Calculate global turbulent kinetic energy/vorticity
def calculate_turbulence():
    turb = 0.0
    for i in range(1, WIDTH - 1):
        for j in range(1, HEIGHT - 1):
            dv_dx = (v[IX(i + 1, j)] - v[IX(i - 1, j)]) / 2.0
            du_dy = (u[IX(i, j + 1)] - u[IX(i, j - 1)]) / 2.0
            vorticity = abs(dv_dx - du_dy)
            turb += vorticity
    return min(1.0, turb / (WIDTH * HEIGHT * 0.1))

# --- Procedural Poetry Engine ---
VOCABULARY = {
    "gentle": {
        "unstressed": ["the", "a", "soft", "sweet", "calm", "pure", "still", "light", "pale", "clear"],
        "iambs": [("the night", "is still"), ("a gentle", "breeze"), ("the calm", "profound"), ("in quiet", "grace")],
        "verbs": ["flows", "gleams", "breathes", "shines", "sleeps", "rests", "fades"]
    },
    "turbulent": {
        "unstressed": ["fierce", "dark", "wild", "deep", "grim", "cold", "mad", "rough", "harsh", "stark"],
        "iambs": [("the storm", "awakes"), ("in raging", "fire"), ("with shattered", "souls"), ("the tempest", "roars")],
        "verbs": ["breaks", "burns", "tears", "screams", "strikes", "crushes", "chokes"]
    }
}

def generate_iambic_line(turbulence):
    # Turbulence determines emotional vocabulary and meter fidelity
    mood = "turbulent" if turbulence > 0.4 else "gentle"
    vocab = VOCABULARY[mood]
    
    # 5 feet for iambic pentameter (da-DUM da-DUM da-DUM da-DUM da-DUM)
    feet = []
    for _ in range(5):
        # High turbulence causes metric variation (trochaic inversions / disrupted cadence)
        if turbulence > 0.6 and random.random() < 0.4:
            # Disruptive foot (STRESSED-unstressed)
            unstr = random.choice(vocab["unstressed"]).upper()
            strss = random.choice(vocab["verbs"])
            feet.append(f"{unstr}-{strss}")
        else:
            # Strict Iambic foot (unstressed-STRESSED)
            unstr = random.choice(vocab["unstressed"])
            strss = random.choice(vocab["verbs"]).upper()
            feet.append(f"{unstr} {strss}")
            
    return " / ".join(feet)

# --- Main Rendering Loop ---
def main():
    os.system('cls' if os.name == 'nt' else 'clear')
    poem_line = "The fluid stirs within the quiet dark..."
    step = 0
    
    try:
        while True:
            # Inject fluid disturbances periodically
            if step % 5 == 0:
                cx = random.randint(5, WIDTH - 6)
                cy = random.randint(3, HEIGHT - 4)
                f = random.uniform(-2.0, 2.0)
                u[IX(cx, cy)] += f
                v[IX(cx, cy)] += random.uniform(-1.5, 1.5)
                dens[IX(cx, cy)] += random.uniform(5.0, 15.0)

            fluid_step()
            turb = calculate_turbulence()
            
            # Generate new line dictated by current fluid turbulence
            if step % 8 == 0:
                poem_line = generate_iambic_line(turb)
                
            # Render ASCII Fluid Canvas
            density_chars = " .:-=+*#%@"
            buffer = []
            for j in range(HEIGHT):
                row = ""
                for i in range(WIDTH):
                    d = dens[IX(i, j)]
                    char_idx = min(len(density_chars) - 1, int(d))
                    row += density_chars[char_idx]
                buffer.append(row)

            # Move cursor to top left
            print("\033[H", end="")
            print("=" * WIDTH)
            print(f" FLUID TURBULENCE INDEX: [{turb:.3f}] | EMOTIONAL CADENCE ".center(WIDTH))
            print("=" * WIDTH)
            for row in buffer:
                print(row)
            print("-" * WIDTH)
            print(f"POETRY: {poem_line}".ljust(WIDTH))
            print("-" * WIDTH)

            step += 1
            time.sleep(0.08)
    except KeyboardInterrupt:
        print("\nSimulation ended.")

if __name__ == "__main__":
    main()