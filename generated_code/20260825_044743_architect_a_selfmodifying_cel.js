const canvas = document.createElement('canvas');
document.body.appendChild(canvas);
document.body.style.margin = '0';
document.body.style.overflow = 'hidden';
document.body.style.background = '#050508';

const ctx = canvas.getContext('2d');
let width, height, cols, rows;
const cellSize = 8;
let grid = [];
let nextGrid = [];
let rules = []; // Dynamic CA rules derived from spectrum

// Audio Setup (Web Audio API)
let audioCtx, masterGain, filter, oscillatorNodes = [];
let audioStarted = false;

// Simulated Real-Time Astronomical Data Stream (Spectral Lines)
// Represents absorption/emission spectrum wavelengths (nm) & intensities
const baseSpectralLines = [
  { wavelength: 410.2, element: 'H-delta' },
  { wavelength: 434.0, element: 'H-gamma' },
  { wavelength: 486.1, element: 'H-beta' },
  { wavelength: 589.0, element: 'Na-D' },
  { wavelength: 656.3, element: 'H-alpha' },
  { wavelength: 854.2, element: 'Ca-II' }
];

function resize() {
  width = canvas.width = window.innerWidth;
  height = canvas.height = window.innerHeight;
  cols = Math.floor(width / cellSize);
  rows = Math.floor(height / cellSize);
  
  grid = Array(cols).fill(0).map(() => Array(rows).fill(0));
  nextGrid = Array(cols).fill(0).map(() => Array(rows).fill(0));
  seedGrid();
}

function seedGrid() {
  for (let x = 0; x < cols; x++) {
    for (let y = 0; y < rows; y++) {
      grid[x][y] = Math.random() > 0.85 ? 1 : 0;
    }
  }
}

// Generate real-time spectral flux & derive CA self-modification rules
function fetchSpectralData() {
  const time = Date.now() * 0.0005;
  const currentSpectrum = baseSpectralLines.map((line, i) => {
    // Simulate real-time cosmic noise, redshift, and stellar variability
    const flux = Math.sin(time * (i + 1) + line.wavelength) * 0.5 + 0.5;
    return { ...line, flux };
  });

  // Self-modification rule extraction:
  // Average flux dictates survival/birth thresholds of the Cellular Automaton
  const avgFlux = currentSpectrum.reduce((acc, s) => acc + s.flux, 0) / currentSpectrum.length;
  
  // Rule mapping: [birth_min, birth_max, survive_min, survive_max]
  rules = [
    Math.floor(2 + avgFlux * 1.5), 
    3, 
    Math.floor(2 - avgFlux * 0.5), 
    Math.floor(3 + avgFlux * 2)
  ];

  return currentSpectrum;
}

// Self-Modifying Cellular Automaton Logic
function updateAutomaton() {
  const [bMin, bMax, sMin, sMax] = rules;

  for (let x = 0; x < cols; x++) {
    for (let y = 0; y < rows; y++) {
      let neighbors = 0;
      for (let dx = -1; dx <= 1; dx++) {
        for (let dy = -1; dy <= 1; dy++) {
          if (dx === 0 && dy === 0) continue;
          const nx = (x + dx + cols) % cols;
          const ny = (y + dy + rows) % rows;
          neighbors += grid[nx][ny] > 0 ? 1 : 0;
        }
      }

      const currentState = grid[x][x];
      // Mutation: High density causes self-modifying state shift
      if (currentState === 0 && neighbors >= bMin && neighbors <= bMax) {
        nextGrid[x][y] = 1;
      } else if (currentState > 0 && (neighbors < sMin || neighbors > sMax)) {
        nextGrid[x][y] = 0;
      } else if (currentState > 0) {
        // Aging state for sound/visual gradient
        nextGrid[x][y] = Math.min(currentState + 1, 5);
      } else {
        nextGrid[x][y] = 0;
      }
    }
  }

  // Swap grids
  [grid, nextGrid] = [nextGrid, grid];
}

// Initialize Ambient Polyphonic Soundscape Engine
function initAudio() {
  audioCtx = new (window.AudioContext || window.webkitAudioContext)();
  masterGain = audioCtx.createGain();
  masterGain.gain.setValueAtTime(0.15, audioCtx.currentTime);

  filter = audioCtx.createBiquadFilter();
  filter.type = 'lowpass';
  filter.frequency.setValueAtTime(400, audioCtx.currentTime);

  filter.connect(masterGain);
  masterGain.connect(audioCtx.destination);

  // Polyphonic bank mapping spectral lines to pentatonic audio drones
  baseSpectralLines.forEach((line) => {
    const osc = audioCtx.createOscillator();
    const oscGain = audioCtx.createGain();
    
    // Map wavelength to frequency (400nm-800nm -> ~100Hz-800Hz tuned to harmonic series)
    const baseFreq = 110 * Math.pow(2, ((line.wavelength % 200) / 200) * 2);
    
    osc.type = 'sine';
    osc.frequency.setValueAtTime(baseFreq, audioCtx.currentTime);
    oscGain.gain.setValueAtTime(0, audioCtx.currentTime);

    osc.connect(oscGain);
    oscGain.connect(filter);
    osc.start();

    oscillatorNodes.push({ osc, gainNode: oscGain, baseFreq });
  });

  audioStarted = true;
}

// Render CA state visually and translate grid activity into ambient audio
function render(spectrum) {
  // Trail fade effect
  ctx.fillStyle = 'rgba(5, 5, 8, 0.2)';
  ctx.fillRect(0, 0, width, height);

  let totalActiveCells = 0;

  for (let x = 0; x < cols; x++) {
    for (let y = 0; y < rows; y++) {
      const state = grid[x][y];
      if (state > 0) {
        totalActiveCells++;
        
        // Spectral coloring based on cell position and intensity
        const hue = (x / cols) * 260 + (y / rows) * 100;
        const alpha = state / 5;
        
        ctx.fillStyle = `hsla(${hue}, 80%, 60%, ${alpha})`;
        ctx.fillRect(x * cellSize, y * cellSize, cellSize - 1, cellSize - 1);
      }
    }
  }

  // Translate Automaton density & Spectral data into sound Modulation
  if (audioStarted) {
    const activeRatio = totalActiveCells / (cols * rows);
    
    // Dynamic Filter cutoff based on spatial entropy of CA
    filter.frequency.setTargetAtTime(200 + activeRatio * 3000, audioCtx.currentTime, 0.1);

    // Modulate individual oscillators via current spectral flux
    spectrum.forEach((spec, index) => {
      if (oscillatorNodes[index]) {
        const targetGain = spec.flux * 0.15 * (1 + activeRatio * 2);
        oscillatorNodes[index].gainNode.gain.setTargetAtTime(targetGain, audioCtx.currentTime, 0.2);
        
        // Subtle microtonal drift based on spectral wavelength
        const pitchDrift = Math.sin(Date.now() * 0.001 + spec.wavelength) * 2;
        oscillatorNodes[index].osc.frequency.setTargetAtTime(
          oscillatorNodes[index].baseFreq + pitchDrift, 
          audioCtx.currentTime, 
          0.1
        );
      }
    });
  }
}

// Main Execution Loop
function loop() {
  const spectrum = fetchSpectralData();
  updateAutomaton();
  render(spectrum);
  requestAnimationFrame(loop);
}

// User Interaction to unlock Web Audio API & reset seed
window.addEventListener('resize', resize);
window.addEventListener('click', () => {
  if (!audioStarted) {
    initAudio();
  } else {
    seedGrid();
  }
});

// Start
resize();
loop();