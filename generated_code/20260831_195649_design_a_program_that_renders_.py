import sys
import psutil
import time
import random
import curses

# --- Coral Reef Memory Visualizer ---
# This script visualizes the Python process's memory usage as an ASCII coral reef.
# It runs in a terminal using the curses library.
# - The 'reef' grows based on memory consumption.
# - High, sustained memory usage simulates 'leaks', causing 'bleaching' (turning white/dim).
# - Memory decreases (simulating garbage collection/freeing) trigger vibrant 'blooms' (colors).
# - It uses psutil to track its own process memory.

# Define simulated "memory leak" behavior for demonstration
class MemoryLeaker:
    def __init__(self):
        self.leaked_data = []
        self.mode = "stable" 
        self.ticks = 0

    def cycle(self):
        self.ticks += 1
        # Artificially cycle through growing, leaking, and cleaning to show effects
        if self.ticks % 150 == 0:
            self.mode = random.choice(["leak", "clean", "stable", "stable"])
            
        if self.mode == "leak":
            self.leaked_data.append("0" * 1024 * 1024) # Leak ~1MB per tick
        elif self.mode == "clean" and self.leaked_data:
            # Simulate garbage collection
            self.leaked_data = self.leaked_data[max(0, len(self.leaked_data) - 5):]
        # 'stable' does nothing to memory

class ReefVisualizer:
    def __init__(self, stdscr):
        self.stdscr = stdscr
        self.process = psutil.Process()
        self.base_mem = self.process.memory_info().rss
        self.max_mem_seen = self.base_mem
        
        # Grid setup
        self.max_y, self.max_x = self.stdscr.getmaxyx()
        self.grid = {} # (y, x) -> {'char': str, 'color': int, 'health': float}
        self.coral_chars = ['*', 'o', '+', 'x', '~', '§', '¶', '8', '&']
        self.bloom_chars = ['@', '#', '%', 'O']
        
        # Color setup
        curses.start_color()
        curses.use_default_colors()
        curses.init_pair(1, curses.COLOR_CYAN, -1)    # Base water/coral
        curses.init_pair(2, curses.COLOR_BLUE, -1)    # Deep water
        curses.init_pair(3, curses.COLOR_GREEN, -1)   # Healthy algae
        curses.init_pair(4, curses.COLOR_MAGENTA, -1) # Bloom
        curses.init_pair(5, curses.COLOR_RED, -1)     # Intense Bloom
        curses.init_pair(6, curses.COLOR_WHITE, -1)   # Bleached
        curses.init_pair(7, curses.COLOR_BLACK, curses.COLOR_WHITE) # Extreme bleach
        
        # Initialize ocean floor
        for x in range(self.max_x):
            self.grid[(self.max_y - 1, x)] = {'char': '_', 'color': 2, 'health': 1.0}

    def get_memory_ratio(self):
        current_mem = self.process.memory_info().rss
        if current_mem > self.max_mem_seen:
            self.max_mem_seen = current_mem
            
        # Ratio of growth since start (can be large if leaking)
        mem_diff_mb = (current_mem - self.base_mem) / (1024 * 1024)
        return current_mem, mem_diff_mb

    def update_reef(self, current_mem, mem_growth_mb, is_gc_event):
        target_size = min((self.max_y * self.max_x) // 2, int(mem_growth_mb * 50) + 10)
        
        # Determine reef stress
        stress_level = min(1.0, mem_growth_mb / 50.0) if mem_growth_mb > 0 else 0
        
        # Grow reef if under target
        if len(self.grid) < target_size:
            # Pick a random existing piece to grow from
            if self.grid:
                y, x = random.choice(list(self.grid.keys()))
                # Prefer growing up or sideways
                dy, dx = random.choice([(-1, 0), (-1, -1), (-1, 1), (0, -1), (0, 1)])
                ny, nx = y + dy, x + dx
                
                if 0 <= ny < self.max_y and 0 <= nx < self.max_x and (ny, nx) not in self.grid:
                    char = random.choice(self.coral_chars)
                    self.grid[(ny, nx)] = {'char': char, 'color': 1, 'health': 1.0 - stress_level}

        # Apply environmental effects
        keys_to_remove = []
        for (y, x), cell in self.grid.items():
            if cell['char'] == '_': continue # Skip floor
            
            # Health degrades under stress (high memory)
            cell['health'] -= (stress_level * 0.05)
            
            # GC Event triggers healing and blooming
            if is_gc_event:
                cell['health'] += 0.5
                if random.random() < 0.1: # 10% chance to bloom on GC
                    cell['char'] = random.choice(self.bloom_chars)
                    cell['color'] = random.choice([4, 5])
            
            cell['health'] = max(0.0, min(1.0, cell['health']))

            # Determine appearance based on health
            if cell['health'] < 0.1:
                cell['color'] = 7 # Severely Bleached
                cell['char'] = '.'
            elif cell['health'] < 0.3:
                cell['color'] = 6 # Bleaching
            elif cell['char'] in self.bloom_chars and cell['health'] > 0.8:
                pass # Keep bloom color
            else:
                # Return to normal color if healthy
                cell['color'] = random.choice([1, 3])
                if cell['char'] in self.bloom_chars:
                   cell['char'] = random.choice(self.coral_chars)

            # Dead coral slowly erodes
            if cell['health'] <= 0.01 and random.random() < 0.01:
                keys_to_remove.append((y, x))

        for k in keys_to_remove:
            del self.grid[k]

    def draw(self, current_mem, mem_growth_mb, mode):
        self.stdscr.clear()
        
        # Draw water background gently
        for y in range(self.max_y):
            if random.random() < 0.05:
                x = random.randint(0, self.max_x - 1)
                try:
                    self.stdscr.addstr(y, x, "~", curses.color_pair(2) | curses.A_DIM)
                except curses.error:
                    pass

        # Draw reef
        for (y, x), cell in self.grid.items():
            try:
                attr = curses.color_pair(cell['color'])
                if cell['health'] > 0.8: attr |= curses.A_BOLD
                if cell['health'] < 0.3: attr |= curses.A_DIM
                self.stdscr.addstr(y, x, cell['char'], attr)
            except curses.error:
                pass # Handle edge of screen drawing issues safely

        # Draw HUD
        hud = f" Mem: {current_mem / (1024*1024):.1f}MB | Growth: +{mem_growth_mb:.1f}MB | Mode: {mode} "
        try:
            self.stdscr.addstr(0, 0, hud[:self.max_x-1], curses.color_pair(6) | curses.A_REVERSE)
        except curses.error:
            pass

        self.stdscr.refresh()

def main(stdscr):
    curses.curs_set(0) # Hide cursor
    stdscr.nodelay(1)  # Non-blocking input
    
    leaker = MemoryLeaker()
    visualizer = ReefVisualizer(stdscr)
    
    last_mem = 0
    
    while True:
        # 1. Update simulation state
        leaker.cycle()
        
        # 2. Measure Memory
        current_mem, mem_growth_mb = visualizer.get_memory_ratio()
        
        # Detect significant drop (simulated Garbage Collection)
        is_gc_event = current_mem < (last_mem - 1024 * 512) # Drop of > 512KB
        last_mem = current_mem

        # 3. Update Visuals
        visualizer.update_reef(current_mem, mem_growth_mb, is_gc_event)
        visualizer.draw(current_mem, mem_growth_mb, leaker.mode)
        
        # 4. Check for exit
        if stdscr.getch() == ord('q'):
            break
            
        time.sleep(0.05)

if __name__ == "__main__":
    try:
        curses.wrapper(main)
    except KeyboardInterrupt:
        sys.exit(0)