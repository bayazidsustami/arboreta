interface Commit {
  hash: string;
  author: string;
  message: string;
  parents: string[];
  branch: string;
  isConflict?: boolean;
}

type Stitch = 'chain' | 'single_crochet' | 'double_crochet' | 'slip_stitch' | 'increase' | 'decrease' | 'popcorn';

interface PatternRow {
  rowNumber: number;
  branchName: string;
  instruction: string;
  stitches: Stitch[];
  symbolicDiagram: string;
}

/**
 * Maps Git stitch types to standardized crochet abbreviations and ASCII symbols.
 */
const STITCH_MAP: Record<Stitch, abbr: name: string string; symbol: { }> = {
  chain: { name: 'Chain', abbr: 'ch', symbol: 'o' },
  single_crochet: { name: 'Single Crochet', abbr: 'sc', symbol: '+' },
  double_crochet: { name: 'Double Crochet', abbr: 'dc', symbol: 'T' },
  slip_stitch: { name: 'Slip Stitch', abbr: 'sl st', symbol: '•' },
  increase: { name: 'Increase (2 sc in same st)', abbr: 'inc', symbol: 'V' },
  decrease: { name: 'Decrease (sc2tog)', abbr: 'dec', symbol: 'A' },
  popcorn: { name: 'Popcorn Stitch (Conflict!)', abbr: 'pop', symbol: '*' },
};

/**
 * Converts Git Commit Histories into Algorithmic Crochet Patterns.
 */
class GitToCrochetPatternConverter {
  private commits: Map<string, Commit> = new Map();

  constructor(commitHistory: Commit[]) {
    commitHistory.forEach(c => this.commits.set(c.hash, c));
  }

  /**
   * Translates a commit node into a specific sequence of crochet stitches
   * based on its structural properties (parents, messages, branch switches, conflicts).
   */
  private translateCommitToStitches(commit: Commit): Stitch[] {
    const stitches: Stitch[] = [];

    // Base stitch derived from commit hash characteristics
    const hashSum = commit.hash.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
    const baseStitches: Stitch[] = ['single_crochet', 'double_crochet', 'chain'];
    stitches.push(baseStitches[hashSum % baseStitches.length]);

    // Branching structures dictating increases/decreases
    if (commit.parents.length > 1) {
      // Merge commit: Decrease/Join structural elements together
      stitches.push('decrease');
      stitches.push('slip_stitch');
    } else {
      // Linear or root commit
      const children = Array.from(this.commits.values()).filter(c => c.parents.includes(commit.hash));
      if (children.length > 1) {
        // Branch point: Expand row count via Increase
        stitches.push('increase');
        stitches.push('chain');
      }
    }

    // Merge conflicts generate textured "Popcorn" stitches representing tension
    if (commit.isConflict) {
      stitches.push('popcorn');
      stitches.push('chain');
    }

    // Hash length / Message length adds structural padding chains
    const messagePadding = Math.min(commit.message.length % 4, 3);
    for (let i = 0; i < messagePadding; i++) {
      stitches.push('chain');
    }

    return stitches;
  }

  /**
   * Compiles the full pattern sequence into printable instructions and visual ASCII graphs.
   */
  public generatePattern(): PatternRow[] {
    const sortedCommits = Array.from(this.commits.values());
    const patternRows: PatternRow[] = [];

    sortedCommits.forEach((commit, index) => {
      const stitches = this.translateCommitToStitches(commit);
      
      // Summarize stitches for printable row instructions
      const counts: Partial<Record<Stitch, number>> = {};
      stitches.forEach(s => counts[s] = (counts[s] || 0) + 1);

      const instructionParts = Object.entries(counts).map(
        ([stitch, count]) => `${count} ${STITCH_MAP[stitch as Stitch].abbr}`
      );

      const symbolicDiagram = stitches.map(s => STITCH_MAP[s as Stitch].symbol).join(' ');

      patternRows.push({
        rowNumber: index + 1,
        branchName: commit.branch,
        instruction: `Row ${index + 1} [${commit.branch}]: ${instructionParts.join(', ')}`,
        stitches,
        symbolicDiagram: `| ${symbolicDiagram} |`
      });
    });

    return patternRows;
  }

  /**
   * Formats pattern into a printable ASCII document.
   */
  public renderPrintableDocument(): string {
    const rows = this.generatePattern();
    let output = `====================================================\n`;
    output += `       GIT REPOSITORY CROCHET PATTERN               \n`;
    output += `====================================================\n\n`;
    output += `STITCH KEY:\n`;
    Object.entries(STITCH_MAP).forEach(([_, val]) => {
      output += `  ${val.symbol} = ${val.name} (${val.abbr})\n`;
    });
    output += `\n----------------------------------------------------\n`;
    output += `PATTERN INSTRUCTIONS:\n`;
    output += `----------------------------------------------------\n\n`;

    rows.forEach(row => {
      output += `${row.instruction}\n`;
      output += `Chart: ${row.symbolicDiagram}\n\n`;
    });

    output += `====================================================\n`;
    output += `Finish off and weave in loose ends at HEAD commit.  \n`;
    output += `====================================================\n`;

    return output;
  }
}

// Sample Git Commit History with branching and a merge conflict
const mockGitHistory: Commit[] = [
  { hash: 'a1b2c3d', author: 'Dev', message: 'Initial commit', parents: [], branch: 'main' },
  { hash: 'e5f6g7h', author: 'Dev', message: 'Add core features', parents: ['a1b2c3d'], branch: 'main' },
  { hash: 'i8j9k0l', author: 'Dev', message: 'Create feature branch', parents: ['e5f6g7h'], branch: 'feature/crochet' },
  { hash: 'm1n2o3p', author: 'Dev', message: 'Update main concurrently', parents: ['e5f6g7h'], branch: 'main' },
  { hash: 'q4r5s6t', author: 'Dev', message: 'Merge feature into main with conflict', parents: ['m1n2o3p', 'i8j9k0l'], branch: 'main', isConflict: true }
];

// Execute utility
const converter = new GitToCrochetPatternConverter(mockGitHistory);
console.log(converter.renderPrintableDocument());