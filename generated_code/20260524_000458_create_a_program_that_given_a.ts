import { createCanvas, Canvas } from 'canvas';
import * as tf from '@tensorflow/tfjs';
import '@tensorflow/tfjs-backend-webgl';

// ---------- CONFIG ----------
const VIDEO_WIDTH = 640;
const VIDEO_HEIGHT = 480;
const L_SYSTEM_ITERATIONS = 5;
const FRAME_INTERVAL = 100; // ms

// ---------- GLOBAL STATE ----------
let videoElem: HTMLVideoElement;
let canvasElem: HTMLCanvasElement;
let ctx: CanvasRenderingContext2D;
let audioCtx: AudioContext;
let oscillator: OscillatorNode;
let gainNode: GainNode;

// ---------- UTILS ----------
function lerp(a: number, b: number, t: number) {
  return a + (b - a) * t;
}

// ---------- EMOTION MODEL ----------
let emotionModel: tf.LayersModel;
async function loadEmotionModel() {
  // Simple placeholder: load a pre‑trained mobilenet‑like model that outputs a single
  // valence score in [0,1]. In practice replace with a proper sentiment CNN.
  emotionModel = await tf.loadLayersModel(
    'https://tfhub.dev/google/tfjs-model/imagenet/mobilenet_v2_140_224/classification/3/default/1',
  );
}

// ---------- EYE‑TRACKING ----------
let gazeX = VIDEO_WIDTH / 2;
function initEyeTracking() {
  // Very coarse gaze estimator: use mouse position as proxy.
  window.addEventListener('mousemove', (e) => {
    const rect = canvasElem.getBoundingClientRect();
    gazeX = e.clientX - rect.left;
  });
}

// ---------- L‑SYSTEM ----------
type Rule = { predecessor: string; successor: string };
class LSystem {
  axiom: string;
  rules: Rule[];
  angle: number;
  length: number;

  constructor(axiom: string, rules: Rule[], angle: number, length: number) {
    this.axiom = axiom;
    this.rules = rules;
    this.angle = angle;
    this.length = length;
  }

  generate(iterations: number, hueMod: number) {
    let current = this.axiom;
    for (let i = 0; i < iterations; i++) {
      let next = '';
      for (const ch of current) {
        const rule = this.rules.find((r) => r.predecessor === ch);
        if (rule) {
          // Modulate successor length with hue
          const mod = lerp(0.5, 1.5, hueMod);
          next += rule.successor.replace(/L/g, `L${mod.toFixed(2)}`);
        } else {
          next += ch;
        }
      }
      current = next;
    }
    return current;
  }
}

// ---------- RENDERER ----------
function renderLSystem(instructions: string, tempo: number) {
  ctx.clearRect(0, 0, VIDEO_WIDTH, VIDEO_HEIGHT);
  ctx.save();
  ctx.translate(VIDEO_WIDTH / 2, VIDEO_HEIGHT);
  ctx.strokeStyle = '#fff';
  ctx.lineWidth = 1;
  let stack: { x: number; y: number; angle: number }[] = [];
  let angle = (Math.PI / 180) * 25;
  let length = 5 * tempo;

  for (const cmd of instructions) {
    if (cmd === 'F' || cmd.startsWith('L')) {
      const len = cmd.startsWith('L') ? parseFloat(cmd.slice(1)) * length : length;
      const nx = ctx.currentX + Math.cos(angle) * len;
      const ny = ctx.currentY + Math.sin(angle) * len;
      ctx.beginPath();
      ctx.moveTo(0, 0);
      ctx.lineTo(len, 0);
      ctx.stroke();
      ctx.translate(len, 0);
    } else if (cmd === '+') {
      angle += this.angle;
    } else if (cmd === '-') {
      angle -= this.angle;
    } else if (cmd === '[') {
      stack.push({ x: ctx.currentX, y: ctx.currentY, angle });
    } else if (cmd === ']') {
      const state = stack.pop();
      if (state) {
        ctx.restore();
        ctx.save();
        ctx.translate(state.x, state.y);
        angle = state.angle;
      }
    }
  }
  ctx.restore();
}

// ---------- AUDIO ----------
function initAudio() {
  audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
  oscillator = audioCtx.createOscillator();
  gainNode = audioCtx.createGain();
  oscillator.type = 'sine';
  oscillator.connect(gainNode).connect(audioCtx.destination);
  oscillator.start();
}

// Update tempo and timbre based on growth rate
function updateAudio(growthRate: number, gazePos: number) {
  const freq = lerp(200, 800, growthRate);
  const pan = lerp(-1, 1, gazePos / VIDEO_WIDTH);
  oscillator.frequency.setValueAtTime(freq, audioCtx.currentTime);
  // simple stereo panning via gain
  gainNode.gain.setValueAtTime(0.5, audioCtx.currentTime);
}

// ---------- MAIN LOOP ----------
async function processFrame() {
  const tmpCanvas = document.createElement('canvas');
  tmpCanvas.width = VIDEO_WIDTH;
  tmpCanvas.height = VIDEO_HEIGHT;
  const tmpCtx = tmpCanvas.getContext('2d')!;
  tmpCtx.drawImage(videoElem, 0, 0, VIDEO_WIDTH, VIDEO_HEIGHT);
  const imgData = tmpCtx.getImageData(0, 0, VIDEO_WIDTH, VIDEO_HEIGHT);

  // Compute average hue
  let sumHue = 0;
  const data = imgData.data;
  for (let i = 0; i < data.length; i += 4) {
    const r = data[i] / 255,
      g = data[i + 1] / 255,
      b = data[i + 2] / 255;
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    const delta = max - min;
    let h = 0;
    if (delta) {
      if (max === r) h = ((g - b) / delta) % 6;
      else if (max === g) h = (b - r) / delta + 2;
      else h = (r - g) / delta + 4;
    }
    h = ((h * 60 + 360) % 360) / 360; // normalize
    sumHue += h;
  }
  const avgHue = sumHue / (VIDEO_WIDTH * VIDEO_HEIGHT);

  // Emotion valence (placeholder random)
  const emotionTensor = tf.browser.fromPixels(imgData).toFloat().div(255).expandDims();
  const preds = emotionModel.predict(emotionTensor) as tf.Tensor;
  const valence = (await preds.mean().data())[0]; // fake valence between 0‑1

  // L‑system parameters
  const lsys = new LSystem('F', [{ predecessor: 'F', successor: 'F[+F]F[-F]F' }], 25, 5);
  const hueMod = avgHue;
  const generated = lsys.generate(L_SYSTEM_ITERATIONS, hueMod);

  // growth rate influences tempo
  const growthRate = valence * hueMod;
  const tempo = lerp(0.5, 2.0, growthRate);

  renderLSystem(generated, tempo);
  updateAudio(growthRate, gazeX);

  setTimeout(processFrame, FRAME_INTERVAL);
}

// ---------- INITIALISATION ----------
async function init() {
  // video
  videoElem = document.createElement('video');
  videoElem.width = VIDEO_WIDTH;
  videoElem.height = VIDEO_HEIGHT;
  videoElem.autoplay = true;
  document.body.appendChild(videoElem);
  const stream = await navigator.mediaDevices.getUserMedia({ video: { width: VIDEO_WIDTH, height: VIDEO_HEIGHT } });
  videoElem.srcObject = stream;

  // canvas
  canvasElem = document.createElement('canvas');
  canvasElem.width = VIDEO_WIDTH;
  canvasElem.height = VIDEO_HEIGHT;
  document.body.appendChild(canvasElem);
  ctx = canvasElem.getContext('2d')!;

  await loadEmotionModel();
  initEyeTracking();
  initAudio();

  processFrame();
}

init();