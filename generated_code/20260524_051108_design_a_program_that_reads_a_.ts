import { createNoise2D } from 'https://cdn.jsdelivr.net/npm/simplex-noise@3.0.0/simplex-noise.js';

// ---- Setup HTML elements ----
const video = document.createElement('video');
video.autoplay = true;
video.playsInline = true;
video.style.display = 'none';
document.body.appendChild(video);

const canvas = document.createElement('canvas');
canvas.width = 640;
canvas.height = 480;
canvas.style.width = '100%';
canvas.style.height = 'auto';
document.body.appendChild(canvas);
const ctx = canvas.getContext('2d')!;

// ---- Audio context ----
const AudioCtx = window.AudioContext || (window as any).webkitAudioContext;
const audioCtx = new AudioCtx();
const masterGain = audioCtx.createGain();
masterGain.gain.value = 0.3;
masterGain.connect(audioCtx.destination);

// custom tuning: 12 notes (C major) but with non‑equal ratios
const tuning = [1, 16/15, 9/8, 6/5, 5/4, 4/3, 45/32, 3/2, 8/5, 5/3, 9/5, 15/8];
const baseFreq = 220; // A3

// ---- Helper: map hue (0‑360) to a note frequency ----
function hueToFreq(h: number): number {
  const idx = Math.floor((h / 360) * tuning.length) % tuning.length;
  return baseFreq * tuning[idx];
}

// ---- Helper: get dominant hue using simple k‑means (k=3) ----
function dominantHue(imgData: ImageData): number {
  const pixels = imgData.data;
  const samples = 500; // random subset
  const points: [number, number][] = [];
  for (let i = 0; i < samples; i++) {
    const x = Math.floor(Math.random() * imgData.width);
    const y = Math.floor(Math.random() * imgData.height);
    const idx = (y * imgData.width + x) * 4;
    const r = pixels[idx], g = pixels[idx+1], b = pixels[idx+2];
    const max = Math.max(r,g,b), min = Math.min(r,g,b);
    const delta = max - min;
    let h = 0;
    if (delta !== 0) {
      if (max === r) h = ((g - b) / delta) % 6;
      else if (max === g) h = (b - r) / delta + 2;
      else h = (r - g) / delta + 4;
      h = Math.round(h * 60);
      if (h < 0) h += 360;
    }
    points.push([h, 0]); // only hue matters
  }
  // 3‑means clustering on hue (1‑dim)
  const centers = [0, 120, 240];
  for (let iter = 0; iter < 5; iter++) {
    const groups: number[][] = [[], [], []];
    for (const [h] of points) {
      const dists = centers.map(c => Math.abs(c - h));
      const minIdx = dists.indexOf(Math.min(...dists));
      groups[minIdx].push(h);
    }
    for (let i = 0; i < 3; i++) {
      if (groups[i].length) {
        centers[i] = groups[i].reduce((a,b)=>a+b,0)/groups[i].length;
      }
    }
  }
  // pick the largest cluster's center as dominant hue
  const largest = centers.reduce((best, c, i, arr) =>
    (groups[i]?.length ?? 0) > (groups[best]?.length ?? 0) ? i : best, 0);
  return centers[largest];
}

// ---- Edge orientation histogram (0‑180) ----
function edgeOrientationHistogram(imgData: ImageData): Float32Array {
  const w = imgData.width, h = imgData.height;
  const gray = new Uint8ClampedArray(w * h);
  const data = imgData.data;
  // convert to grayscale
  for (let i = 0; i < w * h; i++) {
    const r = data[i*4], g = data[i*4+1], b = data[i*4+2];
    gray[i] = 0.299*r + 0.587*g + 0.114*b;
  }
  const hist = new Float32Array(36); // 5° bins up to 180°
  // Sobel kernels
  const gx = [-1,0,1,-2,0,2,-1,0,1];
  const gy = [-1,-2,-1,0,0,0,1,2,1];
  for (let y = 1; y < h-1; y++) {
    for (let x = 1; x < w-1; x++) {
      let sx = 0, sy = 0;
      for (let ky = -1; ky <= 1; ky++) {
        for (let kx = -1; kx <= 1; kx++) {
          const v = gray[(y+ky)*w + (x+kx)];
          const kIdx = (ky+1)*3 + (kx+1);
          sx += v * gx[kIdx];
          sy += v * gy[kIdx];
        }
      }
      const mag = Math.hypot(sx, sy);
      if (mag > 20) { // ignore weak edges
        let angle = Math.atan2(sy, sx) * 180/Math.PI;
        if (angle < 0) angle += 180;
        const bin = Math.floor(angle / 5) % 36;
        hist[bin] += mag;
      }
    }
  }
  // normalize
  const sum = hist.reduce((a,b)=>a+b,0);
  if (sum) for (let i=0;i<hist.length;i++) hist[i]/=sum;
  return hist;
}

// ---- Generate a note from hue, schedule it ----
let lastNoteTime = 0;
function playNoteFromHue(hue: number) {
  const now = audioCtx.currentTime;
  if (now - lastNoteTime < 0.2) return; // limit rate
  const freq = hueToFreq(hue);
  const osc = audioCtx.createOscillator();
  const gain = audioCtx.createGain();
  osc.type = 'sine';
  osc.frequency.value = freq;
  gain.gain.setValueAtTime(0, now);
  gain.gain.linearRampToValueAtTime(0.5, now+0.01);
  gain.gain.exponentialRampToValueAtTime(0.001, now+0.5);
  osc.connect(gain).connect(masterGain);
  osc.start(now);
  osc.stop(now+0.6);
  lastNoteTime = now;
}

// ---- Mandala drawing driven by audio and edge data ----
const noise = createNoise2D();
function drawMandala(hist: Float32Array, time: number) {
  const cx = canvas.width/2, cy = canvas.height/2;
  const radius = Math.min(cx, cy) * 0.8;
  ctx.clearRect(0,0,canvas.width,canvas.height);
  ctx.save();
  ctx.translate(cx,cy);
  const layers = 6;
  for (let l=0;l<layers;l++) {
    const angleOffset = time*0.1 + l*0.3;
    const points = 12;
    ctx.beginPath();
    for (let i=0;i<=points;i++) {
      const t = i/points;
      const theta = t * Math.PI*2 + angleOffset;
      const idx = Math.floor(t*hist.length) % hist.length;
      const mod = 1 + hist[idx]*2; // edge strength modulates radius
      const r = radius * (l+1)/layers * mod;
      const x = r * Math.cos(theta) + noise(t*3, l*0.5)*5;
      const y = r * Math.sin(theta) + noise(t*3, l*0.5)*5;
      if (i===0) ctx.moveTo(x,y);
      else ctx.lineTo(x,y);
    }
    ctx.closePath();
    const hue = (time*30 + l*60) % 360;
    ctx.fillStyle = `hsla(${hue},70%,50%,0.6)`;
    ctx.fill();
    ctx.strokeStyle = `hsla(${hue},70%,30%,0.8)`;
    ctx.lineWidth = 1;
    ctx.stroke();
  }
  ctx.restore();
}

// ---- Main loop ----
async function start() {
  const stream = await navigator.mediaDevices.getUserMedia({ video: true });
  video.srcObject = stream;
  await new Promise(r => video.onloadedmetadata = r);
  // resume AudioContext on first interaction
  document.body.addEventListener('click',()=>audioCtx.resume(),{once:true});
  function frame(time: number) {
    ctx.drawImage(video,0,0,canvas.width,canvas.height);
    const frameData = ctx.getImageData(0,0,canvas.width,canvas.height);
    const hue = dominantHue(frameData);
    playNoteFromHue(hue);
    const hist = edgeOrientationHistogram(frameData);
    drawMandala(hist, time/1000);
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}
start().catch(console.error);