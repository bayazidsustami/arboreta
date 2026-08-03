import { execSync } from 'child_process';
import * as readline from 'readline';

// --- Types & Interfaces ---
interface Commit {
  hash: string;
  message: string;
  author: string;
  isMerge: boolean;
  churn: number; // total insertions + deletions
  parents: string[];
}

interface Plant {
  x: number;
  y: number;
  type: 'stem' | 'flower' | 'fungus' | 'bud' | 'leaf';
  char: string;
  color: string;
  age: number;
}

// --- Git Log Parser ---
function getGitCommits(): Commit[] {
  try {
    const rawLog = execSync('git log --pretty=format:"COMMIT|%h|%s|%an|%p" --numstat -n 40', {
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'ignore'],
    });

    const commits: Commit[] = [];
    const lines = rawLog.split('\n');
    let currentCommit: Partial<Commit> | null = null;
    let currentChurn = 0;

    for (const line of lines) {
      if (line.startsWith('COMMIT|')) {
        if (currentCommit) {
          currentCommit.churn = currentChurn;
          commits.push(currentCommit as Commit);
        }
        const [, hash, message, author, parentsStr] = line.split('|');
        const parents = parentsStr ? parentsStr.trim().split(' ') : [];
        currentCommit = {
          hash,
          message,
          author,
          parents,
          isMerge: parents.length > 1 || message.toLowerCase().includes('merge'),
        };
        currentChurn = 0;
      } else if (currentCommit && line.trim() !== '') {
        const parts = line.split('\t');
        if (parts.length >= 2) {
          const added = parseInt(parts[0], 10) || 0;
          const deleted = parseInt(parts[1], 10) || 0;
          currentChurn += added + deleted;
        }
      }
    }
    if (currentCommit) {
      currentCommit.churn = currentChurn;
      commits.push(currentCommit as Commit);
    }
    return commits.reverse(); // Chronological order
  } catch {
    // Fallback procedural seed data if not run inside a git repository
    return Array.from({ length: 25 }, (_, i) => ({
      hash: Math.random().toString(16).substring(2, 8),
      message: i % 5 === 0 ? `Merge branch 'feature/${i}'` : `Refactor module #${i}`,
      author: 'Gardener',
      isMerge: i % 5 === 0,
      churn: Math.floor(Math.random() * (i % 3 === 0 ? 350 : 30)),
      parents: ['prev'],
    }));
  }
}

// --- Procedural Garden Engine ---
class TerminalGarden {
  private width: number;
  private height: number;
  private grid: string[][];
  private colorGrid: string[][];
  private plants: Plant[] = [];
  private commits: Commit[];
  private commitIndex = 0;
  private timer: NodeJS.Timeout | null = null;

  // ANSI Colors
  private colors = {
    reset: '\x1b[0m',
    stem: '\x1b[32m',       // Green
    leaf: '\x1b[92m',       // Bright Green
    flower1: '\x1b[35m',    // Magenta
    flower2: '\x1b[93m',    // Yellow
    flower3: '\x1b[95m',    // Light Magenta
    fungus1: '\x1b[31m',    // Red
    fungus2: '\x1b[33m',    // Dark Yellow / Brownish
    decay: '\x1b[90m',      // Gray
    hud: '\x1b[36m',        // Cyan
  };

  constructor(commits: Commit[]) {
    this.commits = commits;
    this.width = Math.min(process.stdout.columns || 80, 100);
    this.height = Math.min((process.stdout.rows || 24) - 4, 30);
    this.grid = Array.from({ length: this.height }, () => Array(this.width).fill(' '));
    this.colorGrid = Array.from({ length: this.height }, () => Array(this.width).fill(''));
  }

  public start(): void {
    // Terminal setup
    process.stdout.write('\x1b[?25l'); // Hide cursor
    process.stdout.write('\x1b[2J');   // Clear screen

    this.setupInput();

    // Loop to plant commits step-by-step
    this.timer = setInterval(() => {
      this.growStep();
      this.render();
    }, 300);
  }

  private growStep(): void {
    if (this.commitIndex >= this.commits.length) {
      // Gentle garden breeze animation once all commits are planted
      this.simulateBreeze();
      return;
    }

    const commit = this.commits[this.commitIndex++];
    const x = Math.floor((this.commitIndex / (this.commits.length + 1)) * (this.width - 10)) + 5;
    const groundY = this.height - 2;

    // Base Stem Growth
    const stemHeight = Math.min(Math.floor(commit.churn / 20) + 3, this.height - 6);
    for (let h = 0; h < stemHeight; h++) {
      const y = groundY - h;
      if (y > 0) {
        this.grid[y][x] = '│';
        this.colorGrid[y][x] = this.colors.stem;
      }
    }

    const topY = Math.max(1, groundY - stemHeight);

    // Sprout Leaves along stem
    if (stemHeight > 2) {
      const leafY = topY + Math.floor(stemHeight / 2);
      if (x > 1) {
        this.grid[leafY][x - 1] = '🍃';
        this.colorGrid[leafY][x - 1] = this.colors.leaf;
      }
      if (x < this.width - 2) {
        this.grid[leafY][x + 1] = '🌱';
        this.colorGrid[leafY][x + 1] = this.colors.leaf;
      }
    }

    // Branch Merges -> Bloom Flower Petals
    if (commit.isMerge) {
      const petals = ['🌸', '🌺', '🌼', '🌻', '🌹'];
      const petal = petals[Math.floor(Math.random() * petals.length)];
      
      this.grid[topY][x] = petal;
      this.colorGrid[topY][x] = this.colors.flower1;

      // Bloom surround
      const offsets = [[-1, 0], [1, 0], [0, -1], [0, 1]];
      offsets.forEach(([dx, dy]) => {
        const nx = x + dx;
        const ny = topY + dy;
        if (nx >= 0 && nx < this.width && ny >= 0 && ny < this.height && this.grid[ny][nx] === ' ') {
          this.grid[ny][nx] = '✨';
          this.colorGrid[ny][nx] = this.colors.flower2;
        }
      });
    } else {
      this.grid[topY][x] = '🌿';
      this.colorGrid[topY][x] = this.colors.stem;
    }

    // High Churn (> 150 lines modified) -> Fungal Decay
    if (commit.churn > 150) {
      const decayRadius = Math.min(Math.floor(commit.churn / 100), 3);
      for (let dy = -decayRadius; dy <= decayRadius; dy++) {
        for (let dx = -decayRadius; dx <= decayRadius; dx++) {
          const fx = x + dx;
          const fy = groundY + dy;
          if (
            fx >= 0 && fx < this.width &&
            fy >= 0 && fy < this.height &&
            Math.random() < 0.6
          ) {
            const fungusChars = ['🍄', '🌾', '🟫', '░'];
            this.grid[fy][fx] = fungusChars[Math.floor(Math.random() * fungusChars.length)];
            this.colorGrid[fy][fx] = Math.random() > 0.5 ? this.colors.fungus1 : this.colors.fungus2;
          }
        }
      }
    }
  }

  private simulateBreeze(): void {
    // Gentle particle effect on mature garden
    const rx = Math.floor(Math.random() * this.width);
    const ry = Math.floor(Math.random() * (this.height - 4));
    if (this.grid[ry][rx] === ' ') {
      this.grid[ry][rx] = Math.random() > 0.5 ? '･' : '｡';
      this.colorGrid[ry][rx] = this.colors.decay;
      setTimeout(() => {
        if (this.grid[ry][rx] === '･' || this.grid[ry][rx] === '｡') {
          this.grid[ry][rx] = ' ';
        }
      }, 600);
    }
  }

  private render(): void {
    let output = '\x1b[H'; // Move cursor to top-left

    // Ground line
    const groundY = this.height - 1;
    for (let x = 0; x < this.width; x++) {
      if (this.grid[groundY][x] === ' ') {
        this.grid[groundY][x] = '═';
        this.colorGrid[groundY][x] = this.colors.stem;
      }
    }

    // Compose Frame
    for (let y = 0; y < this.height; y++) {
      let line = '';
      for (let x = 0; x < this.width; x++) {
        const color = this.colorGrid[y][x] || this.colors.reset;
        line += `${color}${this.grid[y][x]}${this.colors.reset}`;
      }
      output += line + '\n';
    }

    // HUD Header & Info
    const latest = this.commits[Math.max(0, this.commitIndex - 1)];
    const statusStr = this.commitIndex >= this.commits.length ? 'GARDEN FULLY BLOOMED' : 'GROWING...';
    output += `${this.colors.hud}=== GIT PROCEDURAL GARDEN [${statusStr}] ===${this.colors.reset}\n`;
    if (latest) {
      output += `${this.colors.hud}Commit: ${latest.hash} | Author: ${latest.author} | Churn: ${latest.churn} loc${this.colors.reset}\n`;
      output += `${this.colors.hud}Msg: ${latest.message.substring(0, 60)}${this.colors.reset}\n`;
    }
    output += `${this.colors.decay}Press 'q' or Ctrl+C to exit.${this.colors.reset}`;

    process.stdout.write(output);
  }

  private setupInput(): void {
    if (process.stdin.setRawMode) {
      process.stdin.setRawMode(true);
    }
    readline.emitKeypressEvents(process.stdin);
    process.stdin.on('keypress', (_, key) => {
      if (key && (key.name === 'q' || (key.ctrl && key.name === 'c'))) {
        this.cleanup();
        process.exit();
      }
    });
  }

  private cleanup(): void {
    if (this.timer) clearInterval(this.timer);
    process.stdout.write('\x1b[?25h'); // Show cursor
    process.stdout.write('\x1b[2J\x1b[H'); // Clear
  }
}

// --- Main Execution ---
const commits = getGitCommits();
const garden = new TerminalGarden(commits);
garden.start();