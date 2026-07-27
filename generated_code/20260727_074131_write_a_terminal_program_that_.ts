import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';

// --- Types & Interfaces ---
interface Star {
  cmd: string;
  count: number;
  x: number;
  y: number;
  z: number;
  vx: number;
  vy: number;
  vz: number;
  mass: number;
  isError: boolean;
  supernovaAge: number; // -1 if not exploding, >= 0 during explosion
}

interface ConstellationEdge {
  from: number;
  to: number;
}

interface Particle {
  x: number;
  y: number;
  z: number;
  vx: number;
  vy: number;
  vz: number;
  char: string;
  life: number;
  maxLife: number;
  color: string;
}

// --- History Parsing ---
function fetchShellHistory(): string[] {
  const home = os.homedir();
  const possibleFiles = [
    path.join(home, '.zsh_history'),
    path.join(home, '.bash_history'),
    path.join(home, '.history')
  ];

  for (const file of possibleFiles) {
    if (fs.existsSync(file)) {
      try {
        const raw = fs.readFileSync(file, 'utf-8');
        return raw
          .split('\n')
          .map(line => {
            // Remove ZSH metadata prefix (: 1600000000:0;cmd)
            const clean = line.replace(/^:\s*\d+:\d+;/, '').trim();
            return clean;
          })
          .filter(cmd => cmd.length > 0);
      } catch {
        // Fallback to sample history if file read fails
      }
    }
  }

  // Sample fallback history if no local history found
  return [
    'git status', 'npm start', 'git commit -m "fix"', 'cd src', 'ls -la',
    'git push', 'npm test', 'cat "unclosed_string', 'grep -r [[invalid]',
    'docker run -it', 'npm start', 'git status', 'cd ..', 'python3 -m json',
    'vim index.ts', 'npm run build', 'curl http://localhost:3000',
    'sudo rm -rf /', 'git diff', 'node --eval "console.log('
  ];
}

// Check for simple syntax errors in terminal commands
function isSyntaxError(cmd: string): boolean {
  // Check unclosed quotes
  const singleQuotes = (cmd.match(/'/g) || []).length;
  const doubleQuotes = (cmd.match(/"/g) || []).length;
  if (singleQuotes % 2 !== 0 || doubleQuotes % 2 !== 0) return true;

  // Check unbalanced brackets
  let parens = 0, square = 0, curly = 0;
  for (const char of cmd) {
    if (char === '(') parens++; if (char === ')') parens--;
    if (char === '[') square++; if (char === ']') square--;
    if (char === '{') curly++; if (char === '}') curly--;
    if (parens < 0 || square < 0 || curly < 0) return true;
  }
  if (parens !== 0 || square !== 0 || curly !== 0) return true;

  // Trailing pipes or operators
  if (/[|&;]\s*$/.test(cmd)) return true;

  return false;
}

// --- Simulation Setup ---
const history = fetchShellHistory();
const freqMap = new Map<string, number>();
const errorMap = new Map<string, boolean>();

for (const cmd of history) {
  freqMap.set(cmd, (freqMap.get(cmd) || 0) + 1);
  if (!errorMap.has(cmd)) {
    errorMap.set(cmd, isSyntaxError(cmd));
  }
}

// Take top unique commands for rich constellation map
const sortedCmds = Array.from(freqMap.entries())
  .sort((a, b) => b[1] - a[1])
  .slice(0, 30);

const stars: Star[] = sortedCmds.map(([cmd, count]) => {
  const isErr = errorMap.get(cmd) || false;
  return {
    cmd,
    count,
    x: (Math.random() - 0.5) * 60,
    y: (Math.random() - 0.5) * 40,
    z: (Math.random() - 0.5) * 60,
    vx: (Math.random() - 0.5) * 0.2,
    vy: (Math.random() - 0.5) * 0.2,
    vz: (Math.random() - 0.5) * 0.2,
    mass: Math.sqrt(count) * 2 + 1,
    isError: isErr,
    supernovaAge: isErr ? 0 : -1 // Syntax errors trigger supernovas
  };
});

// Build constellation connections between sequential history commands
const edges: ConstellationEdge[] = [];
const cmdIndex = new Map(stars.map((s, idx) => [s.cmd, idx]));
for (let i = 0; i < history.length - 1; i++) {
  const fromIdx = cmdIndex.get(history[i]);
  const toIdx = cmdIndex.get(history[i + 1]);
  if (fromIdx !== undefined && toIdx !== undefined && fromIdx !== toIdx) {
    if (!edges.some(e => (e.from === fromIdx && e.to === toIdx) || (e.from === toIdx && e.to === fromIdx))) {
      edges.push({ from: fromIdx, to: toIdx });
    }
  }
}

const particles: Particle[] = [];

// --- Renderer & Math Engine ---
let angleX = 0;
let angleY = 0;
const G = 0.15; // Gravitational constant

function applyPhysics() {
  // Gravitational attraction between star nodes
  for (let i = 0; i < stars.length; i++) {
    for (let j = i + 1; j < stars.length; j++) {
      const s1 = stars[i];
      const s2 = stars[j];

      const dx = s2.x - s1.x;
      const dy = s2.y - s1.y;
      const dz = s2.z - s1.z;
      const distSq = dx * dx + dy * dy + dz * dz + 10; // Softened gravity
      const dist = Math.sqrt(distSq);

      const force = (G * s1.mass * s2.mass) / distSq;
      const fx = (force * dx) / dist;
      const fy = (force * dy) / dist;
      const fz = (force * dz) / dist;

      s1.vx += fx / s1.mass;
      s1.vy += fy / s1.mass;
      s1.vz += fz / s1.mass;

      s2.vx -= fx / s2.mass;
      s2.vy -= fy / s2.mass;
      s2.vz -= fz / s2.mass;
    }
  }

  // Move stars & update supernovas
  for (const star of stars) {
    star.x += star.vx;
    star.y += star.vy;
    star.z += star.vz;
    
    // Damping
    star.vx *= 0.96;
    star.vy *= 0.96;
    star.vz *= 0.96;

    // Procedural Supernova Explosions for Syntax Errors
    if (star.isError) {
      star.supernovaAge++;
      if (star.supernovaAge % 15 === 0) {
        // Emit shockwave particles
        const particleChars = ['*', '!', '+', 'o', '#', '░', '▒', '▓', '█'];
        const colors = ['\x1b[31m', '\x1b[33m', '\x1b[35m', '\x1b[91m', '\x1b[93m'];
        for (let p = 0; p < 25; p++) {
          const theta = Math.random() * Math.PI * 2;
          const phi = Math.acos((Math.random() * 2) - 1);
          const speed = 0.5 + Math.random() * 1.5;

          particles.push({
            x: star.x,
            y: star.y,
            z: star.z,
            vx: speed * Math.sin(phi) * Math.cos(theta),
            vy: speed * Math.sin(phi) * Math.sin(theta),
            vz: speed * Math.cos(phi),
            char: particleChars[Math.floor(Math.random() * particleChars.length)],
            life: 0,
            maxLife: 20 + Math.random() * 15,
            color: colors[Math.floor(Math.random() * colors.length)]
          });
        }
      }
    }
  }

  // Update particles
  for (let i = particles.length - 1; i >= 0; i--) {
    const p = particles[i];
    p.x += p.vx;
    p.y += p.vy;
    p.z += p.vz;
    p.life++;
    if (p.life >= p.maxLife) {
      particles.splice(i, 1);
    }
  }
}

// 3D Projection Engine
function project(x: number, y: number, z: number, width: number, height: number): { px: number; py: number; depth: number } | null {
  // Rotate around Y
  let rx = x * Math.cos(angleY) + z * Math.sin(angleY);
  let rz = -x * Math.sin(angleY) + z * Math.cos(angleY);
  let ry = y;

  // Rotate around X
  const ryFinal = ry * Math.cos(angleX) - rz * Math.sin(angleX);
  const rzFinal = ry * Math.sin(angleX) + rz * Math.cos(angleX);

  const fov = 120;
  const distance = 80;
  const cameraZ = rzFinal + distance;

  if (cameraZ <= 1) return null;

  const aspect = 2.0; // Terminal character aspect ratio correction
  const px = Math.floor(width / 2 + (rx * fov) / cameraZ * aspect);
  const py = Math.floor(height / 2 + (ryFinal * fov) / cameraZ);

  return { px, py, depth: cameraZ };
}

// Bresenham's 2D line drawing for rendering constellation lines
function drawLine(
  x0: number, y0: number, x1: number, y1: number,
  buffer: string[][], zBuffer: number[][], depth: number,
  width: number, height: number, char: string, color: string
) {
  let dx = Math.abs(x1 - x0);
  let dy = Math.abs(y1 - y0);
  let sx = x0 < x1 ? 1 : -1;
  let sy = y0 < y1 ? 1 : -1;
  let err = dx - dy;

  let currX = x0;
  let currY = y0;

  while (true) {
    if (currX >= 0 && currX < width && currY >= 0 && currY < height) {
      if (depth < zBuffer[currY][currX]) {
        zBuffer[currY][currX] = depth;
        buffer[currY][currX] = color + char + '\x1b[0m';
      }
    }
    if (currX === x1 && currY === y1) break;
    let e2 = 2 * err;
    if (e2 > -dy) { err -= dy; currX += sx; }
    if (e2 < dx) { err += dx; currY += sy; }
  }
}

// Main Render Loop
function render() {
  const width = process.stdout.columns || 80;
  const height = process.stdout.rows || 24;

  const buffer: string[][] = Array.from({ length: height }, () => Array(width).fill(' '));
  const zBuffer: number[][] = Array.from({ length: height }, () => Array(width).fill(Infinity));

  angleY += 0.015;
  angleX += 0.008;

  applyPhysics();

  // 1. Render Constellation Lines
  for (const edge of edges) {
    const s1 = stars[edge.from];
    const s2 = stars[edge.to];
    const p1 = project(s1.x, s1.y, s1.z, width, height);
    const p2 = project(s2.x, s2.y, s2.z, width, height);

    if (p1 && p2) {
      const avgDepth = (p1.depth + p2.depth) / 2;
      drawLine(p1.px, p1.py, p2.px, p2.py, buffer, zBuffer, avgDepth, width, height, '·', '\x1b[36m\x1b[2m');
    }
  }

  // 2. Render Supernova Particles
  for (const p of particles) {
    const proj = project(p.x, p.y, p.z, width, height);
    if (proj && proj.px >= 0 && proj.px < width && proj.py >= 0 && proj.py < height) {
      if (proj.depth < zBuffer[proj.py][proj.px]) {
        zBuffer[proj.py][proj.px] = proj.depth;
        buffer[proj.py][proj.px] = `${p.color}${p.char}\x1b[0m`;
      }
    }
  }

  // 3. Render Stars (Commands)
  for (const star of stars) {
    const proj = project(star.x, star.y, star.z, width, height);
    if (proj && proj.px >= 0 && proj.px < width && proj.py >= 0 && proj.py < height) {
      if (proj.depth < zBuffer[proj.py][proj.px]) {
        zBuffer[proj.py][proj.px] = proj.depth;

        // Choose visual style based on gravitational mass & syntax status
        let symbol = '•';
        let color = '\x1b[37m'; // White

        if (star.isError) {
          symbol = '✸'; // Supernova Core
          color = '\x1b[91m\x1b[1m'; // Bright Red
        } else if (star.count > 5) {
          symbol = '★';
          color = '\x1b[93m\x1b[1m'; // Bright Yellow
        } else if (star.count > 2) {
          symbol = '✶';
          color = '\x1b[96m'; // Bright Cyan
        }

        const label = `${symbol} ${star.cmd} (${star.count})`;
        
        // Draw star label onto buffer
        for (let k = 0; k < label.length; k++) {
          const targetX = proj.px + k;
          if (targetX >= 0 && targetX < width) {
            buffer[proj.py][targetX] = `${color}${label[k]}\x1b[0m`;
          }
        }
      }
    }
  }

  // Output buffer to terminal
  let output = '\x1b[H'; // Move cursor to home
  for (let y = 0; y < height; y++) {
    output += buffer[y].join('') + (y < height - 1 ? '\n' : '');
  }
  process.stdout.write(output);
}

// --- Terminal Setup & Life Cycle ---
console.clear();
process.stdout.write('\x1b[?25l'); // Hide cursor

const interval = setInterval(render, 40);

function cleanup() {
  clearInterval(interval);
  process.stdout.write('\x1b[?25h'); // Restore cursor
  console.clear();
  process.exit(0);
}

process.on('SIGINT', cleanup);
process.on('SIGTERM', cleanup);