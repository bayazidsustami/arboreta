import * as fs from 'fs';

// Esoteric Visual Synthesizer: Stellar Collapse Driven by Source Indentation
// This script reads its own source code, maps line indentation levels to 
// gravitational pull and color bleed coefficients, and simulates a dying star 
// collapsing into a singularity in real-time within the terminal.

const sourceCode = fs.readFileSync(__filename, 'utf8');
const lines = sourceCode.split('\n');

// Extract indentation topology from source code lines
const indents = lines.map(line => {
  const match = line.match(/^(\s*)/);
  return match ? match[1].length : 0;
});

const maxIndent = Math.max(...indents, 1);
const modulationField = indents.map(i => i / maxIndent);

const WIDTH = 64;
const HEIGHT = 32;

// Initialize cellular automaton grid
let grid: number[][] = Array.from({ length: HEIGHT }, () => Array(WIDTH).fill(0));
let colorGrid: number[][] = Array.from({ length: HEIGHT }, () => Array(WIDTH).fill(0));

const cx = Math.floor(WIDTH / 2);
const cy = Math.floor(HEIGHT / 2);

// Seed the initial dying star structure
for (let y = 0; y < HEIGHT; y++) {
  for (let x = 0; x < WIDTH; x++) {
    const dx = x - cx;
    const dy = (y - cy) * 2;
    const dist = Math.sqrt(dx * dx + dy * dy);
    if (dist < 10) {
      grid[y][x] = dist < 3 ? 6 : Math.floor(Math.random() * 4) + 1;
      colorGrid[y][x] = Math.floor(Math.random() * 6);
    }
  }
}

// ANSI escape sequences for rendering
const PALETTE = [
  '\x1b[30m', // Void
  '\x1b[34m', // Deep Blue Shift
  '\x1b[36m', // Cyan Plasma
  '\x1b[32m', // Green Flare
  '\x1b[33m', // Thermal Yellow
  '\x1b[31m', // Crimson Core
  '\x1b[35m'  // Magenta Singularity
];
const RESET = '\x1b[0m';
const CHARS = [' ', '.', ':', '-', '=', '*', '#', '@'];

function render(tick: number) {
  let frame = `\x1b[H\x1b[J`;
  frame += `=== DYING STAR SYNTHESIZER [Tick: ${tick}] ===\n`;

  for (let y = 0; y < HEIGHT; y++) {
    let row = '';
    for (let x = 0; x < WIDTH; x++) {
      const state = grid[y][x];
      const color = colorGrid[y][x] % PALETTE.length;
      const char = CHARS[Math.min(state, CHARS.length - 1)];
      row += `${PALETTE[color]}${char}${RESET}`;
    }
    frame += row + '\n';
  }
  process.stdout.write(frame);
}

function update(tick: number) {
  const nextGrid: number[][] = Array.from({ length: HEIGHT }, () => Array(WIDTH).fill(0));
  const nextColor: number[][] = Array.from({ length: HEIGHT }, () => Array(WIDTH).fill(0));

  // Indentation values modulate physical constants dynamically
  const modIdx = tick % modulationField.length;
  const gravity = 0.2 + (modulationField[modIdx] * 0.7);
  const colorBleed = modulationField[(modIdx * 3) % modulationField.length];

  for (let y = 0; y < HEIGHT; y++) {
    for (let x = 0; x < WIDTH; x++) {
      const current = grid[y][x];
      if (current === 0) continue;

      const dx = cx - x;
      const dy = cy - y;
      const dist = Math.sqrt(dx * dx + dy * dy);

      if (dist < 1.8) {
        // Core densification at the center of the singularity
        nextGrid[cy][cx] = 6;
        nextColor[cy][cx] = 6;
        continue;
      }

      // Pull cells inward toward the center based on source code indentation gravity
      const stepX = x + Math.sign(dx) * (Math.abs(dx) > Math.abs(dy) ? 1 : (Math.random() < gravity ? 1 : 0));
      const stepY = y + Math.sign(dy) * (Math.abs(dy) >= Math.abs(dx) ? 1 : (Math.random() < gravity ? 1 : 0));

      const tx = Math.max(0, Math.min(WIDTH - 1, stepX));
      const ty = Math.max(0, Math.min(HEIGHT - 1, stepY));

      nextGrid[ty][tx] = current;
      const col = colorGrid[y][x];
      nextColor[ty][tx] = Math.random() < colorBleed ? (col + 1) % PALETTE.length : col;
    }
  }

  grid = nextGrid;
  colorGrid = nextColor;
}

let tick = 0;
const loop = setInterval(() => {
  render(tick);
  update(tick);
  tick++;
  if (tick > 400) {
    clearInterval(loop);
    console.log(RESET + '\nCellular collapse complete. Singularity stabilized.');
  }
}, 75);