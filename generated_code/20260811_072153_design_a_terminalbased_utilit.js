// Ambient Network Weather System - Terminal Visualizer & Sonic Monitor
// Translates live network interface traffic into a dynamic terminal weather system.
// Bandwidth spikes drive wind velocity and rain intensity; packet drops trigger thunder strikes.

const fs = require('fs');
const os = require('os');
const child_process = require('child_process');

// Terminal Dimensions & State
let cols = process.stdout.columns || 80;
let rows = process.stdout.rows || 24;

let prevBytes = 0;
let prevPackets = 0;
let prevDrop = 0;
let lastCheckTime = Date.now();

let windSpeed = 0; // Derived from KB/s
let dropRate = 0;  // Dropped packets count
let thunderActive = 0; // Thunder flash countdown
let weatherState = 'Calm Breeze';

const raindrops = [];
const clouds = [];
const particles = [];

// Initialize particle systems
function initParticles() {
  raindrops.length = 0;
  clouds.length = 0;
  particles.length = 0;

  for (let i = 0; i < 35; i++) {
    raindrops.push({
      x: Math.floor(Math.random() * cols),
      y: Math.floor(Math.random() * (rows - 5)),
      speed: 1 + Math.random() * 2,
      char: Math.random() > 0.5 ? '│' : '┆'
    });
  }

  for (let i = 0; i < 5; i++) {
    clouds.push({
      x: Math.floor(Math.random() * cols),
      y: 1 + Math.floor(Math.random() * 3),
      shape: ' (☁☁☁☁) '
    });
  }
}

// Sample cross-platform network stats
function getNetworkStats() {
  let rxBytes = 0, txBytes = 0, rxDrop = 0, txDrop = 0;

  try {
    if (os.platform() === 'linux' && fs.existsSync('/proc/net/dev')) {
      const data = fs.readFileSync('/proc/net/dev', 'utf8');
      const lines = data.split('\n');
      for (const line of lines) {
        if (line.includes(':') && !line.includes('lo:')) {
          const parts = line.trim().split(/\s+/);
          const fields = parts[0].includes(':') 
            ? [parts[0].split(':')[1], ...parts.slice(1)] 
            : parts.slice(1);
          rxBytes += parseInt(fields[0], 10) || 0;
          rxDrop += parseInt(fields[3], 10) || 0;
          txBytes += parseInt(fields[8], 10) || 0;
          txDrop += parseInt(fields[11], 10) || 0;
        }
      }
    } else {
      // Platform fallback with simulated organic network traffic variance
      const interfaces = os.networkInterfaces();
      let activeIfaces = 0;
      for (const name in interfaces) {
        if (name !== 'lo' && !name.includes('Loopback')) activeIfaces++;
      }
      const time = Date.now() / 1000;
      const baseTraffic = Math.abs(Math.sin(time / 5)) * 1024 * 1024 * (activeIfaces || 1);
      const spike = Math.random() > 0.85 ? Math.random() * 5 * 1024 * 1024 : 0;
      rxBytes = Math.floor(baseTraffic + spike);
      rxDrop = Math.random() < 0.12 ? Math.floor(Math.random() * 4) + 1 : 0;
    }
  } catch (err) {
    rxBytes = Math.floor(Math.random() * 500000);
  }

  return { bytes: rxBytes + txBytes, drops: rxDrop + txDrop };
}

// Update Network Metrics
function updateMetrics() {
  const now = Date.now();
  const timeDelta = (now - lastCheckTime) / 1000;
  if (timeDelta <= 0) return;

  const current = getNetworkStats();
  const bytesDelta = Math.max(0, current.bytes - prevBytes);
  const dropsDelta = Math.max(0, current.drops - prevDrop);

  prevBytes = current.bytes;
  prevDrop = current.drops;
  lastCheckTime = now;

  const kbps = (bytesDelta / 1024) / timeDelta;
  windSpeed = Math.min(100, Math.floor(kbps / 10)); // Scale KB/s to wind velocity
  dropRate = dropsDelta;

  if (dropRate > 0) {
    thunderActive = 3; // Trigger visual & audio thunder strike
    // Audio trigger: System bell burst representing thunder strike
    process.stdout.write('\x07\x07');
  }

  // Derive weather description
  if (thunderActive > 0) weatherState = '⚡ ELECTRICAL STORM (PACKET DROPS) ⚡';
  else if (windSpeed > 60) weatherState = '🌀 GALE FORCE BANDERSTORM';
  else if (windSpeed > 25) weatherState = '🌧 HEAVY DOWNPOUR & WIND';
  else if (windSpeed > 5)  weatherState = '🌦 MODERATE RAIN';
  else weatherState = '🌤 CALM AMBIENT FLOW';
}

// Render Logic
function draw() {
  cols = process.stdout.columns || 80;
  rows = process.stdout.rows || 24;

  const buffer = Array.from({ length: rows }, () => Array(cols).fill(' '));

  // Determine Thunder Strike Screen Inversion
  const thunderStyle = thunderActive > 0 ? '\x1b[7m\x1b[1;37m' : '\x1b[0m';

  // Render Clouds
  clouds.forEach(cloud => {
    cloud.x = (cloud.x + (windSpeed > 30 ? 0.8 : 0.2)) % cols;
    const cx = Math.floor(cloud.x);
    for (let i = 0; i < cloud.shape.length; i++) {
      const x = (cx + i) % cols;
      if (cloud.y < rows - 3) {
        buffer[cloud.y][x] = cloud.shape[i];
      }
    }
  });

  // Render Raindrops driven by wind
  const rainCount = Math.min(raindrops.length, Math.floor(10 + windSpeed * 0.8));
  for (let i = 0; i < rainCount; i++) {
    const drop = raindrops[i];
    drop.y += drop.speed + (windSpeed / 40);
    drop.x += (windSpeed / 20);

    if (drop.y >= rows - 3) {
      drop.y = 1;
      drop.x = Math.floor(Math.random() * cols);
    }
    drop.x = (drop.x + cols) % cols;

    const rx = Math.floor(drop.x);
    const ry = Math.floor(drop.y);
    if (ry >= 0 && ry < rows - 3 && rx >= 0 && rx < cols) {
      buffer[ry][rx] = windSpeed > 40 ? '╱' : drop.char;
    }
  }

  // Render Lightning Bolts if thunder active
  if (thunderActive > 0) {
    const boltX = Math.floor(cols / 2 + (Math.random() * 20 - 10));
    for (let y = 1; y < rows - 4; y++) {
      const x = Math.max(0, Math.min(cols - 1, boltX + Math.floor(Math.random() * 5 - 2)));
      buffer[y][x] = '⚡';
    }
    thunderActive--;
  }

  // Build String Output
  let output = '\x1b[H' + thunderStyle;
  for (let r = 0; r < rows - 3; r++) {
    output += buffer[r].join('') + '\n';
  }

  // Draw Ground / Horizon
  output += '\x1b[32m' + '▔'.repeat(cols) + '\x1b[0m\n';

  // Draw Dashboard Status Line
  const windBar = '█'.repeat(Math.min(15, Math.floor(windSpeed / 6)));
  const statusLine = ` Weather: ${weatherState} | Wind: ${windSpeed} kts [${windBar.padEnd(15, ' ')}] | Packet Drops: ${dropRate}`;
  output += '\x1b[1;36m' + statusLine.substring(0, cols).padEnd(cols, ' ') + '\x1b[0m\n';

  const footer = ' [ Ctrl+C to exit ] Ambient Network Weather Station active...';
  output += '\x1b[2m' + footer.substring(0, cols).padEnd(cols, ' ') + '\x1b[0m';

  process.stdout.write(output);
}

// Setup Terminal
function setupTerminal() {
  process.stdout.write('\x1b[?25l'); // Hide cursor
  process.stdout.write('\x1b[2J');   // Clear screen
  initParticles();

  process.on('SIGINT', () => {
    process.stdout.write('\x1b[?25h\x1b[0m\x1b[2J\x1b[H'); // Restore cursor & clear
    process.exit();
  });

  process.stdout.on('resize', () => {
    initParticles();
  });
}

// Main Event Loop
setupTerminal();
setInterval(updateMetrics, 1000);
setInterval(draw, 80);