import * as fs from 'fs';
import * as path from 'path';

// Generation Counter: 0
// Memory State Mutator: 0.1337

/**
 * Self-Modifying Quine: Maps Memory Fragmentation into Decaying Cross-Stitch SVG & Microtonal Soundscape
 */
class VictorianDecayQuine {
    private gen: number = 0;
    private sourceCode: string = '';

    constructor() {
        // Quine behavior: read own source file at runtime
        this.sourceCode = fs.readFileSync(__filename, 'utf-8');
        this.extractGen();
    }

    private extractGen(): void {
        const match = this.sourceCode.match(/\/\/ Generation Counter: (\d+)/);
        this.gen = match ? parseInt(match[1], 10) : 0;
    }

    // 1. Measure live heap memory allocations and fragmentation
    public getMemoryMetrics() {
        // Allocate dynamic memory buffer to alter live heap fragmentation profile
        const volatileAllocations: Array<Uint8Array> = [];
        for (let i = 0; i < (this.gen % 12) + 5; i++) {
            volatileAllocations.push(new Uint8Array(Math.floor(Math.random() * 1024 * 256)));
        }

        const mem = process.memoryUsage();
        const heapUsed = mem.heapUsed;
        const heapTotal = mem.heapTotal;
        // Heap fragmentation index based on active vs allocated space ratio
        const fragmentationRatio = Math.max(0.01, 1 - (heapUsed / (heapTotal || 1)));

        return { heapUsed, heapTotal, fragmentationRatio, external: mem.external };
    }

    // 2. Sonify heap memory allocations into 19-Tone Equal Temperament (19-TET) ambient microtonal chimes
    public generateMicrotonalChimes(fragmentation: number, heap: number): number[] {
        const baseFreq = 220; // A3 baseline
        const division = 19; // 19-TET microtonal scale divisions
        const chimes: number[] = [];

        // Map byte segments of heap memory size into microtonal pitch intervals
        for (let i = 0; i < 8; i++) {
            const step = Math.floor((heap >> (i * 3)) % 38);
            const microtonalFreq = baseFreq * Math.pow(2, step / division);
            // Apply detuning jitter modulated by memory fragmentation
            const detuned = microtonalFreq * (1 + (fragmentation * 0.04 * (i % 2 === 0 ? 1 : -1)));
            chimes.push(Number(detuned.toFixed(2)));
        }

        return chimes;
    }

    // 3. Render decaying Victorian cross-stitch embroidery lattice using SVG
    public renderCrossStitchSVG(fragmentation: number, chimes: number[]): string {
        const width = 800;
        const height = 800;
        const gridSize = 20;
        const cols = width / gridSize;
        const rows = height / gridSize;

        let svg = `<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="0 0 ${width} ${height}" style="background:#0c0a0e;">\n`;
        svg += `<style>
            .stitch { stroke-linecap: round; stroke-width: 2.5; transition: all 0.3s; }
            .bg-grid { stroke: #2d2233; stroke-width: 0.5; opacity: 0.25; }
        </style>\n`;

        // Canvas grid simulating Aida fabric weave
        for (let x = 0; x <= width; x += gridSize) {
            svg += `<line x1="${x}" y1="0" x2="${x}" y2="${height}" class="bg-grid"/>\n`;
        }
        for (let y = 0; y <= height; y += gridSize) {
            svg += `<line x1="0" y1="${y}" x2="${width}" y2="${y}" class="bg-grid"/>\n`;
        }

        // Victorian textile color palette (Burgundy, Rose, Antique Gold, Muted Moss)
        const palette = ['#800020', '#b56576', '#d4af37', '#556b2f', '#4a154b'];

        // Generative Victorian damask/flower pattern
        for (let r = 0; r < rows; r++) {
            for (let c = 0; c < cols; c++) {
                const cx = c * gridSize;
                const cy = r * gridSize;

                // Pattern symmetry equation perturbed by generational drift
                const distFromCenter = Math.hypot(c - cols / 2, r - rows / 2);
                const symmetryFactor = Math.sin(c * 0.35) * Math.cos(r * 0.35) + Math.cos(distFromCenter * 0.25);

                // Memory fragmentation dictates thread decay/rot probability
                const decayThreshold = 0.15 + fragmentation * 0.75;
                const noise = (Math.sin(r * 12.9898 + c * 78.233 + this.gen) * 43758.5453) % 1;

                if (Math.abs(symmetryFactor) > 0.3 && noise > decayThreshold) {
                    const colorIndex = Math.abs(Math.floor(chimes[c % chimes.length] + r)) % palette.length;
                    const color = palette[colorIndex];

                    // Thread decay distortion, frayed offset, and fading opacity
                    const opacity = Math.max(0.1, 1 - decayThreshold);
                    const jitter = (noise - 0.5) * fragmentation * 10;

                    // Render cross-stitch 'X' motif
                    svg += `<g opacity="${opacity.toFixed(2)}">
                        <line x1="${cx + 3 + jitter}" y1="${cy + 3}" x2="${cx + gridSize - 3}" y2="${cy + gridSize - 3 + jitter}" stroke="${color}" class="stitch"/>
                        <line x1="${cx + gridSize - 3}" y1="${cy + 3 + jitter}" x2="${cx + 3 + jitter}" y2="${cx + gridSize - 3}" stroke="${color}" class="stitch"/>
                    </g>\n`;
                }
            }
        }

        svg += `</svg>`;
        return svg;
    }

    // 4. Self-Modification Engine: Mutate source file state in-place
    public selfModify(): void {
        const newGen = this.gen + 1;
        const mutatedSource = this.sourceCode
            .replace(/\/\/ Generation Counter: \d+/, `// Generation Counter: ${newGen}`)
            .replace(/\/\/ Memory State Mutator: [\d.]+/, `// Memory State Mutator: ${Math.random().toFixed(4)}`);

        fs.writeFileSync(__filename, mutatedSource, 'utf-8');
    }

    // Main execution cycle
    public execute(): void {
        const metrics = this.getMemoryMetrics();
        const chimes = this.generateMicrotonalChimes(metrics.fragmentationRatio, metrics.heapUsed);
        const svg = this.renderCrossStitchSVG(metrics.fragmentationRatio, chimes);

        const svgPath = path.join(path.dirname(__filename), 'victorian_decay.svg');
        fs.writeFileSync(svgPath, svg, 'utf-8');

        console.log(`--- [Victorian Decay Engine - Generation ${this.gen}] ---`);
        console.log(`Heap Used: ${(metrics.heapUsed / 1024 / 1024).toFixed(2)} MB`);
        console.log(`Memory Fragmentation Ratio: ${(metrics.fragmentationRatio * 100).toFixed(2)}%`);
        console.log(`Microtonal Ambient Frequencies (19-TET):`);
        console.log(chimes.map(f => `${f} Hz`).join(' | '));
        console.log(`Live SVG Render output saved to: ${svgPath}`);

        this.selfModify();
    }
}

// Run engine
new VictorianDecayQuine().execute();