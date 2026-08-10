// ASCII Pipe Fluid Dynamics Language Interpreter (HydroScript)
// Simulates fluid pressure/particles flowing through ASCII pipes, valves, and transducers.

const PIPELINES = `
       +--- 9 > d > d > d ---------\\
       |                           |
       |  +-- 9 > d > d > d > i -\\ |
       |  |                      | |
       |  |  +-- 8 > d > d > i -\\| |
       |  |  |                  || |
       v  v  v                  vv v
  5 > d > p  p                  p  p
`;

class HydroInterpreter {
  constructor(asciiArt) {
    this.grid = asciiArt.split('\n').map(row => row.split(''));
    this.height = this.grid.length;
    this.width = Math.max(...this.grid.map(r => r.length));
    this.particles = [];
    this.output = '';

    // Initialize fluid sources (digits 1-9 emit particles moving right)
    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < (this.grid[y]?.length || 0); x++) {
        const char = this.grid[y][x];
        if (char >= '1' && char <= '9') {
          this.particles.push({ x, y, dx: 1, dy: 0, val: parseInt(char, 10) });
        }
      }
    }
  }

  step() {
    const nextParticles = [];

    for (const p of this.particles) {
      // Advance fluid particle based on current direction vector
      const nx = p.x + p.dx;
      const ny = p.y + p.dy;

      // Check bounds
      if (ny < 0 || ny >= this.height || nx < 0 || nx >= (this.grid[ny]?.length || 0)) {
        continue;
      }

      const cell = this.grid[ny][nx];
      let { dx, dy, val } = p;
      let destroyed = false;

      // Interact with pipe components and valves
      switch (cell) {
        case '>': dx = 1; dy = 0; break;
        case '<': dx = -1; dy = 0; break;
        case '^': dx = 0; dy = -1; break;
        case 'v': dx = 0; dy = 1; break;
        case '/':  [dx, dy] = [-dy, -dx]; break; // 45-degree mirror valve
        case '\\': [dx, dy] = [dy, dx]; break;   // 135-degree mirror valve
        case 'i': val += 1; break;               // Increment pressure valve
        case 'm': val -= 1; break;               // Decrement pressure valve
        case 'd': val *= 2; break;               // Double pressure multiplier
        case 's': val *= val; break;             // Square pressure multiplier
        case 'p':                                // ASCII output transducer
          this.output += String.fromCharCode(val);
          destroyed = true;
          break;
        case 'n':                                // Numeric output transducer
          this.output += val + ' ';
          destroyed = true;
          break;
        case '?':                                // Pressure switch valve
          if (val <= 0) [dx, dy] = [-dy, dx];    // Turn right if pressure zero/negative
          break;
        case '#':                                // Fluid sink / drain
          destroyed = true;
          break;
        case ' ':                                // Leakage/Evaporation in open space
          destroyed = true;
          break;
        // Pipe junctions ('-', '|', '+') preserve current momentum
      }

      if (!destroyed) {
        nextParticles.push({ x: nx, y: ny, dx, dy, val });
      }
    }

    // Merge colliding fluid particles (combine pressure values)
    const mergedMap = new Map();
    for (const p of nextParticles) {
      const key = `${p.x},${p.y}`;
      if (mergedMap.has(key)) {
        const existing = mergedMap.get(key);
        existing.val += p.val; // Sum fluid pressures
      } else {
        mergedMap.set(key, p);
      }
    }

    this.particles = Array.from(mergedMap.values());
    return this.particles.length > 0;
  }

  run() {
    let ticks = 0;
    const maxTicks = 1000;
    while (this.step() && ticks < maxTicks) {
      ticks++;
    }
    return this.output;
  }
}

// Execute the fluid program
const interpreter = new HydroInterpreter(PIPELINES);
const result = interpreter.run();

console.log("HydroScript Execution Output:");
console.log(result);