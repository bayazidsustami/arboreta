/**
 * BARD-CA: A Shakespearean Sonnet to Cellular Automata Compiler
 * 
 * Translates Shakespearean sonnets into generative, self-organizing ASCII ecosystem rules.
 * The rhythm of the iambic pentameter dictates neighbor thresholds, state mutations,
 * and growth parameters of a 2D multi-state cellular automaton.
 */

// Cell States representing stages of the poetic ecosystem
type CellState = 0 | 1 | 2 | 3 | 4 | 5;

const CHARMAP: Record<CellState, string> = {
  0: ' ', // Soil / Empty
  1: '.', // Moss / Spore
  2: 'v', // Sprout
  3: '*', // Flower / Bloom
  4: '#', // Oak / Canopy
  5: '~', // Humus / Decay
};

interface CARule {
  birthMask: number[];
  survivalMask: number[];
  mutationRate: number;
  decayRate: number;
  iambicHarmony: number; // Measure of poetic meter perfection (0.0 - 1.0)
}

class MeterAnalyzer {
  // Syllable vowel heuristic
  private static countSyllables(word: string): number {
    word = word.toLowerCase().replace(/(?:[^laeiouy]|ed|es|e)$/g, '').replace(/^y/, '');
    const matches = word.match(/[aeiouy]{1,2}/g);
    return matches ? matches.length : 1;
  }

  // Estimates stress pattern for a word (0 = unstressed, 1 = stressed)
  private static getStressPattern(word: string): number[] {
    const syl = this.countSyllables(word);
    if (syl === 1) return [1];
    // Alternate starting unstressed (iambic default tendency)
    const pattern: number[] = [];
    for (let i = 0; i < syl; i++) {
      pattern.push(i % 2 === 1 ? 1 : 0);
    }
    return pattern;
  }

  // Parses a sonnet line into binary stress vector
  public static parseLine(line: string): number[] {
    const words = line.replace(/[^a-zA-Z\s]/g, '').split(/\s+/).filter(Boolean);
    const stresses: number[] = [];
    for (const word of words) {
      stresses.push(...this.getStressPattern(word));
    }
    return stresses;
  }
}

class SonnetCompiler {
  /**
   * Compiles 14 lines of a Sonnet into Cellular Automata rules based on:
   * - Iambic Rhythm (0-1 transitions)
   * - Meter regularity (drives survival/birth thresholds)
   * - Rhyme/Quatrain structure
   */
  public static compile(sonnetText: string): CARule {
    const lines = sonnetText.trim().split('\n').map(l => l.trim()).filter(l => l.length > 0);
    
    let totalBeats = 0;
    let iambicMatches = 0;
    const lineStresses: number[][] = [];

    for (const line of lines) {
      const stress = MeterAnalyzer.parseLine(line);
      lineStresses.push(stress);
      
      for (let i = 0; i < stress.length; i++) {
        totalBeats++;
        // Check for ideal iambic rhythm (even indices unstressed 0, odd indices stressed 1)
        if (i % 2 === 1 && stress[i] === 1) iambicMatches++;
        if (i % 2 === 0 && stress[i] === 0) iambicMatches++;
      }
    }

    const iambicHarmony = totalBeats > 0 ? iambicMatches / totalBeats : 0.5;

    // Construct birth & survival masks from stress density per line/quatrain
    const birthMask: number[] = [];
    const survivalMask: number[] = [];

    lines.forEach((line, idx) => {
      const stressCount = lineStresses[idx].reduce((a, b) => a + b, 0);
      const neighborTarget = (stressCount % 8) + 1;
      
      if (idx % 2 === 0) {
        if (!birthMask.includes(neighborTarget)) birthMask.push(neighborTarget);
      } else {
        if (!survivalMask.includes(neighborTarget)) survivalMask.push(neighborTarget);
      }
    });

    // Ensure non-empty fallback rules
    if (birthMask.length === 0) birthMask.push(3);
    if (survivalMask.length === 0) survivalMask.push(2, 3);

    return {
      birthMask,
      survivalMask,
      mutationRate: Math.max(0.01, 1.0 - iambicHarmony),
      decayRate: 0.15 * (1.0 - iambicHarmony * 0.5),
      iambicHarmony,
    };
  }
}

class ASCIIEcosystem {
  private width: number;
  private height: number;
  private grid: CellState[][];
  private rule: CARule;

  constructor(width: number, height: number, rule: CARule) {
    this.width = width;
    this.height = height;
    this.rule = rule;
    this.grid = Array.from({ length: height }, () => Array(width).fill(0));
    this.seedEcosystem();
  }

  private seedEcosystem(): void {
    // Seed initial poetic spores in center based on harmony density
    const cx = Math.floor(this.width / 2);
    const cy = Math.floor(this.height / 2);
    const radius = Math.floor(Math.min(this.width, this.height) / 3);

    for (let y = cy - radius; y <= cy + radius; y++) {
      for (let x = cx - radius; x <= cx + radius; x++) {
        if (x >= 0 && x < this.width && y >= 0 && y < this.height) {
          if (Math.random() < this.rule.iambicHarmony * 0.7) {
            this.grid[y][x] = (Math.floor(Math.random() * 3) + 1) as CellState;
          }
        }
      }
    }
  }

  private countNeighbors(x: number, y: number): number {
    let count = 0;
    for (let dy = -1; dy <= 1; dy++) {
      for (let dx = -1; dx <= 1; dx++) {
        if (dx === 0 && dy === 0) continue;
        const nx = (x + dx + this.width) % this.width;
        const ny = (y + dy + this.height) % this.height;
        if (this.grid[ny][nx] > 0 && this.grid[ny][nx] < 5) {
          count++;
        }
      }
    }
    return count;
  }

  public step(): void {
    const nextGrid: CellState[][] = Array.from({ length: this.height }, () => Array(this.width).fill(0));

    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        const current = this.grid[y][x];
        const neighbors = this.countNeighbors(x, y);

        // State transitions dictated by compiled sonnet rules
        if (current === 0) {
          if (this.rule.birthMask.includes(neighbors)) {
            nextGrid[y][x] = 1; // Spore birth
          }
        } else if (current === 5) {
          // Organic decay returns to fertile soil
          nextGrid[y][x] = Math.random() < 0.3 ? 0 : 5;
        } else {
          if (this.rule.survivalMask.includes(neighbors)) {
            // Growth / Maturity
            if (Math.random() < this.rule.iambicHarmony * 0.4) {
              nextGrid[y][x] = Math.min(4, current + 1) as CellState;
            } else {
              nextGrid[y][x] = current;
            }
          } else {
            // Overcrowding or starvation -> Decay
            if (Math.random() < this.rule.decayRate) {
              nextGrid[y][x] = 5;
            } else {
              nextGrid[y][x] = 0;
            }
          }
        }

        // Spontaneous poetic mutation driven by rhythm irregularity
        if (Math.random() < this.rule.mutationRate * 0.015) {
          nextGrid[y][x] = Math.floor(Math.random() * 6) as CellState;
        }
      }
    }

    this.grid = nextGrid;
  }

  public render(): string {
    const border = '+' + '-'.repeat(this.width) + '+\n';
    const rows = this.grid
      .map(row => '|' + row.map(cell => CHARMAP[cell]).join('') + '|')
      .join('\n');
    return border + rows + border;
  }
}

// Example Execution: Compiling Shakespeare's Sonnet 18 into a living ecosystem
const SONNET_18 = `
Shall I compare thee to a summer's day?
Thou art more lovely and more temperate:
Rough winds do shake the darling buds of May,
And summer's lease hath all too short a date:
Sometime too hot the eye of heaven shines,
And often is his gold complexion dimm'd;
And every fair from fair sometime declines,
By chance or nature's changing course untrimm'd;
But thy eternal summer shall not fade
Nor lose possession of that fair thou owest;
Nor shall Death brag thou wander'st in his shade,
When in eternal lines to time thou growest:
So long as men can breathe or eyes can see,
So long lives this and this gives life to thee.
`;

// Compile Sonnet into CA Transition Rules
const rule = SonnetCompiler.compile(SONNET_18);

console.log("=== BARD-CA SONNET COMPILER ===");
console.log("Compiled Shakespeare's Sonnet 18 into CA Rule Set:");
console.log(`- Birth Neighbor Rules: [${rule.birthMask.join(', ')}]`);
console.log(`- Survival Neighbor Rules: [${rule.survivalMask.join(', ')}]`);
console.log(`- Iambic Harmony Metric: ${(rule.iambicHarmony * 100).toFixed(1)}%`);
console.log(`- Rhythm Mutation Rate: ${(rule.mutationRate * 100).toFixed(1)}%`);
console.log("===============================\n");

// Initialize Ecosystem Grid
const ecosystem = new ASCIIEcosystem(60, 18, rule);

// Run 5 generations of self-organizing growth
for (let gen = 1; gen <= 5; gen++) {
  console.log(`Generation ${gen}:`);
  console.log(ecosystem.render());
  ecosystem.step();
}