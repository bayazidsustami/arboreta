import * as http from 'http';
import * as os from 'os';
import * as v8 from 'v8';

/**
 * Bioluminescent Ocean Telemetry Engine
 * Node.js server streaming live system telemetry (CPU, Memory, GC)
 * to an interactive, real-time fluid dynamics simulation in the browser.
 */

const PORT = 3000;

// Telemetry State
let lastCpuMeasure = os.cpus();
let lastHeapUsed = process.memoryUsage().heapUsed;

// Calculate CPU load percentage across all cores
function getCpuLoad(): number {
  const currentCpus = os.cpus();
  let totalIdle = 0;
  let totalTick = 0;

  for (let i = 0; i < currentCpus.length; i++) {
    const prev = lastCpuMeasure[i];
    const curr = currentCpus[i];
    if (!prev) continue;

    const prevTotal = Object.values(prev.times).reduce((a, b) => a + b, 0);
    const currTotal = Object.values(curr.times).reduce((a, b) => a + b, 0);

    totalIdle += curr.times.idle - prev.times.idle;
    totalTick += currTotal - prevTotal;
  }

  lastCpuMeasure = currentCpus;
  return totalTick === 0 ? 0 : Math.max(0, Math.min(1, 1 - totalIdle / totalTick));
}

// Detect GC drops and memory pressure
function getMemoryMetrics(): { heapUsageRatio: number; gcTsunamiDetected: boolean; heapDropMb: number } {
  const mem = process.memoryUsage();
  const heapStats = v8.getHeapStatistics();
  
  const heapUsageRatio = mem.heapUsed / heapStats.heap_size_limit;
  const heapDelta = lastHeapUsed - mem.heapUsed;
  lastHeapUsed = mem.heapUsed;

  // Trigger Tsunami if more than 2MB dropped suddenly (GC cycle)
  const heapDropMb = heapDelta / (1024 * 1024);
  const gcTsunamiDetected = heapDropMb > 2.0;

  return { heapUsageRatio, gcTsunamiDetected, heapDropMb };
}

// HTTP Server serving SSE Telemetry and WebGL Fluid Visualizer
const server = http.createServer((req, res) => {
  if (req.url === '/events') {
    // Server-Sent Events endpoint for real-time telemetry streaming
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*'
    });

    const interval = setInterval(() => {
      const cpu = getCpuLoad();
      const mem = getMemoryMetrics();
      const payload = JSON.stringify({
        cpu,
        heapRatio: mem.heapUsageRatio,
        tsunami: mem.gcTsunamiDetected,
        gcMb: mem.heapDropMb
      });
      res.write(`data: ${payload}\n\n`);
    }, 100);

    req.on('close', () => clearInterval(interval));
    return;
  }

  // Serve Frontend HTML Visualizer
  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Bioluminescent Ocean Telemetry Fluid Dynamics</title>
  <style>
    body, html { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: #02050e; font-family: monospace; }
    canvas { width: 100%; height: 100%; display: block; filter: blur(0.5px) contrast(1.2); }
    #hud {
      position: absolute; top: 20px; left: 20px; color: #a0f0ff; text-shadow: 0 0 8px #00f0ff;
      pointer-events: none; z-index: 10; font-size: 13px; background: rgba(2, 8, 20, 0.7);
      padding: 15px; border-radius: 8px; border: 1px solid rgba(0, 240, 255, 0.2);
    }
    .val { color: #ffffff; font-weight: bold; }
    .alert { color: #ff3366; text-shadow: 0 0 8px #ff3366; animation: blink 0.2s infinite alternate; }
    @keyframes blink { from { opacity: 0.5; } to { opacity: 1; } }
  </style>
</head>
<body>
  <div id="hud">
    <h2>BIOLUMINESCENT OCEAN TELEMETRY</h2>
    <div>CPU LOAD (Thermal Storms): <span id="cpuVal" class="val">0%</span></div>
    <div>HEAP PRESSURE (Tide Level): <span id="memVal" class="val">0%</span></div>
    <div id="status">Status: Calm Abyssal Waters</div>
  </div>
  <canvas id="c"></canvas>

  <script>
    const canvas = document.getElementById('c');
    const ctx = canvas.getContext('2d');

    let width = canvas.width = window.innerWidth;
    let height = canvas.height = window.innerHeight;

    window.addEventListener('resize', () => {
      width = canvas.width = window.innerWidth;
      height = canvas.height = window.innerHeight;
      initGrid();
    });

    // Grid Fluid Dynamics Config
    const GRID_SIZE = 40;
    let cols = Math.floor(width / GRID_SIZE) + 1;
    let rows = Math.floor(height / GRID_SIZE) + 1;

    interface Cell {
      vx: number; vy: number;
      density: number;
      temp: number;
    }

    let grid = [];
    function initGrid() {
      cols = Math.floor(width / GRID_SIZE) + 1;
      rows = Math.floor(height / GRID_SIZE) + 1;
      grid = [];
      for (let r = 0; r < rows; r++) {
        const row = [];
        for (let c = 0; c < cols; c++) {
          row.push({ vx: 0, vy: 0, density: Math.random() * 0.2, temp: 0 });
        }
        grid.push(row);
      }
    }
    initGrid();

    // Particle System for Bioluminescent Plankton
    const PARTICLE_COUNT = 1200;
    const particles = [];
    for (let i = 0; i < PARTICLE_COUNT; i++) {
      particles.push({
        x: Math.random() * width,
        y: Math.random() * height,
        vx: 0, vy: 0,
        energy: Math.random(),
        size: Math.random() * 2.5 + 1,
        hue: 170 + Math.random() * 40
      });
    }

    let currentCpu = 0;
    let currentMem = 0;
    let tsunamiShockwave = 0;

    // Connect SSE stream
    const eventSource = new EventSource('/events');
    eventSource.onmessage = (e) => {
      const data = JSON.parse(e.data);
      currentCpu = data.cpu;
      currentMem = data.heapRatio;

      document.getElementById('cpuVal').innerText = (currentCpu * 100).toFixed(1) + '%';
      document.getElementById('memVal').innerText = (currentMem * 100).toFixed(1) + '%';

      if (data.tsunami) {
        tsunamiShockwave = 1.0;
        document.getElementById('status').innerText = 'CRITICAL: GC TSUNAMI CYCLE TRIGGERED!';
        document.getElementById('status').className = 'alert';
      } else if (currentCpu > 0.6) {
        document.getElementById('status').innerText = 'WARNING: CPU Thermal Storm Active';
        document.getElementById('status').className = 'alert';
      } else {
        document.getElementById('status').innerText = 'Status: Calm Abyssal Waters';
        document.getElementById('status').className = '';
      }
    };

    // Interactive mouse force
    let mx = -1000, my = -1000, md = false;
    window.addEventListener('mousemove', (e) => { mx = e.clientX; my = e.clientY; });

    // Main Fluid + Bioluminescence Rendering Loop
    function step() {
      // Fade background to create bioluminescent trailing paths
      ctx.fillStyle = 'rgba(2, 5, 14, 0.2)';
      ctx.fillRect(0, 0, width, height);

      // Handle CPU Thermal Storm Injection (Hot rising plume vortices)
      if (currentCpu > 0.1) {
        const stormIntensity = currentCpu * 20;
        for (let i = 0; i < Math.floor(currentCpu * 6); i++) {
          const c = Math.floor(Math.random() * (cols - 2)) + 1;
          const r = rows - 2;
          grid[r][c].vy -= Math.random() * stormIntensity;
          grid[r][c].vx += (Math.random() - 0.5) * stormIntensity;
          grid[r][c].temp = Math.min(1, grid[r][c].temp + 0.5);
        }
      }

      // Handle GC Tsunami Wave Shockwave
      if (tsunamiShockwave > 0.01) {
        const force = tsunamiShockwave * 45;
        for (let r = 0; r < rows; r++) {
          for (let c = 0; c < cols; c++) {
            grid[r][c].vx += (Math.random() - 0.5) * force;
            grid[r][c].vy += force * (r < rows / 2 ? 0.5 : -0.5);
            grid[r][c].density = Math.min(1.0, grid[r][c].density + 0.3 * tsunamiShockwave);
          }
        }
        tsunamiShockwave *= 0.92; // Decay
      }

      // Diffuse & Advect Fluid Vector Field
      for (let r = 1; r < rows - 1; r++) {
        for (let c = 1; c < cols - 1; c++) {
          const cell = grid[r][c];

          // Mouse perturbation
          const dx = (c * GRID_SIZE) - mx;
          const dy = (r * GRID_SIZE) - my;
          const dist = Math.sqrt(dx * dx + dy * dy);
          if (dist < 150) {
            const push = (150 - dist) * 0.05;
            cell.vx += (dx / dist) * push;
            cell.vy += (dy / dist) * push;
          }

          // Fluid Damping
          cell.vx *= 0.95;
          cell.vy *= 0.95;
          cell.temp *= 0.96;

          // Thermal Buoyancy
          cell.vy -= cell.temp * 0.8;
        }
      }

      // Update & Render Bioluminescent Plankton Particles
      for (let p of particles) {
        const gc = Math.floor(Math.max(0, Math.min(cols - 1, p.x / GRID_SIZE)));
        const gr = Math.floor(Math.max(0, Math.min(rows - 1, p.y / GRID_SIZE)));

        const cell = grid[gr][gc];
        p.vx += cell.vx * 0.15;
        p.vy += cell.vy * 0.15;

        p.vx *= 0.92;
        p.vy *= 0.92;

        p.x += p.vx;
        p.y += p.vy;

        // Wrap edges
        if (p.x < 0) p.x = width;
        if (p.x > width) p.x = 0;
        if (p.y < 0) p.y = height;
        if (p.y > height) p.y = 0;

        // Velocity excites bioluminescence brightness
        const speed = Math.sqrt(p.vx * p.vx + p.vy * p.vy);
        const excitement = Math.min(1.0, speed * 0.2 + cell.temp + tsunamiShockwave * 2.0);

        // Render Bioluminescent Glow
        const hue = p.hue + (cell.temp * 40) - (tsunamiShockwave * 60); // Shifts red under CPU heat, deep violet under Tsunami
        const brightness = 40 + excitement * 60;
        const alpha = 0.3 + excitement * 0.7;

        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size * (1 + excitement), 0, Math.PI * 2);
        ctx.fillStyle = \`hsla(\${hue}, 100%, \${brightness}%, \${alpha})\`;
        ctx.shadowBlur = 10 * excitement + 2;
        ctx.shadowColor = \`hsl(\${hue}, 100%, 50%)\`;
        ctx.fill();
      }

      ctx.shadowBlur = 0; // Reset canvas state
      requestAnimationFrame(step);
    }

    step();
  </script>
</body>
</html>`);
});

server.listen(PORT, () => {
  console.log(`\n===============================================================`);
  console.log(`🌊 BIOLUMINESCENT OCEAN TELEMETRY ENGINE RUNNING`);
  console.log(`👉 Open: http://localhost:${PORT}`);
  console.log(`🔥 CPU load drives Thermal Storms | 🌊 GC drops trigger Tsunamis`);
  console.log(`===============================================================\n`);
});