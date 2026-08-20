import * as fs from 'fs';

// --- CONFIGURATION & ECOSYSTEM PARAMETERS ---
const WIDTH = 80;
const HEIGHT = 30;
const ITERATIONS = 300;

// Source Code Elevation Map Mapping (0.0 to 1.0)
const CHAR_ELEVATION: { [key: string]: number } = {
  ' ': 0.0, '.': 0.1, ',': 0.15, ';': 0.2, ':': 0.25,
  '-': 0.3, '_': 0.35, '=': 0.4, '+': 0.45, '*': 0.5,
  '(': 0.6, ')': 0.6, '{': 0.7, '}': 0.7, '[': 0.7, ']': 0.7,
  '#': 0.85, '@': 1.0
};

// Ecosystem Terrain & Fluid Grids
let terrain: number[][] = Array.from({ length: HEIGHT }, () => new Array(WIDTH).fill(0));
let water: number[][] = Array.from({ length: HEIGHT }, () => new Array(WIDTH).fill(0));
let algae: number[][] = Array.from({ length: HEIGHT }, () => new Array(WIDTH).fill(0));

// Memory Leak Simulation Pool (allocates uncollected memory over time)
const memoryLeakPool: Array<Uint8Array> = [];

// --- 1. PARSE OWN SOURCE CODE AS TERRAIN ---
function loadTerrainFromSource(): void {
  let source = '';
  try {
    source = fs.readFileSync(__filename, 'utf-8');
  } catch {
    source = "function defaultTerrain() { return Math.random() * 100; }".repeat(50);
  }

  // Calculate character frequencies
  const freqMap: { [key: string]: number } = {};
  for (const char of source) {
    freqMap[char] = (freqMap[char] || 0) + 1;
  }
  const maxFreq = Math.max(...Object.values(freqMap), 1);

  // Map source characters onto the 2D elevation grid
  let charIndex = 0;
  for (let r = 0; r < HEIGHT; r++) {
    for (let c = 0; c < WIDTH; c++) {
      const char = source[charIndex % source.length] || ' ';
      const baseElev = CHAR_ELEVATION[char] ?? ((char.charCodeAt(0) % 10) / 10);
      const freqWeight = (freqMap[char] || 0) / maxFreq;
      
      terrain[r][c] = Number((baseElev * 0.6 + freqWeight * 0.4).toFixed(2));
      water[r][c] = r === 0 ? 0.8 : 0.0; // Rain sources at top boundary
      charIndex++;
    }
  }
}

// --- 2. FLUID DYNAMICS & ALGAL BLOOM SIMULATION ---
function simulateStep(step: number): void {
  const nextWater = water.map(row => [...row]);
  const nextAlgae = algae.map(row => [...row]);

  // Simulate continuous memory leaks (growth increases leak intensity)
  if (step % 2 === 0) {
    memoryLeakPool.push(new Uint8Array(1024 * 128)); // 128 KB leak allocation
  }
  const leakIntensity = Math.min(1.0, memoryLeakPool.length / 150);

  for (let r = 0; r < HEIGHT; r++) {
    for (let c = 0; c < WIDTH; c++) {
      const currentHeight = terrain[r][c] + water[r][c];

      // Downward & Outward Fluid Flow (Diffusive Hydrodynamics)
      const neighbors = [
        [r + 1, c], [r - 1, c], [r, c + 1], [r, c - 1]
      ];

      for (let [nr, nc] of neighbors) {
        if (nr >= 0 && nr < HEIGHT && nc >= 0 && nc < WIDTH) {
          const neighborHeight = terrain[nr][nc] + water[nr][nc];
          if (currentHeight > neighborHeight && water[r][c] > 0.01) {
            const flow = (currentHeight - neighborHeight) * 0.15;
            nextWater[r][c] -= flow;
            nextWater[nr][nc] += flow;
          }
        }
      }

      // Toxic Algal Growth: Thrives in high water levels amplified by memory leak toxicity
      if (water[r][c] > 0.1) {
        const growthRate = 0.02 + leakIntensity * 0.15;
        nextAlgae[r][c] = Math.min(1.0, algae[r][c] + growthRate);
      } else {
        nextAlgae[r][c] = Math.max(0.0, algae[r][c] - 0.05); // Die-off without water
      }
    }
  }

  water = nextWater;
  algae = nextAlgae;
}

// --- 3. ASCII ECOSYSTEM RENDERER ---
function renderFrame(step: number): void {
  let frame = `\x1b[H=== SOURCE TERRAIN ECOSYSTEM | STEP: ${step} | MEMORY LEAK POOL: ${(memoryLeakPool.length * 128 / 1024).toFixed(1)} MB ===\n`;

  for (let r = 0; r < HEIGHT; r++) {
    let line = '';
    for (let c = 0; c < WIDTH; c++) {
      const w = water[r][c];
      const a = algae[r][c];
      const t = terrain[r][c];

      if (a > 0.4 && w > 0.1) {
        // Toxic Algal Bloom (Green ASCII)
        line += `\x1b[32m${a > 0.7 ? '█' : '▓'}\x1b[0m`;
      } else if (w > 0.2) {
        // Water Bodies (Blue ASCII)
        line += `\x1b[34m${w > 0.6 ? '≈' : '~'}\x1b[0m`;
      } else {
        // Base Source Code Terrain (Grayscale ASCII)
        if (t > 0.7) line += '▲';
        else if (t > 0.4) line += '▵';
        else if (t > 0.2) line += '·';
        else line += ' ';
      }
    }
    frame += line + '\n';
  }

  process.stdout.write(frame);
}

// --- MAIN RUNTIME LOOP ---
function run(): void {
  loadTerrainFromSource();
  process.stdout.write('\x1b[2J'); // Clear screen

  let currentStep = 0;
  const timer = setInterval(() => {
    simulateStep(currentStep);
    renderFrame(currentStep);
    currentStep++;

    if (currentStep >= ITERATIONS) {
      clearInterval(timer);
      console.log('\nSimulation completed. Ecosystem reach equilibrium/toxicity limit.');
    }
  }, 50);
}

run();