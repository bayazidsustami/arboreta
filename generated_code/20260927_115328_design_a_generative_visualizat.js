const https = require('https');
const { performance } = require('perf_hooks');

// Global endpoints used to source ping latency fluctuations as our pigment source
const endpoints = [
  { name: 'Cloudflare', url: '[https://1.1.1.1](https://1.1.1.1)' },
  { name: 'Google', url: '[https://www.google.com](https://www.google.com)' },
  { name: 'GitHub', url: '[https://github.com](https://github.com)' },
  { name: 'CloudFront', url: '[https://aws.amazon.com](https://aws.amazon.com)' }
];

// Determine terminal screen dimensions
const cols = process.stdout.columns || 80;
const rows = (process.stdout.rows || 24) - 2;

// Initialize pigment density grid and color palette grid for watercolor diffusion
let grid = Array.from({ length: rows }, () => Array.from({ length: cols }, () => 0));
let colorGrid = Array.from({ length: rows }, () => Array.from({ length: cols }, () => ({ r: 30, g: 90, b: 180 })));

// Hide cursor and clear the terminal window for our canvas
process.stdout.write('\x1b[?25l');
process.stdout.write('\x1b[2J');

// Graceful cleanup on exit
process.on('SIGINT', () => {
  process.stdout.write('\x1b[?25h\x1b[0m\n');
  process.exit(0);
});

// Measure HTTP round-trip latency to simulate global ping requests
async function measureLatency(url) {
  const start = performance.now();
  return new Promise((resolve) => {
    const req = https.get(url, { timeout: 3000 }, (res) => {
      res.destroy();
      resolve(performance.now() - start);
    });
    req.on('error', () => resolve(250 + Math.random() * 150));
    req.on('timeout', () => { req.destroy(); resolve(800); });
  });
}

// Update the watercolor topology simulation based on latest latency data
async function updateTopology() {
  const latencies = await Promise.all(endpoints.map(e => measureLatency(e.url)));
  const avgLatency = latencies.reduce((a, b) => a + b, 0) / latencies.length;
  
  // Apply cellular automata diffusion and evaporation for watercolor bleed effect
  let newGrid = grid.map(row => [...row]);
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      let sum = grid[r][c] * 0.4;
      let count = 0.4;
      const neighbors = [[-1, 0], [1, 0], [0, -1], [0, 1]];
      for (let [dr, dc] of neighbors) {
        let nr = r + dr, nc = c + dc;
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
          sum += grid[nr][nc] * 0.15;
          count += 0.15;
        }
      }
      newGrid[r][c] = Math.max(0, (sum / count) * 0.96); // Pigment evaporation
    }
  }
  grid = newGrid;

  // Drop new watercolor pigment blobs driven by endpoint latencies
  latencies.forEach((lat, idx) => {
    const dropRow = Math.floor(((idx * 2 + 1) / (endpoints.length * 2)) * rows);
    const dropCol = Math.floor((Math.sin(Date.now() * 0.0008 + idx * 1.5) * 0.45 + 0.5) * cols);
    
    const radius = Math.min(Math.floor(lat / 25), 10);
    const intensity = Math.min(lat / 80, 2.5);

    for (let r = Math.max(0, dropRow - radius); r <= Math.min(rows - 1, dropRow + radius); r++) {
      for (let c = Math.max(0, dropCol - radius); c <= Math.min(cols - 1, dropCol + radius); c++) {
        let dist = Math.hypot(r - dropRow, c - dropCol);
        if (dist <= radius) {
          let factor = Math.max(0, 1 - dist / radius);
          grid[r][c] = Math.min(12, grid[r][c] + intensity * factor);
          
          // Dynamic color shifting based on latency profile
          colorGrid[r][c] = {
            r: Math.floor(40 + Math.min(lat, 220) * 0.9),
            g: Math.floor(110 + Math.cos(lat * 0.02) * 60),
            b: Math.floor(240 - idx * 40)
          };
        }
      }
    }
  });

  // Render canvas with 24-bit TrueColor ANSI escape sequences
  let output = '\x1b[H'; 
  const chars = ' .·:=+*#%@█';
  
  for (let r = 0; r < rows; r++) {
    let line = '';
    for (let c = 0; c < cols; c++) {
      let val = grid[r][c];
      if (val > 0.05) {
        let charIdx = Math.min(Math.floor(val * 0.9), chars.length - 1);
        let char = chars[charIdx];
        let col = colorGrid[r][c];
        line += `\x1b[38;2;${col.r};${col.g};${col.b}m${char}\x1b[0m`;
      } else {
        line += ' ';
      }
    }
    output += line + '\n';
  }
  
  // Footer status bar
  output += `\x1b[36m[Watercolor Latency Topology] Avg: ${avgLatency.toFixed(1)}ms | Press Ctrl+C to Exit\x1b[0m`;
  process.stdout.write(output);
}

// Start generative loop
setInterval(updateTopology, 1200);