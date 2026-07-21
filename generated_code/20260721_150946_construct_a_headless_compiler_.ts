/**
 * Headless Audio-to-SVG Tapestry Compiler
 * Translates audio Fourier Transforms into generative vector tapestries.
 */

interface HarmonicPeak {
  frequency: number;
  magnitude: number;
  phase: number;
}

interface FrameResonance {
  timestamp: number;
  harmonics: HarmonicPeak[];
  spectralCentroid: number;
  energy: number;
}

class FastFourierTransform {
  /**
   * Performs an in-place Cooley-Tukey FFT on complex input arrays.
   */
  public static transform(real: Float64Array, imag: Float64Array): void {
    const n = real.length;
    if (n <= 1) return;

    // Bit-reversal permutation
    for (let i = 0; i < n; i++) {
      let j = 0;
      for (let bit = n >> 1, k = i; bit > 0; bit >>= 1, k >>= 1) {
        if (k & 1) j |= bit;
      }
      if (i < j) {
        const tempR = real[i]; real[i] = real[j]; real[j] = tempR;
        const tempI = imag[i]; imag[i] = imag[j]; imag[j] = tempI;
      }
    }

    // Iterative FFT
    for (let len = 2; len <= n; len <<= 1) {
      const halfLen = len >> 1;
      const angle = (-2 * Math.PI) / len;
      const wStepR = Math.cos(angle);
      const wStepI = Math.sin(angle);

      for (let i = 0; i < n; i += len) {
        let wR = 1;
        let wI = 0;
        for (let j = 0; j < halfLen; j++) {
          const uR = real[i + j];
          const uI = imag[i + j];
          const vR = real[i + j + halfLen] * wR - imag[i + j + halfLen] * wI;
          const vI = real[i + j + halfLen] * wI + imag[i + j + halfLen] * wR;

          real[i + j] = uR + vR;
          imag[i + j] = uI + vI;
          real[i + j + halfLen] = uR - vR;
          imag[i + j + halfLen] = uI - vI;

          const nextWR = wR * wStepR - wI * wStepI;
          const nextWI = wR * wStepI + wI * wStepR;
          wR = nextWR;
          wI = nextWI;
        }
      }
    }
  }
}

class AudioAnalyzer {
  private readonly sampleRate: number;
  private readonly fftSize: number;

  constructor(sampleRate = 44100, fftSize = 1024) {
    this.sampleRate = sampleRate;
    this.fftSize = fftSize;
  }

  /**
   * Analyzes raw audio PCM samples over time using sliding window STFT.
   */
  public analyze(pcmSignal: Float64Array, hopSize = 512): FrameResonance[] {
    const resonances: FrameResonance[] = [];
    const numFrames = Math.floor((pcmSignal.length - this.fftSize) / hopSize);

    for (let frame = 0; frame < numFrames; frame++) {
      const offset = frame * hopSize;
      const real = new Float64Array(this.fftSize);
      const imag = new Float64Array(this.fftSize);

      // Apply Hann windowing
      for (let i = 0; i < this.fftSize; i++) {
        const window = 0.5 * (1 - Math.cos((2 * Math.PI * i) / (this.fftSize - 1)));
        real[i] = pcmSignal[offset + i] * window;
      }

      FastFourierTransform.transform(real, imag);

      const harmonics: HarmonicPeak[] = [];
      let totalMag = 0;
      let weightedFreqSum = 0;

      for (let k = 0; k < this.fftSize / 2; k++) {
        const mag = Math.sqrt(real[k] * real[k] + imag[k] * imag[k]);
        const phase = Math.atan2(imag[k], real[k]);
        const freq = (k * this.sampleRate) / this.fftSize;

        totalMag += mag;
        weightedFreqSum += freq * mag;

        harmonics.push({ frequency: freq, magnitude: mag, phase });
      }

      // Extract top N dominant harmonic peaks
      harmonics.sort((a, b) => b.magnitude - a.magnitude);
      const topHarmonics = harmonics.slice(0, 8);

      resonances.push({
        timestamp: offset / this.sampleRate,
        harmonics: topHarmonics,
        spectralCentroid: totalMag > 0 ? weightedFreqSum / totalMag : 0,
        energy: totalMag / (this.fftSize / 2),
      });
    }

    return resonances;
  }
}

class SVGTapestryCompiler {
  private readonly width: number;
  private readonly height: number;

  constructor(width = 1200, height = 1200) {
    this.width = width;
    this.height = height;
  }

  /**
   * Compiles calculated frame resonances into an intricate SVG Tapestry.
   */
  public compile(frames: FrameResonance[]): string {
    const centerX = this.width / 2;
    const centerY = this.height / 2;
    const svgElements: string[] = [];

    // Background Gradient definitions
    const defs = `
  <defs>
    <radialGradient id="bgGrad" cx="50%" cy="50%" r="75%">
      <stop offset="0%" stop-color="#0a0814" />
      <stop offset="50%" stop-color="#05020a" />
      <stop offset="100%" stop-color="#000002" />
    </radialGradient>
    <filter id="glow">
      <feGaussianBlur stdDeviation="3" result="coloredBlur"/>
      <feMerge>
        <feMergeNode in="coloredBlur"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>`;

    svgElements.push(defs);
    svgElements.push(`<rect width="${this.width}" height="${this.height}" fill="url(#bgGrad)" />`);

    // Render generative motifs from harmonic control points
    frames.forEach((frame, frameIdx) => {
      const t = frameIdx / frames.length;
      const baseRadius = 50 + t * (Math.min(this.width, this.height) / 2 - 80);
      const rotationAngle = (frame.spectralCentroid * 0.05) % (Math.PI * 2);

      const pathSegments: string[] = [];
      const numPoints = frame.harmonics.length;

      for (let i = 0; i < numPoints; i++) {
        const h1 = frame.harmonics[i];
        const h2 = frame.harmonics[(i + 1) % numPoints];

        // Angular positions tied to harmonic frequency and phase
        const angle1 = (i / numPoints) * Math.PI * 2 + rotationAngle + h1.phase * 0.2;
        const angle2 = ((i + 1) / numPoints) * Math.PI * 2 + rotationAngle + h2.phase * 0.2;

        // Radius modulated by harmonic magnitude and spectral energy
        const r1 = baseRadius + Math.log1p(h1.magnitude) * 12;
        const r2 = baseRadius + Math.log1p(h2.magnitude) * 12;

        // Start and End anchor points
        const x1 = centerX + r1 * Math.cos(angle1);
        const y1 = centerY + r1 * Math.sin(angle1);
        const x2 = centerX + r2 * Math.cos(angle2);
        const y2 = centerY + r2 * Math.sin(angle2);

        // Control points bound to harmonic ratios and resonance frequencies
        const harmonicRatio = h1.frequency / (h2.frequency || 1);
        const cpFactor1 = 1.2 + Math.sin(harmonicRatio) * 0.5;
        const cpFactor2 = 0.8 + Math.cos(harmonicRatio) * 0.5;

        const cp1x = centerX + r1 * cpFactor1 * Math.cos(angle1 + h1.phase * 0.1);
        const cp1y = centerY + r1 * cpFactor1 * Math.sin(angle1 + h1.phase * 0.1);
        const cp2x = centerX + r2 * cpFactor2 * Math.cos(angle2 - h2.phase * 0.1);
        const cp2y = centerY + r2 * cpFactor2 * Math.sin(angle2 - h2.phase * 0.1);

        if (i === 0) {
          pathSegments.push(`M ${x1.toFixed(2)},${y1.toFixed(2)}`);
        }
        pathSegments.push(
          `C ${cp1x.toFixed(2)},${cp1y.toFixed(2)} ${cp2x.toFixed(2)},${cp2y.toFixed(2)} ${x2.toFixed(2)},${y2.toFixed(2)}`
        );
      }

      // Dynamic color palette determined by spectral properties
      const hue = (frame.spectralCentroid * 0.3 + t * 180) % 360;
      const saturation = Math.min(100, 50 + frame.energy * 200);
      const strokeWidth = (0.3 + frame.energy * 2.5).toFixed(2);
      const opacity = (0.2 + (1 - t) * 0.7).toFixed(3);

      const pathD = pathSegments.join(' ');
      svgElements.push(
        `<path d="${pathD}" fill="none" stroke="hsl(${hue.toFixed(0)}, ${saturation.toFixed(0)}%, 65%)" stroke-width="${strokeWidth}" stroke-opacity="${opacity}" filter="url(#glow)" />`
      );
    });

    return `<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="0 0 ${this.width} ${this.height}" width="100%" height="100%">\n${svgElements.join('\n')}\n</svg>`;
  }
}

/**
 * Generate synthetic multi-harmonic audio signal for testing/demo pipeline.
 */
function generateHarmonicAudioSignal(durationSec = 3, sampleRate = 44100): Float64Array {
  const totalSamples = durationSec * sampleRate;
  const signal = new Float64Array(totalSamples);

  for (let i = 0; i < totalSamples; i++) {
    const time = i / sampleRate;
    // Harmonic frequencies sweeping over time
    const f0 = 110 + 55 * Math.sin(2 * Math.PI * 0.5 * time); // Fundamental
    const f1 = f0 * 2;
    const f2 = f0 * 3.01;
    const f3 = f0 * 4.98;

    signal[i] =
      0.5 * Math.sin(2 * Math.PI * f0 * time) +
      0.25 * Math.sin(2 * Math.PI * f1 * time + 0.5) +
      0.15 * Math.sin(2 * Math.PI * f2 * time + 1.2) +
      0.1 * Math.sin(2 * Math.PI * f3 * time + 2.1);
  }

  return signal;
}

// Pipeline Execution
const sampleRate = 44100;
const audioSignal = generateHarmonicAudioSignal(2.5, sampleRate);

const analyzer = new AudioAnalyzer(sampleRate, 1024);
const resonances = analyzer.analyze(audioSignal, 512);

const tapestryCompiler = new SVGTapestryCompiler(1200, 1200);
const svgOutput = tapestryCompiler.compile(resonances);

console.log(svgOutput);