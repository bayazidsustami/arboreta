const os = require('os');

/**
 * Generative ASCII Plant Growth Simulator
 * Driven by live system CPU & Memory metrics.
 * 
 * - Memory Usage: Dictates growth energy, branching probability, and node density.
 * - CPU Load: Drives environmental stress, inducing pruning, leaf drop, and mutation.
 */

class BotanicalNode {
  constructor(x, y, angle, energy, depth = 0) {
    this.x = x;
    this.y = y;
    this.angle = angle; // radians
    this.energy = energy;
    this.depth = depth;
    this.age = 0;
    this.children = [];
    this.char = depth === 0 ? '┴' : '│';
    this.alive = true;
  }

  grow(cpuLoad, memUsage) {
    this.age++;
    this.energy -= 0.05 + (cpuLoad * 0.1);

    // Dynamic glyph selection based on depth and health
    if (this.depth > 0 && this.children.length > 0) {
      const spread = Math.abs(this.children[0].angle - this.angle);
      this.char = spread > 0.4 ? 'Y' : (this.angle < 0 ? '╱' : '╲');
    } else if (this.depth > 4) {
      this.char = cpuLoad > 0.7 ? 'x' : (memUsage > 0.6 ? '❀' : '♣');
    }

    // Attempt branching if enough energy remains and memory permits
    if (this.alive && this.energy > 1.0 && this.children.length === 0 && this.depth < 8) {
      const branchCount = (memUsage > 0.5 && Math.random() < memUsage) ? 2 : 1;
      for (let i = 0; i < branchCount; i++) {
        const spreadAngle = (Math.random() - 0.5) * 0.8 + (i === 0 ? -0.3 : 0.3);
        const childAngle = this.angle + spreadAngle;
        const length = 1 + Math.random() * 1.5;
        const nx = this.x + Math.sin(childAngle) * length;
        const ny = this.y - Math.cos(childAngle) * length;

        this.children.push(new BotanicalNode(nx, ny, childAngle, this.energy * 0.75, this.depth + 1));
      }
    }

    // Propagate growth down the structure
    this.children.forEach(child => child.grow(cpuLoad, memUsage));

    // Self-Pruning Mechanism: High CPU load causes structural degradation/decay
    if (cpuLoad > 0.4 && Math.random() < (cpuLoad * 0.15)) {
      this.prune();
    }
  }

  prune() {
    if (this.children.length > 0) {
      // Prune leaves/branches first
      const idx = Math.floor(Math.random() * this.children.length);
      this.children[idx].prune();
      if (!this.children[idx].alive && this.children[idx].children.length === 0) {
        this.children.splice(idx, 1);
      }
    } else {
      this.alive = false;
      this.char = '⋅';
    }
  }

  render(buffer) {
    const rx = Math.round(this.x);
    const ry = Math.round(this.y);
    if (ry >= 0 && ry < buffer.length && rx >= 0 && rx < buffer[0].length) {
      buffer[ry][rx] = this.char;
    }
    this.children.forEach(child => child.render(buffer));
  }
}

class PlantSimulator {
  constructor(width = 80, height = 30) {
    this.width = width;
    this.height = height;
    this.roots = [new BotanicalNode(width / 2, height - 2, 0, 5.0)];
    this.lastCpuSample = os.cpus();
  }

  // Calculate overall CPU utilization percentage
  getCPULoad() {
    const currentCpus = os.cpus();
    let idleDiff = 0;
    let totalDiff = 0;

    for (let i = 0; i < currentCpus.length; i++) {
      const prev = this.lastCpuSample[i].times;
      const curr = currentCpus[i].times;
      const prevTotal = Object.values(prev).reduce((a, b) => a + b, 0);
      const currTotal = Object.values(curr).reduce((a, b) => a + b, 0);

      idleDiff += curr.idle - prev.idle;
      totalDiff += currTotal - prevTotal;
    }

    this.lastCpuSample = currentCpus;
    return totalDiff === 0 ? 0 : 1 - (idleDiff / totalDiff);
  }

  // Calculate normalized memory usage
  getMemoryUsage() {
    return 1 - (os.freemem() / os.totalmem());
  }

  step() {
    const cpuLoad = this.getCPULoad();
    const memUsage = this.getMemoryUsage();

    // Create a blank render canvas
    const buffer = Array.from({ length: this.height }, () => Array(this.width).fill(' '));

    // Draw Soil Line
    for (let x = 0; x < this.width; x++) {
      buffer[this.height - 1][x] = '=';
    }

    // Sprout new stalks if memory availability allows high energy
    if (Math.random() < memUsage * 0.3 && this.roots.length < 5) {
      const rx = Math.floor(Math.random() * (this.width - 20)) + 10;
      this.roots.push(new BotanicalNode(rx, this.height - 2, (Math.random() - 0.5) * 0.2, 3.5 + memUsage * 3));
    }

    // Grow and render nodes
    this.roots.forEach(root => {
      root.grow(cpuLoad, memUsage);
      root.render(buffer);
    });

    // Cleanup dead root stems
    this.roots = this.roots.filter(r => r.alive || r.children.length > 0);

    // Draw HUD metrics
    const stats = ` [ CPU: ${(cpuLoad * 100).toFixed(1)}% | MEM: ${(memUsage * 100).toFixed(1)}% | Active Stalks: ${this.roots.length} ] `;
    const startX = Math.max(0, Math.floor((this.width - stats.length) / 2));
    for (let i = 0; i < stats.length; i++) {
      if (startX + i < this.width) buffer[0][startX + i] = stats[i];
    }

    // Output frame to terminal
    console.clear();
    console.log(buffer.map(row => row.join('')).join('\n'));
  }

  start(intervalMs = 400) {
    setInterval(() => this.step(), intervalMs);
  }
}

const sim = new PlantSimulator(80, 28);
sim.start();