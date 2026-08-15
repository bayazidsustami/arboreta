import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import * as readline from 'readline';

// --- Interfaces ---
interface Star {
  x: number;
  y: number;
  char: string;
  brightness: number; // 0.0 to 1.0
  command: string;
  frequency: number;
  lastUsed: Date;
  clusterId: number;
}

interface BlackHole {
  x: number;
  y: number;
  radius: number;
  life: number; // 1.0 down to 0.0
  errorCmd: string;
}

interface ConstellationLine {
  x1: number;
  y1: number;
  x2: number;
  y2: number;
  opacity: number;
}

// --- Shell History Parsing ---
function getHistoryFilePath(): string {
  const home = os.homedir();
  const candidates = [
    process.env.HISTFILE,
    path.join(home, '.zsh_history'),
    path.join(home, '.bash_history')
  ];
  for (const file of candidates) {
    if (file && fs.existsSync(file)) return file;
  }
  return '';
}

function parseHistory(): { commands: Map<string, { count: number; lastTime: Date }>; errors: Array<{ cmd: string; time: Date }> } {
  const historyPath = getHistoryFilePath();
  const commands = new Map<string, { count: number; lastTime: Date }>();
  const errors: Array<{ cmd: string; time: Date }> = [];

  if (!historyPath) {
    // Generate dummy historical data if no history file exists
    const dummyCmds = ['git status', 'npm start', 'ls -la', 'cd src', 'node index.js', 'docker ps', 'vim config.json'];
    const dummyErrs = ['gti status', 'npm statr', 'sl -la', 'cd src/nonexistent'];
    
    dummyCmds.forEach((cmd, idx) => {
      commands.set(cmd, { count: (idx + 1) * 7, lastTime: new Date(Date.now() - idx * 86400000) });
    });
    dummyErrs.forEach((cmd, idx) => {
      errors.push({ cmd, time: new Date(Date.now() - idx * 3600000) });
    });
    return { commands, errors };
  }

  const content = fs.readFileSync(historyPath, 'utf-8');
  const lines = content.split('\n');

  // Syntax error pattern matching (typos, unknown subcommands)
  const errorPattern = /^(sl|gti|got|mda|mkrdir|cd\.\.|npm statr|npm runn|dockre)\b/;

  for (const line of lines) {
    let clean = line.replace(/^:\s*\d+:\d+;/, '').trim(); // Strip zsh timestamp headers if present
    if (!clean) continue;

    // Check if entry contains zsh timestamp
    let timestamp = new Date();
    const tsMatch = line.match(/^:\s*(\d+):/);
    if (tsMatch) {
      timestamp = new Date(parseInt(tsMatch[1], 10) * 1000);
    }

    const baseCmd = clean.split(' ')[0];

    if (errorPattern.test(clean) || clean.includes('err') || clean.includes('undefined')) {
      errors.push({ cmd: clean, time: timestamp });
    } else {
      const existing = commands.get(clean) || { count: 0, lastTime: timestamp };
      commands.set(clean, {
        count: existing.count + 1,
        lastTime: timestamp > existing.lastTime ? timestamp : existing.lastTime
      });
    }
  }

  return { commands, errors };
}

// --- Terminal Renderer Engine ---
class StarlightTerminalMapper {
  private width: number = 80;
  private height: number = 24;
  private stars: Star[] = [];
  private blackHoles: BlackHole[] = [];
  private selectedStarIdx: number = 0;
  private timer: NodeJS.Timeout | null = null;

  constructor() {
    this.updateDimensions();
  }

  private updateDimensions() {
    this.width = process.stdout.columns || 80;
    this.height = Math.max((process.stdout.rows || 24) - 4, 10);
  }

  // Converts string hash into deterministic astronomical coordinates
  private hashToCoords(str: string): { x: number; y: number; cluster: number } {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      hash = (hash << 5) - hash + str.charCodeAt(i);
      hash |= 0;
    }
    const normalizedX = Math.abs(hash % (this.width - 6)) + 3;
    const normalizedY = Math.abs((hash >> 3) % (this.height - 4)) + 2;
    const cluster = Math.abs(hash % 5);
    return { x: normalizedX, y: normalizedY, cluster };
  }

  public init() {
    const { commands, errors } = parseHistory();
    const now = Date.now();

    // Map commands to Stars
    let maxFreq = 1;
    commands.forEach(val => { if (val.count > maxFreq) maxFreq = val.count; });

    commands.forEach((data, cmd) => {
      const { x, y, cluster } = this.hashToCoords(cmd);
      const ageHours = (now - data.lastTime.getTime()) / (1000 * 3600);
      const recencyFactor = Math.max(0.2, 1 - ageHours / (24 * 30)); // 30 day decay
      const frequencyFactor = Math.min(1.0, data.count / maxFreq);
      const brightness = 0.3 * frequencyFactor + 0.7 * recencyFactor;

      const starChars = ['.', '·', '*', '✦', '★', '✸'];
      const charIdx = Math.min(Math.floor(brightness * starChars.length), starChars.length - 1);

      this.stars.push({
        x,
        y,
        char: starChars[charIdx],
        brightness,
        command: cmd,
        frequency: data.count,
        lastUsed: data.lastTime,
        clusterId: cluster
      });
    });

    // Map errors to Black Holes
    errors.slice(-8).forEach(err => {
      const { x, y } = this.hashToCoords(err.cmd);
      this.blackHoles.push({
        x,
        y,
        radius: 2 + Math.floor(Math.random() * 2),
        life: 1.0,
        errorCmd: err.cmd
      });
    });

    // Setup terminal interface
    process.stdout.write('\x1b[?25l'); // Hide cursor
    process.stdout.write('\x1b[2J');   // Clear screen

    if (process.stdin.setRawMode) {
      process.stdin.setRawMode(true);
      readline.emitKeypressEvents(process.stdin);
      process.stdin.on('keypress', (_, key) => this.handleInput(key));
    }

    process.on('SIGWINCH', () => {
      this.updateDimensions();
      process.stdout.write('\x1b[2J');
    });

    // Main animation frame loop
    this.timer = setInterval(() => this.render(), 100);
  }

  private handleInput(key: readline.Key) {
    if (key.ctrl && key.name === 'c') {
      this.cleanup();
      process.exit();
    }
    if (key.name === 'left' || key.name === 'h') {
      this.selectedStarIdx = (this.selectedStarIdx - 1 + this.stars.length) % this.stars.length;
    }
    if (key.name === 'right' || key.name === 'l' || key.name === 'tab') {
      this.selectedStarIdx = (this.selectedStarIdx + 1) % this.stars.length;
    }
  }

  private cleanup() {
    if (this.timer) clearInterval(this.timer);
    process.stdout.write('\x1b[?25h'); // Show cursor
    process.stdout.write('\x1b[0m\n');
  }

  private render() {
    const buffer: string[][] = Array.from({ length: this.height }, () =>
      Array(this.width).fill(' ')
    );
    const colorBuffer: string[][] = Array.from({ length: this.height }, () =>
      Array(this.width).fill('\x1b[0m')
    );

    // Fade Black Holes over time
    this.blackHoles.forEach(bh => {
      bh.life -= 0.005;
      if (bh.life < 0) bh.life = 0;
    });

    // 1. Draw Constellation lines between stars in identical clusters
    for (let i = 0; i < this.stars.length; i++) {
      for (let j = i + 1; j < this.stars.length; j++) {
        const s1 = this.stars[i];
        const s2 = this.stars[j];
        if (s1.clusterId === s2.clusterId) {
          const dist = Math.hypot(s1.x - s2.x, s1.y - s2.y);
          if (dist < 15) {
            this.drawLine(s1.x, s1.y, s2.x, s2.y, buffer, colorBuffer);
          }
        }
      }
    }

    // 2. Draw Stars
    this.stars.forEach((star, idx) => {
      if (star.x >= 0 && star.x < this.width && star.y >= 0 && star.y < this.height) {
        const isSelected = idx === this.selectedStarIdx;
        buffer[star.y][star.x] = isSelected ? '☉' : star.char;

        // Color scale based on brightness and selection
        if (isSelected) {
          colorBuffer[star.y][star.x] = '\x1b[1;33m'; // Bright Yellow
        } else if (star.brightness > 0.7) {
          colorBuffer[star.y][star.x] = '\x1b[1;36m'; // Bright Cyan
        } else if (star.brightness > 0.4) {
          colorBuffer[star.y][star.x] = '\x1b[0;34m'; // Blue
        } else {
          colorBuffer[star.y][star.x] = '\x1b[2;37m'; // Dim White
        }
      }
    });

    // 3. Render Fading Black Holes (Past Syntax Errors)
    this.blackHoles.forEach(bh => {
      if (bh.life <= 0) return;
      const r = Math.ceil(bh.radius * bh.life);
      for (let dy = -r; dy <= r; dy++) {
        for (let dx = -r * 2; dx <= r * 2; dx++) {
          const px = bh.x + dx;
          const py = bh.y + dy;
          if (px >= 0 && px < this.width && py >= 0 && py < this.height) {
            const dist = Math.hypot(dx / 2, dy);
            if (dist <= r) {
              buffer[py][px] = dist < r * 0.5 ? ' ' : '░';
              colorBuffer[py][px] = bh.life > 0.5 ? '\x1b[40;30m' : '\x1b[2;35m'; // Event horizon effect
            }
          }
        }
      }
    });

    // Frame Buffer output construct
    let output = '\x1b[H'; // Cursor to top-left
    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        output += colorBuffer[y][x] + buffer[y][x];
      }
      output += '\x1b[0m\n';
    }

    // Render Status Dashboard
    const sel = this.stars[this.selectedStarIdx];
    const statusLine1 = `── STAR MAPPER ── [Star ${this.selectedStarIdx + 1}/${this.stars.length}] ───────────────────────────────────`;
    const statusLine2 = sel 
      ? `Command: \x1b[1;32m"${sel.command}"\x1b[0m | Executions: \x1b[1;33m${sel.frequency}\x1b[0m | Brightness: \x1b[1;36m${(sel.brightness * 100).toFixed(0)}%\x1b[0m`
      : 'Scanning sky...';
    const statusLine3 = `Active Black Holes (Errors): ${this.blackHoles.filter(b => b.life > 0).length} | Nav: [←/→/Tab] | Exit: [Ctrl+C]`;

    output += `\x1b[0;37m${statusLine1.slice(0, this.width)}\x1b[0m\n`;
    output += `${statusLine2}\x1b[K\n`;
    output += `\x1b[2;37m${statusLine3.slice(0, this.width)}\x1b[0m\x1b[K`;

    process.stdout.write(output);
  }

  // Bresenham's line algorithm for rendering constellation connections
  private drawLine(x0: number, y0: number, x1: number, y1: number, buf: string[][], colorBuf: string[][]) {
    const dx = Math.abs(x1 - x0);
    const dy = Math.abs(y1 - y0);
    const sx = x0 < x1 ? 1 : -1;
    const sy = y0 < y1 ? 1 : -1;
    let err = dx - dy;

    let cx = x0;
    let cy = y0;

    while (true) {
      if (cx >= 0 && cx < this.width && cy >= 0 && cy < this.height) {
        if (buf[cy][cx] === ' ') {
          buf[cy][cx] = '·';
          colorBuf[cy][cx] = '\x1b[2;30m'; // Subtle dark gray path
        }
      }
      if (cx === x1 && cy === y1) break;
      const e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        cx += sx;
      }
      if (e2 < dx) {
        err += dx;
        cy += sy;
      }
    }
  }
}

// Executable entry point
const mapper = new StarlightTerminalMapper();
mapper.init();