import { Canvas, CanvasRenderingContext2D, createCanvas } from 'canvas';

/**
 * Markov-Chain Fluid Dynamics Haiku Simulator
 * 
 * Simulated fluid dynamics (Navier-Stokes grid approximation) where particle positions 
 * track high-vorticity stress regions. Particles are valid haiku syllables managed by a 
 * Markov chain, which reassemble into grammatically coherent 5-7-5 haikus along vorticity lines.
 */

// --- Vocabulary & Markov Chain Matrix ---
type SyllableToken = { text: string; syllables: number; tag: 'noun' | 'verb' | 'adj' | 'prep' };

const VOCABULARY: SyllableToken[] = [
  // 1 Syllable
  { text: 'cold', syllables: 1, tag: 'adj' },
  { text: 'wind', syllables: 1, tag: 'noun' },
  { text: 'drifts', syllables: 1, tag: 'verb' },
  { text: 'soft', syllables: 1, tag: 'adj' },
  { text: 'rain', syllables: 1, tag: 'noun' },
  { text: 'falls', syllables: 1, tag: 'verb' },
  { text: 'deep', syllables: 1, tag: 'adj' },
  { text: 'night', syllables: 1, tag: 'noun' },
  { text: 'flows', syllables: 1, tag: 'verb' },
  { text: 'dark', syllables: 1, tag: 'adj' },
  { text: 'stream', syllables: 1, tag: 'noun' },
  { text: 'shines', syllables: 1, tag: 'verb' },
  { text: 'through', syllables: 1, tag: 'prep' },
  { text: 'in', syllables: 1, tag: 'prep' },
  { text: 'on', syllables: 1, tag: 'prep' },
  
  // 2 Syllables
  { text: 'silent', syllables: 2, tag: 'adj' },
  { text: 'shadows', syllables: 2, tag: 'noun' },
  { text: 'whisper', syllables: 2, tag: 'verb' },
  { text: 'autumn', syllables: 2, tag: 'noun' },
  { text: 'river', syllables: 2, tag: 'noun' },
  { text: 'dances', syllables: 2, tag: 'verb' },
  { text: 'frozen', syllables: 2, tag: 'adj' },
  { text: 'moonlight', syllables: 2, tag: 'noun' },
  { text: 'ripples', syllables: 2, tag: 'verb' },
  { text: 'gentle', syllables: 2, tag: 'adj' },

  // 3 Syllables
  { text: 'misty morning', syllables: 3, tag: 'noun' },
  { text: 'disappearing', syllables: 3, tag: 'verb' },
  { text: 'everlasting', syllables: 3, tag: 'adj' },
  { text: 'silent ocean', syllables: 3, tag: 'noun' }
];

// Valid grammatical state transitions (Markov Rules)
const MARKOV_TRANSITIONS: Record<string, string[]> = {
  adj: ['noun', 'adj'],
  noun: ['verb', 'prep', 'adj'],
  verb: ['prep', 'noun', 'adj'],
  prep: ['adj', 'noun']
};

class MarkovHaikuGenerator {
  static getNextToken(current: SyllableToken, maxSyllables: number): SyllableToken {
    const allowedTags = MARKOV_TRANSITIONS[current.tag] || ['noun'];
    const candidates = VOCABULARY.filter(
      v => allowedTags.includes(v.tag) && v.syllables <= maxSyllables
    );
    if (candidates.length === 0) {
      const fallback = VOCABULARY.filter(v => v.syllables <= maxSyllables);
      return fallback[Math.floor(Math.random() * fallback.length)] || VOCABULARY[0];
    }
    return candidates[Math.floor(Math.random() * candidates.length)];
  }

  static generateLine(targetSyllables: number): SyllableToken[] {
    const line: SyllableToken[] = [];
    let currentSyllables = 0;
    let currentToken = VOCABULARY[Math.floor(Math.random() * VOCABULARY.length)];

    while (currentSyllables < targetSyllables) {
      const remaining = targetSyllables - currentSyllables;
      if (currentToken.syllables <= remaining) {
        line.push(currentToken);
        currentSyllables += currentToken.syllables;
      }
      if (currentSyllables < targetSyllables) {
        currentToken = this.getNextToken(currentToken, targetSyllables - currentSyllables);
      }
    }
    return line;
  }

  static generateHaiku(): { text: string; lineIndex: number }[] {
    const lines = [5, 7, 5];
    const tokensWithMeta: { text: string; lineIndex: number }[] = [];

    lines.forEach((syllables, lineIdx) => {
      const lineTokens = this.generateLine(syllables);
      lineTokens.forEach(t => {
        tokensWithMeta.push({ text: t.text, lineIndex: lineIdx });
      });
    });

    return tokensWithMeta;
  }
}

// --- Simplified Grid-Based Fluid Dynamics ---
class FluidGrid {
  width: number;
  height: number;
  vx: Float32Array;
  vy: Float32Array;
  vorticity: Float32Array;

  constructor(width: number, height: number) {
    this.width = width;
    this.height = height;
    this.vx = new Float32Array(width * height);
    this.vy = new Float32Array(width * height);
    this.vorticity = new Float32Array(width * height);
    this.initFlow();
  }

  private idx(x: number, y: number): number {
    return y * this.width + x;
  }

  private initFlow() {
    // Generate swirling vortices
    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        const cx = x - this.width / 2;
        const cy = y - this.height / 2;
        const dist = Math.sqrt(cx * cx + cy * cy) + 0.1;
        const i = this.idx(x, y);
        this.vx[i] = -cy / dist * 2.5 + (Math.random() - 0.5);
        this.vy[i] = cx / dist * 2.5 + (Math.random() - 0.5);
      }
    }
  }

  update() {
    // Compute vorticity: curl(V) = dVy/dx - dVx/dy
    for (let y = 1; y < this.height - 1; y++) {
      for (let x = 1; x < this.width - 1; x++) {
        const dvy_dx = (this.vy[this.idx(x + 1, y)] - this.vy[this.idx(x - 1, y)]) * 0.5;
        const dvx_dy = (this.vx[this.idx(x, y + 1)] - this.vx[this.idx(x, y - 1)]) * 0.5;
        this.vorticity[this.idx(x, y)] = Math.abs(dvy_dx - dvx_dy);
      }
    }
  }

  getVelocity(x: number, y: number): [number, number] {
    const gx = Math.min(Math.max(Math.floor(x), 0), this.width - 1);
    const gy = Math.min(Math.max(Math.floor(y), 0), this.height - 1);
    const i = this.idx(gx, gy);
    return [this.vx[i], this.vy[i]];
  }

  getVorticity(x: number, y: number): number {
    const gx = Math.min(Math.max(Math.floor(x), 0), this.width - 1);
    const gy = Math.min(Math.max(Math.floor(y), 0), this.height - 1);
    return this.vorticity[this.idx(gx, gy)];
  }
}

// --- Fluid Syllable Particle ---
interface TextParticle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  text: string;
  lineIndex: number;
  stress: number;
}

class FluidHaikuSimulator {
  width: number;
  height: number;
  grid: FluidGrid;
  particles: TextParticle[] = [];

  constructor(width: number, height: number) {
    this.width = width;
    this.height = height;
    this.grid = new FluidGrid(Math.floor(width / 10), Math.floor(height / 10));
    this.spawnHaikuParticles();
  }

  spawnHaikuParticles() {
    const haikuTokens = MarkovHaikuGenerator.generateHaiku();
    this.particles = haikuTokens.map((token) => ({
      x: Math.random() * this.width,
      y: Math.random() * this.height,
      vx: 0,
      vy: 0,
      text: token.text,
      lineIndex: token.lineIndex,
      stress: 0
    }));
  }

  step() {
    this.grid.update();

    // High vorticity alignment forces (vorticity stress lines target high y-levels per line)
    const targetYByLine = [
      this.height * 0.25,
      this.height * 0.50,
      this.height * 0.75
    ];

    for (const p of this.particles) {
      const gx = (p.x / this.width) * this.grid.width;
      const gy = (p.y / this.height) * this.grid.height;

      const [flowVx, flowVy] = this.grid.getVelocity(gx, gy);
      p.stress = this.grid.getVorticity(gx, gy);

      // Advection under fluid flow
      p.vx = p.vx * 0.85 + flowVx * 0.15;
      p.vy = p.vy * 0.85 + flowVy * 0.15;

      // High-vorticity stress attraction forces (rearranging along haiku lines)
      const targetY = targetYByLine[p.lineIndex];
      const vorticityPull = p.stress * 0.8;
      p.vy += (targetY - p.y) * 0.005 * (1 + vorticityPull);

      // Update positions
      p.x += p.vx;
      p.y += p.vy;

      // Wrap boundaries
      if (p.x < 0) p.x = this.width;
      if (p.x > this.width) p.x = 0;
      if (p.y < 0) p.y = this.height;
      if (p.y > this.height) p.y = 0;

      // Mutate words along extreme vorticity stress points via Markov transition
      if (p.stress > 0.4 && Math.random() < 0.05) {
        const dummyToken: SyllableToken = { text: p.text, syllables: 1, tag: 'noun' };
        p.text = MarkovHaikuGenerator.getNextToken(dummyToken, 2).text;
      }
    }
  }

  render(ctx: CanvasRenderingContext2D) {
    // Clear canvas with dark fluid aesthetic
    ctx.fillStyle = 'rgba(10, 15, 25, 0.3)';
    ctx.fillRect(0, 0, this.width, this.height);

    // Draw Vorticity lines
    ctx.lineWidth = 1;
    for (let y = 0; y < this.grid.height; y += 2) {
      for (let x = 0; x < this.grid.width; x += 2) {
        const vort = this.grid.vorticity[y * this.grid.width + x];
        if (vort > 0.2) {
          ctx.strokeStyle = `rgba(60, 120, 200, ${vort * 0.3})`;
          ctx.beginPath();
          ctx.arc(x * 10, y * 10, vort * 12, 0, Math.PI * 2);
          ctx.stroke();
        }
      }
    }

    // Render Haiku Text Particles
    ctx.font = 'bold 16px monospace';
    for (const p of this.particles) {
      const alpha = Math.min(1, Math.max(0.3, p.stress * 2));
      
      // Dynamic coloration based on stress line alignment
      if (p.lineIndex === 0) ctx.fillStyle = `rgba(255, 180, 180, ${alpha})`;
      else if (p.lineIndex === 1) ctx.fillStyle = `rgba(180, 255, 210, ${alpha})`;
      else ctx.fillStyle = `rgba(180, 220, 255, ${alpha})`;

      ctx.fillText(p.text, p.x, p.y);
    }
  }
}

// --- Main Simulation Execution Routine ---
function runSimulation() {
  const width = 800;
  const height = 400;
  const canvas = createCanvas(width, height);
  const ctx = canvas.getContext('2d');
  const simulator = new FluidHaikuSimulator(width, height);

  console.log('Initializing Markov-Chain Fluid Dynamics Haiku Simulator...');
  
  let frame = 0;
  const maxFrames = 100;

  const stepSimulation = () => {
    if (frame >= maxFrames) {
      console.log(`Simulation render completed (${maxFrames} frames simulated).`);
      return;
    }

    simulator.step();
    simulator.render(ctx);

    if (frame % 25 === 0) {
      console.log(`--- Snapshot Frame ${frame} ---`);
      const lines: string[][] = [[], [], []];
      simulator.particles.forEach(p => lines[p.lineIndex].push(p.text));
      lines.forEach((lineWords, i) => {
        console.log(`Line ${i + 1} (5-7-5): ${lineWords.join(' ')}`);
      });
    }

    frame++;
    setImmediate(stepSimulation);
  };

  stepSimulation();
}

runSimulation();