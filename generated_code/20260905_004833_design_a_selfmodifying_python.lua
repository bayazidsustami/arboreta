-- Lua script that outputs a complete, self-modifying Python script.
-- The generated Python script renders its own execution stack as an evolving ASCII fluid simulation.

local python_code = [=[
import inspect
import math
import os
import sys
import time

class ASCIIFluidSim:
    def __init__(self, width=60, height=20):
        self.w = width
        self.h = height
        self.size = width * height
        self.u = [0.0] * self.size
        self.v = [0.0] * self.size
        self.u_prev = [0.0] * self.size
        self.v_prev = [0.0] * self.size
        self.density = [0.0] * self.size
        self.density_prev = [0.0] * self.size
        self.chars = " .:-=+*#%@"

    def IX(self, x, y):
        x = max(0, min(self.w - 1, int(x)))
        y = max(0, min(self.h - 1, int(y)))
        return x + y * self.w

    def add_source(self, x, y, amount, vx=0.0, vy=0.0):
        idx = self.IX(x, y)
        self.density[idx] += amount
        self.u[idx] += vx
        self.v[idx] += vy

    def step(self):
        # Diffuse and propagate density/velocity gradients
        for y in range(1, self.h - 1):
            for x in range(1, self.w - 1):
                idx = self.IX(x, y)
                avg_d = (self.density[self.IX(x+1, y)] + self.density[self.IX(x-1, y)] +
                         self.density[self.IX(x, y+1)] + self.density[self.IX(x, y-1)]) / 4.0
                self.density_prev[idx] = self.density[idx] * 0.85 + avg_d * 0.12

        # Advect density based on velocity vectors
        for y in range(self.h):
            for x in range(self.w):
                idx = self.IX(x, y)
                prev_x = x - self.u[idx]
                prev_y = y - self.v[idx]
                p_idx = self.IX(prev_x, prev_y)
                self.density[idx] = self.density_prev[p_idx] * 0.98

    def render(self, stack_frames):
        os.system('cls' if os.name == 'nt' else 'clear')
        buffer = []
        for y in range(self.h):
            row = []
            for x in range(self.w):
                d = self.density[self.IX(x, y)]
                char_idx = min(len(self.chars) - 1, max(0, int(d * (len(self.chars) - 1))))
                row.append(self.chars[char_idx])
            buffer.append("".join(row))

        # Overlay execution stack onto the fluid field
        print("=== SELF-MODIFYING FLUID EXECUTION STACK ===")
        for i, frame in enumerate(stack_frames[:self.h - 2]):
            line = f"Frame {i}: {frame.function}() | Vars: {frame.f_locals}"
            if i < len(buffer):
                orig_row = buffer[i + 1]
                # Overlay text over fluid characters
                blended = "".join(line[j] if j < len(line) else orig_row[j] for j in range(min(len(line), self.w)))
                buffer[i + 1] = blended + orig_row[len(blended):]

        print("\n".join(buffer))
        print("=" * self.w)

sim = ASCIIFluidSim()

def modify_self_and_mutate(depth, val):
    # Retrieve current stack frame
    stack = inspect.stack()
    
    # Induce variable mutations (ripples/sources in fluid)
    ripple_x = (depth * 7 + int(val)) % sim.w
    ripple_y = depth % sim.h
    sim.add_source(ripple_x, ripple_y, amount=2.5, vx=math.cos(depth), vy=math.sin(depth))
    sim.step()
    sim.render(stack)
    time.sleep(0.15)

    # Self-modifying step: alter script file dynamically on deep frames
    if depth == 3:
        try:
            with open(__file__, 'r') as f:
                content = f.read()
            # Mutate variable multiplier in code dynamically
            if "val * 1.5" not in content:
                new_content = content.replace("val * 2", "val * 1.5")
                with open(__file__, 'w') as f:
                    f.write(new_content)
        except Exception:
            pass

    if depth > 0:
        # Recursive call inducing changing local state
        modify_self_and_mutate(depth - 1, val * 2)

if __name__ == "__main__":
    for cycle in range(5):
        modify_self_and_mutate(6, cycle + 1)
]=]

print(python_code)