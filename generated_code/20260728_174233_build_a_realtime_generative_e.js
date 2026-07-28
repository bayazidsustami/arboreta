#!/usr/bin/env node

/**
 * Gothic Git Cathedral Engine
 * Parses local Git commit history and renders an interactive ASCII Gothic Cathedral.
 * Code churn, bug-fix keywords, and test failures apply physical stress to the flying buttresses,
 * causing procedural erosion, stone fracturing, and debris particles over time.
 * 
 * Interactivity:
 *  - Left/Right Arrows: Scrub through commit timeline
 *  - Space: Toggle auto-play / pause
 *  - 'R': Reset build state
 *  - 'Q' or Ctrl+C: Exit
 */

const { execSync } = require('child_process');
const readline = require('readline');

// Raw ASCII template for the Gothic Cathedral
const CATHEDRAL_TEMPLATE = [
  "                          /\\                          ",
  "                         /  \\                         ",
  "                        / || \\                        ",
  "                       /  ||  \\                       ",
  "                      /|  ||  |\\                      ",
  "                     / |  ||  | \\                     ",
  "                    /  |  ||  |  \\                    ",
  "             /\\    /   |  ||  |   \\    /\\             ",
  "            /  \\  /    |  ||  |    \\  /  \\            ",
  "           /    \\/     |  ||  |     \\/    \\           ",
  "          /   /\\       | (||) |       /\\   \\          ",
  "         /   /  \\      |  ||  |      /  \\   \\         ",
  "  /|    |   /    \\=====|==||==|=====/    \\   |    |\\  ",
  " / |    |  /      \\    | /  \\ |    /      \\  |    | \\ ",
  "|  |====| /        \\   |/ || \\|   /        \\ |====|  |",
  "|  |    |/          \\  | (OO) |  /          \\|    |  |",
  "|  |    |            \\ | /  \\ | /            |    |  |",
  "|  |    |             \\|  ||  |/             |    |  |",
  "|__|____|______________|_ || _|______________|____|__|",
  "|  |    |  /=======\\   |  ||  |   /=======\\  |    |  |",
  "|  |    | |   (O)   |  |  ||  |  |   (O)   | |    |  |",
  "|  |    | |   / \\   |  |  ||  |  |   / \\   | |    |  |",
  "|  |====|=|  |   |  |==|  ||  |==|  |   |  |=|====|  |",
  "|__|____|_|__|___|__|_|___||___|_|__|___|__|_|____|__|"
];

// Identifies characters belonging to flying buttresses (for targeted structural damage)
function isButtress(x, y) {
  const isWingX = (x >= 0 && x <= 22) || (x >= 32 && x <= 54);
  const isArchY = y >= 7 && y <= 17;
  return isWingX && isArchY;
}

// Extract git history; fall back to synthetic history if git is unavailable
function loadGitHistory() {
  try {
    const rawLog = execSync(
      'git log --pretty=format:"%h|%an|%s|%at" --shortstat -n 50',
      { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'ignore'] }
    );
    
    const commits = [];
    const entries = rawLog.split('\n\n');
    
    for (const entry of entries) {
      const lines = entry.trim().split('\n');
      if (!lines[0]) continue;
      
      const [hash, author, subject, timestamp] = lines[0].split('|');
      let additions = 0;
      let deletions = 0;
      
      if (lines[1]) {
        const insMatch = lines[1].match(/(\d+) insertion/);
        const delMatch = lines[1].match(/(\d+) deletion/);
        if (insMatch) additions = parseInt(insMatch[1], 10);
        if (delMatch) deletions = parseInt(delMatch[1], 10);
      }
      
      const churn = additions + deletions;
      const isBug = /fix|bug|patch|issue|error|fail|revert/i.test(subject);
      const isTestFail = /test|ci|build|broken/i.test(subject) && isBug;
      
      // Calculate stress score (0.0 to 1.0)
      const churnStress = Math.min(1, churn / 400);
      const bugStress = isBug ? 0.35 : 0;
      const failStress = isTestFail ? 0.5 : 0;
      const stress = Math.min(1.0, churnStress * 0.4 + bugStress + failStress);
      
      commits.push({
        hash: hash || '0000000',
        author: author || 'Unknown',
        subject: subject || 'No message',
        date: new Date(parseInt(timestamp || '0', 10) * 1000).toLocaleDateString(),
        churn,
        isBug,
        isTestFail,
        stress
      });
    }
    
    return commits.reverse();
  } catch (e) {
    // Return synthetic commits if not in a git repo
    return Array.from({ length: 35 }, (_, i) => {
      const churn = Math.floor(Math.sin(i) * 200 + 220);
      const isBug = i % 4 === 0;
      const isTestFail = i % 7 === 0;
      return {
        hash: Math.random().toString(16).substring(2, 9),
        author: `Dev_${(i % 3) + 1}`,
        subject: isBug ? `fix(core): patch structural leak #${i}` : `feat: expand spire layer ${i}`,
        date: new Date(Date.now() - (35 - i) * 86400000).toLocaleDateString(),
        churn,
        isBug,
        isTestFail,
        stress: Math.min(1.0, (churn / 400) * 0.4 + (isBug ? 0.35 : 0) + (isTestFail ? 0.3 : 0))
      };
    });
  }
}

class CathedralEngine {
  constructor() {
    this.commits = loadGitHistory();
    this.commitIndex = 0;
    this.isPlaying = true;
    this.debris = []; // Active falling dust/stone particles
    this.damageMap = new Map(); // Coordinates damaged over time
    this.timer = null;
    
    this.initTerminal();
  }

  initTerminal() {
    readline.emitKeypressEvents(process.stdin);
    if (process.stdin.isTTY) process.stdin.setRawMode(true);
    
    process.stdout.write('\x1b[?25l'); // Hide cursor
    
    process.stdin.on('keypress', (str, key) => {
      if (key.ctrl && key.name === 'c') this.exit();
      else if (key.name === 'q') this.exit();
      else if (key.name === 'right') this.step(1);
      else if (key.name === 'left') this.step(-1);
      else if (key.name === 'space') this.isPlaying = !this.isPlaying;
      else if (key.name === 'r') {
        this.damageMap.clear();
        this.commitIndex = 0;
      }
    });

    this.start();
  }

  step(dir) {
    this.commitIndex = Math.max(0, Math.min(this.commits.length - 1, this.commitIndex + dir));
    this.applyStress();
    this.render();
  }

  applyStress() {
    const commit = this.commits[this.commitIndex];
    if (!commit) return;

    // Accumulate structural damage based on stress score
    const numFractures = Math.floor(commit.stress * 12);
    for (let i = 0; i < numFractures; i++) {
      const y = Math.floor(Math.random() * CATHEDRAL_TEMPLATE.length);
      const x = Math.floor(Math.random() * CATHEDRAL_TEMPLATE[0].length);
      
      // Damage strikes flying buttresses with double probability
      if (isButtress(x, y) || Math.random() < 0.3) {
        const key = `${x},${y}`;
        const currentDmg = this.damageMap.get(key) || 0;
        if (currentDmg < 3) {
          this.damageMap.set(key, currentDmg + 1);
          // Spawn debris particle
          if (CATHEDRAL_TEMPLATE[y][x] !== ' ') {
            this.debris.push({
              x,
              y: y + 1,
              char: ['.', ':', '*', '`'][Math.floor(Math.random() * 4)],
              vy: 0.5 + Math.random() * 0.5
            });
          }
        }
      }
    }
  }

  updatePhysics() {
    // Animate falling debris particles
    for (let i = this.debris.length - 1; i >= 0; i--) {
      const p = this.debris[i];
      p.y += p.vy;
      if (p.y >= CATHEDRAL_TEMPLATE.length + 2) {
        this.debris.splice(i, 1);
      }
    }
  }

  render() {
    const commit = this.commits[this.commitIndex];
    const width = CATHEDRAL_TEMPLATE[0].length;
    
    // Construct frame buffer
    const buffer = CATHEDRAL_TEMPLATE.map(row => row.split(''));

    // Apply damage effects to frame
    for (const [key, dmg] of this.damageMap.entries()) {
      const [x, y] = key.split(',').map(Number);
      if (buffer[y] && buffer[y][x] && buffer[y][x] !== ' ') {
        if (dmg === 1) buffer[y][x] = ';';
        else if (dmg === 2) buffer[y][x] = '.';
        else if (dmg >= 3) buffer[y][x] = ' ';
      }
    }

    // Apply active debris particles to buffer
    const debrisOverlay = Array.from({ length: CATHEDRAL_TEMPLATE.length }, () => Array(width).fill(null));
    for (const p of this.debris) {
      const py = Math.floor(p.y);
      if (py >= 0 && py < CATHEDRAL_TEMPLATE.length && p.x >= 0 && p.x < width) {
        debrisOverlay[py][p.x] = p.char;
      }
    }

    // Render header HUD
    let output = '\x1b[H\x1b[2J'; // Clear screen & reset cursor
    output += '\x1b[1;36m=== GOTHIC GIT CATHEDRAL - STRUCTURAL STRESS ENGINE ===\x1b[0m\n';
    
    // Render Cathedral with dynamic ANSI colors based on integrity
    for (let y = 0; y < buffer.length; y++) {
      let line = '';
      for (let x = 0; x < width; x++) {
        const particle = debrisOverlay[y][x];
        if (particle) {
          line += `\x1b[33m${particle}\x1b[0m`; // Falling debris in amber/yellow
          continue;
        }

        const char = buffer[y][x];
        const key = `${x},${y}`;
        const dmg = this.damageMap.get(key) || 0;

        if (isButtress(x, y)) {
          if (dmg === 0) line += `\x1b[32m${char}\x1b[0m`;      // Healthy buttress (green)
          else if (dmg === 1) line += `\x1b[33m${char}\x1b[0m`; // Stressed (yellow)
          else line += `\x1b[31m${char}\x1b[0m`;               // Failing (red)
        } else if (char === '(' || char === ')' || char === 'O') {
          line += `\x1b[35m${char}\x1b[0m`;                     // Stained Glass Window (magenta)
        } else {
          line += `\x1b[37m${char}\x1b[0m`;                     // Main Structure (white)
        }
      }
      output += line + '\n';
    }

    // Stress Meter Bar
    const barWidth = 30;
    const filled = Math.round(commit.stress * barWidth);
    const meter = '█'.repeat(filled) + '░'.repeat(barWidth - filled);
    const stressColor = commit.stress > 0.6 ? '\x1b[31m' : (commit.stress > 0.3 ? '\x1b[33m' : '\x1b[32m');

    output += '\n----------------------------------------------------------\n';
    output += `\x1b[1mCommit:\x1b[0m \x1b[33m${commit.hash}\x1b[0m [${this.commitIndex + 1}/${this.commits.length}] | \x1b[1mDate:\x1b[0m ${commit.date}\n`;
    output += `\x1b[1mAuthor:\x1b[0m ${commit.author}\n`;
    output += `\x1b[1mMsg:\x1b[0m    ${commit.subject.substring(0, 48)}\n`;
    output += `\x1b[1mChurn:\x1b[0m  ${commit.churn} lines | \x1b[1mBug Fix:\x1b[0m ${commit.isBug ? 'YES' : 'NO'} | \x1b[1mCI Fail:\x1b[0m ${commit.isTestFail ? 'YES' : 'NO'}\n`;
    output += `\x1b[1mButtress Stress:\x1b[0m ${stressColor}[${meter}] ${(commit.stress * 100).toFixed(1)}%\x1b[0m\n`;
    output += '\n\x1b[90m[Controls: ←/→ Scrub | Space Pause/Play | R Reset | Q Quit]\x1b[0m\n';

    process.stdout.write(output);
  }

  start() {
    this.render();
    this.timer = setInterval(() => {
      this.updatePhysics();
      if (this.isPlaying) {
        if (Math.random() < 0.3) {
          this.commitIndex = (this.commitIndex + 1) % this.commits.length;
          if (this.commitIndex === 0) this.damageMap.clear();
          this.applyStress();
        }
      }
      this.render();
    }, 120);
  }

  exit() {
    if (this.timer) clearInterval(this.timer);
    process.stdout.write('\x1b[?25h\x1b[0m\x1b[2J\x1b[H'); // Show cursor & clear screen
    process.exit(0);
  }
}

// Run the engine
new CathedralEngine();