import curses
import random
import math
import time
from collections import defaultdict

# Sound engine using standard ANSI terminal bell or system sound
# Uses math-based frequency mapping to ASCII pitch/chords
def play_note(frequency, duration=0.05):
    # Terminal bell frequency variation proxy via visual/audio pulse
    print("\a", end="", flush=True)

class TextPhysicsAutomaton:
    def __init__(self, width, height):
        self.w = width
        self.h = height
        # Dynamic grid for text structure physics
        self.grid = [[' ' for _ in range(width)] for _ in range(height)]
        self.mass = [[0 for _ in range(width)] for _ in range(height)]
        self.chars = " #$%&@*+=-:."
        self.spawn_initial_structures()

    def spawn_initial_structures(self):
        # Seed the grid with structural text elements
        for _ in range(15):
            cx, cy = random.randint(5, self.w - 6), random.randint(3, self.h - 4)
            size = random.randint(3, 6)
            for dy in range(-size, size + 1):
                for dx in range(-size, size + 1):
                    if 0 <= cy + dy < self.h and 0 <= cx + dx < self.w:
                        if dx * dx + dy * dy <= size * size:
                            char = random.choice("#$%&@*")
                            self.grid[cy + dy][cx + dx] = char
                            self.mass[cy + dy][cx + dx] = len(self.chars) - self.chars.find(char)

    def step(self):
        new_grid = [[' ' for _ in range(self.w)] for _ in range(self.h)]
        new_mass = [[0 for _ in range(self.w)] for _ in range(self.h)]
        collapsed_notes = []

        # Cellular automaton rules driven by ASCII text physics
        for y in range(self.h - 1, -1, -1):
            for x in range(self.w):
                if self.grid[y][x] == ' ':
                    continue

                m = self.mass[y][x]
                
                # Calculate local spatial density (neighbors count)
                density = 0
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < self.h and 0 <= nx < self.w:
                            if self.grid[ny][nx] != ' ':
                                density += 1

                # Structural integrity & gravity collapse
                if y + 1 < self.h and self.grid[y + 1][x] == ' ':
                    # Fall down due to gravity
                    new_grid[y + 1][x] = self.grid[y][x]
                    new_mass[y + 1][x] = m
                elif y + 1 < self.h and density > 6:
                    # High density over-compression causes text collapse & acoustic release
                    collapse_char = self.chars[max(0, self.chars.find(self.grid[y][x]) - 1)]
                    if collapse_char != ' ':
                        new_grid[y][x] = collapse_char
                        new_mass[y][x] = m - 1
                    else:
                        # Full collapse trigger -> sound generation
                        freq = 220 * (2 ** ((x / self.w * 24) / 12))  # Scale pitch by X position
                        collapsed_notes.append((freq, density))
                else:
                    # Diagonal dispersion when blocked
                    sides = [-1, 1]
                    random.shuffle(sides)
                    moved = False
                    for dx in sides:
                        if 0 <= x + dx < self.w and y + 1 < self.h and self.grid[y + 1][x + dx] == ' ':
                            new_grid[y + 1][x + dx] = self.grid[y][x]
                            new_mass[y + 1][x + dx] = m
                            moved = True
                            break
                    if not moved:
                        new_grid[y][x] = self.grid[y][x]
                        new_mass[y][x] = m

        self.grid = new_grid
        self.mass = new_mass
        return collapsed_notes

    def inject_text(self, x, y, text):
        for i, char in enumerate(text):
            if 0 <= x + i < self.w and 0 <= y < self.h:
                self.grid[y][x + i] = char
                self.mass[y][x + i] = 10

def main(stdscr):
    curses.curs_set(0)
    stdscr.nodelay(True)
    stdscr.timeout(50)

    h, w = stdscr.getmaxyx()
    sim = TextPhysicsAutomaton(w, h - 2)

    last_sound_time = 0

    while True:
        stdscr.erase()

        # Handle user input to spawn structure streams
        key = stdscr.getch()
        if key == ord('q') or key == 27:
            break
        elif key == ord(' '):
            sim.spawn_initial_structures()
        elif key != -1:
            # Drop user typed character into physics simulation
            sim.inject_text(random.randint(5, w - 5), 1, chr(key if 32 <= key <= 126 else 65))

        # Advance physics automaton step
        sound_events = sim.step()

        # Audio synthesis trigger based on density collapses
        if sound_events and (time.time() - last_sound_time > 0.08):
            freq, density = sound_events[0]
            play_note(freq)
            last_sound_time = time.time()

        # Render ASCII grid to terminal screen
        for y in range(sim.h):
            for x in range(sim.w):
                ch = sim.grid[y][x]
                if ch != ' ':
                    color = (ord(ch) % 6) + 1
                    try:
                        stdscr.addch(y, x, ch, curses.A_BOLD if color > 3 else curses.A_NORMAL)
                    except curses.error:
                        pass

        # Instructions / HUD
        status = f" [ASCII TEXT PHYSICS AUTOMATON]  Press Space: Seed | Type: Inject Text | Q: Quit "
        try:
            stdscr.addstr(h - 1, 0, status[:w - 1], curses.A_REVERSE)
        except curses.error:
            pass

        stdscr.refresh()
        time.sleep(0.03)

if __name__ == "__main__":
    curses.wrapper(main)