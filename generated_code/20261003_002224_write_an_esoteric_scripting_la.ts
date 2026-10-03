// Stained Glass Memory Interpreter - Esoteric TypeScript VM
// Translates memory allocation spikes & segfaults into a real-time generative terminal stained glass window.

import * as process from 'process';

interface Pane {
  char: string;
  color: number;
  cracked: boolean;
}

class StainedGlassWindow {
  width: number;
  height: number;
  grid: Pane[][];

  constructor(width: number, height: number) {
    this.width = width;
    this.height = height;
    const motifs = ['█', '▓', '▒', '░', '◆', '◈', '◇', '◢', '◣', '◤', '◥'];
    const colors = [31, 32, 33, 34, 35, 36, 91, 92, 93, 94, 95, 96];

    this.grid = Array.from({ length: height }, () =>
      Array.from({ length: width }, () => ({
        char: motifs[Math.floor(Math.random() * motifs.length)],
        color: colors[Math.floor(Math.random() * colors.length)],
        cracked: false
      }))
    );
  }

  // Renders the stained glass window using ANSI escape codes
  render(heapMB: number, ip: number) {
    let output = '\x1b[H\x1b[36m=== STAINED GLASS MEMORY VISUALIZER ===\x1b[0m\n';
    for (let y = 0; y < this.height; y++) {
      let rowStr = '';
      for (let x = 0; x < this.width; x++) {
        const pane = this.grid[y][x];
        if (pane.cracked) {
          rowStr += `\x1b[90m⚡\x1b[0m`;
        } else {
          rowStr += `\x1b[${pane.color}m${pane.char}\x1b[0m`;
        }
      }
      output += rowStr + '\n';
    }
    output += `\x1b[33m[Heap Usage: ${heapMB.toFixed(2)} MB] | [Instruction Pointer: ${ip}]\x1b[0m\n`;
    process.stdout.write(output);
  }

  // Propagates structural cracks across the window during a segmentation fault
  fracture(startX: number, startY: number) {
    let queue: [number, number][] = [[startX, startY]];
    let steps = 25;
    while (queue.length > 0 && steps-- > 0) {
      const [cx, cy] = queue.shift()!;
      if (cx >= 0 && cx < this.width && cy >= 0 && cy < this.height) {
        this.grid[cy][cx].cracked = true;
        const directions = [[0, 1], [1, 0], [0, -1], [-1, 0], [1, 1], [-1, -1]];
        for (const [dx, dy] of directions) {
          if (Math.random() > 0.4) {
            queue.push([cx + dx, cy + dy]);
          }
        }
      }
    }
  }

  // Amplifies glass glow/vibrancy when a memory allocation spike occurs
  spikeVibration() {
    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        if (!this.grid[y][x].cracked && Math.random() > 0.8) {
          this.grid[y][x].color = 90 + Math.floor(Math.random() * 7);
        }
      }
    }
  }
}

class GlassVM {
  window: StainedGlassWindow;
  memory: Map<number, Uint8Array> = new Map();
  program: string[] = [];
  ip = 0;
  lastHeap = 0;

  constructor(width: number, height: number) {
    this.window = new StainedGlassWindow(width, height);
  }

  loadSource(code: string) {
    this.program = code.split('\n').map(l => l.trim()).filter(l => l.length > 0);
  }

  step() {
    if (this.ip >= this.program.length) this.ip = 0;
    const line = this.program[this.ip];
    const tokens = line.split(' ');
    const cmd = tokens[0];

    try {
      if (cmd === 'ALLOC') {
        const addr = parseInt(tokens[1]);
        const size = parseInt(tokens[2]);
        if (isNaN(addr) || isNaN(size)) throw new Error('Invalid allocation parameters');
        this.memory.set(addr, new Uint8Array(size));
      } else if (cmd === 'FREE') {
        const addr = parseInt(tokens[1]);
        this.memory.delete(addr);
      } else if (cmd === 'SEGFAULT' || cmd === 'CRASH') {
        throw new Error('Segmentation Fault (Access Violation)');
      }
    } catch (e) {
      // Trigger random structural cracks across the window
      const rx = Math.floor(Math.random() * this.window.width);
      const ry = Math.floor(Math.random() * this.window.height);
      this.window.fracture(rx, ry);
    }

    this.ip++;
  }

  run() {
    console.clear();
    setInterval(() => {
      this.step();

      // Monitor memory allocation spikes
      const currentHeap = process.memoryUsage().heapUsed / 1024 / 1024;
      if (Math.abs(currentHeap - this.lastHeap) > 0.5) {
        this.window.spikeVibration();
      }
      this.lastHeap = currentHeap;

      this.window.render(currentHeap, this.ip);
    }, 250);
  }
}

// Example Execution Program
const script = `
ALLOC 100 1048576
ALLOC 101 2097152
ALLOC 102 4194304
SEGFAULT
ALLOC 103 8388608
FREE 100
SEGFAULT
ALLOC 104 1048576
`;

const vm = new GlassVM(45, 18);
vm.loadSource(script);
vm.run();