/**
 * CPU Cache Miss Ambient Synthesizer
 * 
 * Simulates CPU memory architecture (L1/L2/L3 caches and RAM latency) during an
 * asynchronous array sorting operation, mapping memory access cache misses and hit latencies
 * into real-time FM synthesis, spatialized audio, and evolving harmonic textures.
 */

// Memory Hierarchy Simulation Constants
const CACHE_LINE_SIZE = 16; // 16 elements per cache line
const L1_SIZE = 128;        // L1 cache capacity in lines
const L2_SIZE = 1024;       // L2 cache capacity in lines
const L3_SIZE = 8192;       // L3 cache capacity in lines

// Simulated latencies in milliseconds
const L1_LATENCY_MS = 0.5;
const L2_LATENCY_MS = 2.0;
const L3_LATENCY_MS = 10.0;
const RAM_LATENCY_MS = 50.0;

// Pentatonic scale frequency ratios for harmonic ambient generation
const BASE_FREQ = 110; // A2 pitch base
const SCALE_RATIOS = [1, 9 / 8, 5 / 4, 3 / 2, 5 / 3, 2, 9 / 4, 5 / 2, 3, 10 / 3];

type CacheLevel = 'L1' | 'L2' | 'L3' | 'RAM';

interface MemoryAccessResult {
  index: number;
  level: CacheLevel;
  latencyMs: number;
  isMiss: boolean;
}

/**
 * Multi-Level Cache Memory Simulator
 */
class SimulatedCache {
  private l1 = new Set<number>();
  private l2 = new Set<number>();
  private l3 = new Set<number>();

  public access(index: number): MemoryAccessResult {
    const lineIndex = Math.floor(index / CACHE_LINE_SIZE);

    if (this.l1.has(lineIndex)) {
      return { index, level: 'L1', latencyMs: L1_LATENCY_MS, isMiss: false };
    }

    if (this.l2.has(lineIndex)) {
      this.promoteToL1(lineIndex);
      return { index, level: 'L2', latencyMs: L2_LATENCY_MS, isMiss: true };
    }

    if (this.l3.has(lineIndex)) {
      this.promoteToL2(lineIndex);
      this.promoteToL1(lineIndex);
      return { index, level: 'L3', latencyMs: L3_LATENCY_MS, isMiss: true };
    }

    // Main Memory (RAM) Fetch on L3 Miss
    this.promoteToL3(lineIndex);
    this.promoteToL2(lineIndex);
    this.promoteToL1(lineIndex);
    return { index, level: 'RAM', latencyMs: RAM_LATENCY_MS, isMiss: true };
  }

  private promoteToL1(line: number) {
    if (this.l1.size >= L1_SIZE) {
      const oldest = this.l1.values().next().value;
      if (oldest !== undefined) this.l1.delete(oldest);
    }
    this.l1.add(line);
  }

  private promoteToL2(line: number) {
    if (this.l2.size >= L2_SIZE) {
      const oldest = this.l2.values().next().value;
      if (oldest !== undefined) this.l2.delete(oldest);
    }
    this.l2.add(line);
  }

  private promoteToL3(line: number) {
    if (this.l3.size >= L3_SIZE) {
      const oldest = this.l3.values().next().value;
      if (oldest !== undefined) this.l3.delete(oldest);
    }
    this.l3.add(line);
  }
}

/**
 * Web Audio Ambient Synthesizer Engine
 */
class CacheSynthEngine {
  private ctx: AudioContext;
  private masterGain: GainNode;
  private filter: BiquadFilterNode;

  constructor() {
    const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    this.ctx = new AudioCtx();

    this.masterGain = this.ctx.createGain();
    this.masterGain.gain.setValueAtTime(0.3, this.ctx.currentTime);

    this.filter = this.ctx.createBiquadFilter();
    this.filter.type = 'lowpass';
    this.filter.frequency.setValueAtTime(800, this.ctx.currentTime);

    this.filter.connect(this.masterGain);
    this.masterGain.connect(this.ctx.destination);
  }

  public async resume() {
    if (this.ctx.state === 'suspended') {
      await this.ctx.resume();
    }
  }

  public triggerAccess(result: MemoryAccessResult, arraySize: number) {
    const now = this.ctx.currentTime;

    // Pitch derived from array index mapped to pentatonic scale degrees
    const scaleIndex = Math.floor((result.index / arraySize) * SCALE_RATIOS.length) % SCALE_RATIOS.length;
    const baseFreq = BASE_FREQ * SCALE_RATIOS[scaleIndex];

    // FM Synthesis nodes
    const carrier = this.ctx.createOscillator();
    const modulator = this.ctx.createOscillator();
    const modGain = this.ctx.createGain();
    const noteGain = this.ctx.createGain();
    const panner = this.ctx.createStereoPanner();

    // Latency normalization controls timbre, depth, and reverb tail length
    const normLatency = result.latencyMs / RAM_LATENCY_MS;
    
    // Waveform timbre reflects memory hierarchy depth
    carrier.type = result.level === 'RAM' ? 'sawtooth' : result.level === 'L3' ? 'square' : result.level === 'L2' ? 'triangle' : 'sine';
    modulator.type = 'sine';

    // Frequency modulation depth scales with miss status
    const modRatio = result.isMiss ? 2.01 : 1.5;
    carrier.frequency.setValueAtTime(baseFreq, now);
    modulator.frequency.setValueAtTime(baseFreq * modRatio, now);
    
    const modIndex = normLatency * 500 + 10;
    modGain.gain.setValueAtTime(modIndex, now);
    modGain.gain.exponentialRampToValueAtTime(0.01, now + normLatency + 0.1);

    modulator.connect(modGain);
    modGain.connect(carrier.frequency);

    // Dynamic ENVELOPE shaped by cache hit/miss latency
    const attack = 0.005 + normLatency * 0.05;
    const release = 0.1 + normLatency * 1.5;

    noteGain.gain.setValueAtTime(0.0001, now);
    noteGain.gain.exponentialRampToValueAtTime(0.2, now + attack);
    noteGain.gain.exponentialRampToValueAtTime(0.0001, now + attack + release);

    // Spatial panning based on index position across memory buffer
    const panVal = (result.index / arraySize) * 2 - 1;
    panner.pan.setValueAtTime(Math.max(-1, Math.min(1, panVal)), now);

    // Global filter sweep modulated by cache misses
    const currentFilterFreq = 400 + normLatency * 3600;
    this.filter.frequency.setTargetAtTime(currentFilterFreq, now, 0.1);

    // Route signal graph
    carrier.connect(noteGain);
    noteGain.connect(panner);
    panner.connect(this.filter);

    carrier.start(now);
    modulator.start(now);

    const totalDuration = attack + release;
    carrier.stop(now + totalDuration);
    modulator.stop(now + totalDuration);
  }
}

/**
 * Asynchronous Sorting Algorithm monitored by Cache Latency Engine
 */
class AsynchronousCacheSorter {
  private cache = new SimulatedCache();

  constructor(
    private synth: CacheSynthEngine,
    private delayFactorMs: number = 1.0
  ) {}

  private async trackAccess(array: number[], index: number) {
    const access = this.cache.access(index);
    this.synth.triggerAccess(access, array.length);
    // Pacing execution directly linked to simulated CPU hardware latency
    await new Promise((res) => setTimeout(res, access.latencyMs * 0.1 * this.delayFactorMs));
  }

  public async quickSort(arr: number[], low = 0, high = arr.length - 1): Promise<void> {
    if (low < high) {
      const pivotIdx = await this.partition(arr, low, high);
      await this.quickSort(arr, low, pivotIdx - 1);
      await this.quickSort(arr, pivotIdx + 1, high);
    }
  }

  private async partition(arr: number[], low: number, high: number): Promise<number> {
    const pivotIndex = high;
    await this.trackAccess(arr, pivotIndex);
    const pivot = arr[pivotIndex];

    let i = low - 1;

    for (let j = low; j < high; j++) {
      await this.trackAccess(arr, j);
      if (arr[j] < pivot) {
        i++;
        await this.swap(arr, i, j);
      }
    }

    await this.swap(arr, i + 1, high);
    return i + 1;
  }

  private async swap(arr: number[], i: number, j: number) {
    await this.trackAccess(arr, i);
    await this.trackAccess(arr, j);
    const temp = arr[i];
    arr[i] = arr[j];
    arr[j] = temp;
  }
}

/**
 * Script entry point and initialization
 */
export async function startAmbientSynthesizer() {
  const ARRAY_SIZE = 384;
  const data = Array.from({ length: ARRAY_SIZE }, () => Math.floor(Math.random() * 1000));

  const synth = new CacheSynthEngine();
  await synth.resume();

  const sorter = new AsynchronousCacheSorter(synth, 0.5);

  console.log('Generating memory-driven soundscape...');
  await sorter.quickSort(data);
  console.log('Soundscape process complete.');
}

// Auto-attach user interaction trigger in web runtime environments
if (typeof window !== 'undefined') {
  window.addEventListener('click', () => {
    startAmbientSynthesizer().catch(console.error);
  }, { once: true });
}