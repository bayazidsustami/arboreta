import sys
import os
import time
import random
import math

# Cross-platform non-blocking input setup for interactive keystroke mutation
try:
    import termios
    import tty
    import select
    HAS_TERMIOS = True
except ImportError:
    HAS_TERMIOS = False
    try:
        import msvcrt
        HAS_MSVCRT = True
    except ImportError:
        HAS_MSVCRT = False

class TerminalFernEngine:
    def __init__(self, text="FRACTAL"):
        self.text = text
        self.width = 80
        self.height = 24
        # Color palettes using ANSI terminal color codes
        self.palettes = [
            [32, 34, 36],   # Forest Emerald & Cyan
            [31, 33, 35],   # Autumn Amber & Magenta
            [36, 37, 96],   # Winter Frost & Ice
            [32, 92, 93],   # Spring Lime & Gold
        ]
        self.palette_idx = 0
        self.wind_speed = 0.5
        self.wind_turbulence = 0.1
        self.season_name = "Spring"
        
        # Coordinate buffer for the recursive fractal fern points
        self.fern_points = []
        self.init_fern()

    def init_fern(self):
        # Initialize Barnsley fern base coordinates via iterated function system (IFS)
        x, y = 0.0, 0.0
        self.fern_points = []
        for _ in range(300):
            r = random.random()
            if r < 0.01:
                x, y = 0.0, 0.16 * y
            elif r < 0.86:
                x, y = 0.85 * x + 0.04 * y, -0.04 * x + 0.85 * y + 1.6
            elif r < 0.93:
                x, y = 0.2 * x - 0.26 * y, 0.23 * x + 0.22 * y + 1.6
            else:
                x, y = -0.15 * x + 0.28 * y, 0.26 * x + 0.24 * y + 0.44
            self.fern_points.append([x, y])

    def step_fern(self):
        # Evolve fern points with seasonal wind dynamics and turbulence
        new_points = []
        for x, y in self.fern_points:
            r = random.random()
            if r < 0.01:
                nx, ny = 0.0, 0.16 * y
            elif r < 0.86:
                nx, ny = 0.85 * x + 0.04 * y, -0.04 * x + 0.85 * y + 1.6
            elif r < 0.93:
                nx, ny = 0.2 * x - 0.26 * y, 0.23 * x + 0.22 * y + 1.6
            else:
                nx, ny = -0.15 * x + 0.28 * y, 0.26 * x + 0.24 * y + 0.44
            
            # Apply dynamic wind distortion
            wind_effect = self.wind_speed * math.sin(time.time() * 2.0 + ny * self.wind_turbulence)
            nx += wind_effect * 0.1
            new_points.append([nx, ny])
        
        if len(new_points) > 500:
            new_points = new_points[-500:]
        self.fern_points = new_points

    def mutate(self):
        # Permanently mutate color palette, seasonal profile, and wind physics on keystroke
        self.palette_idx = (self.palette_idx + 1) % len(self.palettes)
        self.wind_speed = random.uniform(-1.5, 1.5)
        self.wind_turbulence = random.uniform(0.05, 0.5)
        seasons = ["Spring", "Summer", "Autumn", "Winter"]
        self.season_name = random.choice(seasons)
        self.init_fern()

    def render(self):
        # Construct character grid for the current frame
        grid = [[" " for _ in range(self.width)] for _ in range(self.height)]
        
        palette = self.palettes[self.palette_idx]
        color_char = ".,*#@"
        
        # Map fractal fern points to terminal character grid
        for idx, (x, y) in enumerate(self.fern_points):
            gx = int(self.width // 2 + x * 6)
            gy = int(self.height - 2 - y * 2)
            if 0 <= gx < self.width and 0 <= gy < self.height:
                c = color_char[idx % len(color_char)]
                grid[gy][gx] = c

        # Overlay procedural typography text onto the upper canvas
        start_x = max(2, (self.width - len(self.text)) // 2)
        start_y = 2
        for i, char in enumerate(self.text):
            if start_x + i < self.width:
                grid[start_y][start_x + i] = char

        # Render ANSI color frame buffer
        output = []
        output.append("\033[H\033[J")
        output.append(f"=== TYPOGRAPHY FERN ENGINE | Season: {self.season_name} | Wind: {self.wind_speed:.2f} ===\n")
        output.append(f"Press ANY KEY to permanently mutate palette & physics. Press Ctrl+C to exit.\n")
        output.append("+" + "-" * (self.width - 2) + "+\n")
        
        base_color = palette[0]
        for row in grid:
            row_str = "".join(row)
            output.append(f"\033[{base_color}m|{row_str}|\033[0m\n")
        output.append("+" + "-" * (self.width - 2) + "+")
        
        sys.stdout.write("".join(output))
        sys.stdout.flush()

    def run(self):
        old_settings = None
        if HAS_TERMIOS:
            old_settings = termios.tcgetattr(sys.stdin)
            tty.setcbreak(sys.stdin.fileno())

        try:
            os.system('cls' if os.name == 'nt' else 'clear')
            while True:
                key_pressed = False
                if HAS_TERMIOS:
                    if select.select([sys.stdin], [], [], 0)[0]:
                        sys.stdin.read(1)
                        key_pressed = True
                elif HAS_MSVCRT:
                    if msvcrt.kbhit():
                        msvcrt.getch()
                        key_pressed = True

                if key_pressed:
                    self.mutate()

                self.step_fern()
                self.render()
                time.sleep(0.05)
        except KeyboardInterrupt:
            print("\nExiting engine. Goodbye!")
        finally:
            if HAS_TERMIOS and old_settings:
                termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)

if __name__ == "__main__":
    engine = TerminalFernEngine("RECURSION")
    engine.run()