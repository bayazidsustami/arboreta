// Simple 1‑dimensional cellular automaton (Rule 30) visualized in the console
// Run with Node.js: `node cellular.js`

// Configuration
const width = 80;        // cells per generation
const generations = 40;  // total generations to compute
const alive = '█';       // character for live cell
const dead = ' ';        // character for dead cell

// Rule 30 lookup table: index is binary pattern (111->0 ... 000->7)
const rule30 = [0, 1, 1, 1, 1, 0, 0, 0];

// Initialize first generation with a single live cell in the middle
let current = new Uint8Array(width);
current[Math.floor(width / 2)] = 1;

// Helper to render a generation as a string
function render(arr) {
  let line = '';
  for (let i = 0; i < arr.length; i++) line += arr[i] ? alive : dead;
  return line;
}

// Main loop: compute and display each generation
for (let gen = 0; gen < generations; gen++) {
  console.log(render(current));

  const next = new Uint8Array(width);
  for (let i = 0; i < width; i++) {
    // Wrap‑around neighbors (periodic boundary)
    const left  = current[(i - 1 + width) % width];
    const center = current[i];
    const right = current[(i + 1) % width];

    // Build 3‑bit index: left*4 + center*2 + right
    const idx = (left << 2) | (center << 1) | right;
    next[i] = rule30[idx];
  }
  current = next;
}