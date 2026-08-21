import { JSDOM } from 'jsdom';

/**
 * Interactive Color Palette Generator & Ambient Soundscape Synthesizer
 * 
 * Analyzes DOM structural layout, color distribution, and visual density,
 * mapping these spatial and color properties into real-time Web Audio synthesis.
 */

// --- Types ---

export interface ColorData {
  r: number;
  g: number;
  b: number;
  hex: string;
  hsl: { h: number; s: number; l: number };
  weight: number; // Ratio of visual area occupied (0 to 1)
}

export interface SpatialRegion {
  bounds: { x: number; y: number; width: number; height: number };
  color: ColorData;
  depth: number;
  nodeCount: number;
  density: number;
}

export interface PageVisualData {
  palette: ColorData[];
  regions: SpatialRegion[];
  dominantHue: number; // 0 - 360
  complexity: number;  // 0 - 1
  contrastRatio: number;
}

// --- Analysis Module ---

export class PageAnalyzer {
  /**
   * Extracts visual layout and color distribution data from a target DOM document.
   */
  public analyzeDocument(doc: Document): PageVisualData {
    const viewWidth = doc.documentElement.clientWidth || 1280;
    const viewHeight = doc.documentElement.clientHeight || 800;
    const totalArea = viewWidth * viewHeight;

    const colorFrequency = new Map<string, { color: ColorData; area: number }>();
    const regions: SpatialRegion[] = [];
    let totalNodes = 0;

    const traverse = (node: Node, depth: number) => {
      totalNodes++;
      if (node.nodeType === 1) { // Element Node
        const el = node as HTMLElement;
        const rect = this.getElementBounds(el);
        const area = rect.width * rect.height;

        if (area > 0 && rect.width > 0 && rect.height > 0) {
          const bgColor = this.extractColor(el);
          if (bgColor) {
            const key = `${bgColor.r},${bgColor.g},${bgColor.b}`;
            const existing = colorFrequency.get(key);
            if (existing) {
              existing.area += area;
            } else {
              colorFrequency.set(key, { color: bgColor, area });
            }

            // Capture significant structural regions
            if (area / totalArea > 0.02) {
              regions.push({
                bounds: rect,
                color: bgColor,
                depth,
                nodeCount: el.childElementCount,
                density: el.childElementCount / (area / 10000)
              });
            }
          }
        }

        for (let i = 0; i < el.childNodes.length; i++) {
          traverse(el.childNodes[i], depth + 1);
        }
      }
    };

    traverse(doc.body || doc.documentElement, 0);

    // Calculate palette weights
    const colorEntries = Array.from(colorFrequency.values());
    const sumArea = colorEntries.reduce((acc, curr) => acc + curr.area, 0) || 1;
    
    const palette: ColorData[] = colorEntries
      .map(entry => ({
        ...entry.color,
        weight: entry.area / sumArea
      }))
      .sort((a, b) => b.weight - a.weight)
      .slice(0, 8); // Top 8 colors

    const dominantHue = palette.length > 0 ? palette[0].hsl.h : 200;
    const complexity = Math.min(1, totalNodes / 1000);
    const contrastRatio = this.calculateMaxContrast(palette);

    return {
      palette,
      regions,
      dominantHue,
      complexity,
      contrastRatio
    };
  }

  private extractColor(el: HTMLElement): ColorData | null {
    const style = el.style?.backgroundColor || '';
    if (!style || style === 'transparent' || style === 'inherit') {
      return null;
    }
    
    // Parse RGB/RGBA strings
    const match = style.match(/\d+/g);
    if (!match || match.length < 3) return null;

    const [r, g, b] = match.map(Number);
    const hsl = this.rgbToHsl(r, g, b);
    const hex = `#${((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1)}`;

    return { r, g, b, hex, hsl, weight: 0 };
  }

  private getElementBounds(el: HTMLElement): { x: number; y: number; width: number; height: number } {
    // Fallback parsing for static DOM nodes without active rendering context
    const width = parseFloat(el.style?.width || '0') || 100;
    const height = parseFloat(el.style?.height || '0') || 50;
    const x = parseFloat(el.style?.left || '0') || 0;
    const y = parseFloat(el.style?.top || '0') || 0;
    return { x, y, width, height };
  }

  private rgbToHsl(r: number, g: number, b: number): { h: number; s: number; l: number } {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b);
    let h = 0, s = 0;
    const l = (max + min) / 2;

    if (max !== min) {
      const d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      switch (max) {
        case r: h = (g - b) / d + (g < b ? 6 : 0); break;
        case g: h = (b - r) / d + 2; break;
        case b: h = (r - g) / d + 4; break;
      }
      h /= 6;
    }

    return { h: Math.round(h * 360), s: Math.round(s * 100), l: Math.round(l * 100) };
  }

  private calculateMaxContrast(palette: ColorData[]): number {
    if (palette.length < 2) return 0.5;
    let maxLuminanceDiff = 0;
    for (let i = 0; i < palette.length; i++) {
      for (let j = i + 1; j < palette.length; j++) {
        const diff = Math.abs(palette[i].hsl.l - palette[j].hsl.l);
        if (diff > maxLuminanceDiff) maxLuminanceDiff = diff;
      }
    }
    return maxLuminanceDiff / 100;
  }
}

// --- Generative Soundscape Engine ---

export class AmbientSoundscape {
  private ctx: AudioContext | null = null;
  private masterGain: GainNode | null = null;
  private isPlaying = false;
  private activeNodes: AudioNode[] = [];

  // Musical Scale Map based on Dominant Hue (Pentatonic Modes)
  private scales: Record<string, number[]> = {
    warm: [261.63, 293.66, 329.63, 392.00, 440.00], // C Major Pentatonic (Red/Orange/Yellow)
    cool: [220.00, 261.63, 293.66, 329.63, 392.00], // A Minor Pentatonic (Blue/Cyan/Green)
    mystic: [277.18, 311.13, 369.99, 415.30, 466.16] // F# Major Pentatonic (Purple/Magenta)
  };

  /**
   * Initializes Web Audio Context
   */
  public init(): void {
    const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    this.ctx = new AudioCtx();
    this.masterGain = this.ctx.createGain();
    this.masterGain.gain.setValueAtTime(0.3, this.ctx.currentTime);
    this.masterGain.connect(this.ctx.destination);
  }

  /**
   * Translates visual page data into continuous ambient synthesis parameters.
   */
  public synthesize(data: PageVisualData): void {
    if (!this.ctx || !this.masterGain) this.init();
    if (this.isPlaying) this.stop();

    if (!this.ctx || !this.masterGain) return;
    this.isPlaying = true;

    const scale = this.selectScale(data.dominantHue);

    // 1. Fundamental Drone Drone mapped to Dominant Color & Saturation
    this.createDroneLayer(data.palette[0] || { hsl: { h: data.dominantHue, s: 50, l: 30 } }, scale);

    // 2. Spatial Resonance Layers mapped to structural HTML regions
    data.regions.forEach((region, index) => {
      this.createSpatialTextureLayer(region, scale, index);
    });

    // 3. Generative Granular Arpeggios driven by page layout complexity
    this.startGenerativeArpeggiator(scale, data.complexity, data.contrastRatio);
  }

  private selectScale(hue: number): number[] {
    if (hue >= 330 || hue < 90) return this.scales.warm;
    if (hue >= 90 && hue < 250) return this.scales.cool;
    return this.scales.mystic;
  }

  private createDroneLayer(dominantColor: Partial<ColorData>, scale: number[]): void {
    if (!this.ctx || !this.masterGain) return;

    const baseFreq = scale[0] / 2; // Low Octave
    const osc = this.ctx.createOscillator();
    const filter = this.ctx.createBiquadFilter();
    const gain = this.ctx.createGain();

    // Saturation determines oscillator timbre
    const saturation = dominantColor.hsl?.s ?? 50;
    osc.type = saturation > 60 ? 'sawtooth' : saturation > 30 ? 'triangle' : 'sine';
    osc.frequency.setValueAtTime(baseFreq, this.ctx.currentTime);

    // Lightness controls low-pass filter cutoff frequency
    const lightness = dominantColor.hsl?.l ?? 50;
    const cutoff = 100 + (lightness / 100) * 800;
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(cutoff, this.ctx.currentTime);

    // Modulation LFO for subtle pitch drift
    const lfo = this.ctx.createOscillator();
    const lfoGain = this.ctx.createGain();
    lfo.frequency.setValueAtTime(0.1, this.ctx.currentTime); // Slow sweep
    lfoGain.gain.setValueAtTime(3, this.ctx.currentTime);
    lfo.connect(osc.frequency);
    lfo.start();

    gain.gain.setValueAtTime(0.15, this.ctx.currentTime);

    osc.connect(filter);
    filter.connect(gain);
    gain.connect(this.masterGain);

    osc.start();

    this.activeNodes.push(osc, filter, gain, lfo, lfoGain);
  }

  private createSpatialTextureLayer(region: SpatialRegion, scale: number[], index: number): void {
    if (!this.ctx || !this.masterGain) return;

    const osc = this.ctx.createOscillator();
    const panner = this.ctx.createStereoPanner ? this.ctx.createStereoPanner() : null;
    const gain = this.ctx.createGain();

    // Map region depth and node density to tone pitch
    const pitchIndex = (region.depth + Math.floor(region.density)) % scale.length;
    const freq = scale[pitchIndex];

    osc.type = 'sine';
    osc.frequency.setValueAtTime(freq, this.ctx.currentTime);

    // Map screen x-coordinate to stereo panning (-1.0 to 1.0)
    if (panner) {
      const panVal = Math.max(-1, Math.min(1, (region.bounds.x / 1000) * 2 - 1));
      panner.pan.setValueAtTime(panVal, this.ctx.currentTime);
    }

    // Gain scaled by region area weight
    const volume = Math.min(0.08, (region.bounds.width * region.bounds.height) / (1280 * 800 * 5));
    gain.gain.setValueAtTime(volume, this.ctx.currentTime);

    if (panner) {
      osc.connect(panner);
      panner.connect(gain);
    } else {
      osc.connect(gain);
    }

    gain.connect(this.masterGain);
    osc.start();

    this.activeNodes.push(osc, gain, ...(panner ? [panner] : []));
  }

  private startGenerativeArpeggiator(scale: number[], complexity: number, contrast: number): void {
    if (!this.ctx || !this.masterGain) return;

    // High complexity = faster generative rhythms
    const interval = Math.max(150, 600 - complexity * 400);

    const triggerPulse = () => {
      if (!this.isPlaying || !this.ctx || !this.masterGain) return;

      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      const randomPitch = scale[Math.floor(Math.random() * scale.length)] * (Math.random() > 0.7 ? 2 : 1);
      osc.type = contrast > 0.5 ? 'sine' : 'triangle';
      osc.frequency.setValueAtTime(randomPitch, this.ctx.currentTime);

      // Envelope shaping
      const now = this.ctx.currentTime;
      gain.gain.setValueAtTime(0, now);
      gain.gain.linearRampToValueAtTime(0.05, now + 0.05);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.8);

      osc.connect(gain);
      gain.connect(this.masterGain);

      osc.start(now);
      osc.stop(now + 0.85);

      setTimeout(triggerPulse, interval + (Math.random() * 200 - 100));
    };

    triggerPulse();
  }

  public stop(): void {
    this.isPlaying = false;
    this.activeNodes.forEach(node => {
      if ('stop' in node && typeof (node as AudioScheduledSourceNode).stop === 'function') {
        (node as AudioScheduledSourceNode).stop();
      }
      node.disconnect();
    });
    this.activeNodes = [];
  }
}

// --- Main Interactive Application Controller ---

export class Application {
  private analyzer: PageAnalyzer;
  private soundscape: AmbientSoundscape;

  constructor() {
    this.analyzer = new PageAnalyzer();
    this.soundscape = new AmbientSoundscape();
  }

  /**
   * Executes the analysis and synthesis workflow on a sample or current HTML document.
   */
  public run(doc: Document): { data: PageVisualData; soundscape: AmbientSoundscape } {
    console.log('Analyzing visual structure and dominant palette...');
    const visualData = this.analyzer.analyzeDocument(doc);

    console.log(`Dominant Hue: ${visualData.dominantHue}°`);
    console.log(`Palette Extracted:`, visualData.palette.map(c => c.hex));
    console.log(`Structural Regions Discovered: ${visualData.regions.length}`);

    // Begin generative soundscape synthesis
    this.soundscape.synthesize(visualData);

    return {
      data: visualData,
      soundscape: this.soundscape
    };
  }
}

// --- Execution & Demonstration Setup ---

const sampleHTML = `
  <!DOCTYPE html>
  <html>
    <head><title>Test Layout</title></head>
    <body style="background-color: rgb(15, 23, 42); width: 1280px; height: 800px;">
      <header style="background-color: rgb(30, 41, 59); width: 1280px; height: 80px; top: 0px; left: 0px;">
        <nav style="background-color: rgb(51, 65, 85); width: 400px; height: 40px; top: 20px; left: 800px;"></nav>
      </header>
      <main style="background-color: rgb(15, 23, 42); width: 1280px; height: 600px; top: 80px; left: 0px;">
        <section style="background-color: rgb(225, 29, 72); width: 600px; height: 400px; top: 120px; left: 50px;">
          <div style="background-color: rgb(253, 186, 116); width: 100px; height: 100px;"></div>
        </section>
        <aside style="background-color: rgb(30, 41, 59); width: 400px; height: 400px; top: 120px; left: 700px;"></aside>
      </main>
    </body>
  </html>
`;

// Initialize simulated DOM environment using JSDOM
const dom = new JSDOM(sampleHTML);
const app = new Application();

// Execute complete layout translation and soundscape pipeline
app.run(dom.window.document);