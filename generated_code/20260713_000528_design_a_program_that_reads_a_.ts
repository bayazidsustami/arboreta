import { Synth, Transport } from "https://cdn.jsdelivr.net/npm/tone@14.8.39/+esm";

// ----- Configuration -----
const VIDEO_WIDTH = 320;
const VIDEO_HEIGHT = 240;
const PALETTE_SIZE = 8;
const LSYSTEM_ITERATIONS = 5;
const NOTE_DURATION = "8n";
const SCALE_FREQS = [261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88, 554.37]; // C major + extra
// -------------------------

// ----- Global objects -----
const video = document.createElement("video");
video.autoplay = true;
video.width = VIDEO_WIDTH;
video.height = VIDEO_HEIGHT;

const canvas = document.createElement("canvas");
canvas.width = VIDEO_WIDTH;
canvas.height = VIDEO_HEIGHT;
const ctx = canvas.getContext("2d")!;

const drawCanvas = document.createElement("canvas");
drawCanvas.width = 800;
drawCanvas.height = 600;
document.body.appendChild(drawCanvas);
const drawCtx = drawCanvas.getContext("2d")!;

const synth = new Synth().toDestination();
Transport.start();
// -------------------------

// ----- Helper functions -----
function getDominantColors(imageData: ImageData, count: number): number[][] {
  const buckets: Map<string, number> = new Map();
  const data = imageData.data;
  for (let i = 0; i < data.length; i += 4) {
    const r = Math.round(data[i] / 32) * 32;
    const g = Math.round(data[i + 1] / 32) * 32;
    const b = Math.round(data[i + 2] / 32) * 32;
    const key = `${r},${g},${b}`;
    buckets.set(key, (buckets.get(key) ?? 0) + 1);
  }
  const sorted = Array.from(buckets.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, count)
    .map(kv => kv[0].split(",").map(Number));
  return sorted;
}

function colorToFreq(color: number[]): number {
  const brightness = (color[0] + color[1] + color[2]) / 3;
  const idx = Math.floor((brightness / 255) * (SCALE_FREQS.length - 1));
  return SCALE_FREQS[idx];
}

// simple interval based tension (0 = unison, larger = more tension)
function intervalTension(a: number, b: number): number {
  const ratio = Math.max(a, b) / Math.min(a, b);
  const cents = 1200 * Math.log2(ratio);
  return Math.abs(cents - Math.round(cents / 100) * 100); // distance from nearest whole semitone
}

// ----- L‑System -----
type RuleSet = Record<string, string>;

let axiom = "F";
let rules: RuleSet = { F: "F[+F]F[-F]F" };
let angle = Math.PI / 7;

function generateLSystem(axiom: string, rules: RuleSet, iter: number): string {
  let cur = axiom;
  for (let i = 0; i < iter; i++) {
    cur = cur.replaceAll(/[A-Za-z\[\]\+\-]/g, ch => rules[ch] ?? ch);
  }
  return cur;
}

function drawLSystem(instructions: string) {
  drawCtx.clearRect(0, 0, drawCanvas.width, drawCanvas.height);
  drawCtx.save();
  drawCtx.translate(drawCanvas.width / 2, drawCanvas.height);
  let stack: [number, number, number] = [] as any;
  let len = 5;
  for (const ch of instructions) {
    switch (ch) {
      case "F":
        drawCtx.beginPath();
        drawCtx.moveTo(0, 0);
        drawCtx.lineTo(0, -len);
        drawCtx.strokeStyle = `hsl(${(Math.random() * 360).toFixed(0)},80%,60%)`;
        drawCtx.stroke();
        drawCtx.translate(0, -len);
        break;
      case "+":
        drawCtx.rotate(angle);
        break;
      case "-":
        drawCtx.rotate(-angle);
        break;
      case "[":
        stack.push([drawCtx.getTransform().a, drawCtx.getTransform().e, drawCtx.getTransform().f] as any);
        break;
      case "]":
        const [a, e, f] = stack.pop()!;
        drawCtx.setTransform(a, 0, 0, a, e, f);
        break;
    }
  }
  drawCtx.restore();
}

// ----- Main loop -----
async function init() {
  const stream = await navigator.mediaDevices.getUserMedia({ video: true });
  video.srcObject = stream;

  function step() {
    ctx.drawImage(video, 0, 0, VIDEO_WIDTH, VIDEO_HEIGHT);
    const img = ctx.getImageData(0, 0, VIDEO_WIDTH, VIDEO_HEIGHT);
    const palette = getDominantColors(img, PALETTE_SIZE);

    // Play notes from palette
    const now = Tone.now();
    palette.forEach((col, i) => {
      const freq = colorToFreq(col);
      synth.triggerAttackRelease(freq, NOTE_DURATION, now + i * 0.1);
    });

    // Compute harmonic tension between successive notes
    let tension = 0;
    for (let i = 0; i < palette.length - 1; i++) {
      tension += intervalTension(colorToFreq(palette[i]), colorToFreq(palette[i + 1]));
    }
    tension /= palette.length - 1;

    // Modify L‑system rule based on tension
    if (tension > 30) {
      rules.F = "F[+F]F[-F]F[+F]F";
    } else {
      rules.F = "F[+F]F[-F]F";
    }

    const lString = generateLSystem(axiom, rules, LSYSTEM_ITERATIONS);
    drawLSystem(lString);
    requestAnimationFrame(step);
  }

  requestAnimationFrame(step);
}

init();