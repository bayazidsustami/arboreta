import * as http from 'http';
import * as url from 'url';
import * as fs from 'fs';
import * as path from 'path';
import {parseMidi} from 'midi-file-parser';
import {execSync} from 'child_process';

// ====== Helper Types ======
type MidiEvent = { deltaTime: number; type: string; subtype?: string; noteNumber?: number; velocity?: number };
type Note = { start: number; duration: number; velocity: number };
type LSystem = { axiom: string; rules: Record<string, (depth: number, tempo: number, intensity: number) => string> };

// ====== Core Logic ======

// 1. Load and parse MIDI, extract note timings (in seconds assuming 120bpm default)
function loadMidi(filePath: string): Note[] {
    const data = fs.readFileSync(filePath);
    const midi = parseMidi(data);
    const ticksPerBeat = midi.header.ticksPerBeat;
    const tempoEvents = midi.tracks.flat().filter(e => e.subtype === 'setTempo');
    const microsecondsPerBeat = tempoEvents[0]?.microsecondsPerBeat ?? 500000; // default 120 BPM
    const secondsPerTick = microsecondsPerBeat / 1e6 / ticksPerBeat;

    const notes: Note[] = [];
    const ongoing: Record<number, { start: number; velocity: number }> = {};

    let absTime = 0;
    midi.tracks.forEach(track => {
        absTime = 0;
        track.forEach((e: MidiEvent) => {
            absTime += e.deltaTime * secondsPerTick;
            if (e.type === 'channel' && e.subtype === 'noteOn' && e.velocity && e.velocity > 0) {
                ongoing[e.noteNumber!] = { start: absTime, velocity: e.velocity };
            } else if ((e.type === 'channel' && e.subtype === 'noteOff') ||
                       (e.type === 'channel' && e.subtype === 'noteOn' && e.velocity === 0)) {
                const on = ongoing[e.noteNumber!];
                if (on) {
                    notes.push({ start: on.start, duration: absTime - on.start, velocity: on.velocity });
                    delete ongoing[e.noteNumber!];
                }
            }
        });
    });
    return notes;
}

// 2. Derive simple hierarchical rhythmic motifs (levels based on duration quantization)
function deriveMotifs(notes: Note[]): number[] {
    // map durations to nearest power-of-two fraction of a beat
    const beats = notes.map(n => Math.round((n.duration / 0.5) * 100) / 100); // assume 0.5s beat at 120BPM
    // compress to motif indices
    const uniques = Array.from(new Set(beats)).sort((a, b) => a - b);
    return beats.map(b => uniques.indexOf(b));
}

// 3. Build L‑system that evolves with tempo & intensity
function buildLSystem(): LSystem {
    return {
        axiom: 'F',
        rules: {
            'F': (depth, tempo, intensity) => {
                const prob = Math.min(1, intensity / 127);
                if (depth > 6) return 'F';
                const angle = Math.sin(tempo / 60) * 30;
                return prob > 0.5 ? `F[+${angle}]F[-${angle}]` : `F[+${angle}]`;
            }
        }
    };
}

// 4. Generate SVG path from L‑system string
function lSystemToPath(lsys: LSystem, depth: number, tempo: number, intensity: number): string {
    let str = lsys.axiom;
    for (let i = 0; i < depth; i++) {
        str = str.replace(/[A-Z]/g, c => lsys.rules[c] ? lsys.rules[c](i, tempo, intensity) : c);
    }
    const stack: { x: number; y: number; angle: number }[] = [];
    let x = 250, y = 250, angle = -90;
    const path: string[] = ['M', x.toString(), y.toString()];
    const step = 10;
    for (const ch of str) {
        if (ch === 'F') {
            x += step * Math.cos(angle * Math.PI / 180);
            y += step * Math.sin(angle * Math.PI / 180);
            path.push('L', x.toString(), y.toString());
        } else if (ch === '+') {
            const a = parseFloat(str.substr(str.indexOf(ch) + 1));
            angle += isNaN(a) ? 25 : a;
        } else if (ch === '-') {
            const a = parseFloat(str.substr(str.indexOf(ch) + 1));
            angle -= isNaN(a) ? 25 : a;
        } else if (ch === '[') {
            stack.push({ x, y, angle });
        } else if (ch === ']') {
            const last = stack.pop();
            if (last) ({ x, y, angle } = last);
            path.push('M', x.toString(), y.toString());
        }
    }
    return path.join(' ');
}

// 5. Serve HTML/JS that runs audio, syncs SVG animation, and allows UI controls
function serve(port: number, midiPath: string) {
    const notes = loadMidi(midiPath);
    const motifs = deriveMotifs(notes);
    const lsys = buildLSystem();
    const server = http.createServer((req, res) => {
        const parsed = url.parse(req.url ?? '', true);
        if (parsed.pathname === '/') {
            const html = `
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8"><title>MIDI L‑System Visualizer</title>
<style>
body{font-family:sans-serif;background:#111;color:#ddd;display:flex;flex-direction:column;align-items:center;}
#svg{border:1px solid #555;background:#222;}
.controls{margin-top:10px;}
</style>
</head>
<body>
<h1>MIDI‑driven L‑System</h1>
<svg id="svg" width="500" height="500"></svg>
<div class="controls">
<label>Palette: <input type="color" id="color" value="#00ff00"></label>
<label>Line width: <input type="range" id="weight" min="1" max="10" value="2"></label>
<label>Depth: <input type="range" id="depth" min="1" max="8" value="4"></label>
<button id="snapshot">PDF Snapshot</button>
</div>
<audio id="audio" src="${path.basename(midiPath)}.wav" crossorigin="anonymous"></audio>
<script src="https://cdn.jsdelivr.net/npm/tone@14.8.39/build/Tone.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js"></script>
<script>
(async () => {
    const notes = ${JSON.stringify(notes)};
    const audio = document.getElementById('audio');
    const svg = document.getElementById('svg');
    const pathEl = document.createElementNS('http://www.w3.org/2000/svg','path');
    svg.appendChild(pathEl);
    const colorInp = document.getElementById('color');
    const weightInp = document.getElementById('weight');
    const depthInp = document.getElementById('depth');
    const snapBtn = document.getElementById('snapshot');

    function draw() {
        const now = audio.currentTime;
        const tempo = 120; // placeholder, could be dynamic from MIDI meta
        const intensity = notes.reduce((a,n)=>a+ (now>=n.start && now<=n.start+n.duration? n.velocity:0),0)/ notes.length || 0;
        const depth = parseInt(depthInp.value);
        const pathData = (${lSystemToPath.toString()})(${JSON.stringify(lsys)}, depth, tempo, intensity);
        pathEl.setAttribute('d', pathData);
        pathEl.setAttribute('stroke', colorInp.value);
        pathEl.setAttribute('stroke-width', weightInp.value);
        pathEl.setAttribute('fill','none');
        requestAnimationFrame(draw);
    }

    audio.addEventListener('play',()=>requestAnimationFrame(draw));

    snapBtn.onclick = async () => {
        const {jsPDF}=window.jspdf;
        const pdf = new jsPDF({unit:'pt',format:[500,500]});
        const serializer = new XMLSerializer();
        const svgText = serializer.serializeToString(svg);
        const canvas = document.createElement('canvas');
        canvas.width=500;canvas.height=500;
        const ctx = canvas.getContext('2d');
        const img = new Image();
        img.onload=()=>{ctx?.drawImage(img,0,0);pdf.addImage(canvas.toDataURL('image/png'), 'PNG',0,0,500,500);pdf.save('snapshot.pdf');};
        const svgBlob = new Blob([svgText],{type:'image/svg+xml;charset=utf-8'});
        const url = URL.createObjectURL(svgBlob);
        img.src = url;
    };
})();
</script>
</body>
</html>`;
            res.writeHead(200, { 'Content-Type': 'text/html' });
            res.end(html);
        } else if (parsed.pathname?.endsWith('.wav')) {
            // Convert MIDI to WAV using timidity (requires timidity installed)
            const wavPath = midiPath + '.wav';
            if (!fs.existsSync(wavPath)) {
                try { execSync(`timidity "${midiPath}" -Ow -o "${wavPath}"`); } catch (e) { console.error('timidity conversion failed'); }
            }
            const stream = fs.createReadStream(wavPath);
            res.writeHead(200, { 'Content-Type': 'audio/wav' });
            stream.pipe(res);
        } else {
            res.writeHead(404);
            res.end();
        }
    }).listen(port, () => console.log(`Server running at http://localhost:${port}`));
}

// ====== Entrypoint ======
if (process.argv.length < 3) {
    console.error('Usage: ts-node script.ts <midi-file> [port]');
    process.exit(1);
}
const midiFile = path.resolve(process.argv[2]);
const port = parseInt(process.argv[3] ?? '8080');
serve(port, midiFile);