// Generative Financial Pipe Organ Concerto
// Uses Web Audio API to translate market dynamics (volatility, crash events, HFT rate) into ambient pipe organ audio.

class MarketPipeOrganConcerto {
  constructor() {
    this.audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    this.isPlaying = false;
    
    // Musical scale: Organ starts in D Dorian (Ambient/Mystical), shifts to D Minor (Haunting) during crashes
    this.basePitch = 146.83; // D3
    this.scales = {
      ambient: [0, 2, 3, 7, 9, 12, 14, 15, 19], // D Dorian / Ambient
      crash: [0, 1, 3, 6, 7, 8, 12, 13, 15]      // D Minor / Locrian (Dramatic/Haunting)
    };
    this.currentScale = this.scales.ambient;

    // Financial State Parameters
    this.marketState = {
      price: 100,
      volatility: 0.05,  // Affects pitch dispersion and dissonance
      hftActivity: 120,  // Beats Per Minute / Arpeggio tempo (60 - 300 BPM)
      isCrash: false
    };

    this.setupAudioNodes();
  }

  setupAudioNodes() {
    // Pipe Organ Acoustics: Reverb & Spatial Wash
    this.masterGain = this.audioCtx.createGain();
    this.masterGain.gain.setValueAtTime(0.3, this.audioCtx.currentTime);

    // Filter modeling pipe chamber reverberation and darkness
    this.filter = this.audioCtx.createBiquadFilter();
    this.filter.type = 'lowpass';
    this.filter.frequency.setValueAtTime(800, this.audioCtx.currentTime);

    // Simple Delay/Reverb Network for Cathedral effect
    this.delay = this.audioCtx.createDelay();
    this.delay.delayTime.setValueAtTime(0.35, this.audioCtx.currentTime);
    this.delayFeedback = this.audioCtx.createGain();
    this.delayFeedback.gain.setValueAtTime(0.6, this.audioCtx.currentTime);

    // Routing
    this.delay.connect(this.delayFeedback);
    this.delayFeedback.connect(this.delay);

    this.masterGain.connect(this.filter);
    this.filter.connect(this.audioCtx.destination);
    this.filter.connect(this.delay);
    this.delay.connect(this.audioCtx.destination);
  }

  // Synthesizes a pipe organ rank (combining additive harmonic pipe ranks: 16', 8', 4', 2')
  playOrganNote(freq, duration, velocity = 0.5) {
    if (!this.isPlaying) return;

    const now = this.audioCtx.currentTime;
    const noteGain = this.audioCtx.createGain();
    noteGain.connect(this.masterGain);

    // Pipe harmonics (Fundamental, Octave, Super-octave, Sub-bass)
    const ranks = [
      { ratio: 0.5, gain: 0.4, type: 'triangle' }, // 16' Sub-bass
      { ratio: 1.0, gain: 0.5, type: 'sawtooth' }, // 8' Principal
      { ratio: 2.0, gain: 0.3, type: 'square' },   // 4' Octave
      { ratio: 3.0, gain: 0.1, type: 'sine' }     // 2 2/3' Mixture rank
    ];

    ranks.forEach(rank => {
      const osc = this.audioCtx.createOscillator();
      const rankGain = this.audioCtx.createGain();
      
      osc.type = rank.type;
      osc.frequency.setValueAtTime(freq * rank.ratio, now);

      // Micro-detune to simulate physical organ pipe imperfections
      const detune = (Math.random() - 0.5) * (this.marketState.volatility * 50);
      osc.detune.setValueAtTime(detune, now);

      rankGain.gain.setValueAtTime(rank.gain * velocity, now);
      osc.connect(rankGain);
      rankGain.connect(noteGain);

      osc.start(now);
      osc.stop(now + duration);
    });

    // Organ pipe attack/release swell dynamics
    noteGain.gain.setValueAtTime(0.001, now);
    noteGain.gain.exponentialRampToValueAtTime(0.4 * velocity, now + 0.08); // Pipe wind attack
    noteGain.gain.exponentialRampToValueAtTime(0.0001, now + duration);
  }

  // Main Generative Loop driven by simulated High-Frequency Trading (HFT) pacing
  startConcerto() {
    if (this.isPlaying) return;
    this.isPlaying = true;
    if (this.audioCtx.state === 'suspended') {
      this.audioCtx.resume();
    }

    let noteIndex = 0;

    const scheduleNextArpeggio = () => {
      if (!this.isPlaying) return;

      // Map market state to music properties
      this.currentScale = this.marketState.isCrash ? this.scales.crash : this.scales.ambient;

      // Select pitch based on arpeggio order and volatility variance
      const scaleDegree = this.currentScale[noteIndex % this.currentScale.length];
      const octaveShift = Math.floor(Math.random() * (1 + Math.floor(this.marketState.volatility * 5)));
      const semitones = scaleDegree + (octaveShift * 12);
      
      const freq = this.basePitch * Math.pow(2, semitones / 12);
      const noteDuration = (60 / this.marketState.hftActivity) * 1.5;

      this.playOrganNote(freq, noteDuration, this.marketState.isCrash ? 0.8 : 0.4);

      // Adjust organ swell / dark tone depending on volatility
      const cutoffFreq = Math.max(300, 2000 - (this.marketState.volatility * 3000));
      this.filter.frequency.setTargetAtTime(cutoffFreq, this.audioCtx.currentTime, 0.1);

      noteIndex++;

      // HFT rate directly determines tempo interval between notes
      const intervalMs = (60 / this.marketState.hftActivity) * 1000;
      setTimeout(scheduleNextArpeggio, intervalMs);
    };

    scheduleNextArpeggio();
    this.startMarketDataSimulation();
  }

  // Simulates real-time stock market dynamics, crashes, and HFT spikes
  startMarketDataSimulation() {
    setInterval(() => {
      const delta = (Math.random() - 0.49) * 2; // Random walk
      this.marketState.price += delta;

      // Volatility calculation (0.01 = stable, 1.0 = chaos)
      this.marketState.volatility = Math.min(1.0, Math.max(0.01, Math.abs(delta) / 2));

      // HFT Algorithm density fluctuates between 80 and 320 BPM
      this.marketState.hftActivity = Math.floor(80 + (this.marketState.volatility * 240));

      // Detect market crash trigger (sharp downward price shock or extreme volatility)
      if (delta < -1.5 || (this.marketState.volatility > 0.7 && Math.random() < 0.3)) {
        this.marketState.isCrash = true;
        console.warn(`[MARKET CRASH DETECTED] Volatility: ${this.marketState.volatility.toFixed(2)}. Shifting to minor/locrian pipe organ key.`);
      } else {
        this.marketState.isCrash = false;
      }
    }, 1000);
  }

  stop() {
    this.isPlaying = false;
  }
}

// Browser User-Interaction Trigger (Web Audio Autoplay policy compliant)
const concerto = new MarketPipeOrganConcerto();
window.addEventListener('click', () => concerto.startConcerto(), { once: true });
console.log("Generative Financial Pipe Organ initialized. Click anywhere on the page to start the audio engine.");