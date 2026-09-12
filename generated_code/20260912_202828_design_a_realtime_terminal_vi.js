#!/usr/bin/env node

/**
 * Git-Automata: A Real-Time Terminal Visualizer
 * Parses git log history to simulate an interactive cellular automaton ecosystem.
 * Each commit hash seeds a unique species with custom genetic rules, color, and lifespan.
 * 
 * Requirements: Node.js (v12+) run inside any git repository directory.
 * Run: node script.js
 */

const { spawn } = require('child_process');
const readline = require('readline');

// Terminal Dimensions & Config
const WIDTH = Math.min(process.stdout.columns || 80, 100);
const HEIGHT = Math.min(process.stdout.rows ? process.stdout.rows - 4 : 24, 40);
const TICK_RATE = 100; // ms per simulation tick
const COMMIT_INTERVAL = 3000; // ms between introducing new commits

// Grid initialization
let grid = Array.from({ length: HEIGHT }, () => Array(WIDTH).fill(null));
const activeSpecies = new Map();
let commitBuffer = [];
let commitIndex = 0;
let stats = { totalCommits: 0, activeSpeciesCount: 0, generation: 0 };

/**
 * Hash conversion to genetic attributes:
 * - Rule byte 1-2: Birth mask & Survival mask (Life-like CA)
 * - Byte 3: Color palette index
 * - Byte 4: Lifespan (decay rate)
 */
function parseCommitToSpecies(hash, author, message) {
  const seed = parseInt(hash.slice(0, 8), 16);
  const birthMask = (seed & 0xff);
  const survivalMask = ((seed >> 8) & 0xff);
  const colorCode = 31 + ((seed >> 16) % 6); // ANSI color codes 31-36
  const maxAge = 15 + ((seed >> 24) % 35);
  const char = message.trim()[0] || '#';

  return {
    id: hash.slice(0, 7),
    author: author.split(' ')[0],
    birth: birthMask,
    survival: survivalMask,
    color: colorCode,
    maxAge: maxAge,
    char: char.toUpperCase()
  };
}

// Fetch Git History
function loadGitHistory() {
  return new Promise((resolve) => {
    const git = spawn('git', ['log', '--pretty=format:%h|%an|%s', '-n', '100']);
    let output = '';

    git.stdout.on('data', (data) => output += data.toString());
    git.on('close', () => {
      if (!output.trim()) {
        // Fallback dummy data if not in a git repo or repo is empty
        for (let i = 0; i < 20; i++) {
          const fakeHash = Math.random().toString(16).substr(2, 40);
          commitBuffer.push(parseCommitToSpecies(fakeHash, "Dev", "Initial genesis commit"));
        }
      } else {
        const lines = output.trim().split('\n');
        commitBuffer = lines.map(line => {
          const [hash, author, msg] = line.split('|');
          return parseCommitToSpecies(hash || '0000000', author || 'Unknown', msg || 'Update');
        });
      }
      resolve();
    });
  });
}

// Seed a new species into the cellular matrix
function injectSpecies(species) {
  activeSpecies.set(species.id, species);
  const cx = Math.floor(Math.random() * (WIDTH - 10)) + 5;
  const cy = Math.floor(Math.random() * (HEIGHT - 10)) + 5;

  // Glider / Seed pattern
  const offsets = [[0,0], [1,0], [2,0], [2,1], [1,2]];
  offsets.forEach(([dx, dy]) => {
    const x = (cx + dx) % WIDTH;
    const y = (cy + dy) % HEIGHT;
    grid[y][x] = { speciesId: species.id, age: 0 };
  });
}

// Compute automaton step: Birth, Mutation, Decay
function stepSimulation() {
  const newGrid = Array.from({ length: HEIGHT }, () => Array(WIDTH).fill(null));
  stats.generation++;

  for (let y = 0; y < HEIGHT; y++) {
    for (let x = 0; x < WIDTH; x++) {
      const cell = grid[y][x];
      const neighborCounts = new Map();
      let totalNeighbors = 0;

      // Count Moore neighborhood species
      for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          if (dx === 0 && dy === 0) continue;
          const nx = (x + dx + WIDTH) % WIDTH;
          const ny = (y + dy + HEIGHT) % HEIGHT;
          const nCell = grid[ny][nx];
          if (nCell) {
            totalNeighbors++;
            neighborCounts.set(nCell.speciesId, (neighborCounts.get(nCell.speciesId) || 0) + 1);
          }
        }
      }

      // Dominant neighbor species for birth/mutation logic
      let dominantSpeciesId = null;
      let maxCount = 0;
      neighborCounts.forEach((count, id) => {
        if (count > maxCount) {
          maxCount = count;
          dominantSpeciesId = id;
        }
      });

      if (cell) {
        const species = activeSpecies.get(cell.speciesId);
        const survives = species && ((species.survival >> totalNeighbors) & 1);
        const isExpired = cell.age >= (species ? species.maxAge : 20);

        if (survives && !isExpired) {
          // Mutation chance under high density
          let currentId = cell.speciesId;
          if (totalNeighbors >= 5 && Math.random() < 0.05 && dominantSpeciesId) {
            currentId = dominantSpeciesId; // Gene displacement
          }
          newGrid[y][x] = { speciesId: currentId, age: cell.age + 1 };
        }
      } else if (dominantSpeciesId) {
        // Birth evaluation based on dominant local species genetics
        const species = activeSpecies.get(dominantSpeciesId);
        const givesBirth = species && ((species.birth >> totalNeighbors) & 1);
        if (givesBirth) {
          newGrid[y][x] = { speciesId: dominantSpeciesId, age: 0 };
        }
      }
    }
  }

  grid = newGrid;
  stats.activeSpeciesCount = new Set(grid.flat().filter(Boolean).map(c => c.speciesId)).size;
}

// Render engine using ANSI Escape sequences
function render() {
  let frame = '\x1b[H'; // Move cursor to top-left

  // Title & Dashboard
  frame += `\x1b[1;37m=== GIT-AUTOMATA ECOSYSTEM ===\x1b[0m Gen: \x1b[33m${stats.generation}\x1b[0m | Active Species: \x1b[32m${stats.activeSpeciesCount}\x1b[0m\n`;
  frame += '─'.repeat(WIDTH) + '\n';

  // Cellular Board Rendering
  for (let y = 0; y < HEIGHT; y++) {
    for (let x = 0; x < WIDTH; x++) {
      const cell = grid[y][x];
      if (cell) {
        const species = activeSpecies.get(cell.speciesId);
        if (species) {
          const fade = cell.age > (species.maxAge * 0.7) ? '\x1b[2m' : '\x1b[1m';
          frame += `${fade}\x1b[${species.color}m${species.char}\x1b[0m`;
        } else {
          frame += '\x1b[30m.\x1b[0m';
        }
      } else {
        frame += ' ';
      }
    }
    frame += '\n';
  }

  // Footer / Status
  frame += '─'.repeat(WIDTH) + '\n';
  const lastCommit = commitBuffer[(commitIndex - 1 + commitBuffer.length) % commitBuffer.length];
  if (lastCommit) {
    frame += `\x1b[90mLatest Genome: [${lastCommit.id}] by @${lastCommit.author} (Char: ${lastCommit.char})\x1b[0m\x1b[K`;
  }

  process.stdout.write(frame);
}

// Setup Keyboard & Exit Handlers
function setupInput() {
  readline.emitKeypressEvents(process.stdin);
  if (process.stdin.setRawMode) process.stdin.setRawMode(true);
  
  process.stdin.on('keypress', (str, key) => {
    if (key.ctrl && key.name === 'c') {
      process.stdout.write('\x1b[?25h\x1b[2J\x1b[H'); // Restore terminal
      process.exit();
    }
  });
}

// Main Controller Cycle
async function main() {
  process.stdout.write('\x1b[2J\x1b[?25l'); // Clear screen & hide cursor
  setupInput();
  await loadGitHistory();

  // Periodically inject new commits as novel species
  setInterval(() => {
    if (commitBuffer.length > 0) {
      const species = commitBuffer[commitIndex % commitBuffer.length];
      injectSpecies(species);
      commitIndex++;
      stats.totalCommits++;
    }
  }, COMMIT_INTERVAL);

  // Simulation tick loop
  setInterval(() => {
    stepSimulation();
    render();
  }, TICK_RATE);
}

main();