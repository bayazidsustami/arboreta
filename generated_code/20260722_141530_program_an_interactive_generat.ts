import * as http from 'http';
import { performance } from 'perf_hooks';

/**
 * Interactive Stained-Glass Generative Memory Renderer
 * 
 * Monitors real-time Node.js V8 heap allocations & GC events,
 * streaming telemetry via SSE to a self-contained HTML5 Canvas Voronoi renderer.
 */

const PORT = 3000;

interface MemoryTelemetry {
  heapUsed: number;
  heapTotal: number;
  rss: number;
  gcDetected: boolean;
  delta: number;
  timestamp: number;
}

let lastHeapUsed = process.memoryUsage().heapUsed;
let gcDetected = false;

// Simulated periodic memory churn to drive dynamic visual evolution
const memoryPool: Uint8Array[] = [];
setInterval(() => {
  if (Math.random() > 0.3) {
    // Allocate memory chunk
    memoryPool.push(new Uint8Array(1024 * 512 * Math.floor(Math.random() * 8 + 1)));
  } else if (memoryPool.length > 0) {
    // Trigger allocation drop / simulate GC pressure
    memoryPool.splice(0, Math.floor(memoryPool.length * 0.5));
  }
}, 150);

// HTTP Server serving the application & real-time SSE stream
const server = http.createServer((req, res) => {
  if (req.url === '/events') {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*'
    });

    const interval = setInterval(() => {
      const mem = process.memoryUsage();
      const currentHeap = mem.heapUsed;
      const delta = currentHeap - lastHeapUsed;
      
      // Heuristic for GC cycle detection (sharp drop in heap usage)
      const isGC = delta < -1024 * 512;
      
      const data: MemoryTelemetry = {
        heapUsed: currentHeap,
        heapTotal: mem.heapTotal,
        rss: mem.rss,
        gcDetected: isGC,
        delta: delta,
        timestamp: performance.now()
      };

      lastHeapUsed = currentHeap;
      res.write(`data: ${JSON.stringify(data)}\n\n`);
    }, 100);

    req.on('close', () => clearInterval(interval));
    return;
  }

  // Serve Interactive Stained-Glass Frontend
  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end(getHTMLContent());
});

server.listen(PORT, () => {
  console.log(`\n=============================================================`);
  console.log(`  Stained Glass Heap Visualizer Running!`);
  console.log(`  Open your browser at: http://localhost:${PORT}`);
  console.log(`=============================================================\n`);
});

function getHTMLContent(): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Heap Allocation Stained Glass Window</title>
  <style>
    body, html {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background-color: #050508;
      font-family: 'Courier New', Courier, monospace;
    }
    canvas {
      display: block;
      width: 100vw;
      height: 100vh;
    }
    #hud {
      position: absolute;
      top: 20px;
      left: 20px;
      color: rgba(255, 255, 255, 0.85);
      background: rgba(0, 0, 0, 0.6);
      padding: 15px;
      border-radius: 8px;
      border: 1px solid rgba(255, 255, 255, 0.15);
      backdrop-filter: blur(5px);
      pointer-events: none;
      box-shadow: 0 0 20px rgba(0,0,0,0.8);
    }
    .val { color: #00ffcc; font-weight: bold; }
    .gc { color: #ff0055; font-weight: bold; animation: flash 0.5s ease-out; }
  </style>
</head>
<body>
  <div id="hud">
    <h2>HEAP STAINED GLASS</h2>
    <div>Heap Used: <span id="heapUsed" class="val">0</span> MB</div>
    <div>Heap Total: <span id="heapTotal" class="val">0</span> MB</div>
    <div>Allocation Rate: <span id="allocRate" class="val">0</span> KB/s</div>
    <div>GC Cycles: <span id="gcCount" class="val">0</span></div>
  </div>
  <canvas id="glassCanvas"></canvas>

  <script>
    const canvas = document.getElementById('glassCanvas');
    const ctx = canvas.getContext('2d');
    
    let width = canvas.width = window.innerWidth;
    let height = canvas.height = window.innerHeight;

    window.addEventListener('resize', () => {
      width = canvas.width = window.innerWidth;
      height = canvas.height = window.innerHeight;
      initSeeds();
    });

    let seeds = [];
    const NUM_SEEDS = 42;
    let gcCount = 0;
    let flashIntensity = 0;
    let targetHueOffset = 0;
    let currentHueOffset = 0;
    let memoryRatio = 0.5;

    // Seed structure representing glass fragments
    function initSeeds() {
      seeds = [];
      for (let i = 0; i < NUM_SEEDS; i++) {
        seeds.push({
          x: Math.random() * width,
          y: Math.random() * height,
          vx: (Math.random() - 0.5) * 0.5,
          vy: (Math.random() - 0.5) * 0.5,
          baseHue: Math.random() * 360,
          roughness: Math.random()
        });
      }
    }
    initSeeds();

    // Connect to Node.js telemetry stream
    const evtSource = new EventSource('/events');
    evtSource.onmessage = (event) => {
      const data = JSON.parse(event.data);
      
      const heapUsedMB = (data.heapUsed / 1024 / 1024).toFixed(2);
      const heapTotalMB = (data.heapTotal / 1024 / 1024).toFixed(2);
      const allocRateKB = (data.delta / 1024).toFixed(1);

      document.getElementById('heapUsed').textContent = heapUsedMB;
      document.getElementById('heapTotal').textContent = heapTotalMB;
      document.getElementById('allocRate').textContent = allocRateKB;

      memoryRatio = Math.min(1, data.heapUsed / data.heapTotal);
      targetHueOffset = memoryRatio * 280;

      if (data.gcDetected) {
        gcCount++;
        flashIntensity = 1.0;
        document.getElementById('gcCount').textContent = gcCount;

        // Distort seeds on Garbage Collection shatter
        seeds.forEach(seed => {
          seed.vx += (Math.random() - 0.5) * 8;
          seed.vy += (Math.random() - 0.5) * 8;
        });
      }
    };

    // Voronoi Stained Glass Renderer
    function render() {
      ctx.fillStyle = '#050508';
      ctx.fillRect(0, 0, width, height);

      // Smooth color transitions based on heap state
      currentHueOffset += (targetHueOffset - currentHueOffset) * 0.05;

      // Update seed coordinates with memory velocity
      seeds.forEach(s => {
        s.x += s.vx;
        s.y += s.vy;
        s.vx *= 0.95;
        s.vy *= 0.95;

        if (s.x < 0 || s.x > width) s.vx *= -1;
        if (s.y < 0 || s.y > height) s.vy *= -1;
      });

      // Render pixel-grid Voronoi diagram for glass fragments
      const step = 6; // Grid resolution for real-time performance
      for (let x = 0; x < width; x += step) {
        for (let y = 0; y < height; y += step) {
          let minDist1 = Infinity;
          let minDist2 = Infinity;
          let closestSeed = seeds[0];

          for (let i = 0; i < seeds.length; i++) {
            const s = seeds[i];
            const dx = x - s.x;
            const dy = y - s.y;
            const dist = Math.sqrt(dx * dx + dy * dy);

            if (dist < minDist1) {
              minDist2 = minDist1;
              minDist1 = dist;
              closestSeed = s;
            } else if (dist < minDist2) {
              minDist2 = dist;
            }
          }

          // Crack geometry defined by distance bisector (minDist2 - minDist1)
          const edgeDist = minDist2 - minDist1;
          const isLeadLine = edgeDist < (2.5 + memoryRatio * 3.0);

          if (isLeadLine) {
            // Dark lead lines between stained glass fragments
            ctx.fillStyle = '#0a0a10';
          } else {
            // Radiant glass fragment coloration shifting with memory usage
            const hue = (closestSeed.baseHue + currentHueOffset) % 360;
            const sat = 70 + memoryRatio * 30;
            const light = 25 + (1 - edgeDist / 100) * 35 + flashIntensity * 40;

            ctx.fillStyle = \`hsla(\${hue}, \${sat}%, \${light}%, 0.85)\`;
          }

          ctx.fillRect(x, y, step, step);
        }
      }

      // GC Light Flash effect
      if (flashIntensity > 0) {
        ctx.fillStyle = \`rgba(255, 255, 255, \${flashIntensity * 0.3})\`;
        ctx.fillRect(0, 0, width, height);
        flashIntensity *= 0.88;
      }

      requestAnimationFrame(render);
    }

    render();
  </script>
</body>
</html>`;
}