import * as v8 from 'v8';

/**
 * Self-Sorting ASCII-Art Clock & Memory-Driven Fluid Simulation
 * 
 * 1. Self-Sorts: Extracts its own source code, sorts the lines/characters logically,
 *    and maps those source characters into fluid particles.
 * 2. Real-time ASCII Clock: Displays current time as ASCII art digits.
 * 3. Memory Gravity: Samples heap memory usage to continuously update fluid gravity.
 * 4. Dynamic ASCII Fluid: Simulates particle density/pressure dynamics using SPH-like mechanics.
 */

const WIDTH = 80;
const HEIGHT = 40;

// Current source code retrieval for self-sorting dynamic texture
const selfSource = (__filename ? require('fs').readFileSync(__filename, 'utf8') : '')
  .split('\n')
  .map(line => line.trim())
  .filter(line => line.length > 0)
  .sort((a, b) => a.localeCompare(b))
  .join('');

const CHAR_POOL = selfSource.length > 0 ? selfSource : '0123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZ';

// Simple 5x3 ASCII digit map
const DIGITS: { [key: string]: string[] } = {
  '0': ['###', '# #', '# #', '# #', '###'],
  '1': ['  #', '  #', '  #', '  #', '  #'],
  '2': ['###', '  #', '###', '#  ', '###'],
  '3': ['###', '  #', '###', '  #', '###'],
  '4': ['# #', '# #', '###', '  #', '  #'],
  '5': ['###', '#  ', '###', '  #', '###'],
  '6': ['###', '#  ', '###', '# #', '###'],
  '7': ['###', '  #', '  #', '  #', '  #'],
  '8': ['###', '# #', '###', '# #', '###'],
  '9': ['###', '# #', '###', '  #', '###'],
  ':': ['   ', ' # ', '   ', ' # ', '   ']
};

interface Particle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  char: string;
}

class SelfSortingClockFluid {
  private particles: Particle[] = [];
  private grid: string[][] = [];

  constructor() {
    this.initGrid();
  }

  private initGrid(): void {
    this.grid = Array.from({ length: HEIGHT }, () => Array(WIDTH).fill(' '));
  }

  // Get memory usage ratio (0.0 to 2.0 scale) to drive gravity dynamic
  private getMemoryGravity(): { gx: number; gy: number } {
    const mem = process.memoryUsage();
    const heapRatio = mem.heapUsed / mem.heapTotal;
    // Base gravity downward (gy), horizontal drift (gx) based on total allocated memory balance
    const gy = 0.15 + heapRatio * 0.8;
    const gx = Math.sin(Date.now() / 1000) * 0.1 * heapRatio;
    return { gx, gy };
  }

  // Generate clock particles in ASCII layout
  private injectClockParticles(): void {
    const now = new Date();
    const hrs = String(now.getHours()).padStart(2, '0');
    const mins = String(now.getMinutes()).padStart(2, '0');
    const secs = String(now.getSeconds()).padStart(2, '0');
    const timeStr = `${hrs}:${mins}:${secs}`;

    const startX = Math.floor((WIDTH - timeStr.length * 4) / 2);
    const startY = 3;

    let charIdx = 0;
    for (let i = 0; i < timeStr.length; i++) {
      const char = timeStr[i];
      const sprite = DIGITS[char] || DIGITS[':'];

      for (let r = 0; r < 5; r++) {
        for (let c = 0; c < 3; c++) {
          if (sprite[r][c] !== ' ') {
            // Pick next character from sorted source code
            const sourceChar = CHAR_POOL[charIdx % CHAR_POOL.length];
            charIdx++;

            // Inject particle at digit position if slot isn't overcrowded
            const px = startX + i * 4 + c;
            const py = startY + r;

            if (Math.random() < 0.25) {
              this.particles.push({
                x: px + (Math.random() - 0.5) * 0.5,
                y: py + (Math.random() - 0.5) * 0.5,
                vx: (Math.random() - 0.5) * 0.5,
                vy: (Math.random() - 0.5) * 0.2,
                char: sourceChar
              });
            }
          }
        }
      }
    }

    // Limit maximum particles for fluid terminal rendering performance
    if (this.particles.length > 600) {
      this.particles.splice(0, this.particles.length - 600);
    }
  }

  // Update particles with fluid behavior, repulsion, and memory gravity
  private updatePhysics(): void {
    const { gx, gy } = this.getMemoryGravity();
    const smoothingRadius = 2.5;

    // Apply SPH-like particle interactions
    for (let i = 0; i < this.particles.length; i++) {
      const p1 = this.particles[i];

      // Gravity force driven by system memory
      p1.vx += gx;
      p1.vy += gy;

      // Inter-particle fluid repulsion/density pressure
      for (let j = i + 1; j < this.particles.length; j++) {
        const p2 = this.particles[j];
        const dx = p2.x - p1.x;
        const dy = p2.y - p1.y;
        const dist = Math.sqrt(dx * dx + dy * dy);

        if (dist < smoothingRadius && dist > 0.0001) {
          const force = (1 - dist / smoothingRadius) * 0.08;
          const fx = (dx / dist) * force;
          const fy = (dy / dist) * force;

          p1.vx -= fx;
          p1.vy -= fy;
          p2.vx += fx;
          p2.vy += fy;
        }
      }

      // Move particle
      p1.x += p1.vx;
      p1.y += p1.vy;

      // Dampening / Viscosity
      p1.vx *= 0.92;
      p1.vy *= 0.92;

      // Boundary collisions (box container)
      if (p1.x < 1) { p1.x = 1; p1.vx *= -0.5; }
      if (p1.x >= WIDTH - 1) { p1.x = WIDTH - 2; p1.vx *= -0.5; }
      if (p1.y < 1) { p1.y = 1; p1.vy *= -0.5; }
      if (p1.y >= HEIGHT - 2) { p1.y = HEIGHT - 3; p1.vy *= -0.4; }
    }
  }

  // Render fluid ASCII field onto buffer
  public render(): void {
    this.initGrid();
    this.injectClockParticles();
    this.updatePhysics();

    // Draw borders
    for (let x = 0; x < WIDTH; x++) {
      this.grid[0][x] = '─';
      this.grid[HEIGHT - 2][x] = '─';
    }
    for (let y = 0; y < HEIGHT - 1; y++) {
      this.grid[y][0] = '│';
      this.grid[y][WIDTH - 1] = '│';
    }
    this.grid[0][0] = '┌';
    this.grid[0][WIDTH - 1] = '┐';
    this.grid[HEIGHT - 2][0] = '└';
    this.grid[HEIGHT - 2][WIDTH - 1] = '┘';

    // Render particles
    for (const p of this.particles) {
      const rx = Math.floor(p.x);
      const ry = Math.floor(p.y);
      if (rx > 0 && rx < WIDTH - 1 && ry > 0 && ry < HEIGHT - 2) {
        this.grid[ry][rx] = p.char;
      }
    }

    // Render system status bar driven by heap memory
    const mem = process.memoryUsage();
    const heapMB = (mem.heapUsed / 1024 / 1024).toFixed(2);
    const { gy } = this.getMemoryGravity();
    const statusStr = ` MEM HEAP: ${heapMB} MB | GRAVITY (gy): ${gy.toFixed(3)} | PARTICLES: ${this.particles.length} `;
    
    for (let i = 0; i < statusStr.length && i < WIDTH - 4; i++) {
      this.grid[HEIGHT - 2][2 + i] = statusStr[i];
    }

    // Output to console screen
    process.stdout.write('\x1Bc'); // Clear terminal screen
    process.stdout.write(this.grid.map(row => row.join('')).join('\n') + '\n');
  }
}

// Start simulation tick loop
const sim = new SelfSortingClockFluid();
setInterval(() => {
  sim.render();
}, 50);