// Sound-Reactive ASCII Fluid Dynamics Simulation
// Self-contained Node.js terminal artwork translating frequency bands into fluid dynamics.

const stdout = process.stdout;

// Grid configuration
let width = stdout.columns || 80;
let height = stdout.rows || 40;

// Fluid simulation buffers
let density = new Float32Array(width * height);
let densityPrev = new Float32Array(width * height);
let vx = new Float32Array(width * height);
let vy = new Float32Array(width * height);
let vxPrev = new Float32Array(width * height);
let vyPrev = new Float32Array(width * height);

// ASCII shading gradient & color palettes
const ASCII_SHADE = " .':;l1TJI?S25398640$#@M";
const PALETTE = [
  (val) => `\x1b[38;2;${Math.min(255, val * 3)};${Math.min(255, val * 0.8)};${Math.min(255, val * 5)}m`, // Bass: Violet/Pink
  (val) => `\x1b[38;2;${Math.min(255, val * 0.5)};${Math.min(255, val * 4)};${Math.min(255, val * 3)}m`, // Mid: Cyan/Emerald
  (val) => `\x1b[38;2;${Math.min(255, val * 5)};${Math.min(255, val * 3)};${Math.min(255, val * 0.5)}m`  // Treble: Gold/Orange
];

// Audio Frequency Synthesizer & Analyzer (Simulates multi-band audio spectrum)
class AudioAnalyzer {
  constructor() {
    this.time = 0;
    this.bands = { bass: 0, mid: 0, treble: 0 };
  }

  update() {
    this.time += 0.05;
    // Layered sine synthesizers imitating drum beats, synth rhythms, and hi-hats
    const kick = Math.pow(Math.max(0, Math.sin(this.time * 2.5)), 8);
    const bassline = (Math.sin(this.time * 1.2) + 1) * 0.5;
    const synthMid = Math.abs(Math.sin(this.time * 3.7) * Math.cos(this.time * 1.8));
    const hiHat = Math.pow(Math.sin(this.time * 8.0), 12);

    this.bands.bass = Math.min(1.0, kick * 0.8 + bassline * 0.4);
    this.bands.mid = Math.min(1.0, synthMid);
    this.bands.treble = Math.min(1.0, hiHat);
  }
}

const audio = new AudioAnalyzer();

// Fluid Dynamics Helper Methods
function IX(x, y) {
  x = Math.max(0, Math.min(width - 1, x));
  y = Math.max(0, Math.min(height - 1, y));
  return x + y * width;
}

function addSource(x, y, vxVal, vyVal, densVal) {
  const idx = IX(Math.floor(x), Math.floor(y));
  vx[idx] += vxVal;
  vy[idx] += vyVal;
  density[idx] += densVal;
}

function diffuse(b, x, x0, diff, dt) {
  const a = dt * diff * width * height;
  for (let k = 0; k < 4; k++) {
    for (let i = 1; i < width - 1; i++) {
      for (let j = 1; j < height - 1; j++) {
        x[IX(i, j)] = (x0[IX(i, j)] + a * (
          x[IX(i + 1, j)] + x[IX(i - 1, j)] +
          x[IX(i, j + 1)] + x[IX(i, j - 1)]
        )) / (1 + 4 * a);
      }
    }
  }
}

function advect(b, d, d0, u, v, dt) {
  const dt0 = dt * width;
  for (let i = 1; i < width - 1; i++) {
    for (let j = 1; j < height - 1; j++) {
      let x = i - dt0 * u[IX(i, j)];
      let y = j - dt0 * v[IX(i, j)];
      if (x < 0.5) x = 0.5; if (x > width - 1.5) x = width - 1.5;
      const i0 = Math.floor(x), i1 = i0 + 1;
      if (y < 0.5) y = 0.5; if (y > height - 1.5) y = height - 1.5;
      const j0 = Math.floor(y), j1 = j0 + 1;
      const s1 = x - i0, s0 = 1 - s1;
      const t1 = y - j0, t0 = 1 - t1;
      d[IX(i, j)] = s0 * (t0 * d0[IX(i0, j0)] + t1 * d0[IX(i0, j1)]) +
                    s1 * (t0 * d0[IX(i1, j0)] + t1 * d0[IX(i1, j1)]);
    }
  }
}

function fluidStep(dt = 0.1) {
  diffuse(1, vxPrev, vx, 0.0001, dt);
  diffuse(2, vyPrev, vy, 0.0001, dt);
  advect(1, vx, vxPrev, vxPrev, vyPrev, dt);
  advect(2, vy, vyPrev, vxPrev, vyPrev, dt);
  diffuse(0, densityPrev, density, 0.0001, dt);
  advect(0, density, densityPrev, vx, vy, dt);

  // Dissipation
  for (let i = 0; i < density.length; i++) {
    density[i] *= 0.96;
    vx[i] *= 0.98;
    vy[i] *= 0.98;
  }
}

// Convert audio frequencies into fluid force emitters
function injectAudioForces() {
  const cx = width / 2;
  const cy = height / 2;

  // Bass frequency creates explosive central upward jets
  if (audio.bands.bass > 0.2) {
    const force = audio.bands.bass * 15;
    addSource(cx + (Math.random() - 0.5) * 6, cy + 5, (Math.random() - 0.5) * 4, -force, force * 20);
  }

  // Mid frequencies inject swirling orbital fluid forces
  if (audio.bands.mid > 0.1) {
    const angle = audio.time * 3;
    const radius = Math.min(width, height) * 0.25;
    const ex = cx + Math.cos(angle) * radius;
    const ey = cy + Math.sin(angle) * radius;
    addSource(ex, ey, -Math.sin(angle) * 8, Math.cos(angle) * 8, audio.bands.mid * 15);
  }

  // Treble injects high-frequency dynamic particle sparks
  if (audio.bands.treble > 0.3) {
    const ex = Math.random() * (width - 4) + 2;
    const ey = Math.random() * (height - 4) + 2;
    addSource(ex, ey, (Math.random() - 0.5) * 10, (Math.random() - 0.5) * 10, audio.bands.treble * 25);
  }
}

// Render the ASCII fluid field to terminal stdout
function render() {
  let frame = "\x1b[H"; // Reset cursor position
  const activePalette = audio.bands.bass > 0.6 ? PALETTE[0] : (audio.bands.mid > 0.5 ? PALETTE[1] : PALETTE[2]);

  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const idx = IX(x, y);
      const val = density[idx];
      const charIdx = Math.min(ASCII_SHADE.length - 1, Math.floor((val / 20) * ASCII_SHADE.length));
      const char = ASCII_SHADE[charIdx];

      if (char !== " ") {
        frame += activePalette(val * 12) + char;
      } else {
        frame += " ";
      }
    }
    frame += "\n";
  }

  stdout.write(frame);
}

// Terminal initialization
function init() {
  stdout.write("\x1b[2J\x1b[?25l"); // Clear screen & hide cursor

  process.on("SIGINT", () => {
    stdout.write("\x1b[?25h\x1b[0m\x1b[2J"); // Restore cursor & clear
    process.exit();
  });

  process.stdout.on("resize", () => {
    width = stdout.columns || 80;
    height = stdout.rows || 40;
    density = new Float32Array(width * height);
    densityPrev = new Float32Array(width * height);
    vx = new Float32Array(width * height);
    vy = new Float32Array(width * height);
    vxPrev = new Float32Array(width * height);
    vyPrev = new Float32Array(width * height);
  });

  // Main animation loop (~30 FPS)
  setInterval(() => {
    audio.update();
    injectAudioForces();
    fluidStep();
    render();
  }, 33);
}

init();