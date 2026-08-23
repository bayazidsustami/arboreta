import { EventEmitter } from 'events';

// ============================================================================
// Types & Domain Models
// ============================================================================

export interface CommitData {
  hash: string;
  author: string;
  timestamp: number;
  filesChanged: number;
  linesAdded: number;
  linesDeleted: number;
}

export interface HeatSource {
  contributor: string;
  intensity: number; // Computed from churn and frequency
  decayRate: number;
}

export interface GridCell {
  temperature: number;
  viscosity: number; // High temperature = low viscosity (glass melts)
  vx: number;        // Fluid velocity X
  vy: number;        // Fluid velocity Y
  density: number;   // Glass mass density
}

// ============================================================================
// Git History Parser
// ============================================================================

export class GitHistoryParser {
  private rawLogs: string;

  constructor(rawLogs: string) {
    this.rawLogs = rawLogs;
  }

  /**
   * Parses structural commit logs into structured CommitData.
   * Expected format per line: hash|author|timestamp|filesChanged|linesAdded|linesDeleted
   */
  public parse(): CommitData[] {
    return this.rawLogs
      .trim()
      .split('\n')
      .filter((line) => line.length > 0)
      .map((line) => {
        const [hash, author, timestampStr, filesStr, addedStr, deletedStr] = line.split('|');
        const filesChanged = parseInt(filesStr || '1', 10);
        const linesAdded = parseInt(addedStr || '0', 10);
        const linesDeleted = parseInt(deletedStr || '0', 10);
        
        return {
          hash: hash || '0000000',
          author: author || 'Unknown',
          timestamp: parseInt(timestampStr, 10) || Date.now(),
          filesChanged,
          linesAdded,
          linesDeleted,
        };
      });
  }
}

// ============================================================================
// Fluid Dynamics & Glass Melting Simulation
// ============================================================================

export class GlassSculptureFluidSimulation extends EventEmitter {
  private width: number;
  private height: number;
  private grid: GridCell[][];
  private heatSources: Map<string, HeatSource> = new Map();
  private baseViscosity: number = 100.0; // Solid glass state

  constructor(width: number = 32, height: number = 32) {
    super();
    this.width = width;
    this.height = height;
    this.grid = this.initGrid();
  }

  private initGrid(): GridCell[][] {
    const grid: GridCell[][] = [];
    for (let y = 0; y < this.height; y++) {
      const row: GridCell[] = [];
      for (let x = 0; x < this.width; x++) {
        // Initial glass sculpture shape: dense in the center, hollow at borders
        const distFromCenter = Math.hypot(x - this.width / 2, y - this.height / 2);
        const initialDensity = distFromCenter < this.width / 3 ? 1.0 : 0.0;

        row.push({
          temperature: 20, // Room temperature (°C)
          viscosity: this.baseViscosity,
          vx: 0,
          vy: 0,
          density: initialDensity,
        });
      }
      grid.push(row);
    }
    return grid;
  }

  /**
   * Translates commit activity into a localized thermal impulse.
   */
  public injectCommitHeat(commit: CommitData) {
    const churn = commit.filesChanged * 10 + (commit.linesAdded + commit.linesDeleted);
    const heatEnergy = Math.min(churn * 1.5, 1500); // Cap max local heat energy

    // Map author deterministically to a grid position (glass sculpture region)
    const hashNum = commit.author.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
    const targetX = (hashNum * 7) % (this.width - 4) + 2;
    const targetY = (hashNum * 13) % (this.height - 4) + 2;

    // Heat up region around target coordinate
    const radius = Math.max(1, Math.floor(commit.filesChanged / 2));
    for (let dy = -radius; dy <= radius; dy++) {
      for (let dx = -radius; dx <= radius; dx++) {
        const gx = targetX + dx;
        const gy = targetY + dy;
        if (gx >= 0 && gx < this.width && gy >= 0 && gy < this.height) {
          const cell = this.grid[gy][gx];
          cell.temperature += heatEnergy / (Math.hypot(dx, dy) + 1);
        }
      }
    }

    this.emit('heatInjected', { author: commit.author, targetX, targetY, heatEnergy });
  }

  /**
   * Performs one iteration of thermal diffusion, viscosity shift, and mass convection.
   */
  public step(dt: number = 0.1) {
    const nextGrid = JSON.parse(JSON.stringify(this.grid)) as GridCell[][];

    for (let y = 1; y < this.height - 1; y++) {
      for (let x = 1; x < this.width - 1; x++) {
        const cell = this.grid[y][x];

        // 1. Thermal Diffusion (Heat spreading through glass)
        const neighborHeatSum =
          this.grid[y - 1][x].temperature +
          this.grid[y + 1][x].temperature +
          this.grid[y][x - 1].temperature +
          this.grid[y][x + 1].temperature;
        
        const laplacianHeat = neighborHeatSum - 4 * cell.temperature;
        nextGrid[y][x].temperature += 0.2 * laplacianHeat * dt;

        // Ambient cooling
        nextGrid[y][x].temperature = Math.max(20, nextGrid[y][x].temperature * 0.98);

        // 2. Temperature to Viscosity Mapping (Arrhenius-like transition)
        // High temp (> 500) drastically lowers viscosity, causing flow
        const temp = nextGrid[y][x].temperature;
        const fluidFactor = Math.min(1.0, Math.max(0.0, (temp - 200) / 800));
        nextGrid[y][x].viscosity = this.baseViscosity * (1 - fluidFactor) + 0.1 * fluidFactor;

        // 3. Fluid Buoyancy/Gravity (Thermal convection reshaping the structure)
        if (fluidFactor > 0.1) {
          // Melted glass drips down due to gravity, modified by thermal buoyancy
          const buoyancyForce = (temp - 100) * 0.005;
          const gravityForce = 0.02 * cell.density;
          nextGrid[y][x].vy += (gravityForce - buoyancyForce) * dt;

          // Simple advection of density (Glass reshaping)
          const targetY = Math.min(this.height - 1, Math.max(0, Math.round(y + nextGrid[y][x].vy)));
          const targetX = Math.min(this.width - 1, Math.max(0, Math.round(x + nextGrid[y][x].vx)));

          if (targetY !== y || targetX !== x) {
            const flowAmount = cell.density * 0.1 * (1 / nextGrid[y][x].viscosity);
            nextGrid[y][x].density -= flowAmount;
            nextGrid[targetY][targetX].density += flowAmount;
          }
        }
      }
    }

    this.grid = nextGrid;
    this.emit('frame', this.grid);
  }

  /**
   * ASCII renderer visualizing the melted glass sculpture density and state.
   */
  public renderASCII(): string {
    const chars = [' ', '░', '▒', '▓', '█', '🔥'];
    let output = '';

    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        const cell = this.grid[y][x];
        if (cell.temperature > 600) {
          output += chars[5]; // Incandescent melting glass
        } else if (cell.density > 0.8) {
          output += chars[4];
        } else if (cell.density > 0.5) {
          output += chars[3];
        } else if (cell.density > 0.2) {
          output += chars[2];
        } else if (cell.density > 0.05) {
          output += chars[1];
        } else {
          output += chars[0];
        }
      }
      output += '\n';
    }
    return output;
  }
}

// ============================================================================
// Main Execution Pipeline (Simulation Loop)
// ============================================================================

function runSimulation() {
  // Mock Git History Data stream: hash|author|timestamp|filesChanged|linesAdded|linesDeleted
  const mockGitLog = `
a1b2c3d|Alice|1672531190|3|120|45
e5f6g7h|Bob|1672531200|12|450|300
i8j9k0l|Charlie|1672531210|1|5|2
m1n2o3p|Alice|1672531220|8|310|90
q4r5s6t|Diana|1672531230|15|900|600
u7v8w9x|Bob|1672531240|2|15|3
  `;

  const parser = new GitHistoryParser(mockGitLog);
  const commits = parser.parse();

  const sim = new GlassSculptureFluidSimulation(24, 24);

  console.log('--- Initial Glass Sculpture State ---');
  console.log(sim.renderASCII());

  let commitIdx = 0;
  let stepCount = 0;

  // Real-time playback loop
  const interval = setInterval(() => {
    // Inject a commit periodically
    if (stepCount % 3 === 0 && commitIdx < commits.length) {
      const commit = commits[commitIdx++];
      console.log(`\n[Commit Event] ${commit.author} pushed: ${commit.filesChanged} files churned.`);
      sim.injectCommitHeat(commit);
    }

    // Step fluid simulation forward
    sim.step();
    
    // Render status
    console.log(`\n--- Step ${stepCount + 1} (Glass Melting Dynamics) ---`);
    console.log(sim.renderASCII());

    stepCount++;
    if (stepCount >= 18) {
      clearInterval(interval);
      console.log('--- Simulation Cycle Complete ---');
    }
  }, 300);
}

runSimulation();