import * as fs from "fs";
import * as readline from "readline";
import * as path from "path";

// ---------- simple WAV parser (PCM 16‑bit mono) ----------
interface WAV {
  sampleRate: number;
  data: Int16Array;
}
function readWav(file: string): WAV {
  const buf = fs.readFileSync(file);
  if (buf.toString("utf8", 0, 4) !== "RIFF") throw new Error("Not a WAV");
  const fmt = buf.toString("utf8", 12, 16);
  if (fmt !== "fmt ") throw new Error("Unsupported WAV format");
  const audioFormat = buf.readUInt16LE(20);
  const channels = buf.readUInt16LE(22);
  const sampleRate = buf.readUInt32LE(24);
  const bitsPerSample = buf.readUInt16LE(34);
  if (audioFormat !== 1 || channels !== 1 || bitsPerSample !== 16)
    throw new Error("Only PCM 16‑bit mono WAV supported");
  const dataStart = buf.indexOf("data", 0, "utf8") + 8;
  const sampleCount = (buf.length - dataStart) / 2;
  const data = new Int16Array(sampleCount);
  for (let i = 0; i < sampleCount; i++) data[i] = buf.readInt16LE(dataStart + i * 2);
  return { sampleRate, data };
}

// ---------- FFT (radix‑2, from fft-js) ----------
function fft(re: number[], im: number[]): { re: number[]; im: number[] } {
  const N = re.length;
  const levels = Math.log2(N);
  if (Math.floor(levels) !== levels) throw new Error("FFT size must be power of 2");
  const rev = new Uint32Array(N);
  for (let i = 0; i < N; i++) {
    let j = 0;
    for (let bit = 0; bit < levels; bit++) if (i & (1 << bit)) j |= 1 << (levels - 1 - bit);
    rev[i] = j;
  }
  const R = new Array(N).fill(0).map(() => ({ re: 0, im: 0 }));
  for (let i = 0; i < N; i++) R[rev[i]] = { re: re[i], im: im[i] };
  for (let size = 2; size <= N; size <<= 1) {
    const halfsize = size / 2;
    const tablestep = N / size;
    for (let i = 0; i < N; i += size) {
      for (let j = i, k = 0; j < i + halfsize; j++, k += tablestep) {
        const tpre =  R[j + halfsize].re * Math.cos(-2 * Math.PI * k / N) - R[j + halfsize].im * Math.sin(-2 * Math.PI * k / N);
        const tpim =  R[j + halfsize].re * Math.sin(-2 * Math.PI * k / N) + R[j + halfsize].im * Math.cos(-2 * Math.PI * k / N);
        const pre = R[j].re;
        const pim = R[j].im;
        R[j] = { re: pre + tpre, im: pim + tpim };
        R[j + halfsize] = { re: pre - tpre, im: pim - tpim };
      }
    }
  }
  return { re: R.map(v => v.re), im: R.map(v => v.im) };
}

// ---------- ANSI helpers ----------
const ESC = "\u001b[";
function rgb(r: number, g: number, b: number) {
  return `${ESC}38;2;${r};${g};${b}m`;
}
const reset = `${ESC}0m`;

// ---------- Mandala canvas ----------
class Canvas {
  width: number;
  height: number;
  cells: string[];
  constructor(w: number, h: number) {
    this.width = w;
    this.height = h;
    this.cells = new Array(w * h).fill(" ");
  }
  set(x: number, y: number, char: string) {
    if (x < 0 || y < 0 || x >= this.width || y >= this.height) return;
    this.cells[y * this.width + x] = char;
  }
  clear() {
    this.cells.fill(" ");
  }
  toString() {
    let out = "";
    for (let y = 0; y < this.height; y++) {
      out += this.cells.slice(y * this.width, (y + 1) * this.width).join("") + "\n";
    }
    return out;
  }
}

// ---------- Global state ----------
const args = process.argv.slice(2);
if (args.length === 0) {
  console.error("Usage: ts-node mandala.ts <audio.wav>");
  process.exit(1);
}
const wav = readWav(path.resolve(args[0]));
const fftSize = 1024;
const hop = fftSize / 2;
let cursorX = 0;
let cursorY = 0;

// ---------- Input handling ----------
readline.emitKeypressEvents(process.stdin);
if (process.stdin.isTTY) process.stdin.setRawMode(true);
process.stdin.on("keypress", (_, key) => {
  if (key.name === "c" && key.ctrl) process.exit();
  if (key.name === "up") cursorY = Math.max(-10, cursorY - 1);
  if (key.name === "down") cursorY = Math.min(10, cursorY + 1);
  if (key.name === "left") cursorX = Math.max(-10, cursorX - 1);
  if (key.name === "right") cursorX = Math.min(10, cursorX + 1);
});

// ---------- Main loop ----------
const canvas = new Canvas(80, 24);
let frame = 0;
let pos = 0;

function drawMandala(spectrum: number[]) {
  canvas.clear();
  const radius = 8 + Math.round(spectrum[5] * 4); // low freq mod radius
  const speed = 0.05 + spectrum[30] * 0.1; // mid freq mod speed
  const hueBase = (spectrum[60] * 360) % 360; // high freq hue

  const layers = 5 + Math.round(spectrum[100] * 3);
  for (let l = 1; l <= layers; l++) {
    const r = radius * (l / layers);
    const points = 12 + Math.round(spectrum[l * 2] * 8);
    for (let i = 0; i < points; i++) {
      const angle = ((i / points) * Math.PI * 2) + frame * speed + (cursorX * 0.1);
      const x = Math.round(canvas.width / 2 + r * Math.cos(angle) + cursorX);
      const y = Math.round(canvas.height / 2 + r * Math.sin(angle) + cursorY);
      const hue = (hueBase + l * 30) % 360;
      const col = hsv2rgb(hue, 0.8, 0.9);
      canvas.set(x, y, `${rgb(col.r, col.g, col.b)}*${reset}`);
    }
  }
}

// simple HSV→RGB
function hsv2rgb(h: number, s: number, v: number) {
  const c = v * s;
  const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  const m = v - c;
  let rp = 0, gp = 0, bp = 0;
  if (h < 60) [rp, gp, bp] = [c, x, 0];
  else if (h < 120) [rp, gp, bp] = [x, c, 0];
  else if (h < 180) [rp, gp, bp] = [0, c, x];
  else if (h < 240) [rp, gp, bp] = [0, x, c];
  else if (h < 300) [rp, gp, bp] = [x, 0, c];
  else [rp, gp, bp] = [c, 0, x];
  return {
    r: Math.round((rp + m) * 255),
    g: Math.round((gp + m) * 255),
    b: Math.round((bp + m) * 255),
  };
}

// ---------- Animation ----------
function tick() {
  // grab next chunk
  const chunk = wav.data.subarray(pos, pos + fftSize);
  if (chunk.length < fftSize) pos = 0;
  const win = hannWindow(fftSize);
  const re = new Array(fftSize).fill(0);
  const im = new Array(fftSize).fill(0);
  for (let i = 0; i < fftSize; i++) {
    const sample = i < chunk.length ? chunk[i] : 0;
    re[i] = sample * win[i];
  }
  const { re: fre, im: fim } = fft(re, im);
  const mag = fre.map((v, i) => Math.sqrt(v * v + fim[i] * fim[i]) / fftSize);
  drawMandala(mag);
  process.stdout.write(`${ESC}2J${ESC}0;0H${canvas.toString()}`);
  frame++;
  pos = (pos + hop) % wav.data.length;
}
function hannWindow(N: number) {
  const w = new Array(N);
  for (let n = 0; n < N; n++) w[n] = 0.5 * (1 - Math.cos((2 * Math.PI * n) / (N - 1)));
  return w;
}
setInterval(tick, 60);
process.stdout.write(`${ESC}?25l`); // hide cursor
process.on("exit", () => process.stdout.write(`${ESC}?25h${reset}`));