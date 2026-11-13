/**
 * Typographic Botanical Time Capsule
 * Transforms system error logs and memory metrics into an ASCII botanical garden.
 * Stack traces determine petal decay; memory leaks sprout intricate, rare orchids.
 */

interface SystemLog {
  id: string;
  timestamp: string;
  type: 'NULL_POINTER' | 'MEMORY_LEAK' | 'TYPE_MISMATCH' | 'STACK_OVERFLOW';
  message: string;
  stackTraceDepth: number;
  memoryLeakBytes: number;
}

class BotanicalCanvas {
  private grid: string[][];
  private width: number;
  private height: number;

  constructor(width: number = 74, height: number = 22) {
    this.width = width;
    this.height = height;
    this.grid = Array.from({ length: height }, () => Array(width).fill(' '));
  }

  public drawStem(startX: number, endY: number): void {
    let x = startX;
    for (let y = this.height - 2; y >= endY; y--) {
      if (x >= 0 && x < this.width && y >= 0 && y < this.height) {
        this.grid[y][x] = '|';
        // Organic curvature along the stem
        if (y % 4 === 0) x += (y % 2 === 0 ? 1 : -1);
      }
    }
  }

  public drawPetals(centerX: number, centerY: number, decayRate: number): void {
    // Higher stack trace depth increases decay (withered/drooping characters)
    const petalChars = decayRate > 0.7 ? ['.', '`', '~', '-'] : decayRate > 0.4 ? ['o', 'u', 'c', 'v'] : ['@', '❀', '✿', '❁'];
    const radius = Math.max(2, Math.floor(6 * (1 - decayRate * 0.4)));

    for (let dy = -radius; dy <= radius; dy++) {
      for (let dx = -radius * 2; dx <= radius * 2; dx++) {
        const dist = Math.sqrt((dx * dx) / 4 + dy * dy);
        if (dist <= radius && dist >= radius - 1.5) {
          const px = centerX + dx;
          const py = centerY + dy;
          if (px >= 0 && px < this.width && py >= 0 && py < this.height) {
            const charIndex = Math.abs(px + py) % petalChars.length;
            this.grid[py][px] = petalChars[charIndex];
          }
        }
      }
    }
  }

  public drawOrchidBloom(centerX: number, centerY: number, intensity: number): void {
    // Memory leaks bloom into complex, multi-layered exotic orchids
    const orchidSymbols = ['*', '§', 'Ψ', 'Φ', 'Ω', '❀', '‡'];
    const layers = Math.min(5, Math.max(2, Math.floor(intensity / 100)));

    for (let l = 1; l <= layers; l++) {
      const r = l * 2;
      for (let angle = 0; angle < Math.PI * 2; angle += Math.PI / 6) {
        const ox = Math.round(centerX + Math.cos(angle) * r * 1.5);
        const oy = Math.round(centerY + Math.sin(angle) * r);
        if (ox >= 0 && ox < this.width && oy >= 0 && oy < this.height) {
          this.grid[oy][ox] = orchidSymbols[(l + ox + oy) % orchidSymbols.length];
        }
      }
    }
    
    // Core of the rare orchid
    if (centerX >= 0 && centerX < this.width && centerY >= 0 && centerY < this.height) {
      this.grid[centerY][centerX] = '█';
    }
  }

  public render(logs: SystemLog[]): string {
    // Draw rich soil base
    for (let x = 0; x < this.width; x++) {
      this.grid[this.height - 1][x] = '_';
    }

    const plantX = Math.floor(this.width / 2);
    this.drawStem(plantX, 4);

    logs.forEach((log, index) => {
      const flowerY = Math.max(3, this.height - 5 - (index * 4));
      const decay = Math.min(1.0, log.stackTraceDepth / 25);

      if (log.type === 'MEMORY_LEAK') {
        this.drawOrchidBloom(plantX + (index % 2 === 0 ? 4 : -4), flowerY, log.memoryLeakBytes);
      } else {
        this.drawPetals(plantX, flowerY, decay);
      }
    });

    return this.grid.map(row => row.join('')).join('\n');
  }
}

// Simulated real-time stream of system logs
const systemErrorStream: SystemLog[] = [
  {
    id: 'ERR-101',
    timestamp: '2026-03-30T12:00:00Z',
    type: 'NULL_POINTER',
    message: 'Cannot read properties of undefined (reading "config")',
    stackTraceDepth: 4,
    memoryLeakBytes: 0,
  },
  {
    id: 'ERR-102',
    timestamp: '2026-03-30T12:05:00Z',
    type: 'TYPE_MISMATCH',
    message: 'Argument of type "number" is not assignable to parameter of type "string"',
    stackTraceDepth: 10,
    memoryLeakBytes: 0,
  },
  {
    id: 'ERR-103',
    timestamp: '2026-03-30T12:15:00Z',
    type: 'MEMORY_LEAK',
    message: 'Heap snapshot: Detached DOM tree retained via closure',
    stackTraceDepth: 3,
    memoryLeakBytes: 520, // Triggers rare orchid bloom
  },
  {
    id: 'ERR-104',
    timestamp: '2026-03-30T12:30:00Z',
    type: 'STACK_OVERFLOW',
    message: 'Maximum call stack size exceeded in recursive transformer',
    stackTraceDepth: 28, // High decay rate on petals
  },
];

// Execute the time capsule generation
const capsule = new BotanicalCanvas();
const botanicalIllustration = capsule.render(systemErrorStream);

console.log("=== TYPOGRAPHIC BOTANICAL TIME CAPSULE ===");
console.log(`Translated ${systemErrorStream.length} system events into living flora.\n`);
console.log(botanicalIllustration);
console.log("\n==========================================");