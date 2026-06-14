import { writeFileSync, readFileSync } from "fs";
import { spawnSync } from "child_process";

const pythonCode = `#!/usr/bin/env python3
import sys, os, json, math, random, urllib.request

# ---------- Configuration ----------
MOON_API = "https://api.farmsense.net/v1/moonphases/?d=0"
# Placeholder sound API – replace with a real one if available
SOUND_API = "https://api.noiseapi.com/level"

# ---------- Helper functions ----------
def fetch_json(url):
    try:
        with urllib.request.urlopen(url, timeout=5) as resp:
            return json.loads(resp.read().decode())
    except Exception:
        return None

def get_moon_illumination():
    data = fetch_json(MOON_API)
    if data and isinstance(data, list) and "Illumination" in data[0]:
        return float(data[0]["Illumination"])
    return random.uniform(0, 100)  # fallback

def get_sound_level():
    data = fetch_json(SOUND_API)
    if data and "decibel" in data:
        return float(data["decibel"])
    return random.uniform(30, 80)  # fallback

def ansi_color(code):
    return f"\\033[{code}m"

def reset_color():
    return "\\033[0m"

def generate_mandala(illum, db):
    size = 21  # odd for symmetry
    radius = size // 2
    density = int(1 + (illum / 100) * 4)  # 1‑5 lines per cell
    amp_factor = (db - 30) / 50  # 0‑1 range
    chars = ["·", "+", "*", "✦", "✸"]
    output = []
    for y in range(size):
        line = ""
        for x in range(size):
            dx, dy = x - radius, y - radius
            dist = math.hypot(dx, dy)
            if dist > radius:
                line += " "
                continue
            angle = (math.atan2(dy, dx) + math.tau) % math.tau
            sector = int((angle / math.tau) * 8)
            char = chars[(sector + density) % len(chars)]
            brightness = int(30 + amp_factor * 70)
            line += f"{ansi_color(brightness)}{char}{reset_color()}"
        output.append(line)
    return "\\n".join(output)

def haiku(illum, db):
    lines = [
        f"Silver moon {illum:.0f}% glows",
        f"Night air whispers {db:.0f} dB",
        "Stars listen in silence"
    ]
    return "\\n".join(lines)

def append_haiku_to_self(haiku_text):
    path = os.path.realpath(__file__)
    with open(path, "a", encoding="utf-8") as f:
        f.write("\\n# ---- Haiku for next run ----\\n")
        f.write('"""\\n')
        f.write(haiku_text)
        f.write('\\n"""\\n')

def main():
    illum = get_moon_illumination()
    db = get_sound_level()
    print(generate_mandala(illum, db))
    h = haiku(illum, db)
    print("\\n" + h)
    append_haiku_to_self(h)

if __name__ == "__main__":
    main()
`;

writeFileSync("mandala.py", pythonCode, { mode: 0o755 });
const result = spawnSync("python3", ["mandala.py"], { stdio: "inherit" });
process.exit(result.status);