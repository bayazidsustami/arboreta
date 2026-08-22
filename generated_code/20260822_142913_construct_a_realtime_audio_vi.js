const canvas = document.createElement('canvas');
document.body.appendChild(canvas);
document.body.style.margin = '0';
document.body.style.overflow = 'hidden';
document.body.style.backgroundColor = '#05050a';

const ctx = canvas.getContext('2d');
let w, h, cols, rows;
const cellSize = 8;
let grid, nextGrid;

function resize() {
  w = canvas.width = window.innerWidth;
  h = canvas.height = window.innerHeight;
  cols = Math.floor(w / cellSize);
  rows = Math.floor(h / cellSize);
  grid = new Float32Array(cols * rows);
  nextGrid = new Float32Array(cols * rows);
  for (let i = 0; i < grid.length; i++) {
    grid[i] = Math.random() > 0.85 ? 1.0 : 0.0;
  }
}
window.addEventListener('resize', resize);
resize();

const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
let masterGain, synthOsc, filter;
const baseScale = [261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88, 523.25]; // C Major
let currentDissonance = 0.5;

function initAudio() {
  if (audioCtx.state === 'suspended') audioCtx.resume();
  
  masterGain = audioCtx.createGain();
  masterGain.gain.setValueAtTime(0.15, audioCtx.currentTime);
  
  filter = audioCtx.createBiquadFilter();
  filter.type = 'lowpass';
  filter.frequency.setValueAtTime(800, audioCtx.currentTime);
  
  filter.connect(masterGain);
  masterGain.connect(audioCtx.destination);
  
  setInterval(generativeAudioStep, 400);
}

function getMemoryUsage() {
  if (performance && performance.memory) {
    return performance.memory.usedJSHeapSize / performance.memory.jsHeapSizeLimit;
  }
  return 0.3 + 0.2 * Math.sin(Date.now() * 0.001);
}

function calculateDissonance(freq1, freq2) {
  const ratio = Math.max(freq1, freq2) / Math.min(freq1, freq2);
  const simpleRatios = [1.0, 1.25, 1.333, 1.5, 1.6, 1.875, 2.0];
  let minDiff = 1.0;
  for (let r of simpleRatios) {
    minDiff = Math.min(minDiff, Math.abs(ratio - r));
  }
  return Math.min(1.0, minDiff * 4.0);
}

let lastFreq = 261.63;
function generativeAudioStep() {
  if (!masterGain) return;

  const memUsage = getMemoryUsage();
  const index = Math.floor(memUsage * baseScale.length * 1.5) % baseScale.length;
  const targetFreq = baseScale[index] * (memUsage > 0.6 ? 1.5 : 1.0);
  
  currentDissonance = calculateDissonance(lastFreq, targetFreq);
  lastFreq = targetFreq;

  const osc = audioCtx.createOscillator();
  const noteGain = audioCtx.createGain();
  
  osc.type = currentDissonance > 0.4 ? 'sawtooth' : 'sine';
  osc.frequency.setValueAtTime(targetFreq, audioCtx.currentTime);
  
  filter.frequency.setTargetAtTime(300 + (1 - currentDissonance) * 2000, audioCtx.currentTime, 0.1);
  
  noteGain.gain.setValueAtTime(0.01, audioCtx.currentTime);
  noteGain.gain.exponentialRampToValueAtTime(0.3, audioCtx.currentTime + 0.05);
  noteGain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.35);

  osc.connect(noteGain);
  noteGain.connect(filter);

  osc.start();
  osc.stop(audioCtx.currentTime + 0.4);
}

function updateAutomaton() {
  const survivalMin = 2.0 - currentDissonance * 0.8;
  const survivalMax = 3.5 + currentDissonance * 1.2;

  for (let x = 0; x < cols; x++) {
    for (let y = 0; y < rows; y++) {
      let neighbors = 0;
      for (let dx = -1; dx <= 1; dx++) {
        for (let dy = -1; dy <= 1; dy++) {
          if (dx === 0 && dy === 0) continue;
          const nx = (x + dx + cols) % cols;
          const ny = (y + dy + rows) % rows;
          neighbors += grid[nx + ny * cols] > 0.2 ? 1 : 0;
        }
      }

      const idx = x + y * cols;
      const state = grid[idx];

      if (state > 0.2) {
        if (neighbors >= survivalMin && neighbors <= survivalMax) {
          nextGrid[idx] = Math.min(1.0, state + 0.05);
        } else {
          nextGrid[idx] = Math.max(0.0, state - 0.15);
        }
      } else {
        if (neighbors >= 2.8 && neighbors <= 3.2) {
          nextGrid[idx] = 0.8;
        } else {
          nextGrid[idx] = Math.max(0.0, state - 0.05);
        }
      }
    }
  }

  const temp = grid;
  grid = nextGrid;
  nextGrid = temp;
}

function render() {
  ctx.fillStyle = 'rgba(5, 5, 10, 0.2)';
  ctx.fillRect(0, 0, w, h);

  const hueBase = (currentDissonance * 360) % 360;

  for (let x = 0; x < cols; x++) {
    for (let y = 0; y < rows; y++) {
      const val = grid[x + y * cols];
      if (val > 0.01) {
        const h = (hueBase + val * 60) % 360;
        const l = val * 50;
        ctx.fillStyle = `hsl(${h}, 80%, ${l}%)`;
        ctx.fillRect(x * cellSize, y * cellSize, cellSize - 1, cellSize - 1);
      }
    }
  }

  ctx.fillStyle = 'rgba(255, 255, 255, 0.8)';
  ctx.font = '12px monospace';
  ctx.fillText(`Memory Heap Load: ${(getMemoryUsage() * 100).toFixed(1)}%`, 20, 30);
  ctx.fillText(`Harmonic Dissonance: ${currentDissonance.toFixed(3)}`, 20, 50);
  if (audioCtx.state === 'suspended') {
    ctx.fillText('Click to initialize audio engine', 20, 70);
  }

  updateAutomaton();
  requestAnimationFrame(render);
}

window.addEventListener('click', () => {
  initAudio();
}, { once: true });

render();