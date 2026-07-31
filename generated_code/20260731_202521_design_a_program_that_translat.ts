import * as os from 'os';
import * as fs from 'fs';

/**
 * Thermal Resonance Engine
 * Translates CPU temperature & clock speed drops into real-time polyphonic audio.
 * High CPU temp = Microtonal dissonance, harsh ring-modulated waveforms, chaotic rhythm.
 * Cool CPU = Just-intonated acoustic resonance, pure harmonic sine waves, stable cadence.
 *
 * Usage: npx ts-node thermal_synth.ts | aplay -f cd (Linux) OR ffplay -f s16le -ar 44100 -ac 2 -
 */

const SAMPLE_RATE = 44100;
const CHANNELS = 2;
const BUFFER_SIZE = 1024;
const TWO_PI = Math.PI * 2;

// Musical scale degrees (Hz) centered around A3 (220Hz) - Just Intonation harmonic resonance
const HARMONIC_BASE_FREQS = [110, 165, 220, 275, 330, 440, 550, 660, 880];

interface CpuStatus {
  tempCelsius: number;       // Current thermal state
  avgClockMhz: number;       // Average clock speed
  maxClockMhz: number;       // Expected max clock speed
  throttleRatio: number;     // 0 = no throttle, 1 = severe throttling
}

interface Voice {
  phase: number;
  targetFreq: number;
  currentFreq: number;
  amplitude: number;
  harmonics: number[];
  detuneCents: number;
}

class ThermalAudioSynthesizer {
  private voices: Voice[] = [];
  private sampleCount = 0;
  private currentStatus: CpuStatus = { tempCelsius: 45, avgClockMhz: 3000, maxClockMhz: 3000, throttleRatio: 0 };

  constructor(numVoices: number = 6) {
    for (let i = 0; i < numVoices; i++) {
      this.voices.push({
        phase: 0,
        targetFreq: HARMONIC_BASE_FREQS[i % HARMONIC_BASE_FREQS.length],
        currentFreq: HARMONIC_BASE_FREQS[i % HARMONIC_BASE_FREQS.length],
        amplitude: 0.15,
        harmonics: [1, 0.5, 0.25],
        detuneCents: 0,
      });
    }
  }

  /** Reads actual thermal zones or estimates from system state */
  public pollCpuState(): CpuStatus {
    let temp = 45; // Default fallback baseline
    try {
      // Try reading Linux thermal zone if available
      const zonePath = '/sys/class/thermal/thermal_zone0/temp';
      if (fs.existsSync(zonePath)) {
        const raw = fs.readFileSync(zonePath, 'utf8');
        temp = parseFloat(raw) / 1000.0;
      } else {
        // Fallback: estimate heat based on load average
        const load = os.loadavg()[0];
        const cpus = os.cpus().length || 1;
        temp = 40 + Math.min(50, (load / cpus) * 35);
      }
    } catch {
      temp = 45;
    }

    const cpus = os.cpus();
    let totalSpeed = 0;
    let maxSpeed = 100;
    if (cpus && cpus.length > 0) {
      totalSpeed = cpus.reduce((acc, cpu) => acc + cpu.speed, 0);
      maxSpeed = Math.max(...cpus.map(c => c.speed));
    }
    const avgSpeed = cpus.length > 0 ? totalSpeed / cpus.length : 2500;
    
    // Throttle ratio: dropped speed below max performance potential
    const throttleRatio = Math.max(0, Math.min(1, (maxSpeed - avgSpeed) / (maxSpeed || 1)));

    this.currentStatus = {
      tempCelsius: temp,
      avgClockMhz: avgSpeed,
      maxClockMhz: maxSpeed,
      throttleRatio: throttleRatio
    };

    return this.currentStatus;
  }

  /** Maps thermal metrics to acoustic parameters */
  public updateSynthesisParameters() {
    const { tempCelsius, throttleRatio } = this.currentStatus;

    // Heat factor: 0 at <= 40°C, 1 at >= 85°C
    const heatFactor = Math.max(0, Math.min(1, (tempCelsius - 40) / 45));
    // Combined dissonance index (0 = pure harmony, 1 = chaotic microtonality)
    const dissonanceIndex = Math.min(1, heatFactor * 0.7 + throttleRatio * 0.3);

    this.voices.forEach((voice, idx) => {
      const baseFreq = HARMONIC_BASE_FREQS[idx % HARMONIC_BASE_FREQS.length];

      // Microtonal pitch bend: as temp rises, pitches shift by arbitrary non-tempered cents
      const microtonalShiftCents = (Math.sin(this.sampleCount * 0.0001 + idx) * 150 + (Math.random() - 0.5) * 80) * dissonanceIndex;
      voice.detuneCents = microtonalShiftCents;

      // Frequency calculation with microtonal detuning
      voice.targetFreq = baseFreq * Math.pow(2, microtonalShiftCents / 1200);

      // Interpolate pitch smoothly
      voice.currentFreq += (voice.targetFreq - voice.currentFreq) * 0.05;

      // Dynamic harmonic overtone richness: pure sine waves when cool, harsh overtones when hot
      voice.harmonics = [
        1.0,                                      // Fundamental
        0.5 * dissonanceIndex,                    // 2nd harmonic
        0.8 * Math.pow(dissonanceIndex, 2),        // Harsh 3rd harmonic
        1.2 * Math.pow(dissonanceIndex, 1.5)       // High microtonal ring-mod frequency
      ];
    });
  }

  /** Synthesizes 16-bit PCM stereo audio samples into stdout buffer */
  public generateAudioChunk(): Buffer {
    const buffer = Buffer.alloc(BUFFER_SIZE * CHANNELS * 2); // 16-bit stereo = 4 bytes/sample
    const { tempCelsius } = this.currentStatus;
    const heatFactor = Math.max(0, Math.min(1, (tempCelsius - 40) / 45));

    for (let i = 0; i < BUFFER_SIZE; i++) {
      this.sampleCount++;
      let leftSample = 0;
      let rightSample = 0;

      // Microtonal FM/Ring modulation chaos proportional to CPU thermal load
      const chaosModulator = Math.sin(this.sampleCount * 0.005 * (1 + heatFactor * 5)) * heatFactor * 40;

      this.voices.forEach((voice, vIdx) => {
        const effectiveFreq = voice.currentFreq + (vIdx % 2 === 0 ? chaosModulator : -chaosModulator);
        const phaseIncrement = (TWO_PI * effectiveFreq) / SAMPLE_RATE;
        voice.phase = (voice.phase + phaseIncrement) % TWO_PI;

        // Waveform synthesis blending sine -> triangle -> distorted saw based on heat
        let wave = 0;
        voice.harmonics.forEach((hAmp, hIdx) => {
          const harmonicPhase = (voice.phase * (hIdx + 1)) % TWO_PI;
          wave += Math.sin(harmonicPhase) * hAmp;
        });

        // Apply acoustic warm saturation filter when cooling down
        if (heatFactor < 0.3) {
          wave = Math.tanh(wave * 1.2); // Warm analog resonance clipping
        }

        // Stereo panning across polyphonic voice positions
        const pan = (vIdx / (this.voices.length - 1)) * 0.8 + 0.1;
        leftSample += wave * voice.amplitude * (1 - pan);
        rightSample += wave * voice.amplitude * pan;
      });

      // Master normalization and 16-bit PCM clamping
      const masterVolume = 0.25;
      const pcmLeft = Math.max(-32768, Math.min(32767, Math.floor(leftSample * masterVolume * 32767)));
      const pcmRight = Math.max(-32768, Math.min(32767, Math.floor(rightSample * masterVolume * 32767)));

      buffer.writeInt16LE(pcmLeft, i * 4);
      buffer.writeInt16LE(pcmRight, i * 4 + 2);
    }

    return buffer;
  }
}

// Interactive execution cycle
function startThermalConcert() {
  const synth = new ThermalAudioSynthesizer(6);

  // Poll CPU stats every 250ms
  setInterval(() => {
    const stats = synth.pollCpuState();
    synth.updateSynthesisParameters();
    
    // Log real-time telemetry to stderr so stdout remains clean PCM audio
    const bar = '█'.repeat(Math.round(stats.tempCelsius / 3)) + '░'.repeat(30 - Math.round(stats.tempCelsius / 3));
    process.stderr.write(
      `\r[Thermal Score] Temp: ${stats.tempCelsius.toFixed(1)}°C |${bar}| Clock: ${stats.avgClockMhz.toFixed(0)}MHz (Throttle: ${(stats.throttleRatio * 100).toFixed(0)}%)`
    );
  }, 250);

  // Continuous PCM Audio output stream
  function streamAudio() {
    const chunk = synth.generateAudioChunk();
    const canWrite = process.stdout.write(chunk);
    if (canWrite) {
      setImmediate(streamAudio);
    } else {
      process.stdout.once('drain', streamAudio);
    }
  }

  streamAudio();
}

startThermalConcert();