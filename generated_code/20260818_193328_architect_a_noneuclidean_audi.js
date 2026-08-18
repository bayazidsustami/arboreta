// Non-Euclidean Audio Synthesizer in WebAudio mapping Cosmic Ray Data to Generative Microtonal Soundscapes
(() => {
  // --- 1. NON-EUCLIDEAN METRIC & SPACETIME ENGINE ---
  // Models hyperbolic space (Poincaré Disk) with negative curvature.
  // Distances exponentially increase toward the boundary, altering spatial pan & delay.
  class HyperbolicSpace {
    constructor(curvature = -1.0) {
      this.k = curvature; // Negative curvature K
    }

    // Poincaré disk distance between origin (0,0) and point (x,y) where r < 1
    distanceFromOrigin(x, y) {
      const r = Math.min(0.99, Math.hypot(x, y));
      return (2 / Math.sqrt(Math.abs(this.k))) * Math.atanh(r);
    }

    // Maps Euclidean (x,y) in unit circle to hyperbolic audio dynamics (Gain & Spatial Pan)
    mapAudioParameters(x, y) {
      const d = this.distanceFromOrigin(x, y);
      const angle = Math.atan2(y, x);
      return {
        gain: 1 / (1 + Math.exp(d * 0.8)), // Exponential decay with distance
        pan: Math.sin(angle) * Math.tanh(d), // Non-linear spatial panning
        delayTime: 0.05 + Math.tanh(d) * 0.4, // Non-Euclidean delay warping
        feedback: Math.min(0.85, 0.2 + d * 0.1)
      };
    }
  }

  // --- 2. MICROTONAL FRACTAL HARMONIC MATRIX ---
  // Generates 53-EDO (Equal Division of the Octave) microtonal scales using L-System fractal generation.
  class MicrotonalFractalScale {
    constructor(baseFreq = 136.1) { // 136.1 Hz (Om Frequency / Cosmic Frequency)
      this.baseFreq = baseFreq;
      this.edo = 53; // High-resolution microtonal tuning
      this.grammar = { 'A': 'AB', 'B': 'A' }; // Fibonacci L-system
      this.axiom = 'A';
    }

    generateFractalSequence(depth) {
      let current = this.axiom;
      for (let i = 0; i < depth; i++) {
        current = current.split('').map(char => this.grammar[char] || char).join('');
      }
      return current;
    }

    // Converts fractal sequence string into 53-EDO frequency array
    getFrequencies(depth = 5) {
      const seq = this.generateFractalSequence(depth);
      let stepCounter = 0;
      return seq.split('').map((char, index) => {
        stepCounter += (char === 'A' ? 9 : 5); // Microtonal intervals (9 = ~203.76 cents, 5 = ~113.2 cents)
        const edoStep = stepCounter % this.edo;
        const octaveShift = Math.floor(index / 8) % 4;
        return this.baseFreq * Math.pow(2, octaveShift + (edoStep / this.edo));
      });
    }
  }

  // --- 3. COSMIC RAY DATA EMULATOR & STREAMER ---
  // Simulates high-energy Muon / Particle detector telemetry (flux, energy (GeV), theta angle).
  class CosmicRayStreamer {
    constructor(onParticleDetected) {
      this.onParticleDetected = onParticleDetected;
      this.active = false;
    }

    start() {
      this.active = true;
      this.scheduleNextDetection();
    }

    stop() {
      this.active = false;
    }

    scheduleNextDetection() {
      if (!this.active) return;
      
      // Cosmic ray flux follows a Poisson distribution with random high-energy bursts
      const interval = Math.random() < 0.1 ? Math.random() * 50 : 100 + Math.random() * 800;
      
      setTimeout(() => {
        if (!this.active) return;
        const particle = {
          energy: Math.pow(Math.random(), -1.7) * 0.5, // Power-law distribution (GeV)
          theta: (Math.random() - 0.5) * Math.PI, // Zenith angle (-π/2 to π/2)
          charge: Math.random() > 0.5 ? 1 : -1,
          velocity: 0.8 + Math.random() * 0.199 // Near speed of light (c)
        };
        this.onParticleDetected(particle);
        this.scheduleNextDetection();
      }, interval);
    }
  }

  // --- 4. WEBAUDIO SYNTHESIS ENGINE & RECURSIVE SOUNDSCAPE ---
  class NonEuclideanSynthesizer {
    constructor() {
      this.audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      this.space = new HyperbolicSpace(-1.2);
      this.fractal = new MicrotonalFractalScale(108); // Base frequency
      this.frequencies = this.fractal.getFrequencies(6);
      this.noteIndex = 0;

      // Master Chain
      this.masterGain = this.audioCtx.createGain();
      this.masterGain.gain.value = 0.3;

      // Non-Euclidean Delay Loop (Feedback Loop with Non-Linear Spatial Panning)
      this.delayNode = this.audioCtx.createDelay();
      this.feedbackNode = this.audioCtx.createGain();
      this.pannerNode = this.audioCtx.createStereoPanner();

      this.delayNode.connect(this.feedbackNode);
      this.feedbackNode.connect(this.pannerNode);
      this.pannerNode.connect(this.delayNode);
      this.pannerNode.connect(this.masterGain);

      this.masterGain.connect(this.audioCtx.destination);

      // Cosmic Ray Connection
      this.cosmicStream = new CosmicRayStreamer(this.handleCosmicRay.bind(this));
    }

    async start() {
      if (this.audioCtx.state === 'suspended') {
        await this.audioCtx.resume();
      }
      this.cosmicStream.start();
      this.renderDrone();
      console.log("Non-Euclidean Cosmic Synthesizer Running...");
    }

    // Continuous ambient drone modulated by hyperbolic geometry
    renderDrone() {
      const osc = this.audioCtx.createOscillator();
      const filter = this.audioCtx.createBiquadFilter();
      const gain = this.audioCtx.createGain();

      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(this.frequencies[0] / 2, this.audioCtx.currentTime);

      filter.type = 'lowpass';
      filter.frequency.setValueAtTime(200, this.audioCtx.currentTime);

      gain.gain.setValueAtTime(0.05, this.audioCtx.currentTime);

      osc.connect(filter);
      filter.connect(gain);
      gain.connect(this.masterGain);
      osc.start();

      // LFO spatialization through Non-Euclidean Space
      let t = 0;
      setInterval(() => {
        t += 0.02;
        const x = Math.sin(t * 0.3) * 0.8;
        const y = Math.cos(t * 0.5) * 0.8;
        const spatial = this.space.mapAudioParameters(x, y);

        filter.frequency.setTargetAtTime(100 + spatial.gain * 800, this.audioCtx.currentTime, 0.1);
        this.delayNode.delayTime.setTargetAtTime(spatial.delayTime, this.audioCtx.currentTime, 0.2);
        this.feedbackNode.gain.setTargetAtTime(spatial.feedback, this.audioCtx.currentTime, 0.2);
        this.pannerNode.pan.setTargetAtTime(spatial.pan, this.audioCtx.currentTime, 0.1);
      }, 50);
    }

    // Trigger microtonal fractal voice when a Cosmic Ray hits
    handleCosmicRay(particle) {
      const now = this.audioCtx.currentTime;

      // Advance fractal sequence based on energy level
      this.noteIndex = (this.noteIndex + Math.floor(particle.energy)) % this.frequencies.length;
      const freq = this.frequencies[this.noteIndex];

      // Map incoming cosmic ray particle trajectory to Poincaré Disk (Unit Circle)
      const x = Math.sin(particle.theta) * (particle.velocity * 0.95);
      const y = Math.cos(particle.theta) * (particle.velocity * 0.95);
      const spatial = this.space.mapAudioParameters(x, y);

      // Voice Architecture
      const osc = this.audioCtx.createOscillator();
      const subOsc = this.audioCtx.createOscillator();
      const filter = this.audioCtx.createBiquadFilter();
      const voiceGain = this.audioCtx.createGain();
      const voicePan = this.audioCtx.createStereoPanner();

      // Timbre selection based on particle energy
      osc.type = particle.energy > 5 ? 'triangle' : 'sine';
      subOsc.type = 'sine';

      osc.frequency.setValueAtTime(freq, now);
      subOsc.frequency.setValueAtTime(freq / 2, now); // Microtonal Sub-harmonic

      // Non-Euclidean spatial attenuation on cutoff frequency and panning
      const cutoff = Math.min(10000, 300 + particle.energy * 500 * spatial.gain);
      filter.type = particle.charge > 0 ? 'bandpass' : 'lowpass';
      filter.frequency.setValueAtTime(cutoff, now);
      filter.Q.setValueAtTime(2 + spatial.gain * 10, now);

      voicePan.pan.setValueAtTime(spatial.pan, now);

      // Recursive Envelope (Dynamic Decay based on Hyperbolic Distance)
      const duration = Math.max(0.1, Math.min(4.0, (1 / particle.energy) * 2));
      voiceGain.gain.setValueAtTime(0.001, now);
      voiceGain.gain.exponentialRampToValueAtTime(Math.min(0.8, 0.1 + spatial.gain), now + 0.02);
      voiceGain.gain.exponentialRampToValueAtTime(0.0001, now + duration);

      // Signal Routing
      osc.connect(filter);
      subOsc.connect(filter);
      filter.connect(voiceGain);
      voiceGain.connect(voicePan);
      voicePan.connect(this.masterGain);
      voicePan.connect(this.delayNode); // Feed into hyperbolic delay matrix

      osc.start(now);
      subOsc.start(now);
      osc.stop(now + duration);
      subOsc.stop(now + duration);
    }
  }

  // --- 5. INITIALIZATION & UI OVERLAY ---
  const synth = new NonEuclideanSynthesizer();

  const button = document.createElement('button');
  button.innerText = 'INITIALIZE COSMIC SYNTHESIZER';
  Object.assign(button.style, {
    position: 'fixed',
    top: '50%',
    left: '50%',
    transform: 'translate(-50%, -50%)',
    padding: '20px 40px',
    fontSize: '18px',
    fontFamily: 'monospace',
    color: '#00FFCC',
    backgroundColor: '#111',
    border: '2px solid #00FFCC',
    borderRadius: '8px',
    cursor: 'pointer',
    boxShadow: '0 0 20px rgba(0, 255, 204, 0.4)',
    zIndex: '10000'
  });

  button.addEventListener('click', () => {
    synth.start();
    button.remove();
  });

  document.body.appendChild(button);
})();