import { Readable } from 'stream';

// --- Configuration ---
const WIDTH = 60;
const HEIGHT = 45;
const CELL_EMPTY = ' ';
const CELL_WALL = '█';
const CELL_PILLAR = 'O';
const CELL_ALTAR = '┼';
const CELL_WINDOW = '░';

type Grid = string[][];

// --- Initialization ---
function createGrid(w: number, h: number, fill = CELL_EMPTY): Grid {
    return Array.from({ length: h }, () => Array(w).fill(fill));
}

// Generate the immutable, foundational blueprint of a Gothic Cathedral
function generateBlueprint(w: number, h: number): Grid {
    const grid = createGrid(w, h);
    const midX = Math.floor(w / 2);
    const naveWidth = Math.floor(w * 0.3);
    const transeptStart = Math.floor(h * 0.3);
    const transeptEnd = Math.floor(h * 0.5);

    for (let y = 0; y < h; y++) {
        for (let x = 0; x < w; x++) {
            const inNave = x >= midX - naveWidth && x <= midX + naveWidth;
            const inTransept = y >= transeptStart && y <= transeptEnd && x >= 4 && x < w - 4;
            const inApse = y < transeptStart && Math.pow(x - midX, 2) + Math.pow(y - transeptStart, 2) <= Math.pow(naveWidth, 2);

            if (inNave || inTransept || inApse) {
                grid[y][x] = CELL_EMPTY;
                
                // Outer walls outlining the structural shape
                if (y === h - 1 || x === 4 || x === w - 5 || 
                    (x === midX - naveWidth && y > transeptEnd) || 
                    (x === midX + naveWidth && y > transeptEnd) ||
                    (y === transeptStart && (x < midX - naveWidth || x > midX + naveWidth)) ||
                    (y === transeptEnd && (x < midX - naveWidth || x > midX + naveWidth))) {
                    grid[y][x] = CELL_WALL;
                }
            }
        }
    }

    // Carve out the curved Apse at the top front
    for (let x = 0; x < w; x++) {
        const dist = Math.sqrt(Math.pow(x - midX, 2) + Math.pow(-transeptStart, 2));
        if (Math.abs(dist - naveWidth) < 1) {
            grid[0][x] = CELL_WALL;
        }
    }

    // Place the fixed Altar in the sanctuary
    grid[Math.floor(transeptStart * 1.5)][midX] = CELL_ALTAR;

    // Erect structural pillars along the Nave
    for (let y = transeptEnd + 2; y < h - 2; y += 4) {
        grid[y][midX - Math.floor(naveWidth / 2)] = CELL_PILLAR;
        grid[y][midX + Math.floor(naveWidth / 2)] = CELL_PILLAR;
    }
    return grid;
}

const blueprint = generateBlueprint(WIDTH, HEIGHT);
let dynamicGrid = createGrid(WIDTH, HEIGHT);

// --- Cellular Automaton Logic ---
// Evolution rules governed by audio energy (volume) and frequency shift (rhythm)
function evolveCathedral(energy: number, frequencyShift: number) {
    const nextGrid = createGrid(WIDTH, HEIGHT);

    for (let y = 0; y < HEIGHT; y++) {
        for (let x = 0; x < WIDTH; x++) {
            const isStructural = blueprint[y][x] === CELL_WALL || blueprint[y][x] === CELL_PILLAR || blueprint[y][x] === CELL_ALTAR;
            
            // Count active neighboring dynamic cells
            let neighbors = 0;
            for (let dy = -1; dy <= 1; dy++) {
                for (let dx = -1; dx <= 1; dx++) {
                    if (dx === 0 && dy === 0) continue;
                    const nx = x + dx;
                    const ny = y + dy;
                    if (nx >= 0 && nx < WIDTH && ny >= 0 && ny < HEIGHT) {
                        if (dynamicGrid[ny][nx] !== CELL_EMPTY) neighbors++;
                    }
                }
            }

            const current = dynamicGrid[y][x];

            if (isStructural) {
                // Audio shifts walls into stained glass windows or reinforces them
                if (energy > 0.6 && Math.random() < frequencyShift) {
                    nextGrid[y][x] = CELL_WINDOW;
                } else {
                    nextGrid[y][x] = blueprint[y][x]; 
                }
            } else {
                // Cellular Automaton growth rules influenced by the rhythm
                if (current === CELL_EMPTY) {
                    if (neighbors === 3 || (neighbors === 2 && energy > 0.7)) {
                        nextGrid[y][x] = Math.random() > 0.5 ? '·' : '░'; // Sacred geometries crystallizing
                    } else {
                        nextGrid[y][x] = CELL_EMPTY;
                    }
                } else {
                    if (neighbors < 2 || neighbors > 4 || energy < 0.2) {
                        nextGrid[y][x] = CELL_EMPTY; // Dissolution from silence
                    } else {
                        nextGrid[y][x] = current; // Sustained form
                    }
                }
            }
        }
    }
    dynamicGrid = nextGrid;
}

function render() {
    console.clear();
    const output = dynamicGrid.map(row => row.join('')).join('\n');
    console.log(output);
    console.log(`\n[Phonetic Resonance] Energy: ${(lastEnergy * 100).toFixed(1)}% | Rhythm Shift: ${(lastShift * 100).toFixed(1)}%`);
}

// --- Audio Stream Processing ---
// Mock live audio stream via a Readable stream reading random PCM-like buffer slices
// In production, this can be swapped with: process.stdin.pipe(audioStream)
const audioStream = new Readable({
    read() {
        const size = 1024;
        const buffer = Buffer.alloc(size);
        for (let i = 0; i < size; i++) {
            // Generate synthetic waveforms mimicking speech phonetics and beats
            const time = Date.now() / 1000;
            const sample = Math.sin(time * 440) * Math.cos(time * 5) * 128 + 128;
            buffer[i] = sample + (Math.random() * 32 - 16);
        }
        this.push(buffer);
    }
});

let lastEnergy = 0;
let lastShift = 0;

audioStream.on('data', (chunk: Buffer) => {
    let sum = 0;
    let zeroCrossings = 0;

    for (let i = 0; i < chunk.length; i++) {
        const sample = (chunk[i] - 128) / 128; // Normalize to [-1, 1]
        sum += sample * sample;

        if (i > 0 && ((chunk[i] >= 128 && chunk[i - 1] < 128) || (chunk[i] < 128 && chunk[i - 1] >= 128))) {
            zeroCrossings++;
        }
    }

    // Root Mean Square (RMS) maps to sonic energy
    lastEnergy = Math.min(Math.sqrt(sum / chunk.length) * 2, 1);
    // Zero-crossing rate maps to phonetic frequency shifts/rhythm
    lastShift = Math.min(zeroCrossings / (chunk.length / 2), 1);
});

// Main Loop: Run the cellular automaton simulation at 12hz
setInterval(() => {
    evolveCathedral(lastEnergy, lastShift);
    render();
}, 85);