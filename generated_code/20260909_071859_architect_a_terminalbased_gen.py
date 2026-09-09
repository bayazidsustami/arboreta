import curses
import math
import time
import psutil

# Vibrant ASCII motif palette and color indices
PATTERNS = ["░", "▒", "▓", "█", "┼", "╳", "╬", "❖", "✦", "✽", "❈", "◆", "◇", "◈", "◇", "⬡"]

def get_telemetry():
    """Retrieves live system telemetry: CPU load, RAM usage, and CPU temperature."""
    cpu = psutil.cpu_percent(interval=None)
    mem = psutil.virtual_memory().percent
    
    temp = 45.0  # Default baseline fallback temperature
    try:
        temps = psutil.sensors_temperatures()
        if temps:
            for key in ("coretemp", "cpu_thermal", "k10temp", "acpitz"):
                if key in temps and temps[key]:
                    temp = temps[key][0].current
                    break
            else:
                first_key = next(iter(temps))
                if temps[first_key]:
                    temp = temps[first_key][0].current
    except Exception:
        pass
    
    return cpu, mem, temp

def initialize_colors():
    """Initializes ANSI color pairs mapping telemetry spectrums to textile tones."""
    curses.start_color()
    curses.use_default_colors()
    # 1: Indigo/Navy, 2: Cyan/Weave, 3: Warm Amber, 4: Crimson Fire, 5: Emerald Core, 6: Velvet Magenta
    colors = [
        (1, curses.COLOR_BLUE),
        (2, curses.COLOR_CYAN),
        (3, curses.COLOR_YELLOW),
        (4, curses.COLOR_RED),
        (5, curses.COLOR_GREEN),
        (6, curses.COLOR_MAGENTA)
    ]
    for idx, col in colors:
        curses.init_pair(idx, col, -1)

def render_quilt(stdscr):
    """Generates and weaves real-time procedural ASCII textile patterns."""
    curses.curs_set(0)
    stdscr.nodelay(True)
    initialize_colors()

    time_step = 0.0

    while True:
        # Check for user exit (e.g. pressing 'q' or ESC)
        ch = stdscr.getch()
        if ch in (ord('q'), ord('Q'), 27):
            break

        max_y, max_x = stdscr.getmaxyx()
        if max_y < 5 or max_x < 10:
            time.sleep(0.1)
            continue

        # Sample system state
        cpu, mem, temp = get_telemetry()
        time_step += 0.08 + (cpu / 500.0)  # Execution pace speeds up with CPU load

        stdscr.erase()

        # Quilt geometry driven by system parameters
        patch_size = max(4, int(8 + (mem / 15.0)))
        warp = 1.0 + (cpu / 25.0)
        thermal_phase = temp / 10.0

        for y in range(max_y - 2):
            for x in range(max_x - 1):
                # Calculate patch coordinates
                px = x // patch_size
                py = y // patch_size

                # Symmetry mapping for kaleidoscopic textile blocks
                lx = x % patch_size
                ly = y % patch_size
                sym_x = min(lx, patch_size - 1 - lx)
                sym_y = min(ly, patch_size - 1 - ly)

                # Generative wave equations weaving thread fields
                v1 = math.sin((sym_x + px) * warp * 0.5 + time_step)
                v2 = math.cos((sym_y + py) * (60.0 / max(temp, 1.0)) + thermal_phase)
                v3 = math.sin((sym_x + sym_y + px + py) * 0.3 + time_step * 0.5)

                combined = (v1 + v2 + v3 + 3.0) / 6.0  # Normalize to [0, 1]
                
                # Pick character pattern index
                char_idx = int(combined * (len(PATTERNS) - 1)) % len(PATTERNS)
                symbol = PATTERNS[char_idx]

                # Select weave dynamic colors based on local energy and temperature
                if temp > 65.0:
                    color_pair = 4 if (px + py) % 2 == 0 else 3
                elif cpu > 50.0:
                    color_pair = 2 if combined > 0.5 else 6
                else:
                    color_pair = 1 if (px + py) % 2 == 0 else 5

                try:
                    stdscr.addstr(y, x, symbol, curses.color_pair(color_pair))
                except curses.error:
                    pass

        # Draw system telemetry status bar at bottom
        status = f" [ WARP/CPU: {cpu:4.1f}% ]  [ WEFT/MEM: {mem:4.1f}% ]  [ THERMAL: {temp:4.1f}°C ]  (Press 'q' to exit) "
        status_str = status.center(max_x - 1)[:max_x - 1]
        try:
            stdscr.addstr(max_y - 1, 0, status_str, curses.A_REVERSE | curses.color_pair(3))
        except curses.error:
            pass

        stdscr.refresh()
        time.sleep(0.05)

def main():
    curses.wrapper(render_quilt)

if __name__ == "__main__":
    main()