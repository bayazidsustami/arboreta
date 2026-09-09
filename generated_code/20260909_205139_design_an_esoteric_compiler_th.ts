// DendroSynth Compiler: Compiles tree ring visual growth data into Web Audio API synthesis code.

/**
 * Represents a single growth ring in a tree trunk section.
 */
interface TreeRing {
  id: number;
  width: number; // Ring thickness in mm (reflects rainfall/climate)
  density: number; // 0.0 (light latewood) to 1.0 (dense earlywood)
  eccentricity: number; // Deviation from perfect circle (0.0 to 1.0, reflects wind/tilt)
  scarCount: number; // Structural defects (fire/insect damage)
}

/**
 * Historical growth record of a tree.
 */
interface TreeCrossSection {
  species: string;
  age: number;
  rings: TreeRing[];
}

/**
 * Output target specification for generated audio synthesis code.
 */
interface AudioCompilerOptions {
  sampleRate?: number;
  baseFrequency?: number;
}

class DendroCompiler {
  private baseFreq: number;

  constructor(options: AudioCompilerOptions = {}) {
    this.baseFreq = options.baseFrequency ?? 110; // Default A2
  }

  /**
   * Compiles a tree cross-section into executable JavaScript audio code using Web Audio API.
   */
  public compileToWebAudio(tree: TreeCrossSection): string {
    const ringNodes = tree.rings.map((ring, idx) => this.compileRingToNode(ring, idx, tree.rings.length));

    return `
/**
 * Auto-generated Web Audio API synthesizer.
 * Species: ${tree.species} | Rings: ${tree.age}
 */
function playTreeSonification() {
  const AudioCtx = window.AudioContext || window.webkitAudioContext;
  const ctx = new AudioCtx();
  
  // Master Gain
  const masterGain = ctx.createGain();
  masterGain.gain.setValueAtTime(0.3, ctx.currentTime);
  masterGain.connect(ctx.destination);

  const startTime = ctx.currentTime + 0.1;
  const durationPerRing = 1.2;

  ${ringNodes.join("\n\n")}

  console.log("Synthesizing growth history for ${tree.species} (${tree.age} years)...");
}

playTreeSonification();
`.trim();
  }

  /**
   * Translates a single ring's visual metrics into an Web Audio synthesis chain.
   */
  private compileRingToNode(ring: TreeRing, index: number, totalRings: number): string {
    // Pitch calculated from ring sequence (inner rings = higher pitch, outer = lower pitch)
    const ringRatio = (index + 1) / totalRings;
    const freq = (this.baseFreq * (1 + (1 - ringRatio) * 3)).toFixed(2);
    
    // Ring width governs duration and gain modulation depth
    const gainValue = Math.min(1.0, Math.max(0.05, ring.width / 10)).toFixed(2);
    
    // Eccentricity dictates wave shape via periodic wave harmonics
    const waveType = ring.eccentricity > 0.5 ? "sawtooth" : ring.eccentricity > 0.25 ? "triangle" : "sine";

    // Scars map to transient noise bursts (simulated via frequency detune)
    const detune = (ring.scarCount * 120).toFixed(0);

    return `  // --- Ring ${ring.id} (Width: ${ring.width}mm, Density: ${ring.density}) ---
  (() => {
    const ringTime = startTime + (${index} * durationPerRing);
    
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    const filter = ctx.createBiquadFilter();

    osc.type = "${waveType}";
    osc.frequency.setValueAtTime(${freq}, ringTime);
    osc.detune.setValueAtTime(${detune}, ringTime);

    // Density controls lowpass filter cutoff frequency
    filter.type = "lowpass";
    filter.frequency.setValueAtTime(${(200 + ring.density * 3000).toFixed(0)}, ringTime);

    // Envelope mapping ring thickness
    gain.gain.setValueAtTime(0.001, ringTime);
    gain.gain.exponentialRampToValueAtTime(${gainValue}, ringTime + 0.1);
    gain.gain.exponentialRampToValueAtTime(0.001, ringTime + durationPerRing - 0.05);

    osc.connect(filter);
    filter.connect(gain);
    gain.connect(masterGain);

    osc.start(ringTime);
    osc.stop(ringTime + durationPerRing);
  })();`;
  }
}

// --- Demonstration & Execution ---

const ancientPine: TreeCrossSection = {
  species: "Pinus longaeva",
  age: 5,
  rings: [
    { id: 1, width: 2.1, density: 0.8, eccentricity: 0.1, scarCount: 0 }, // Sapling year
    { id: 2, width: 4.5, density: 0.4, eccentricity: 0.2, scarCount: 0 }, // Rainy season
    { id: 3, width: 1.2, density: 0.9, eccentricity: 0.6, scarCount: 1 }, // Drought & high winds
    { id: 4, width: 0.8, density: 0.95, eccentricity: 0.4, scarCount: 2 }, // Forest fire event
    { id: 5, width: 3.0, density: 0.5, eccentricity: 0.15, scarCount: 0 }, // Recovery year
  ]
};

const compiler = new DendroCompiler({ baseFrequency: 130.81 }); // C3 base
const executableAudioCode = compiler.compileToWebAudio(ancientPine);

// Output compiled code
console.log(executableAudioCode);