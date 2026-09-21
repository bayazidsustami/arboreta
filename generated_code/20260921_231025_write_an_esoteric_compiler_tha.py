#!/usr/bin/env python3
"""
Thunderstorm ASCII Constellation Compiler
A whimsical self-modifying esoteric compiler that weaves generative
ASCII constellations based on simulated local weather conditions.
"""

import os
import sys
import random
import time

def fetch_weather_forecast():
    """Simulates fetching local weather data or checking atmospheric sensors."""
    conditions = ["Sunny", "Rainy", "Thunderstorm", "Cloudy", "Windy"]
    return os.environ.get("WEATHER_OVERRIDE", random.choice(conditions))

def mutate_source_code(weather):
    """Recursively mutates the source file to weave an ASCII constellation tapestry."""
    try:
        script_path = os.path.abspath(__file__)
        with open(script_path, "r", encoding="utf-8") as f:
            content = f.read()
        
        constellation_map = {
            "Thunderstorm": "   *     .     *   \n     /\\  /\\  /\\    \n    *  \\/  \\/  *   ",
            "Sunny":        "     .   .   .     \n   .   (O)   .     \n     .   .   .     ",
            "Rainy":        "    | | | | | |    \n     | | | | |     \n    | | | | | |    "
        }
        art = constellation_map.get(weather, "    *     *     *  ")
        
        mutation_marker = "# --- CONSTELLATION TAPESTRY ---"
        if mutation_marker in content:
            parts = content.split(mutation_marker)
            new_content = parts[0] + f"{mutation_marker}\n# Weather: {weather}\n# ART:\n" + "\n".join(f"# {line}" for line in art.splitlines()) + "\n" + parts[1]
        else:
            new_content = content + f"\n\n{mutation_marker}\n# Weather: {weather}\n# ART:\n" + "\n".join(f"# {line}" for line in art.splitlines()) + "\n"
            
        with open(script_path, "w", encoding="utf-8") as f:
            f.write(new_content)
    except Exception:
        # Graceful fallback if source file is immutable/read-only
        pass

def render_tapestry(weather):
    """Renders the terminal constellation tapestry."""
    print("[*] Initializing Esoteric Compiler...")
    time.sleep(0.5)
    print("[*] Querying local meteorological sensors...")
    time.sleep(0.5)
    print(f"[+] Detected Weather: {weather}")
    
    if weather == "Thunderstorm":
        print("\n[SUCCESS] Atmospheric ionization optimal! Rendering thunderstorm constellation:")
        print("    *     .     *   ")
        print("      /\\  /\\  /\\    ")
        print("     *  \\/  \\/  *   ")
        print("⚡ TAPESTRY WEAVING COMPLETE ⚡\n")
    else:
        print("\n[NOTICE] Insufficient atmospheric charge. Move outside during a thunderstorm to align constellations.")
        print("Current constellation is dormant.")

if __name__ == "__main__":
    current_weather = fetch_weather_forecast()
    mutate_source_code(current_weather)
    render_tapestry(current_weather)