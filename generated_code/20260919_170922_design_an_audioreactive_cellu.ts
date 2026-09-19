/**
 * Audio-reactive cellular automaton baroque portrait generator.
 * Written in TypeScript for Node.js.
 */

const WIDTH = 60;
const HEIGHT = 20;
const BLOCKS = [' ', '░', '▒', '▓', '█'];

// Simulate heart rate input (e.g., BPM affecting cellular rules)
function getHeartRateMultiplier(): number {
    return 1 + Math.sin(Date.now() / 1000) * 0.2;
}

// Initialize grid with symmetrical seeds
let grid: number[][] = Array.from({ length: HEIGHT }, () =>
    Array.from({ length: WIDTH }, () => (Math.random() > 0.85 ? 4 : 0))
);

function step(bpmFactor: number) {
    const newGrid = grid.map(row => [...row]);
    for (let y = 0; y < HEIGHT; y++) {
        for (let x = 0; x < WIDTH / 2; x++) {
            let neighbors = 0;
            for (let dy = -1; dy <= 1; dy++) {
                for (let dx = -1; dx <= 1; dx++) {
                    if (dx === 0 && dy === 0) continue;
                    const ny = y + dy;
                    const nx = x + dx;
                    if (ny >= 0 && ny < HEIGHT && nx >= 0 && nx < WIDTH / 2) {
                        if (grid[ny][nx] > 0) neighbors++;
                    }
                }
            }
            
            const threshold = Math.max(1, Math.floor(4 / bpmFactor));
            if (grid[y][x] > 0) {
                newGrid[y][x] = neighbors >= threshold && neighbors <= 5 ? Math.min(4, grid[y][x] + 1) : 0;
            } else {
                newGrid[y][x] = (neighbors === 3) ? 1 : 0;
            }
            
            // Enforce baroque mirror symmetry
            newGrid[y][WIDTH - 1 - x] = newGrid[y][x];
        }
    }
    grid = newGrid;
}

function render() {
    const output = grid.map(row => row.map(cell => BLOCKS[cell]).join('')).join('\n');
    process.stdout.write('\x1b[H\x1b[2J'); // Clear screen & reset cursor
    console.log("=== BAROQUE CELLULAR PORTRAIT (HEART-RATE REACTIVE) ===");
    console.log(output);
}

function run() {
    setInterval(() => {
        const bpm = getHeartRateMultiplier();
        step(bpm);
        render();
    }, 120);
}

if (require.main === module) {
    run();
}