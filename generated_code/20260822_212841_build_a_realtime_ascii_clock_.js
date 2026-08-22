// Real-Time N-Body Gravitational ASCII Clock
// Digit structures act as gravitational attractors for dynamic particles.
// Every minute, attractors shift, triggering a dynamic particle collapse and reformation.

const WIDTH = 80;
const HEIGHT = 24;
const NUM_PARTICLES = 300;
const G = 1.5;
const DAMPING = 0.88;

// 3x5 Pixel Font Data for Digits '0'-'9' and ':'
const FONT = {
  '0': ["###", "# #", "# #", "# #", "###"],
  '1': ["  #", "  #", "  #", "  #", "  #"],
  '2': ["###", "  #", "###", "#  ", "###"],
  '3': ["###", "  #", "###", "  #", "###"],
  '4': ["# #", "# #", "###", "  #", "  #"],
  '5': ["###", "#  ", "###", "  #", "###"],
  '6': ["###", "#  ", "###", "# #", "###"],
  '7': ["###", "  #", "  #", "  #", "  #"],
  '8': ["###", "# #", "###", "# #", "###"],
  '9': ["###", "# #", "###", "  #", "###"],
  ':': ["   ", " # ", "   ", " # ", "   "]
};

// Particles with position, velocity, and assigned target index
class Particle {
  constructor() {
    this.x = Math.random() * WIDTH;
    this.y = Math.random() * HEIGHT;
    this.vx = (Math.random() - 0.5) * 2;
    this.vy = (Math.random() - 0.5) * 2;
    this.char = ['.', '*', '+', 'o', '#'][Math.floor(Math.random() * 5)];
  }

  update(attractor) {
    if (attractor) {
      const dx = attractor.x - this.x;
      const dy = attractor.y - this.y;
      const distSq = Math.max(dx * dx + dy * dy, 0.1);
      const force = G / distSq;
      
      this.vx += (dx / Math.sqrt(distSq)) * force;
      this.vy += (dy / Math.sqrt(distSq)) * force;
    }

    this.vx *= DAMPING;
    this.vy *= DAMPING;
    this.x += this.vx;
    this.y += this.vy;
  }
}

// Extract target coordinate points from a time string
function getAttractorPoints(timeStr) {
  const points = [];
  let startX = Math.floor((WIDTH - (6 * 4 + 2 * 2)) / 2);
  const startY = Math.floor((HEIGHT - 5) / 2);

  for (let char of timeStr) {
    const glyph = FONT[char] || FONT[':'];
    for (let r = 0; r < 5; r++) {
      for (let c = 0; c < 3; c++) {
        if (glyph[r][c] === '#') {
          points.push({ x: startX + c, y: startY + r });
        }
      }
    }
    startX += (char === ':') ? 3 : 5;
  }
  return points;
}

const particles = Array.from({ length: NUM_PARTICLES }, () => new Particle());
let lastTimeStr = "";
let attractors = [];

// Clear terminal & hide cursor
process.stdout.write('\x1B[2J\x1B[?25l');

function render() {
  const now = new Date();
  const timeStr = [now.getHours(), now.getMinutes(), now.getSeconds()]
    .map(v => String(v).padStart(2, '0'))
    .join(':');

  // Trigger gravitational collapse/re-alignment when digits shift
  if (timeStr !== lastTimeStr) {
    attractors = getAttractorPoints(timeStr);
    lastTimeStr = timeStr;
    // Add velocity kick to simulate dynamic collapse/re-orbiting
    particles.forEach(p => {
      p.vx += (Math.random() - 0.5) * 4;
      p.vy += (Math.random() - 0.5) * 4;
    });
  }

  // Create ASCII display canvas buffer
  const buffer = Array.from({ length: HEIGHT }, () => Array(WIDTH).fill(' '));

  // Update and plot dynamic particle orbits
  particles.forEach((p, idx) => {
    const target = attractors[idx % attractors.length];
    p.update(target);

    const px = Math.round(p.x);
    const py = Math.round(p.y);
    if (px >= 0 && px < WIDTH && py >= 0 && py < HEIGHT) {
      buffer[py][px] = p.char;
    }
  });

  // Render buffer to output stream
  let output = '\x1B[H';
  for (let r = 0; r < HEIGHT; r++) {
    output += buffer[r].join('') + '\n';
  }
  process.stdout.write(output);
}

// Smooth 30 FPS physics update loop
setInterval(render, 1000 / 30);

// Restore cursor upon exit
process.on('SIGINT', () => {
  process.stdout.write('\x1B[?25h\x1B[2J');
  process.exit();
});