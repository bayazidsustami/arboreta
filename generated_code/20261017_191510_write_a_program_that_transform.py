#!/usr/bin/env python3
"""
Psychedelic Weather Cellular Automaton
Transforms weather data into a dynamic terminal watercolor mural.
"""

import os
import random
import sys
import time
import urllib.request
import json

COLORS = [
    "\033[38;5;196m",
    "\033[38;5;208m",
    "\033[38;5;226m",
    "\033[38;5;46m",
    "\033[38;5;51m",
    "\033[38;5;21m",
    "\033[38;5;93m",
    "\033[38;5;201m",
    "\033[38;5;231m",
]
RESET = "\033[0m"
CLEAR = "\033[2J\033[H"

CHARS = ['.', ',', ':', ';', '*', 'x', 'o', 'O', '#', '~', '-', '+', '=']

def fetch_weather():
    try:
        url = "[https://api.open-meteo.com/v1/forecast?latitude=40.71&longitude=-74.01&current=temperature_2m,wind_speed_10m](https://api.open-meteo.com/v1/forecast?latitude=40.71&longitude=-74.01&current=temperature_2m,wind_speed_10m)"
        req = urllib.request.urlopen(url, timeout=1.5)
        data = json.loads(req.read().decode())
        current = data.get("current", {})
        temp = current.get("temperature_2m", 20.0)
        wind = current.get("wind_speed_10m", 5.0)
        return float(temp), float(wind)
    except Exception:
        return random.uniform(10.0, 30.0), random.uniform(2.0, 15.0)

def main():
    try:
        cols = os.get_terminal_size().columns
        rows = os.get_terminal_size().lines - 2
    except OSError:
        cols, rows = 80, 24

    grid = [[random.choice([0, 1]) for _ in range(cols)] for _ in range(rows)]
    
    temp, wind = fetch_weather()
    rule_birth = int(temp) % 3 + 2
    rule_survive_min = int(wind) % 2 + 2
    rule_survive_max = rule_survive_min + 3

    print(CLEAR, end="")
    
    generation = 0
    try:
        while True:
            if generation % 40 == 0:
                temp, wind = fetch_weather()
                rule_birth = int(temp + generation) % 3 + 2

            new_grid = [[0 for _ in range(cols)] for _ in range(rows)]
            output = []

            for r in range(rows):
                row_str = []
                for c in range(cols):
                    neighbors = 0
                    for dr in (-1, 0, 1):
                        for dc in (-1, 0, 1):
                            if dr == 0 and dc == 0:
                                continue
                            nr = (r + dr) % rows
                            nc = (c + dc) % cols
                            neighbors += grid[nr][nc]

                    alive = grid[r][c]
                    if alive:
                        if rule_survive_min <= neighbors <= rule_survive_max:
                            new_grid[r][c] = 1
                        else:
                            new_grid[r][c] = 0
                    else:
                        if neighbors == rule_birth or neighbors == rule_birth + 1:
                            new_grid[r][c] = 1
                        else:
                            new_grid[r][c] = 0

                    if new_grid[r][c]:
                        char_idx = (r + c + generation + neighbors) % len(CHARS)
                        color_idx = (r * c + generation + int(temp)) % len(COLORS)
                        row_str.append(f"{COLORS[color_idx]}{CHARS[char_idx]}{RESET}")
                    else:
                        row_str.append(" ")
                output.append("".join(row_str))

            print("\033[H" + "\n".join(output), end="")
            sys.stdout.flush()

            grid = new_grid
            generation += 1
            time.sleep(0.06)

    except KeyboardInterrupt:
        print(RESET + "\nWatercolor mural complete.")

if __name__ == "__main__":
    main()