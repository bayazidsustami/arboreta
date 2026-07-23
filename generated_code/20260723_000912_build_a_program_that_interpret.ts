import * as http from 'http';
import * as os from 'os';
import * as fs from 'fs';
import { exec } from 'child_process';

/**
 * Hardware Thermal Telemetry Engine
 * Attempts to read native system thermal zones, falling back to a dynamic
 * CPU load/time differential thermal estimation model.
 */
interface ThermalSnapshot {
  celsius: number;
  normalized: number; // 0.0 (cool/idle) to 1.0 (exhausted/hot)
  load: number;
  timestamp: number;
}

let previousCpuTimes = os.cpus();

async function readCpuTemperature(): Promise<number> {
  // 1. Try Linux sysfs thermal zone
  try {
    if (fs.existsSync('/sys/class/thermal/thermal_zone0/temp')) {
      const raw = fs.readFileSync('/sys/class/thermal/thermal_zone0/temp', 'utf8');
      const val = parseFloat(raw) / 1000;
      if (!isNaN(val) && val > 10 && val < 115) return val;
    }
  } catch {}

  // 2. CPU Load Proxy calculation across all cores
  const currentCpuTimes = os.cpus();
  let totalDelta = 0;
  let idleDelta = 0;

  for (let i = 0; i < currentCpuTimes.length; i++) {
    const prev = previousCpuTimes[i]?.times || { user: 0, nice: 0, sys: 0, idle: 0, irq: 0 };
    const curr = currentCpuTimes[i].times;

    const prevTotal = Object.values(prev).reduce((a, b) => a + b, 0);
    const currTotal = Object.values(curr).reduce((a, b) => a + b, 0);

    totalDelta += currTotal - prevTotal;
    idleDelta += curr.idle - prev.idle;
  }
  previousCpuTimes = currentCpuTimes;

  const activeRatio = totalDelta > 0 ? 1 - idleDelta / totalDelta : 0.1;
  // Estimate thermal envelope between ~38°C idle and ~92°C peak stress
  const baseTemp = 38 + activeRatio * 52;
  const jitter = (Math.random() - 0.5) * 1.2;
  return Math.min(95, Math.max(30, baseTemp + jitter));
}

async function getThermalSnapshot(): Promise<ThermalSnapshot> {
  const temp = await readCpuTemperature();
  const minTemp = 35;
  const maxTemp = 88;
  const normalized = Math.max(0, Math.min(1, (temp - minTemp) / (maxTemp - minTemp)));

  return {
    celsius: parseFloat(temp.toFixed(1)),
    normalized: parseFloat(normalized.toFixed(3)),
    load: parseFloat((normalized * 100).toFixed(1)),
    timestamp: Date.now()
  };
}

/**
 * Web Client HTML/JS Engine: Live Eulerian Fluid Simulation & Watercolor Renderer
 */
const htmlApp = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Hardware Exhaustion — Thermal Fluid Landscape</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body, html { width: 100%; height: 100%; overflow: hidden; background: #08070b; font-family: monospace; }
    canvas { display: block; width: 100vw; height: 100vh; filter: contrast(115%) saturate(125%); }
    #hud {
      position: absolute; top: 24px; left: 24px; color: rgba(255,255,255,0.85);
      background: rgba(12, 10, 18, 0.65); backdrop-filter: blur(12px);
      padding: 16px 20px; border-radius: 12px; border: 1px solid rgba(255,255,255,0.1);
      box-shadow: 0 8px 32px rgba(0,0,0,0.5); pointer-events: none;
    }
    .temp-val { font-size: 2.2rem; font-weight: bold; letter-spacing: -1px; margin-top: 4px; }
    .status { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 2px; opacity: 0.6; }
    .bar-container { width: 180px; height: 4px; background: rgba(255,255,255,0.15); border-radius: 2px; margin-top: 10px; overflow: hidden; }
    .bar-fill { height: 100%; width: 0%; background: linear-gradient(90deg, #4facfe, #ff0844); transition: width 0.3s ease; }
  </style>
</head>
<body>
  <div id="hud">
    <div class="status">CPU Thermal Core</div>
    <div class="temp-val" id="tempDisplay">--.-°C</div>
    <div class="bar-container"><div class="bar-fill" id="tempBar"></div></div>
  </div>
  <canvas id="stage"></canvas>

  <script>
    const canvas = document.getElementById('stage');
    const ctx = canvas.getContext('2d');
    let width, height;

    function resize() {
      width = canvas.width = window.innerWidth;
      height = canvas.height = window.innerHeight;
    }
    window.addEventListener('resize', resize);
    resize();

    // Thermal State Data Stream
    let currentTemp = 42.0;
    let normalizedHeat = 0.2;

    const evtSource = new EventSource('/thermals');
    evtSource.onmessage = (e) => {
      const data = JSON.parse(e.data);
      currentTemp = data.celsius;
      normalizedHeat = data.normalized;
      document.getElementById('tempDisplay').innerText = data.celsius.toFixed(1) + '°C';
      document.getElementById('tempBar').style.width = (data.normalized * 100) + '%';
    };

    // Watercolor & Fluid Simulation
    const GRID_SIZE = 64;
    const N = GRID_SIZE;
    const iter = 4;
    
    // Velocity & Density Arrays
    let u = new Float32Array((N + 2) * (N + 2));
    let v = new Float32Array((N + 2) * (N + 2));
    let u_prev = new Float32Array((N + 2) * (N + 2));
    let v_prev = new Float32Array((N + 2) * (N + 2));
    let dens = new Float32Array((N + 2) * (N + 2));
    let dens_prev = new Float32Array((N + 2) * (N + 2));

    function IX(x, y) { return x + (N + 2) * y; }

    function addSource(x, s, dt) {
      for (let i = 0; i < (N + 2) * (N + 2); i++) x[i] += dt * s[i];
    }

    function diffuse(b, x, x0, diff, dt) {
      let a = dt * diff * N * N;
      for (let k = 0; k < iter; k++) {
        for (let i = 1; i <= N; i++) {
          for (let j = 1; j <= N; j++) {
            x[IX(i, j)] = (x0[IX(i, j)] + a * (x[IX(i - 1, j)] + x[IX(i + 1, j)] + x[IX(i, j - 1)] + x[IX(i, j + 1)])) / (1 + 4 * a);
          }
        }
      }
    }

    function advect(b, d, d0, u, v, dt) {
      let dt0 = dt * N;
      for (let i = 1; i <= N; i++) {
        for (let j = 1; j <= N; j++) {
          let x = i - dt0 * u[IX(i, j)];
          let y = j - dt0 * v[IX(i, j)];
          if (x < 0.5) x = 0.5; if (x > N + 0.5) x = N + 0.5;
          let i0 = Math.floor(x), i1 = i0 + 1;
          if (y < 0.5) y = 0.5; if (y > N + 0.5) y = N + 0.5;
          let j0 = Math.floor(y), j1 = j0 + 1;
          let s1 = x - i0, s0 = 1 - s1;
          let t1 = y - j0, t0 = 1 - t1;
          d[IX(i, j)] = s0 * (t0 * d0[IX(i0, j0)] + t1 * d0[IX(i0, j1)]) +
                       s1 * (t0 * d0[IX(i1, j0)] + t1 * d0[IX(i1, j1)]);
        }
      }
    }

    function stepFluid(dt, viscosity) {
      diffuse(1, u_prev, u, viscosity, dt);
      diffuse(2, v_prev, v, viscosity, dt);
      advect(1, u, u_prev, u_prev, v_prev, dt);
      advect(2, v, v_prev, u_prev, v_prev, dt);
      diffuse(0, dens_prev, dens, 0.0001, dt);
      advect(0, dens, dens_prev, u, v, dt);
    }

    // Dynamic Color Palette Mapping based on CPU Exhaustion
    function getWatercolorColor(density, heat) {
      // Cool (Cyan/Indigo) -> Warm (Ember/Crimson/Gold)
      const r = Math.min(255, Math.floor(density * (100 + heat * 155)));
      const g = Math.min(255, Math.floor(density * (140 - heat * 80) + Math.sin(heat * 3) * 30));
      const b = Math.min(255, Math.floor(density * (220 - heat * 180)));
      const alpha = Math.min(0.85, density * 0.9);
      return \`rgba(\${r}, \${g}, \${b}, \${alpha})\`;
    }

    let time = 0;
    function renderFrame() {
      time += 0.02;
      ctx.fillStyle = 'rgba(8, 7, 11, 0.08)'; // Granular watercolor bleed layer decay
      ctx.fillRect(0, 0, width, height);

      // Inject thermal energy & turbulence into central fluid emitters
      const sourceX = Math.floor(N / 2 + Math.sin(time * 1.5) * (N / 4));
      const sourceY = Math.floor(N / 2 + Math.cos(time * 1.1) * (N / 4));
      
      const thermalEnergy = 1.0 + normalizedHeat * 8.0;
      dens[IX(sourceX, sourceY)] += 4.0 * thermalEnergy;
      u[IX(sourceX, sourceY)] += Math.sin(time * 3) * thermalEnergy * 0.8;
      v[IX(sourceX, sourceY)] += Math.cos(time * 2.5) * thermalEnergy * 0.8;

      stepFluid(0.1, 0.0001 + normalizedHeat * 0.002);

      // Draw Watercolor Granular Strokes onto Canvas
      const cellW = width / N;
      const cellH = height / N;

      for (let i = 1; i <= N; i++) {
        for (let j = 1; j <= N; j++) {
          const d = dens[IX(i, j)];
          if (d > 0.02) {
            ctx.beginPath();
            const posX = (i - 1) * cellW;
            const posY = (j - 1) * cellH;
            
            // Pigment edge distortion for organic paper bleed
            const jitterX = (Math.sin(i * 12.0 + time) * 3) * normalizedHeat;
            const jitterY = (Math.cos(j * 12.0 + time) * 3) * normalizedHeat;

            ctx.arc(posX + cellW / 2 + jitterX, posY + cellH / 2 + jitterY, (cellW * 1.8) * Math.min(d, 2.5), 0, Math.PI * 2);
            ctx.fillStyle = getWatercolorColor(d, normalizedHeat);
            ctx.fill();
          }
        }
      }

      requestAnimationFrame(renderFrame);
    }

    renderFrame();
  </script>
</body>
</html>`;

/**
 * HTTP Server & Real-time Telemetry Event Stream Initialization
 */
const PORT = 3000;

const server = http.createServer(async (req, res) => {
  if (req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(htmlApp);
  } else if (req.url === '/thermals') {
    // Server-Sent Events (SSE) Endpoint
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*'
    });

    const interval = setInterval(async () => {
      const snapshot = await getThermalSnapshot();
      res.write(`data: ${JSON.stringify(snapshot)}\n\n`);
    }, 200);

    req.on('close', () => {
      clearInterval(interval);
    });
  } else {
    res.writeHead(404);
    res.end();
  }
});

server.listen(PORT, () => {
  const url = `http://localhost:${PORT}`;
  console.log(`\x1b[36m[Thermal Landscape Engine]\x1b[0m Server running at ${url}`);
  console.log(`\x1b[33mTranslating CPU heat dissipation into real-time fluid watercolor artwork...\x1b[0m`);

  // Auto-launch default browser according to host platform
  const openCmd =
    process.platform === 'darwin' ? `open ${url}` :
    process.platform === 'win32' ? `start ${url}` :
    `xdg-open ${url}`;

  exec(openCmd, (err) => {
    if (err) console.log(`Open your browser at ${url} to view the live fluid landscape.`);
  });
});