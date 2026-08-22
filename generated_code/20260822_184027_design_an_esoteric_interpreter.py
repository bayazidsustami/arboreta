import random
import math

class EsotericLandscapeInterpreter:
    def __init__(self, ascii_art):
        self.code = [line.rstrip() for line in ascii_art.strip().split('\n')]
        self.stack = []
        self.history = []
        
    def step(self, char):
        """Map ASCII landscape characters to stack manipulations."""
        if char == '/':  # Ascend: Push height/position-based value
            self.stack.append(len(self.stack) + 1)
        elif char == '\\':  # Descend: Pop value if available
            if self.stack:
                self.stack.pop()
        elif char == '^':  # Peak: Duplicate top
            if self.stack:
                self.stack.append(self.stack[-1])
        elif char == 'v':  # Valley: Invert top value
            if self.stack:
                self.stack[-1] = -self.stack[-1]
        elif char == '~':  # Water/Flat: Arithmetic blend
            if len(self.stack) >= 2:
                b, a = self.stack.pop(), self.stack.pop()
                self.stack.append(a + b)
        elif char == '*':  # Celestial/Star: Multiply top values
            if len(self.stack) >= 2:
                self.stack.append(self.stack.pop() * self.stack.pop())
        elif char.isdigit():  # Push literal numbers
            self.stack.append(int(char))
            
        # Record current execution depth (stack height) to trace memory execution
        self.history.append(len(self.stack))

    def run(self):
        """Execute the ASCII landscape scanning row by row."""
        for row in self.code:
            for char in row:
                if char != ' ':
                    self.step(char)
        return self.history

def midpoint_displacement(values, roughness=0.5):
    """Generate a 1D fractal terrain array seeded by execution history."""
    if not values:
        return [0]
    
    # Pad input to nearest power of two length
    target_len = 2 ** math.ceil(math.log2(max(len(values), 2))) + 1
    terrain = [0.0] * target_len
    
    # Seed terrain anchor points using execution history
    step_size = (target_len - 1) // max(1, len(values) - 1) or 1
    for i, val in enumerate(values):
        idx = min(i * step_size, target_len - 1)
        terrain[idx] = float(val)

    # Apply Midpoint Displacement algorithm
    displacement = max(values) if values else 1.0
    stride = target_len - 1
    
    random.seed(sum(values))  # Deterministic seed based on memory profile
    
    while stride > 1:
        half = stride // 2
        for i in range(0, target_len - 1, stride):
            mid = i + half
            avg = (terrain[i] + terrain[i + stride]) / 2.0
            offset = random.uniform(-displacement, displacement)
            terrain[mid] = avg + offset
        displacement *= roughness
        stride = half

    return terrain

def render_ascii_terrain(terrain, width=60, height=12):
    """Render 1D fractal terrain map to terminal."""
    min_val, max_val = min(terrain), max(terrain)
    val_range = max_val - min_val if max_val != min_val else 1.0
    
    # Resample terrain to target visual width
    resampled = []
    for i in range(width):
        idx = int(i * (len(terrain) - 1) / (width - 1))
        resampled.append(terrain[idx])

    # Draw matrix
    grid = [[' ' for _ in range(width)] for _ in range(height)]
    
    for x, val in enumerate(resampled):
        normalized = (val - min_val) / val_range
        y = int(normalized * (height - 1))
        y = max(0, min(height - 1, height - 1 - y))  # Invert Y for terminal display
        
        # Terrain gradient styling
        if y < height * 0.3:
            grid[y][x] = '^'  # Mountain peaks
        elif y < height * 0.7:
            grid[y][x] = '#'  # Hills
        else:
            grid[y][x] = '~'  # Lowlands / Water

    return '\n'.join(''.join(row) for row in grid)

# --- Sample Execution ---
if __name__ == "__main__":
    # Sample ASCII Art Landscape acting as source code
    ascii_landscape_code = """
           /\\
          /  \\    ^
   /\\    /    \\  / \\   *
  /  \\  /  ~~  \\/   \\ v
 /    \\/             \\
    """

    # 1. Interpret ASCII code and capture stack execution history
    interpreter = EsotericLandscapeInterpreter(ascii_landscape_code)
    history = interpreter.run()

    # 2. Synthesize fractal terrain elevation from stack history trace
    fractal_elevation = midpoint_displacement(history, roughness=0.45)

    # 3. Output results
    print("=== ASCII SOURCE CODE ===")
    print(ascii_landscape_code)
    print("=== STACK MEMORY EXECUTION HISTORY ===")
    print(history)
    print("\n=== GENERATED FRACTAL TERRAIN MAP ===")
    print(render_ascii_terrain(fractal_elevation))