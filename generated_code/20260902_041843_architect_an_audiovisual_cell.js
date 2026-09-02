/**
 * Audio-Visual Self-Modifying Instruction Automaton
 * Single-file runnable solution (HTML + JS Web Audio API)
 */
const html = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Audio-Visual Self-Modifying Instruction Automaton</title>
    <style>
        body {
            background: #050508;
            color: #00ffcc;
            font-family: 'Courier New', monospace;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            margin: 0;
            overflow: hidden;
        }
        #canvas {
            background: #000;
            border: 1px solid #00ffcc;
            box-shadow: 0 0 20px rgba(0, 255, 204, 0.2);
        }
        #controls {
            margin-top: 15px;
            font-size: 12px;
            color: #888;
        }
        button {
            background: #00ffcc;
            color: #000;
            border: none;
            padding: 8px 16px;
            font-family: inherit;
            font-weight: bold;
            cursor: pointer;
            box-shadow: 0 0 10px rgba(0, 255, 204, 0.5);
        }
        button:hover { background: #fff; }
    </style>
</head>
<body>
    <canvas id="canvas"></canvas>
    <div id="controls">
        <button id="startBtn">INITIALIZE CORE</button>
    </div>

<script>
// --- AUTOMATON & VM ARCHITECTURE ---
const WIDTH = 64;
const HEIGHT = 40;
const CELL_SIZE = 16;
const MEM_SIZE = 16; // 16-byte memory heap per cell

// Custom Instruction Set Architecture (Bytecode)
const OP = {
    NOP: 0x0, MOV: 0x1, ADD: 0x2, SUB: 0x3,
    XOR: 0x4, INC: 0x5, DEC: 0x6, JMP: 0x7,
    MUT: 0x8, OUT: 0x9, SHARE: 0xA, READ: 0xB
};

// Microtonal Frequency Map (19-Tone Equal Temperament scale over 4 octaves)
const BASE_FREQ = 110.0; // A2
const EDO19 = Array.from({length: 76}, (_, i) => BASE_FREQ * Math.pow(2, i / 19));

class Cell {
    constructor(x, y) {
        this.x = x;
        this.y = y;
        this.heap = new Uint8Array(MEM_SIZE);
        this.ip = 0;          // Instruction Pointer
        this.acc = 0;         // Accumulator
        this.freq = 0;        // Last output microtonal frequency
        this.active = false;  // Audio state flag
        this.randomize();
    }

    randomize() {
        for (let i = 0; i < MEM_SIZE; i++) {
            this.heap[i] = Math.floor(Math.random() * 256);
        }
        this.ip = 0;
        this.acc = 0;
    }

    // Step the Virtual Machine executing bytecodes from memory heap
    step(neighbors) {
        let opcode = (this.heap[this.ip] >> 4) & 0x0F;
        let arg = this.heap[this.ip] & 0x0F;
        this.active = false;

        switch (opcode) {
            case OP.NOP: 
                break;
            case OP.MOV: 
                this.acc = this.heap[arg]; 
                break;
            case OP.ADD: 
                this.acc = (this.acc + this.heap[arg]) & 0xFF; 
                break;
            case OP.SUB: 
                this.acc = (this.acc - this.heap[arg] + 256) & 0xFF; 
                break;
            case OP.XOR: 
                this.acc ^= this.heap[arg]; 
                break;
            case OP.INC: 
                this.heap[arg] = (this.heap[arg] + 1) & 0xFF; 
                break;
            case OP.DEC: 
                this.heap[arg] = (this.heap[arg] - 1 + 256) & 0xFF; 
                break;
            case OP.JMP: 
                this.ip = arg; 
                return; // Direct jump
            case OP.MUT: // Self-modifying instruction mutate opcode
                this.heap[arg] ^= (this.acc | 1); 
                break;
            case OP.OUT: // Audio frequency execution trigger
                this.freq = EDO19[this.acc % EDO19.length];
                this.active = true;
                break;
            case OP.SHARE: // Write acc to a neighbor's heap (Cellular interaction)
                if (neighbors.length > 0) {
                    let target = neighbors[this.acc % neighbors.length];
                    target.heap[this.heap[arg] % MEM_SIZE] = this.acc;
                }
                break;
            case OP.READ: // Read neighbor heap into acc
                if (neighbors.length > 0) {
                    let source = neighbors[this.acc % neighbors.length];
                    this.acc = source.heap[arg % MEM_SIZE];
                }
                break;
        }

        this.ip = (this.ip + 1) % MEM_SIZE;
    }
}

// ASCII Glyph Map based on memory entropy
const ASCII_QUILT = " .:-=+*#%@#░▒▓█";

class Grid {
    constructor(w, h) {
        this.w = w;
        this.h = h;
        this.cells = [];
        for (let y = 0; y < h; y++) {
            for (let x = 0; x < w; x++) {
                this.cells.push(new Cell(x, y));
            }
        }
    }

    get(x, y) {
        x = (x + this.w) % this.w;
        y = (y + this.h) % this.h;
        return this.cells[y * this.w + x];
    }

    getNeighbors(x, y) {
        return [
            this.get(x-1, y), this.get(x+1, y),
            this.get(x, y-1), this.get(x, y+1)
        ];
    }

    step() {
        for (let cell of this.cells) {
            cell.step(this.getNeighbors(cell.x, cell.y));
        }
    }
}

// --- AUDIO SYNTHESIS ENGINE ---
class MicrotonalSynth {
    constructor() {
        this.ctx = null;
        this.master = null;
        this.activeNodes = [];
    }

    init() {
        this.ctx = new (window.AudioContext || window.webkitAudioContext)();
        this.master = this.ctx.createGain();
        this.master.gain.value = 0.15;

        // Limiter compressor to prevent clipping audio overload
        let compressor = this.ctx.createDynamicsCompressor();
        compressor.threshold.setValueAtTime(-12, this.ctx.currentTime);
        compressor.knee.setValueAtTime(30, this.ctx.currentTime);
        compressor.ratio.setValueAtTime(12, this.ctx.currentTime);
        
        this.master.connect(compressor);
        compressor.connect(this.ctx.destination);
    }

    playFrequencies(freqs) {
        if (!this.ctx) return;
        
        // Polyphonic voice management (limit simultaneous audio hits per tick)
        let now = this.ctx.currentTime;
        let maxVoices = 8;
        let voices = freqs.slice(0, maxVoices);

        voices.forEach(freq => {
            let osc = this.ctx.createOscillator();
            let gain = this.ctx.createGain();

            osc.type = 'triangle';
            osc.frequency.setValueAtTime(freq, now);

            // Micro-envelope per synthesized grain
            gain.gain.setValueAtTime(0.01, now);
            gain.gain.exponentialRampToValueAtTime(0.1, now + 0.02);
            gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.15);

            osc.connect(gain);
            gain.connect(this.master);

            osc.start(now);
            osc.stop(now + 0.16);
        });
    }
}

// --- RENDERING & SYSTEM LOOPS ---
const canvas = document.getElementById('canvas');
const ctx = canvas.getContext('2d');
canvas.width = WIDTH * CELL_SIZE;
canvas.height = HEIGHT * CELL_SIZE;

const grid = new Grid(WIDTH, HEIGHT);
const synth = new MicrotonalSynth();
let isRunning = false;

function drawQuilt() {
    ctx.fillStyle = '#050508';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.font = '12px monospace';
    ctx.textBaseline = 'top';

    for (let cell of grid.cells) {
        // Calculate heap checksum/entropy to determine color and symbol
        let sum = cell.heap.reduce((a, b) => a + b, 0);
        let charIndex = sum % ASCII_QUILT.length;
        let char = ASCII_QUILT[charIndex];

        let r = cell.heap[0];
        let g = cell.heap[1];
        let b = cell.heap[2];

        // Draw background block
        ctx.fillStyle = `rgb(${r},${g},${b})`;
        ctx.fillRect(cell.x * CELL_SIZE, cell.y * CELL_SIZE, CELL_SIZE, CELL_SIZE);

        // Draw foreground ASCII instruction state
        ctx.fillStyle = cell.active ? '#ffffff' : `hsl(${(cell.acc * 4) % 360}, 100%, 75%)`;
        ctx.fillText(char, cell.x * CELL_SIZE + 3, cell.y * CELL_SIZE + 2);
    }
}

function tick() {
    grid.step();

    // Collect frequencies emitted by active execution units
    let freqs = [];
    for (let cell of grid.cells) {
        if (cell.active) {
            freqs.push(cell.freq);
        }
    }

    if (freqs.length > 0) {
        synth.playFrequencies(freqs);
    }

    drawQuilt();
    setTimeout(() => requestAnimationFrame(tick), 100);
}

document.getElementById('startBtn').addEventListener('click', (e) => {
    if (!isRunning) {
        synth.init();
        isRunning = true;
        e.target.innerText = "RUNNING...";
        e.target.style.background = "#555";
        tick();
    }
});
</script>
</body>
</html>`;

// Execute environment check & bootstrap browser/Node execution
if (typeof window !== 'undefined') {
    document.open();
    document.write(html);
    document.close();
} else {
    console.log("Self-Modifying Audio-Visual Automaton source created. Load string into a browser engine to render.");
}