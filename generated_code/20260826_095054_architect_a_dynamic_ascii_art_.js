const http = require('http');
const v8 = require('v8');

// Config: Celestial Bodies & Orbital Radii
const BODIES = [
  { name: 'Sun',     symbol: '☼', radius: 0,  color: '\x1b[33m', speed: 0 },
  { name: 'Mercury', symbol: '•', radius: 4,  color: '\x1b[37m', baseSpeed: 0.08 },
  { name: 'Venus',   symbol: '♀', radius: 7,  color: '\x1b[32m', baseSpeed: 0.05 },
  { name: 'Earth',   symbol: '⊕', radius: 11, color: '\x1b[36m', baseSpeed: 0.03 },
  { name: 'Mars',    symbol: '♂', radius: 15, color: '\x1b[31m', baseSpeed: 0.02 },
  { name: 'Jupiter', symbol: '♃', radius: 20, color: '\x1b[35m', baseSpeed: 0.01 }
];

// Telemetry state derived from server internals
let stackDepth = 1;
let memoryRate = 1;
let tick = 0;

// 1. Web Server: Synthetic load generation & Stack/Memory tracing
const server = http.createServer((req, res) => {
  // Deepen async stack dynamically based on request path length
  const simulateAsyncStack = (depth, cb) => {
    if (depth <= 0) return cb();
    setImmediate(() => simulateAsyncStack(depth - 1, cb));
  };

  const depthTarget = Math.max(1, (req.url.length % 15) * 2);
  
  simulateAsyncStack(depthTarget, () => {
    // Inspect current call stack depth via Error trace
    const err = new Error();
    stackDepth = (err.stack.match(/at /g) || []).length;

    // Allocate temporary memory to drive heap rate metric
    const payloadSize = (req.url.length + 1) * 1024 * 50;
    const tempBuffer = Buffer.alloc(payloadSize, '🌌');

    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end(`Solar System Telemetry -> Stack Depth: ${stackDepth}, Payload: ${payloadSize} bytes\n`);
  });
}).listen(3000);

// Track Heap allocation rates via V8 statistics
let lastHeapUsed = process.memoryUsage().heapUsed;
setInterval(() => {
  const currentHeap = process.memoryUsage().heapUsed;
  const delta = Math.abs(currentHeap - lastHeapUsed);
  lastHeapUsed = currentHeap;
  // Normalize memory rate (higher allocations = faster orbits)
  memoryRate = Math.max(0.5, Math.min(5.0, delta / 1024 / 100));
}, 200);

// Generate HTTP requests periodically to keep the server stack/memory dynamic
setInterval(() => {
  const paths = ['/orbit', '/mercury/fast', '/jupiter/deep/async/trace', '/sun/pulse'];
  const path = paths[Math.floor(Math.random() * paths.length)];
  http.get(`http://localhost:3000${path}`).on('error', () => {});
}, 300);

// 2. ASCII Renderer: Calculates orbital positions in real-time
function render() {
  tick += 0.05;
  const width = 60;
  const height = 30;
  const centerX = Math.floor(width / 2);
  const centerY = Math.floor(height / 2);
  const aspectCorrection = 2.1; // Correct ASCII character aspect ratio

  // Initialize canvas grid
  const grid = Array.from({ length: height }, () => Array(width).fill(' '));

  // Render Orbits & Celestial Bodies
  BODIES.forEach((body) => {
    if (body.radius === 0) {
      grid[centerY][centerX] = `${body.color}${body.symbol}\x1b[0m`;
      return;
    }

    // Velocity driven by memory allocation rate; angle offset driven by stack depth
    const orbitalSpeed = body.baseSpeed * memoryRate;
    const angle = tick * orbitalSpeed + (stackDepth * 0.1);

    const x = Math.round(centerX + body.radius * Math.cos(angle) * aspectCorrection);
    const y = Math.round(centerY + body.radius * Math.sin(angle));

    if (x >= 0 && x < width && y >= 0 && y < height) {
      grid[y][x] = `${body.color}${body.symbol}\x1b[0m`;
    }
  });

  // Render Frame
  console.clear();
  console.log('\x1b[1m=== DYNAMIC ASCII SOLAR SYSTEM (SERVER REACTION ENGINE) ===\x1b[0m');
  console.log(`[Metrics] Async Stack Depth: \x1b[36m${stackDepth}\x1b[0m | Heap Alloc Rate: \x1b[33m${memoryRate.toFixed(2)}x\x1b[0m`);
  console.log('─'.repeat(width));
  console.log(grid.map(row => row.join('')).join('\n'));
  console.log('─'.repeat(width));
  console.log('Send requests to http://localhost:3000 to alter orbits in real-time.');
}

// 60 FPS Render Loop
setInterval(render, 50);