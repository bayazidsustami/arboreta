const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>BMP Visual Score Synthesizer</title>
  <style>
    body {
      background: #111;
      color: #eee;
      font-family: monospace;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      gap: 15px;
    }
    #container {
      position: relative;
      border: 2px solid #333;
      box-shadow: 0 0 20px rgba(0,0,0,0.8);
      background: #000;
    }
    canvas {
      display: block;
      image-rendering: pixelated;
    }
    #playhead {
      position: absolute;
      top: 0;
      left: 0;
      width: 2px;
      height: 100%;
      background: rgba(255, 255, 255, 0.8);
      box-shadow: 0 0 8px #fff;
      pointer-events: none;
    }
    .controls {
      display: flex;
      gap: 10px;
      align-items: center;
    }
    button, input[type="file"] {
      background: #222;
      color: #0f0;
      border: 1px solid #0f0;
      padding: 8px 12px;
      cursor: pointer;
      font-family: inherit;
    }
    button:hover { background: #0f0; color: #000; }
  </style>
</head>
<body>

  <h2>Esoteric BMP Score Interpreter</h2>
  <div id="container">
    <canvas id="canvas"></canvas>
    <div id="playhead"></div>
  </div>

  <div class="controls">
    <button id="playBtn">Start / Stop</button>
    <button id="generateBtn">Generate Random BMP Score</button>
    <input type="file" id="fileInput" accept=".bmp">
  </div>

<script>
// --- Esoteric Interpreter Engine ---
// Pixels represent time (X-axis) and parallel voices (Y-axis).
// Pixel Hue/Saturation maps to synthesis parameters (Waveform, Filter Cutoff, Resonance, Detune).
// Pixel Brightness (Luminance) maps directly to Musical Pitch (Quantized Scale).

const canvas = document.getElementById('canvas');
const ctx = canvas.getContext('2d');
const playhead = document.getElementById('playhead');
const playBtn = document.getElementById('playBtn');
const generateBtn = document.getElementById('generateBtn');
const fileInput = document.getElementById('fileInput');

let audioCtx = null;
let isPlaying = false;
let currentColumn = 0;
let animationFrameId = null;
let lastStepTime = 0;

// Musical scale frequencies (Pentatonic Scale across multiple octaves)
const BASE_FREQ = 65.41; // C2
const SCALE_INTERVALS = [0, 2, 4, 7, 9]; // Major Pentatonic
const scaleFrequencies = [];

for (let octave = 0; octave < 6; octave++) {
  for (let step of SCALE_INTERVALS) {
    scaleFrequencies.push(BASE_FREQ * Math.pow(2, octave + step / 12));
  }
}

// Convert RGB to HSL for esoteric parameter mapping
function rgbToHsl(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  let h, s, l = (max + min) / 2;

  if (max === min) {
    h = s = 0;
  } else {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    switch (max) {
      case r: h = (g - b) / d + (g < b ? 6 : 0); break;
      case g: h = (b - r) / d + 2; break;
      case b: h = (r - g) / d + 4; break;
    }
    h /= 6;
  }
  return { h, s, l };
}

// Generate a procedure-synthesized BMP image directly into the canvas
function generateDefaultBMP() {
  const width = 64;
  const height = 32;
  canvas.width = width;
  canvas.height = height;
  
  // Scale display up
  canvas.style.width = `${width * 12}px`;
  canvas.style.height = `${height * 12}px`;

  const imgData = ctx.createImageData(width, height);
  for (let x = 0; x < width; x++) {
    for (let y = 0; y < height; y++) {
      const idx = (y * width + x) * 4;
      
      // Esoteric procedural score generation logic
      const active = (Math.sin(x * 0.2 + y * 0.1) + Math.cos(x * 0.5 - y * 0.3)) > 0.5;
      if (active && Math.random() > 0.3) {
        const r = Math.floor((x / width) * 255);
        const g = Math.floor((y / height) * 255);
        const b = Math.floor(Math.sin(x * y) * 127 + 128);
        imgData.data[idx] = r;
        imgData.data[idx + 1] = g;
        imgData.data[idx + 2] = b;
        imgData.data[idx + 3] = 255;
      } else {
        // Dark pixels = silence
        imgData.data[idx] = 0;
        imgData.data[idx + 1] = 0;
        imgData.data[idx + 2] = 0;
        imgData.data[idx + 3] = 255;
      }
    }
  }
  ctx.putImageData(imgData, 0, 0);
}

// Parse custom loaded BMP File
fileInput.addEventListener('change', (e) => {
  const file = e.target.files[0];
  if (!file) return;

  const reader = new FileReader();
  reader.onload = function(event) {
    const img = new Image();
    img.onload = function() {
      canvas.width = img.width;
      canvas.height = img.height;
      canvas.style.width = `${Math.max(img.width * 8, 300)}px`;
      canvas.style.height = `${Math.max(img.height * 8, 150)}px`;
      ctx.drawImage(img, 0, 0);
      currentColumn = 0;
    };
    img.src = event.target.result;
  };
  reader.readAsDataURL(file);
});

// Synthesize Audio Column (Iterates Y-axis for current X-time column)
function playColumn(x) {
  if (!audioCtx) return;

  const width = canvas.width;
  const height = canvas.height;
  const imgData = ctx.getImageData(x, 0, 1, height).data;

  const waveforms = ['sine', 'square', 'sawtooth', 'triangle'];

  for (let y = 0; y < height; y++) {
    const idx = y * 4;
    const r = imgData[idx];
    const g = imgData[idx + 1];
    const b = imgData[idx + 2];
    const alpha = imgData[idx + 3];

    if (alpha === 0 || (r === 0 && g === 0 && b === 0)) continue; // Silence pixel

    const { h, s, l } = rgbToHsl(r, g, b);

    // Skip extremely dark pixels
    if (l < 0.05) continue;

    // --- ESOTERIC MAPPING ---
    // 1. Luminance (L) -> Pitch (Quantized Scale index)
    const scaleIndex = Math.floor(l * (scaleFrequencies.length - 1));
    const frequency = scaleFrequencies[scaleIndex];

    // 2. Hue (H) -> Waveform Selection
    const waveIndex = Math.floor(h * waveforms.length) % waveforms.length;
    const waveform = waveforms[waveIndex];

    // 3. Saturation (S) -> Low-pass Filter Cutoff & Resonance
    const filterCutoff = 200 + s * 4000;
    const resonance = s * 15;

    // --- AUDIO NODE GRAPH CONSTRUCTION ---
    const osc = audioCtx.createOscillator();
    const filter = audioCtx.createBiquadFilter();
    const gain = audioCtx.createGain();

    osc.type = waveform;
    osc.frequency.setValueAtTime(frequency, audioCtx.currentTime);

    // Slight micro-detune based on Red channel to create warmth
    osc.detune.setValueAtTime((r - 128) * 0.5, audioCtx.currentTime);

    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(filterCutoff, audioCtx.currentTime);
    filter.Q.setValueAtTime(resonance, audioCtx.currentTime);

    // Envelope based on Brightness
    const noteGain = l * 0.15; // Keep individual voices balanced
    const now = audioCtx.currentTime;
    const duration = 0.18;

    gain.gain.setValueAtTime(0.001, now);
    gain.gain.exponentialRampToValueAtTime(noteGain, now + 0.02); // Attack
    gain.gain.exponentialRampToValueAtTime(0.0001, now + duration); // Release

    // Connect node chain
    osc.connect(filter);
    filter.connect(gain);
    gain.connect(audioCtx.destination);

    // Trigger synth note
    osc.start(now);
    osc.stop(now + duration);
  }
}

// Loop/Playback Controller
function step(timestamp) {
  if (!isPlaying) return;

  // Control Tempo (125ms per pixel step ~ 480 BPM / 16th notes)
  if (!lastStepTime || timestamp - lastStepTime > 125) {
    lastStepTime = timestamp;

    playColumn(currentColumn);

    // Update visual playhead overlay
    const displayWidth = canvas.clientWidth;
    const playheadPos = (currentColumn / canvas.width) * displayWidth;
    playhead.style.transform = `translateX(${playheadPos}px)`;

    // Loop back at end of image width
    currentColumn = (currentColumn + 1) % canvas.width;
  }

  animationFrameId = requestAnimationFrame(step);
}

// Controls Logic
playBtn.addEventListener('click', () => {
  if (!audioCtx) {
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();
  }

  if (audioCtx.state === 'suspended') {
    audioCtx.resume();
  }

  isPlaying = !isPlaying;
  if (isPlaying) {
    playBtn.textContent = 'Pause';
    animationFrameId = requestAnimationFrame(step);
  } else {
    playBtn.textContent = 'Start / Stop';
    cancelAnimationFrame(animationFrameId);
  }
});

generateBtn.addEventListener('click', () => {
  generateDefaultBMP();
  currentColumn = 0;
});

// Initialize default score on load
generateDefaultBMP();

</script>
</body>
</html>`;

document.open();
document.write(html);
document.close();