import math
import sys
import time
import urllib.request
import json
import random

# Fetches real-time atmospheric pressure data or simulates a fallback if offline
def get_atmospheric_pressure():
    try:
        url = "[https://api.open-meteo.com/v1/forecast?latitude=51.5085&longitude=-0.1257&current=surface_pressure](https://api.open-meteo.com/v1/forecast?latitude=51.5085&longitude=-0.1257&current=surface_pressure)"
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=3) as response:
            data = json.loads(response.read().decode())
            return data.get("current", {}).get("surface_pressure", 1013.25)
    except Exception:
        return 1013.25 + random.uniform(-15, 15)

# Recursively generates 3D fractal noise density modulated by atmospheric pressure
def recursive_nebula_density(x, y, z, octaves, persistence, pressure_factor):
    if octaves <= 0:
        return 0.0
    
    scale = 0.04 * (pressure_factor / 1013.25)
    nx = x * scale
    ny = y * scale
    nz = z * scale
    
    value = math.sin(nx + nz) * math.cos(ny - nz) + math.sin(nx * 0.5 - ny * 0.5)
    next_val = recursive_nebula_density(x * 2.0, y * 2.0, z * 2.0, octaves - 1, persistence, pressure_factor)
    return value + (next_val * persistence)

# Renders a single frame of the 3D procedural nebula into ASCII characters
def render_nebula_frame(width, height, angle, pressure):
    chars = " .:-=+*#%@"
    num_chars = len(chars)
    
    output = []
    z = math.sin(angle) * 10.0
    z_offset = math.cos(angle * 0.5) * 10.0
    
    for y in range(height):
        row = []
        for x in range(width):
            rx = (x - width / 2.0)
            ry = (y - height / 2.0) * 2.0  # Terminal aspect ratio correction
            
            cos_a = math.cos(angle)
            sin_a = math.sin(angle)
            world_x = rx * cos_a - z * sin_a
            world_y = ry
            world_z = rx * sin_a + z * cos_a + z_offset
            
            density = recursive_nebula_density(world_x, world_y, world_z, 3, 0.5, pressure)
            
            norm = (density + 2.0) / 4.0
            norm = max(0.0, min(1.0, norm))
            
            char_idx = int(norm * (num_chars - 1))
            row.append(chars[char_idx])
        output.append("".join(row))
    return "\n".join(output)

def main():
    width, height = 64, 24
    print("Connecting to atmospheric telemetry...")
    pressure = get_atmospheric_pressure()
    print(f"Atmospheric Pressure acquired: {pressure:.2f} hPa. Sculpting Nebula...")
    time.sleep(1.5)
    
    angle = 0.0
    try:
        for _ in range(120):
            sys.stdout.write("\x1b[2J\x1b[H")
            sys.stdout.write(f"=== 3D PROCEDURAL NEBULA [Pressure: {pressure:.2f} hPa] ===\n")
            frame = render_nebula_frame(width, height, angle, pressure)
            sys.stdout.write(frame + "\n")
            sys.stdout.flush()
            
            angle += 0.04
            time.sleep(0.05)
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    main()