import fs from 'fs';
import { spawn } from 'child_process';

/**
 * Esoteric Bytecode Interpreter: Image-to-Chiptune & Terminal Fluid Visualizer
 *
 * Usage:
 *   node script.js <path-to-image.bmp-or-raw>
 *
 * If no file is provided, an internal procedural 64x64 RGBA visual art canvas is generated.
 * Pixel RGBA bytes act as bytecode opcodes for an algorithmic chiptune synth engine.
 * Real-time audio frequencies drive an ASCII Navier-Stokes-inspired fluid dynamics simulation in the console.
 */

// --- 1. Audio Engine & Bytecode Interpreter ---
const SAMPLE_RATE = 22050;
let audioPhase = 0;
let currentFreq = 220;
let currentVol = 0.3;
let waveformType = 0; // 0: Square, 1: Saw, 2: Triangle, 3: Noise

// Virtual CPU State for Esoteric Bytecode Interpreter
const vm = {
  pc: 0,
  registers: new Float32Array(8),
  stack: [],
  bytes: new Uint8Array(0)
};

function loadBytecode(buffer) {
  vm.bytes = new Uint8Array(buffer);
  vm.pc = 0;
}

function stepBytecode() {
  if (vm.bytes.length === 0) return;
  
  // Read RGBA quadruplet as 4 bytes of bytecode
  const r = vm.bytes[vm.pc % vm.bytes.length];
  const g = vm.bytes[(vm.pc + 1) % vm.bytes.length];
  const b = vm.bytes[(vm.pc + 2) % vm.bytes.length];
  const a = vm.bytes[(vm.pc + 3) % vm.bytes.length];
  
  vm.pc = (vm.pc + 4) % vm.bytes.length;

  // Interpret Color Channels as Instructions
  // R: Note / Pitch Modulation (Mapping 0-255 to 55Hz - 1760Hz scale)
  const noteIndex = r % 24;
  currentFreq = 110 * Math.pow(2, noteIndex / 12);

  // G: Waveform & Timbre Selection
  waveformType = g % 4;

  // B: Volume & Rhythm Duty Cycle
  currentVol = (b / 255) * 0.4;

  // A: Stack manipulation & Register Branching
  const regIdx = a % 8;
  vm.registers[regIdx] = (vm.registers[regIdx] + r - g) & 0xFF;
}

function generateAudioSample() {
  audioPhase += currentFreq / SAMPLE_RATE;
  if (audioPhase >= 1.0) audioPhase -= 1.0;

  let val = 0;
  switch (waveformType) {
    case 0: // Pulse / Square Wave
      val = audioPhase < 0.5 ? 1 : -1;
      break;
    case 1: // Sawtooth Wave
      val = 2 * audioPhase - 1;
      break;
    case 2: // Triangle Wave
      val = 2 * Math.abs(2 * audioPhase - 1) - 1;
      break;
    case 3: // Chiptune Noise
      val = Math.random() * 2 - 1;
      break;
  }

  return val * currentVol;
}

// --- 2. Fluid Simulation Engine (Terminal ASCII Visualizer) ---
const N = 32;
const size = (N + 2) * (N + 2);
let u = new Float32Array(size);
let v = new Float32Array(size);
let u_prev = new Float32Array(size);
let v_prev = new Float32Array(size);
let dens = new Float32Array(size);
let dens_prev = new Float32Array(size);

const IX = (x, y) => x + (N + 2) * y;

function addSource(x, s, dt) {
  for (let i = 0; i < size; i++) x[i] += dt * s[i];
}

function diffuse(b, x, x0, diff, dt) {
  const a = dt * diff * N * N;
  for (let k = 0; k < 4; k++) {
    for (let i = 1; i <= N; i++) {
      for (let j = 1; j <= N; j++) {
        x[IX(i, j)] = (x0[IX(i, j)] + a * (x[IX(i - 1, j)] + x[IX(i + 1, j)] + x[IX(i, j - 1)] + x[IX(i, j + 1)])) / (1 + 4 * a);
      }
    }
  }
}

function advect(b, d, d0, u, v, dt) {
  const dt0 = dt * N;
  for (let i = 1; i <= N; i++) {
    for (let j = 1; j <= N; j++) {
      let x = i - dt0 * u[IX(i, j)];
      let y = j - dt0 * v[IX(i, j)];
      if (x < 0.5) x = 0.5; if (x > N + 0.5) x = N + 0.5;
      const i0 = Math.floor(x); const i1 = i0 + 1;
      if (y < 0.5) y = 0.5; if (y > N + 0.5) y = N + 0.5;
      const j0 = Math.floor(y); const j1 = j0 + 1;
      const s1 = x - i0; const s0 = 1 - s1;
      const t1 = y - j0; const t0 = 1 - t1;
      d[IX(i, j)] = s0 * (t0 * d0[IX(i0, j0)] + t1 * d0[IX(i0, j1)]) +
                    s1 * (t0 * d0[IX(i1, j0)] + t1 * d0[IX(i1, j1)]);
    }
  }
}

function fluidStep() {
  diffuse(0, u_prev, u, 0.0001, 0.1);
  diffuse(0, v_prev, v, 0.0001, 0.1);
  advect(1, u, u_prev, u_prev, v_prev, 0.1);
  advect(2, v, v_prev, u_prev, v_prev, 0.1);
  diffuse(0, dens_prev, dens, 0.0001, 0.1);
  advect(0, dens, dens_prev, u, v, 0.1);
}

// Render density grid to ANSI terminal
const asciiRamp = " .:-=+*#%@";
function renderFluid() {
  process.stdout.write('\x1b[H'); // Move cursor to top-left
  let frame = '\n  --- ESOTERIC CHIPTUNE FLUID VISUALIZER ---\n\n';
  
  for (let j = 1; j <= N; j += 2) {
    let line = '  ';
    for (let i = 1; i <= N; i++) {
      const d = dens[IX(i, j)];
      const idx = Math.min(asciiRamp.length - 1, Math.floor(d * asciiRamp.length));
      const char = asciiRamp[idx];
      // Color code based on pitch and waveform
      const color = 31 + (waveformType * 2 + Math.floor(currentFreq / 200)) % 6;
      line += `\x1b[${color}m${char}\x1b[0m `;
    }
    frame += line + '\n';
  }
  
  frame += `\n  [Bytecode PC: ${vm.pc}] [Freq: ${Math.round(currentFreq)} Hz] [Wave: ${['Pulse','Saw','Triangle','Noise'][waveformType]}]  \n`;
  process.stdout.write(frame);
}

// --- 3. Default Image Generator (Procedural Art Bytecode) ---
function generateProceduralArt() {
  const buf = Buffer.alloc(64 * 64 * 4);
  for (let y = 0; y < 64; y++) {
    for (let x = 0; x < 64; x++) {
      const idx = (y * 64 + x) * 4;
      buf[idx] = (x * y) % 256;         // Red: Pitch byte
      buf[idx + 1] = (x ^ y) % 256;     // Green: Timbre byte
      buf[idx + 2] = (x + y) * 4 % 256;  // Blue: Velocity byte
      buf[idx + 3] = 255;               // Alpha
    }
  }
  return buf;
}

// --- 4. Main Execution Setup ---
function main() {
  const filePath = process.argv[2];
  let imageBuffer;

  if (filePath && fs.existsSync(filePath)) {
    imageBuffer = fs.readFileSync(filePath);
  } else {
    imageBuffer = generateProceduralArt();
  }

  loadBytecode(imageBuffer);

  // Clear terminal screen
  process.stdout.write('\x1b[2J');

  // Spawn raw audio output player (ffplay, aplay, or stdout fallback)
  const audioPlayer = spawn('ffplay', [
    '-f', 's16le',
    '-ar', SAMPLE_RATE.toString(),
    '-ac', '1',
    '-nodisp',
    '-'
  ], { stdio: ['pipe', 'ignore', 'ignore'] }).on('error', () => {
    // Graceful fallback if ffplay is not installed
  });

  // Audio & Bytecode loop interval (~50Hz updates)
  let tick = 0;
  setInterval(() => {
    stepBytecode();

    // Inject sound frequencies into fluid simulation center
    const cx = Math.floor(N / 2);
    const cy = Math.floor(N / 2);
    const intensity = (currentFreq / 1000) * (currentVol * 5);
    
    dens[IX(cx, cy)] += intensity * 2;
    u[IX(cx, cy)] += (Math.random() - 0.5) * intensity;
    v[IX(cx, cy)] += (Math.random() - 0.5) * intensity;

    fluidStep();
    renderFluid();

    // Push PCM audio samples to audio player
    if (audioPlayer.stdin && audioPlayer.stdin.writable) {
      const pcmBuffer = Buffer.alloc(SAMPLE_RATE / 20 * 2); // ~50ms audio chunk
      for (let i = 0; i < pcmBuffer.length; i += 2) {
        const sample = generateAudioSample();
        const int16Sample = Math.max(-32768, Math.min(32767, Math.floor(sample * 32767)));
        pcmBuffer.writeInt16LE(int16Sample, i);
      }
      audioPlayer.stdin.write(pcmBuffer);
    }

    tick++;
  }, 20);
}

main();