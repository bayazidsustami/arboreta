const fs = require('fs');
const path = require('path');
const os = require('os');
const readline = require('readline');

// --- Shell History Parser ---
// Reads shell history files (~/.bash_history or ~/.zsh_history) and converts commands into game parameters.
function parseShellHistory() {
  const homeDir = os.homedir();
  const historyFiles = ['.zsh_history', '.bash_history', '.history'];
  let rawContent = '';

  for (const file of historyFiles) {
    try {
      const fullPath = path.join(homeDir, file);
      if (fs.existsSync(fullPath)) {
        rawContent = fs.readFileSync(fullPath, 'utf8');
        if (rawContent.trim().length > 0) break;
      }
    } catch (e) {}
  }

  // Fallback synthetic history if no local history is found
  if (!rawContent) {
    rawContent = `
git status
cd /invalid/directory/path
npm install --save react
sudo rm -rf /
node index.js
cat missing_config.json
git commit -m "fix critical bug"
python3 script.py --invalid-flag
make build
./unknown_binary
docker ps
ssh broken.host.example.com
    `.trim();
  }

  const lines = rawContent.split('\n').map(l => l.trim()).filter(Boolean);
  const commandMap = new Map();

  lines.forEach((line) => {
    // Strip zsh extended metadata format (: 1600000000:0;cmd)
    let cmd = line.startsWith(':') && line.includes(';') ? line.split(';').slice(1).join(';') : line;
    cmd = cmd.trim();
    if (!cmd) return;

    // Deterministic pseudo-exit code based on string signature and failure keywords
    const hash = [...cmd].reduce((acc, char) => (acc * 31 + char.charCodeAt(0)) % 100, 0);
    const isError = cmd.includes('invalid') || cmd.includes('rm -rf /') || cmd.includes('broken.') || (hash % 4 === 0);
    const exitCode = isError ? (hash % 5) + 1 : 0;

    if (!commandMap.has(cmd)) {
      commandMap.set(cmd, { command: cmd, frequency: 0, length: cmd.length, exitCode });
    }
    commandMap.get(cmd).frequency += 1;
  });

  return Array.from(commandMap.values());
}

// --- Procedural Labyrinth Generator ---
// Translates command frequency into map size, successful executions into paths, and broken executions into traps.
class Labyrinth {
  constructor(commands) {
    this.commands = commands;
    this.totalCmds = commands.length;
    this.successCmds = commands.filter(c => c.exitCode === 0);
    this.failedCmds = commands.filter(c => c.exitCode !== 0);

    // Map dimension scales dynamically with command count
    const baseSize = Math.max(11, Math.min(25, 11 + Math.floor(Math.sqrt(this.totalCmds))));
    this.width = baseSize % 2 === 0 ? baseSize + 1 : baseSize;
    this.height = this.width;

    this.grid = Array.from({ length: this.height }, () => Array(this.width).fill('#'));
    this.traps = [];
    this.powerups = [];
    this.start = { x: 1, y: 1 };
    this.exit = { x: this.width - 2, y: this.height - 2 };

    this.generate();
  }

  generate() {
    // Recursive maze carving seeded by successful shell commands (exitCode === 0)
    const stack = [this.start];
    this.grid[this.start.y][this.start.x] = '.';
    let cmdIdx = 0;

    while (stack.length > 0) {
      const current = stack[stack.length - 1];
      const neighbors = this.getUnvisitedNeighbors(current);

      if (neighbors.length > 0) {
        const cmd = this.successCmds[cmdIdx % (this.successCmds.length || 1)] || { length: 5, frequency: 1 };
        const nextIdx = (cmd.length + cmd.frequency) % neighbors.length;
        const next = neighbors[nextIdx];

        // Carve passage
        const wallX = current.x + (next.x - current.x) / 2;
        const wallY = current.y + (next.y - current.y) / 2;
        this.grid[wallY][wallX] = '.';
        this.grid[next.y][next.x] = '.';

        stack.push(next);
        cmdIdx++;
      } else {
        stack.pop();
      }
    }

    // Set Exit Point
    this.grid[this.exit.y][this.exit.x] = 'E';

    // Collect open paths for entity placement
    const openPaths = [];
    for (let y = 1; y < this.height - 1; y++) {
      for (let x = 1; x < this.width - 1; x++) {
        if (this.grid[y][x] === '.' && !(x === this.start.x && y === this.start.y) && !(x === this.exit.x && y === this.exit.y)) {
          openPaths.push({ x, y });
        }
      }
    }

    // Spawn traps derived from failed commands (exitCode !== 0)
    this.failedCmds.forEach((cmd) => {
      if (openPaths.length === 0) return;
      const trapIdx = (cmd.length * 7 + cmd.exitCode * 13) % openPaths.length;
      const cell = openPaths.splice(trapIdx, 1)[0];
      this.grid[cell.y][cell.x] = '^';
      this.traps.push({ ...cell, damage: 15 + (cmd.exitCode * 5), command: cmd.command });
    });

    // Spawn health power-ups from high-frequency commands
    const topCmds = [...this.commands].sort((a, b) => b.frequency - a.frequency).slice(0, 3);
    topCmds.forEach((cmd) => {
      if (openPaths.length === 0) return;
      const pIdx = (cmd.frequency * 17) % openPaths.length;
      const cell = openPaths.splice(pIdx, 1)[0];
      this.grid[cell.y][cell.x] = '+';
      this.powerups.push({ ...cell, heal: 25, command: cmd.command });
    });
  }

  getUnvisitedNeighbors(cell) {
    const directions = [{ x: 0, y: -2 }, { x: 0, y: 2 }, { x: -2, y: 0 }, { x: 2, y: 0 }];
    const neighbors = [];

    for (const dir of directions) {
      const nx = cell.x + dir.x;
      const ny = cell.y + dir.y;
      if (nx > 0 && nx < this.width - 1 && ny > 0 && ny < this.height - 1 && this.grid[ny][nx] === '#') {
        neighbors.push({ x: nx, y: ny });
      }
    }
    return neighbors;
  }
}

// --- Interactive Terminal Engine ---
class ShellLabyrinthGame {
  constructor() {
    this.commands = parseShellHistory();
    this.maze = new Labyrinth(this.commands);
    this.player = { x: 1, y: 1, hp: 100, maxHp: 100 };
    this.logMessage = "Traverse your command history! Reach 'E' to escape.";
    this.gameOver = false;
  }

  start() {
    readline.emitKeypressEvents(process.stdin);
    if (process.stdin.isTTY) {
      process.stdin.setRawMode(true);
    }

    process.stdin.on('keypress', (str, key) => {
      if (key.ctrl && key.name === 'c') this.exitGame("Game Terminated.");
      if (this.gameOver) {
        if (key.name === 'r') this.reset();
        else if (key.name === 'q') this.exitGame("Thanks for playing!");
        return;
      }
      this.handleInput(key.name);
      this.render();
    });

    this.render();
  }

  reset() {
    this.maze = new Labyrinth(this.commands);
    this.player = { x: 1, y: 1, hp: 100, maxHp: 100 };
    this.logMessage = "Labyrinth re-generated!";
    this.gameOver = false;
    this.render();
  }

  handleInput(key) {
    let dx = 0, dy = 0;
    if (['w', 'up'].includes(key)) dy = -1;
    if (['s', 'down'].includes(key)) dy = 1;
    if (['a', 'left'].includes(key)) dx = -1;
    if (['d', 'right'].includes(key)) dx = 1;

    if (dx === 0 && dy === 0) return;

    const newX = this.player.x + dx;
    const newY = this.player.y + dy;

    if (this.maze.grid[newY][newX] === '#') {
      this.logMessage = "\x1b[33mBlocked by a command wall!\x1b[0m";
      return;
    }

    this.player.x = newX;
    this.player.y = newY;
    const tile = this.maze.grid[newY][newX];

    if (tile === '^') {
      const trap = this.maze.traps.find(t => t.x === newX && t.y === newY);
      const damage = trap ? trap.damage : 15;
      const cmdStr = trap ? ` ("${trap.command}")` : '';
      this.player.hp -= damage;
      this.maze.grid[newY][newX] = '.';
      this.logMessage = `\x1b[31mTRAP TRIGGERED! -${damage} HP from broken command${cmdStr}\x1b[0m`;

      if (this.player.hp <= 0) {
        this.player.hp = 0;
        this.gameOver = true;
        this.logMessage = "\x1b[31mGAME OVER! Destroyed by syntax & execution errors. Press 'r' to restart, 'q' to quit.\x1b[0m";
      }
    } else if (tile === '+') {
      const item = this.maze.powerups.find(p => p.x === newX && p.y === newY);
      const heal = item ? item.heal : 25;
      const cmdStr = item ? ` ("${item.command}")` : '';
      this.player.hp = Math.min(this.player.maxHp, this.player.hp + heal);
      this.maze.grid[newY][newX] = '.';
      this.logMessage = `\x1b[32mHEALED +${heal} HP from frequent workflow${cmdStr}\x1b[0m`;
    } else if (tile === 'E') {
      this.gameOver = true;
      this.logMessage = "\x1b[32mVICTORY! You mastered your terminal history and escaped! Press 'r' to replay, 'q' to quit.\x1b[0m";
    } else {
      this.logMessage = "Navigating history corridors...";
    }
  }

  render() {
    process.stdout.write('\x1b[2J\x1b[H');
    console.log('\x1b[36m=== SHELL HISTORY LABYRINTH ===\x1b[0m');
    console.log(`Commands Parsed: ${this.maze.totalCmds} | Paths: ${this.maze.successCmds.length} | Traps: ${this.maze.failedCmds.length}\n`);

    for (let y = 0; y < this.maze.height; y++) {
      let line = '';
      for (let x = 0; x < this.maze.width; x++) {
        if (x === this.player.x && y === this.player.y) {
          line += '\x1b[35m@ \x1b[0m';
        } else {
          const tile = this.maze.grid[y][x];
          switch (tile) {
            case '#': line += '\x1b[90m█\x1b[0m '; break;
            case '.': line += '\x1b[37m. \x1b[0m'; break;
            case '^': line += '\x1b[31m^\x1b[0m '; break;
            case '+': line += '\x1b[32m+\x1b[0m '; break;
            case 'E': line += '\x1b[33mE\x1b[0m '; break;
            default:  line += tile + ' ';
          }
        }
      }
      console.log(line);
    }

    const hpColor = this.player.hp > 50 ? '\x1b[32m' : this.player.hp > 25 ? '\x1b[33m' : '\x1b[31m';
    console.log(`\nHP: ${hpColor}${this.player.hp}/${this.player.maxHp}\x1b[0m`);
    console.log(`Status: ${this.logMessage}`);
    console.log('\nControls: [WASD / Arrow Keys] Move | [Ctrl+C] Quit');
  }

  exitGame(msg) {
    process.stdout.write('\x1b[2J\x1b[H');
    console.log(msg);
    process.exit(0);
  }
}

new ShellLabyrinthGame().start();