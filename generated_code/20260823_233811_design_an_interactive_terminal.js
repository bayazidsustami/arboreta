const os = require('os');

// Terminal setup & ANSI helpers
const stdout = process.stdout;
const ESC = '\x1b[';
const cursorHide = () => stdout.write(`${ESC}?25l`);
const cursorShow = () => stdout.write(`${ESC}?25h`);
const clearScreen = () => stdout.write(`${ESC}2J${ESC}H`);
const moveTo = (x, y) => stdout.write(`${ESC}${y + 1};${x + 1}H`);

// Color definitions (R, G, B)
const Palette = {
  bg: [10, 14, 12],
  stem: [34, 112, 62],
  bloom: [180, 230, 90],
  compete: [220, 90, 180],
  decay: [80, 70, 60],
  dust: [40, 40, 35]
};

const Chars = {
  stem: ['░', '▒', '▓', '╎', '╏', '┆', '┇', '┊', '┋'],
  bloom: ['✿', '❁', '❂', '❃', '❄', '☸', '✻', '✽'],
  compete: ['⚡', '⚔', '╳', '✕', '🞩'],
  decay: ['․', '‥', '…', ' ', ' ', '.']
};

let width = stdout.columns || 80;
let height = stdout.rows || 24;

// Grid state
let grid = [];
function createGrid() {
  grid = Array.from({ length: height }, () =>
    Array.from({ length: width }, () => ({
      char: ' ',
      r: Palette.bg[0],
      g: Palette.bg[1],
      b: Palette.bg[2],
      age: 0,
      type: 'empty', // 'empty' | 'stem' | 'bloom' | 'compete' | 'decay'
      energy: 0
    }))
  );
}

// CPU Monitor
let lastCpuInfo = getCpuSnapshot();

function getCpuSnapshot() {
  const cpus = os.cpus();
  let user = 0, nice = 0, sys = 0, idle = 0, irq = 0;
  for (const cpu of cpus) {
    user += cpu.times.user;
    nice += cpu.times.nice;
    sys += cpu.times.sys;
    idle += cpu.times.idle;
    irq += cpu.times.irq;
  }
  const total = user + nice + sys + idle + irq;
  return { idle, total };
}

function getCpuUsage() {
  const current = getCpuSnapshot();
  const idleDiff = current.idle - lastCpuInfo.idle;
  const totalDiff = current.total - lastCpuInfo.total;
  lastCpuInfo = current;
  if (totalDiff === 0) return 0;
  return Math.max(0, Math.min(1, 1 - idleDiff / totalDiff));
}

// Lichen Spores/Seeds
let spores = [];

function spawnSpores(count = 3) {
  for (let i = 0; i < count; i++) {
    spores.push({
      x: Math.floor(Math.random() * width),
      y: Math.floor(Math.random() * height),
      angle: Math.random() * Math.PI * 2,
      species: Math.floor(Math.random() * 3)
    });
  }
}

// Render loop buffer
function render() {
  let buf = '';
  let lastR = -1, lastG = -1, lastB = -1;

  for (let y = 0; y < height; y++) {
    buf += `${ESC}${y + 1};1H`;
    for (let x = 0; x < width; x++) {
      const cell = grid[y][x];
      if (cell.r !== lastR || cell.g !== lastG || cell.b !== lastB) {
        buf += `${ESC}38;2;${cell.r};${cell.g};${cell.b}m`;
        lastR = cell.r;
        lastG = cell.g;
        lastB = cell.b;
      }
      buf += cell.char;
    }
  }
  stdout.write(buf);
}

// Main Simulation Step
function updateSimulation() {
  const cpuLoad = getCpuUsage();
  const isHighLoad = cpuLoad > 0.35;
  const isIdle = cpuLoad < 0.1;

  // Handle Resize
  if (stdout.columns !== width || stdout.rows !== height) {
    width = stdout.columns || 80;
    height = stdout.rows || 24;
    createGrid();
    clearScreen();
    spores = [];
  }

  // 1. Spawning / Growth based on CPU activity
  if (spores.length === 0 || (isHighLoad && Math.random() < 0.3)) {
    spawnSpores(Math.ceil(cpuLoad * 4));
  }

  // Grow active spores into lichen stalks
  for (let i = spores.length - 1; i >= 0; i--) {
    const s = spores[i];
    const nx = Math.floor(s.x);
    const ny = Math.floor(s.y);

    if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
      const cell = grid[ny][nx];

      // Grow stem or compete
      if (cell.type === 'empty' || cell.type === 'decay') {
        cell.type = 'stem';
        cell.char = Chars.stem[Math.floor(Math.random() * Chars.stem.length)];
        // Blend species colors using CPU load intensity
        cell.r = Math.floor(Palette.stem[0] * (0.5 + cpuLoad * 0.5));
        cell.g = Math.floor(Palette.stem[1] * (0.5 + cpuLoad * 0.5));
        cell.b = Math.floor(Palette.stem[2] * (0.2 + (s.species === 1 ? 0.8 : 0)));
        cell.energy = 100;
        cell.age = 0;
      } else if (cell.type === 'stem' && Math.random() < 0.15) {
        // High load causes lichen to bloom vibrant fruiting bodies
        cell.type = 'bloom';
        cell.char = Chars.bloom[Math.floor(Math.random() * Chars.bloom.length)];
        cell.r = Palette.bloom[0];
        cell.g = Palette.bloom[1];
        cell.b = Palette.bloom[2];
      }

      // Branch out (mathematical growth)
      s.angle += (Math.random() - 0.5) * 0.8;
      s.x += Math.cos(s.angle);
      s.y += Math.sin(s.angle);

      // Kill spore out of bounds or randomly based on CPU idle
      if (s.x < 0 || s.x >= width || s.y < 0 || s.y >= height || Math.random() < (isIdle ? 0.2 : 0.02)) {
        spores.splice(i, 1);
      }
    } else {
      spores.splice(i, 1);
    }
  }

  // 2. Cellular Automata: Competition & Decay
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const cell = grid[y][x];

      if (cell.type === 'empty') continue;

      cell.age++;

      // Count surrounding neighbors
      let neighbors = 0;
      for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          if (dx === 0 && dy === 0) continue;
          const nx = x + dx, ny = y + dy;
          if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
            if (grid[ny][nx].type !== 'empty') neighbors++;
          }
        }
      }

      // Overcrowding / Competition
      if (neighbors >= 7 && cell.type === 'stem' && Math.random() < 0.1) {
        cell.type = 'compete';
        cell.char = Chars.compete[Math.floor(Math.random() * Chars.compete.length)];
        cell.r = Palette.compete[0];
        cell.g = Palette.compete[1];
        cell.b = Palette.compete[2];
      }

      // System Idle -> Decay into digital detritus
      if (isIdle || Math.random() < 0.01) {
        cell.energy -= isIdle ? 15 : 1;

        if (cell.energy <= 0) {
          if (cell.type !== 'decay') {
            cell.type = 'decay';
            cell.char = Chars.decay[Math.floor(Math.random() * Chars.decay.length)];
            cell.r = Palette.decay[0];
            cell.g = Palette.decay[1];
            cell.b = Palette.decay[2];
          } else {
            // Decay degrades further into dust then disappears
            cell.r = Math.max(Palette.bg[0], cell.r - 2);
            cell.g = Math.max(Palette.bg[1], cell.g - 2);
            cell.b = Math.max(Palette.bg[2], cell.b - 2);
            if (cell.r <= Palette.bg[0] + 5 && Math.random() < 0.2) {
              cell.type = 'empty';
              cell.char = ' ';
              cell.r = Palette.bg[0];
              cell.g = Palette.bg[1];
              cell.b = Palette.bg[2];
            }
          }
        }
      } else {
        // High system usage rejuvenates colony
        if (cell.energy < 100) cell.energy += 5;
      }
    }
  }

  // Draw overlay status text
  renderHeader(cpuLoad);
  render();
}

function renderHeader(cpuLoad) {
  const percent = Math.floor(cpuLoad * 100);
  const status = ` [ CPU LOAD: ${percent.toString().padStart(3, ' ')}% | LICHEN SPORES: ${spores.length} ] `;
  for (let i = 0; i < status.length && i < width; i++) {
    grid[0][i] = {
      char: status[i],
      r: 200,
      g: 220,
      b: 200,
      type: 'empty',
      age: 0,
      energy: 100
    };
  }
}

// Cleanup and Execution Init
function main() {
  cursorHide();
  clearScreen();
  createGrid();

  const interval = setInterval(updateSimulation, 80);

  function shutdown() {
    clearInterval(interval);
    cursorShow();
    stdout.write(`${ESC}0m`); // reset terminal colors
    clearScreen();
    process.exit(0);
  }

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main();