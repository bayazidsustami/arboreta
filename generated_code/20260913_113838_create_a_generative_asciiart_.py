import curses
import math
import random
import time
import urllib.request
import json
import threading

class RadioStarMap:
    def __init__(self, stdscr):
        self.stdscr = stdscr
        self.stars = []
        self.constellations = []
        self.radio_flux = 1.0
        self.data_source = "SIMULATED DEEP SKY"
        self.running = True
        self.time_offset = 0.0

    def fetch_radio_data(self):
        """Fetch real-time data from a space weather / radio astronomy endpoint or fallback."""
        try:
            # Fetching real-time solar radio flux (10.7cm radio flux) from NOAA SWPC API
            url = "[https://services.swpc.noaa.gov/json/f107_index_1d.json](https://services.swpc.noaa.gov/json/f107_index_1d.json)"
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=3) as response:
                data = json.loads(response.read().decode())
                if data and len(data) > 0:
                    latest_flux = float(data[-1].get("flux", 100.0))
                    # Normalize flux around typical baseline (approx 70-200 sfu)
                    self.radio_flux = max(0.5, min(3.0, latest_flux / 100.0))
                    self.data_source = f"NOAA 10.7cm RADIO FLUX: {latest_flux:.1f} sfu"
                    return
        except Exception:
            pass
        self.radio_flux = 1.0 + 0.3 * math.sin(time.time() / 10.0)
        self.data_source = "NOAA REAL-TIME STREAM (OFFLINE - SIMULATING)"

    def generate_sky(self, height, width):
        """Generates procedural stars and procedural constellation connections."""
        self.stars = []
        num_stars = int((height * width) * 0.08)
        
        # Star spectral types / ascii chars mapped to intensity
        chars = [".", "·", "°", "*", "o", "O", "@", "✦", "★"]
        
        for _ in range(num_stars):
            y = random.randint(2, height - 3)
            x = random.randint(1, width - 2)
            base_mag = random.random()
            freq = random.uniform(0.5, 3.0)
            phase = random.uniform(0, 2 * math.pi)
            self.stars.append({
                "y": y, "x": x, "mag": base_mag, 
                "freq": freq, "phase": phase, "char_idx": int(base_mag * (len(chars) - 1))
            })

        # Procedurally connect bright stars to form constellations
        bright_stars = [s for s in self.stars if s["mag"] > 0.65]
        self.constellations = []
        for i, s1 in enumerate(bright_stars):
            for s2 in bright_stars[i+1:]:
                dist = math.hypot(s1["x"] - s2["x"], (s1["y"] - s2["y"]) * 2)
                if 4 < dist < 18 and random.random() < 0.25:
                    self.constellations.append((s1, s2))

    def render(self):
        curses.curs_set(0)
        self.stdscr.nodelay(1)
        self.stdscr.timeout(50)
        
        # Initialize color pairs if terminal supports color
        if curses.has_colors():
            curses.start_color()
            curses.init_pair(1, curses.COLOR_CYAN, curses.COLOR_BLACK)
            curses.init_pair(2, curses.COLOR_YELLOW, curses.COLOR_BLACK)
            curses.init_pair(3, curses.COLOR_WHITE, curses.COLOR_BLACK)
            curses.init_pair(4, curses.COLOR_MAGENTA, curses.COLOR_BLACK)
            curses.init_pair(5, curses.COLOR_BLUE, curses.COLOR_BLACK)

        chars = [".", "·", "°", "*", "o", "O", "@", "✦", "★"]
        
        # Fetch radio data in background thread periodically
        def background_fetch():
            while self.running:
                self.fetch_radio_data()
                time.sleep(15)

        thread = threading.Thread(target=background_fetch, daemon=True)
        thread.start()

        h, w = self.stdscr.getmaxyx()
        self.generate_sky(h, w)

        while self.running:
            new_h, new_w = self.stdscr.getmaxyx()
            if new_h != h or new_w != w:
                h, w = new_h, new_w
                self.generate_sky(h, w)

            self.stdscr.erase()
            self.time_offset += 0.08

            # Draw procedural constellation lines
            for s1, s2 in self.constellations:
                # Simple Bresenham-like line representation using subtle markers
                steps = max(abs(s2["x"] - s1["x"]), abs(s2["y"] - s1["y"]))
                if steps > 0:
                    for k in range(1, steps):
                        lx = int(s1["x"] + (s2["x"] - s1["x"]) * k / steps)
                        ly = int(s1["y"] + (s2["y"] - s1["y"]) * k / steps)
                        if 1 <= ly < h - 2 and 1 <= lx < w - 1:
                            try:
                                self.stdscr.addch(ly, lx, "·", curses.color_pair(5) | curses.A_DIM)
                            except curses.error:
                                pass

            # Render light-emitting star pixels powered by radio flux modulation
            for star in self.stars:
                y, x = star["y"], star["x"]
                if 1 <= y < h - 2 and 1 <= x < w - 1:
                    # Modulate intensity using sine wave modulated by active radio flux
                    pulse = math.sin(self.time_offset * star["freq"] + star["phase"]) * 0.4
                    effective_mag = max(0.0, min(1.0, star["mag"] + pulse * self.radio_flux))
                    
                    idx = int(effective_mag * (len(chars) - 1))
                    char = chars[idx]

                    # Assign dynamic color based on magnitude
                    attr = curses.A_NORMAL
                    color = curses.color_pair(3)
                    if idx >= 7:
                        color = curses.color_pair(2) | curses.A_BOLD
                    elif idx >= 4:
                        color = curses.color_pair(1) | curses.A_BOLD
                    elif idx <= 2:
                        color = curses.color_pair(5) | curses.A_DIM

                    try:
                        self.stdscr.addch(y, x, char, color)
                    except curses.error:
                        pass

            # HUD / Status display
            hud = f" [RADIO STAR MAP] | DATA: {self.data_source} | FLUX MOD: x{self.radio_flux:.2f} | 'r': RESEED | 'q': QUIT "
            try:
                self.stdscr.addstr(0, max(0, (w - len(hud)) // 2), hud[:w-1], curses.color_pair(4) | curses.A_REVERSE)
            except curses.error:
                pass

            self.stdscr.refresh()

            # Handle user input
            ch = self.stdscr.getch()
            if ch == ord('q') or ch == ord('Q'):
                self.running = False
            elif ch == ord('r') or ch == ord('R'):
                self.generate_sky(h, w)

def main():
    curses.wrapper(lambda stdscr: RadioStarMap(stdscr).render())

if __name__ == "__main__":
    main()