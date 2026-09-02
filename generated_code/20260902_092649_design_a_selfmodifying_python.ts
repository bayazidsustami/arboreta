import * as fs from 'fs';
import * as path from 'path';

/**
 * Generates a self-modifying Python script that interprets its own source text
 * as spatial coordinates to generate an evolving ASCII-art island map.
 */
function createSelfModifyingPythonScript(): string {
  return `import sys, re, random

# Generation counter tracking the island's evolutionary state
GENERATION = 1

def generate_island():
    # Read self source code to extract geographic seed coordinates
    with open(__file__, 'r', encoding='utf-8') as f:
        source = f.read()

    width, height = 60, 25
    grid = [[' ' for _ in range(width)] for _ in range(height)]

    # Derive geographic points from character positions and ASCII values
    points = []
    for idx, char in enumerate(source):
        x = (idx * 7 + ord(char) * 13) % width
        y = (idx * 11 + ord(char) * 17) % height
        val = ord(char)
        points.append((x, y, val))

    # Calculate terrain elevation using distance transform from derived coordinates
    max_dist = (width**2 + height**2) ** 0.5
    for y in range(height):
        for x in range(width):
            # Calculate influence from local points
            min_dist = min(((x - px)**2 + (y - py)**2)**0.5 for px, py, _ in points[:80])
            elevation = 1.0 - (min_dist / (max_dist * 0.25))

            # Noise modifier based on generation shift
            elevation += ((x * 3 + y * 5 + GENERATION * 7) % 11) / 50.0

            # Map elevation to biome symbols
            if elevation < 0.15:
                grid[y][x] = '~'  # Deep Ocean
            elif elevation < 0.30:
                grid[y][x] = '.'  # Shallow Waters / Shore
            elif elevation < 0.45:
                grid[y][x] = 'o'  # Sandy Beach
            elif elevation < 0.65:
                grid[y][x] = '*'  # Plains / Grassland
            elif elevation < 0.80:
                grid[y][x] = 'n'  # Forest
            elif elevation < 0.92:
                grid[y][x] = '^'  # Mountain
            else:
                grid[y][x] = '▲'  # Peak

    # Render Island Map Frame
    print(f"┌{'─' * width}┐")
    print(f"│  ISLAND ARCHIPELAGO - GENERATION {GENERATION:03d}" + " " * (width - 34) + "│")
    print(f"├{'─' * width}┤")
    for row in grid:
        print(f"│{''.join(row)}│")
    print(f"└{'─' * width}┘")

def evolve_source():
    # Self-modification: Update GENERATION count and insert a new geographic mutation variable
    with open(__file__, 'r', encoding='utf-8') as f:
        content = f.read()

    # Update state counter
    new_content = re.sub(r'GENERATION = (\\d+)', lambda m: f'GENERATION = {int(m.group(1)) + 1}', content)

    # Append a randomized coordinate comment to alter source length and ASCII layout for next run
    lat = round(random.uniform(-89.0, 89.0), 4)
    lon = round(random.uniform(-179.0, 179.0), 4)
    elevation_shift = random.randint(10, 999)
    mutation = f"\\n# GEO_COORD_MUTATION: {lat},{lon} | ELEV_SECTOR_{elevation_shift}"
    
    new_content += mutation

    with open(__file__, 'w', encoding='utf-8') as f:
        f.write(new_content)

if __name__ == '__main__':
    generate_island()
    evolve_source()
`;
}

// Write the self-modifying Python script to file
const outputPath = path.join(process.cwd(), 'evolving_island.py');
const pythonScriptContent = createSelfModifyingPythonScript();

fs.writeFileSync(outputPath, pythonScriptContent, 'utf-8');
console.log(`Generated self-modifying Python script at: ${outputPath}`);
console.log(`Run 'python3 evolving_island.py' multiple times to observe the island evolve.`);