import * as readline from 'readline';

// --- TYPES & INTERFACES ---
interface MemoryPointer {
  address: string;
  poetry: string;
  decayRate: number;
}

interface Point {
  x: number;
  y: number;
}

// --- CONSTANTS & DATA ---
const WIDTH = 70;
const HEIGHT = 20;

const MOLD_CHARS = ['░', '▒', '▓', '█', '*', '%', '@', '~', '?', '!', '&', '§', '#', 'Ø'];
const ANSI = {
  reset: '\x1b[0m',
  clear: '\x1b[2J\x1b[H',
  hideCursor: '\x1b[?25l',
  showCursor: '\x1b[?25h',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  dim: '\x1b[2m',
  bold: '\x1b[1m',
  moldColor: '\x1b[38;5;34m', // Visual mold green
  critColor: '\x1b[38;5;196m' // Stack collapse red
};

// Procedural poetry generators
const POETIC_SUBJECTS = ['null pointer', 'dangling reference', 'orphan thread', 'heap buffer', 'lost stack', 'ghost process', 'dangling node'];
const POETIC_VERBS = ['weeps into', 'corrupts', 'haunts', 'dissolves inside', 'bleeds through', 'shadows', 'fades within'];
const POETIC_OBJECTS = ['the static void', 'cold silicon', 'frozen registers', 'unreachable RAM', 'dark cache', 'allocated space'];

// --- ASCII INTERFACE TEMPLATE ---
const ASCII_UI = [
  "┌────────────────────────────────────────────────────────────────────┐",
  "│ SYS_OS // CORE MEMORY MONITOR              [STACK FRAME: STABLE]   │",
  "├────────────────────────────────────────────────────────────────────┤",
  "│  PROCESS_TREE:                                                     │",
  "│    ├─ init.sys (PID: 0001) [RUNNING]                               │",
  "│    ├─ heap_allocator.bin [LEAK DETECTED]                           │",
  "│    └─ visual_pipeline.engine [INTEGRITY OK]                        │",
  "│                                                                    │",
  "│  PHYSICAL RAM MATRIX:                                              │",
  "│  [0x00]  ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■           │",
  "│  [0x20]  ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■           │",
  "│  [0x40]  ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■           │",
  "│  [0x60]  ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■           │",
  "│                                                                    │",
  "│  STATUS: SYMBOLS DECAYING... RECLAIM MEMORY IMMEDIATELY.           │",
  "└────────────────────────────────────────────────────────────────────┘"
];

// --- MAIN SIMULATOR CLASS ---
class MoldTerminalSimulator {
  private buffer: string[][];
  private moldGrid: boolean[][];
  private leaks: MemoryPointer[] = [];
  private currentInput = '';
  private totalCells = WIDTH * HEIGHT;
  private moldCount = 0;
  private gameInterval?: NodeJS.Timeout;
  private leakInterval?: NodeJS.Timeout;
  private isGameOver = false;

  constructor() {
    this.buffer = Array.from({ length: HEIGHT }, (_, y) =>
      (ASCII_UI[y] || '').padEnd(WIDTH, ' ').substring(0, WIDTH).split('')
    );
    this.moldGrid = Array.from({ length: HEIGHT }, () => Array(WIDTH).fill(false));
  }

  public start(): void {
    // Setup terminal
    process.stdout.write(ANSI.clear + ANSI.hideCursor);
    if (process.stdin.setRawMode) {
      process.stdin.setRawMode(true);
    }
    readline.emitKeypressEvents(process.stdin);
    process.stdin.resume();

    process.stdin.on('keypress', this.handleInput.bind(this));

    // Spawn initial memory leak
    this.spawnLeak();

    // Loop timers
    this.gameInterval = setInterval(() => this.tick(), 150);
    this.leakInterval = setInterval(() => this.spawnLeak(), 9000);

    this.render();
  }

  // Generate dynamic poetic GC trigger
  private generatePoetry(): string {
    const s = POETIC_SUBJECTS[Math.floor(Math.random() * POETIC_SUBJECTS.length)];
    const v = POETIC_VERBS[Math.floor(Math.random() * POETIC_VERBS.length)];
    const o = POETIC_OBJECTS[Math.floor(Math.random() * POETIC_OBJECTS.length)];
    return `${s} ${v} ${o}`;
  }

  // Create dangling reference pointer leak
  private spawnLeak(): void {
    if (this.isGameOver || this.leaks.length >= 3) return;

    const address = '0x' + Math.floor(Math.random() * 0xFFFFFF).toString(16).toUpperCase().padStart(6, '0');
    const poetry = this.generatePoetry();
    
    this.leaks.push({
      address,
      poetry,
      decayRate: 1.5
    });
  }

  // Main simulation tick: grows visual mold decay
  private tick(): void {
    if (this.isGameOver) return;

    // Spread decay based on leak count
    const intensity = Math.max(1, this.leaks.length * 2);
    for (let i = 0; i < intensity; i++) {
      this.spreadMold();
    }

    // Check Stack Collapse threshold (35% total UI corruption)
    if (this.mouldPercentage() >= 35) {
      this.triggerStackCollapse();
      return;
    }

    this.render();
  }

  // Mold propagation algorithm
  private spreadMold(): void {
    let x: number, y: number;

    // Pick seed or neighbor cell
    if (this.moldCount === 0 || Math.random() < 0.2) {
      x = Math.floor(Math.random() * WIDTH);
      y = Math.floor(Math.random() * HEIGHT);
    } else {
      // Find active mold node to decay adjacents
      const moldyPoints: Point[] = [];
      for (let r = 0; r < HEIGHT; r++) {
        for (let c = 0; c < WIDTH; c++) {
          if (this.moldGrid[r][c]) moldyPoints.push({ x: c, y: r });
        }
      }
      if (moldyPoints.length === 0) return;
      const origin = moldyPoints[Math.floor(Math.random() * moldyPoints.length)];
      x = Math.min(Math.max(0, origin.x + Math.floor(Math.random() * 3) - 1), WIDTH - 1);
      y = Math.min(Math.max(0, origin.y + Math.floor(Math.random() * 3) - 1), HEIGHT - 1);
    }

    if (!this.moldGrid[y][x]) {
      this.moldGrid[y][x] = true;
      this.moldCount++;
    }

    // Mutate underlying visual text buffer cell
    const char = MOLD_CHARS[Math.floor(Math.random() * MOLD_CHARS.length)];
    this.buffer[y][x] = char;
  }

  // Cleans mold decay upon successfully typing poem trigger
  private collectGarbage(index: number): void {
    this.leaks.splice(index, 1);

    // Physical memory cleanup: sweep ~40% of active visual mold
    for (let y = 0; y < HEIGHT; y++) {
      for (let x = 0; x < WIDTH; x++) {
        if (this.moldGrid[y][x] && Math.random() < 0.45) {
          this.moldGrid[y][x] = false;
          this.moldCount--;
          // Restore original terminal graphics frame
          const originalRow = ASCII_UI[y] || '';
          this.buffer[y][x] = originalRow[x] || ' ';
        }
      }
    }
  }

  private mouldPercentage(): number {
    return Math.floor((this.moldCount / this.totalCells) * 100);
  }

  // Handles input and checks active poems
  private handleInput(str: string, key: readline.Key): void {
    if (key.ctrl && key.name === 'c') {
      this.stop();
      process.exit();
    }

    if (this.isGameOver) return;

    if (key.name === 'return') {
      const cleanInput = this.currentInput.trim().toLowerCase();
      
      // Match input against active dangling leaks
      const targetIndex = this.leaks.findIndex(l => l.poetry.toLowerCase() === cleanInput);
      if (targetIndex !== -1) {
        this.collectGarbage(targetIndex);
      }
      
      this.currentInput = '';
    } else if (key.name === 'backspace') {
      this.currentInput = this.currentInput.slice(0, -1);
    } else if (str && str.length === 1 && !key.ctrl) {
      this.currentInput += str;
    }

    this.render();
  }

  // Render ANSI graphics frame
  private render(): void {
    let output = ANSI.clear;

    // Header Info
    const corruption = this.mouldPercentage();
    const statusColor = corruption > 20 ? ANSI.critColor : ANSI.cyan;
    output += `${ANSI.bold}${ANSI.cyan}=== POINTER POETRY GARBAGE COLLECTOR ===${ANSI.reset}\n`;
    output += `STACK INTEGRITY: ${statusColor}${100 - corruption}%${ANSI.reset} | ACTIVE LEAKS: ${ANSI.yellow}${this.leaks.length}${ANSI.reset}\n\n`;

    // Render Corrupted ASCII Matrix Buffer
    for (let y = 0; y < HEIGHT; y++) {
      let rowStr = '';
      for (let x = 0; x < WIDTH; x++) {
        const char = this.buffer[y][x];
        if (this.moldGrid[y][x]) {
          rowStr += `${ANSI.moldColor}${char}${ANSI.reset}`;
        } else {
          rowStr += `${ANSI.dim}${char}${ANSI.reset}`;
        }
      }
      output += rowStr + '\n';
    }

    // Leaking Pointers Console
    output += `\n${ANSI.bold}${ANSI.magenta}--- LEAKING POINTER POETRY PROMPTS ---${ANSI.reset}\n`;
    if (this.leaks.length === 0) {
      output += `${ANSI.green}No dangling pointers. Memory stable.${ANSI.reset}\n`;
    } else {
      this.leaks.forEach((leak) => {
        output += `[${ANSI.yellow}${leak.address}${ANSI.reset}] Type: "${ANSI.cyan}${ANSI.bold}${leak.poetry}${ANSI.reset}"\n`;
      });
    }

    // Interactive GC Command Line
    output += `\n${ANSI.bold}GC_EXECUTE > ${ANSI.reset}${this.currentInput}█\n`;

    process.stdout.write(output);
  }

  // GameOver - Terminal Stack Collapse
  private triggerStackCollapse(): void {
    this.isGameOver = true;
    this.stop();

    let output = ANSI.clear;
    output += `${ANSI.critColor}${ANSI.bold}`;
    output += `\n====================================================\n`;
    output += `   FATAL ERROR: STACK FRAME COLLAPSED (SEGFAULT)    \n`;
    output += `   MEMORY LEAKS FULLY CORRUPTED THE INTERFACE.       \n`;
    output += `====================================================\n${ANSI.reset}`;
    
    process.stdout.write(output + ANSI.showCursor + '\n');
    process.exit();
  }

  private stop(): void {
    if (this.gameInterval) clearInterval(this.gameInterval);
    if (this.leakInterval) clearInterval(this.leakInterval);
    process.stdout.write(ANSI.showCursor);
  }
}

// Executing Terminal App
const app = new MoldTerminalSimulator();
app.start();