import { createCanvas, Canvas, CanvasRenderingContext2D } from 'canvas';

// Simple sentiment lexicon
const POSITIVE = new Set(['love', 'joy', 'bright', 'beauty', 'hope', 'grace', 'sweet']);
const NEGATIVE = new Set(['death', 'dark', 'sad', 'pain', 'sorrow', 'gloom', 'tear']);

// Basic iambic stress estimator: count alternating vowel‑consonant groups
function estimateStress(line: string): number {
    const words = line.trim().split(/\s+/);
    let stress = 0;
    for (const w of words) {
        const syl = Math.max(1, w.replace(/[^aeiouy]/gi, '').length);
        stress += syl;
    }
    return stress;
}

// Polarity: +1 positive, -1 negative, 0 neutral
function polarity(line: string): number {
    const tokens = line.toLowerCase().split(/\W+/);
    let score = 0;
    for (const t of tokens) {
        if (POSITIVE.has(t)) score++;
        if (NEGATIVE.has(t)) score--;
    }
    return Math.sign(score);
}

// Enjambment detection: true if line ends without terminal punctuation
function hasEnjambment(line: string): boolean {
    return !/[.!?]$/.test(line.trim());
}

// Convert polarity to hue (red‑green spectrum)
function hueFromPolarity(p: number): number {
    return p > 0 ? 120 : p < 0 ? 0 : 60; // green / red / yellow
}

// Convert stress to opacity (0.3‑1.0)
function opacityFromStress(s: number, maxStress: number): number {
    return 0.3 + 0.7 * (s / maxStress);
}

// Direction vector from enjambment
function directionFromEnjambment(e: boolean): number {
    return e ? Math.PI / 4 : -Math.PI / 4; // diagonal right‑down or left‑up
}

// Cellular automaton configuration
const WIDTH = 200;
const HEIGHT = 200;
const CELL_SIZE = 4;
const COLS = Math.floor(WIDTH / CELL_SIZE);
const ROWS = Math.floor(HEIGHT / CELL_SIZE);

let grid = new Uint8Array(COLS * ROWS);
let next = new Uint8Array(COLS * ROWS);

// Initialise grid randomly
for (let i = 0; i < grid.length; i++) grid[i] = Math.random() > 0.5 ? 1 : 0;

// Load Shakespeare sonnet (hard‑coded for demo)
const SONNET = `Shall I compare thee to a summer’s day?
Thou art more lovely and more temperate:
Rough winds do shake the darling buds of May,
And summer’s lease hath all too short a date;
Sometime too hot the eye of heaven shines,
And often is his gold complexion dimmed;
And every fair from fair sometime declines,
By chance or nature’s changing course untrimmed.
But thy eternal summer shall not fade
Nor lose possession of that fair thou owest;
Nor shall Death brag thou wander’st in his shade,
When in eternal lines to time thou growest:
So long as men can breathe or eyes can see,
So long lives this and this gives life to thee.`.split('\n');

// Pre‑process lines for visual mapping
const maxStress = Math.max(...SONNET.map(l => estimateStress(l)));
const lineInfo = SONNET.map(l => ({
    hue: hueFromPolarity(polarity(l)),
    opacity: opacityFromStress(estimateStress(l), maxStress),
    dir: directionFromEnjambment(hasEnjambment(l))
}));

// Create HTML canvas
const canvas = document.createElement('canvas');
canvas.width = WIDTH;
canvas.height = HEIGHT;
document.body.appendChild(canvas);
const ctx = canvas.getContext('2d') as CanvasRenderingContext2D;
ctx.lineCap = 'round';

// Animation loop
let frame = 0;
function step() {
    // Apply simple Life‑like rule (B3/S23)
    for (let y = 0; y < ROWS; y++) {
        for (let x = 0; x < COLS; x++) {
            const i = y * COLS + x;
            let n = 0;
            for (let dy = -1; dy <= 1; dy++) {
                for (let dx = -1; dx <= 1; dx++) {
                    if (dx === 0 && dy === 0) continue;
                    const nx = (x + dx + COLS) % COLS;
                    const ny = (y + dy + ROWS) % ROWS;
                    n += grid[ny * COLS + nx];
                }
            }
            next[i] = (grid[i] && (n === 2 || n === 3)) || (!grid[i] && n === 3) ? 1 : 0;
        }
    }
    [grid, next] = [next, grid];

    // Visualisation: each live cell draws a brushstroke
    ctx.clearRect(0, 0, WIDTH, HEIGHT);
    for (let y = 0; y < ROWS; y++) {
        for (let x = 0; x < COLS; x++) {
            if (grid[y * COLS + x]) {
                // Map cell to a line of the sonnet (wrap around)
                const lineIdx = (y * COLS + x) % lineInfo.length;
                const info = lineInfo[lineIdx];
                ctx.strokeStyle = `hsla(${info.hue},80%,50%,${info.opacity})`;
                ctx.beginPath();
                const cx = x * CELL_SIZE + CELL_SIZE / 2;
                const cy = y * CELL_SIZE + CELL_SIZE / 2;
                const len = CELL_SIZE * 2;
                const dx = Math.cos(info.dir) * len;
                const dy = Math.sin(info.dir) * len;
                ctx.moveTo(cx - dx / 2, cy - dy / 2);
                ctx.lineTo(cx + dx / 2, cy + dy / 2);
                ctx.stroke();
            }
        }
    }

    frame++;
    requestAnimationFrame(step);
}
step();

// Optional: record 10‑second looping video using MediaRecorder
function recordLoop(durationSec = 10) {
    const stream = (canvas as any).captureStream(30);
    const recorder = new MediaRecorder(stream, { mimeType: 'video/webm' });
    const chunks: BlobPart[] = [];
    recorder.ondataavailable = e => chunks.push(e.data);
    recorder.onstop = () => {
        const blob = new Blob(chunks, { type: 'video/webm' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'living_sonnet.webm';
        a.click();
    };
    recorder.start();
    setTimeout(() => recorder.stop(), durationSec * 1000);
}
// Uncomment to record after 5 seconds of play
setTimeout(() => recordLoop(), 5000);