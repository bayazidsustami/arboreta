// Generative Audio-Visual Kernel Synthesizer
// Simulates OS kernel hex byte stream & CPU cache misses into a self-organizing fractal landscape & soundscape.

(function() {
  // 1. Setup Canvas and Window Styles
  const canvas = document.createElement('canvas');
  document.body.style.margin = '0';
  document.body.style.overflow = 'hidden';
  document.body.style.backgroundColor = '#030308';
  document.body.appendChild(canvas);
  const ctx = canvas.getContext('2d');

  let width = canvas.width = window.innerWidth;
  let height = canvas.height = window.innerHeight;
  window.addEventListener('resize', () => {
    width = canvas.width = window.innerWidth;
    height = canvas.height = window.innerHeight;
  });

  // 2. Simulated Kernel Memory State & Cache Miss Detector
  const MEMORY_SIZE = 256;
  const memory = new Uint8Array(MEMORY_SIZE);
  let ptr = 0;
  let cacheMissBurst = 0;

  function emulateKernelExecution() {
    for (let i = 0; i < 16; i++) {
      let prev = memory[ptr];
      // Bitwise dynamic state shift modeling raw kernel memory page execution
      memory[ptr] = (memory[(ptr + 1) % MEMORY_SIZE] ^ (ptr * 37) ^ (Date.now() & 0xFF)) & 0xFF;
      // Rapid byte value volatility represents a CPU Cache Miss event
      if (Math.abs(memory[ptr] - prev) > 175) {
        cacheMissBurst++;
      }
      ptr = (ptr + 1) % MEMORY_SIZE;
    }
  }

  // 3. Web Audio API Real-Time Synthesizer
  let audioCtx, droneOsc, filter, noiseGain, mainGain, analyser;
  let audioActive = false;

  function initAudio() {
    if (audioActive) return;
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();

    // Harmonic drone oscillator representing current kernel thread
    droneOsc = audioCtx.createOscillator();
    droneOsc.type = 'sawtooth';
    droneOsc.frequency.setValueAtTime(55, audioCtx.currentTime);

    filter = audioCtx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(300, audioCtx.currentTime);

    // Noise buffer generator for CPU Cache Miss bursts ("singing" transients)
    const bufferSize = audioCtx.sampleRate * 2;
    const noiseBuffer = audioCtx.createBuffer(1, bufferSize, audioCtx.sampleRate);
    const output = noiseBuffer.getChannelData(0);
    for (let i = 0; i < bufferSize; i++) {
      output[i] = Math.random() * 2 - 1;
    }

    const noiseSource = audioCtx.createBufferSource();
    noiseSource.buffer = noiseBuffer;
    noiseSource.loop = true;

    noiseGain = audioCtx.createGain();
    noiseGain.gain.setValueAtTime(0, audioCtx.currentTime);

    mainGain = audioCtx.createGain();
    mainGain.gain.setValueAtTime(0.25, audioCtx.currentTime);

    analyser = audioCtx.createAnalyser();
    analyser.fftSize = 64;

    droneOsc.connect(filter);
    noiseSource.connect(noiseGain);
    noiseGain.connect(filter);

    filter.connect(mainGain);
    mainGain.connect(analyser);
    analyser.connect(audioCtx.destination);

    droneOsc.start();
    noiseSource.start();
    audioActive = true;
  }

  window.addEventListener('click', initAudio, { once: true });

  // 4. Sound Modulation via Memory Dynamics
  const fftData = new Uint8Array(32);
  function updateAudio() {
    if (!audioActive) return;

    // Pitch follows memory buffer average byte value
    let avgByte = memory.reduce((a, b) => a + b, 0) / MEMORY_SIZE;
    let targetFreq = 40 + (avgByte % 110);
    droneOsc.frequency.setTargetAtTime(targetFreq, audioCtx.currentTime, 0.05);

    // Filter cutoff modulated by memory entropy
    let entropy = memory[ptr] / 255;
    filter.frequency.setTargetAtTime(150 + entropy * 3000, audioCtx.currentTime, 0.03);

    // Sing cache misses as granular high-frequency noise hits
    if (cacheMissBurst > 0) {
      noiseGain.gain.setValueAtTime(0.2, audioCtx.currentTime);
      noiseGain.gain.exponentialRampToValueAtTime(0.0001, audioCtx.currentTime + 0.12);
      cacheMissBurst = 0;
    }

    analyser.getByteFrequencyData(fftData);
  }

  // 5. Fractal Deformation & Self-Organizing Mesh Render
  let time = 0;

  function calculateFractalHeight(x, y, t, byteVal) {
    let nx = x, ny = y;
    let sum = 0, amp = 1.0, freq = 1.0;

    for (let i = 0; i < 4; i++) {
      let angle = t * 0.15 + (byteVal * 0.01);
      let sinA = Math.sin(angle), cosA = Math.cos(angle);
      let rx = nx * cosA - ny * sinA;
      let ry = nx * sinA + ny * cosA;

      sum += Math.sin(rx * freq + t) * Math.cos(ry * freq + t) * amp;
      freq *= 2.05;
      amp *= 0.48;
      nx = rx + sum * 0.25;
      ny = ry + sum * 0.25;
    }
    return sum;
  }

  function render() {
    emulateKernelExecution();
    updateAudio();

    time += 0.015;

    // Frame feedback persistence
    ctx.fillStyle = 'rgba(3, 3, 8, 0.25)';
    ctx.fillRect(0, 0, width, height);

    const cols = 55;
    const rows = 35;
    const cellW = (width * 1.3) / cols;
    const cellH = (height * 1.1) / rows;
    const audioImpact = fftData.length ? (fftData[0] / 255) : 0.1;

    ctx.save();
    ctx.translate(width / 2, height / 2 + 80);
    ctx.rotate(Math.PI / 5);

    for (let r = 0; r < rows - 1; r++) {
      let byteVal = memory[(r * 5) % MEMORY_SIZE];
      let hue = (byteVal + time * 30) % 360;

      ctx.beginPath();
      ctx.strokeStyle = `hsla(${hue}, 85%, ${45 + audioImpact * 35}%, 0.75)`;
      ctx.lineWidth = 1 + audioImpact * 2;

      for (let c = 0; c < cols; c++) {
        let x = (c - cols / 2) * cellW;
        let y = (r - rows / 2) * cellH;

        // Altitude driven by fractal formula + live hex byte modulation
        let z = calculateFractalHeight(x * 0.003, y * 0.003, time, byteVal) * 110;
        z += (memory[(c + r) % MEMORY_SIZE] / 255) * 35 * (1 + audioImpact * 2);

        let projX = x - y * 0.45;
        let projY = (y * 0.45) - z;

        if (c === 0) ctx.moveTo(projX, projY);
        else ctx.lineTo(projX, projY);
      }
      ctx.stroke();
    }

    ctx.restore();

    // System Telemetry HUD
    ctx.fillStyle = 'rgba(0, 255, 170, 0.8)';
    ctx.font = '12px monospace';
    ctx.fillText('KERNEL_STREAM: 0x' + Array.from(memory.slice(0, 8))
      .map(b => b.toString(16).padStart(2, '0')).join(''), 20, 35);
    ctx.fillText(`CACHE_MISS_TRANSIENT: ${audioActive ? 'SINGING' : 'MUTED'}`, 20, 55);

    if (!audioActive) {
      ctx.fillStyle = 'rgba(255, 255, 255, 0.85)';
      ctx.font = '13px monospace';
      ctx.fillText('[ CLICK ANYWHERE TO INITIALIZE AUDIO SYNTHESIZER ]', width / 2 - 190, height - 35);
    }

    requestAnimationFrame(render);
  }

  render();
})();