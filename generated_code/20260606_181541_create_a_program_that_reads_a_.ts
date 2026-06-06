import { start } from "https://cdn.skypack.dev/@pixiv/threejs-examples@0.154.0/utils";

// ---------- CONFIG ----------
const FRAME_RATE = 30; // fps for processing
const COLOR_SAMPLE_COUNT = 5000; // pixels sampled per frame
const NOTES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]; // chromatic
const BASE_FREQ = 261.63; // C4 frequency (Hz)
const SCALE_RATIO = Math.pow(2, 1 / 12); // semitone ratio
// ------------------------------------------------

// ---------- GLOBAL STATE ----------
let audioCtx: AudioContext;
let masterGain: GainNode;
let lastNoteTime = 0;
let lastBeat = 0;
let beatInterval = 0.5; // seconds per beat, will adapt
// ------------------------------------------------

// ---------- SETUP CANVAS ----------
const video = document.createElement("video");
video.autoplay = true;
video.playsInline = true;
video.style.display = "none";
document.body.append(video);

const canvas = document.createElement("canvas");
canvas.width = window.innerWidth;
canvas.height = window.innerHeight;
document.body.append(canvas);
const ctx = canvas.getContext("2d")!;

const offscreen = document.createElement("canvas");
offscreen.width = 160;
offscreen.height = 120;
const offCtx = offscreen.getContext("2d")!;
// ------------------------------------------------

// ---------- AUDIO HELPERS ----------
function noteFromHue(hue: number): number {
    // hue [0,360) -> note index [0,11]
    const idx = Math.floor((hue / 360) * NOTES.length) % NOTES.length;
    return BASE_FREQ * Math.pow(SCALE_RATIO, idx);
}

function playNote(freq: number, time: number) {
    const osc = audioCtx.createOscillator();
    const env = audioCtx.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(freq, time);
    env.gain.setValueAtTime(0, time);
    env.gain.linearRampToValueAtTime(0.2, time + 0.01);
    env.gain.exponentialRampToValueAtTime(0.001, time + 0.5);
    osc.connect(env).connect(masterGain);
    osc.start(time);
    osc.stop(time + 0.6);
}
// ------------------------------------------------

// ---------- FRAME PROCESSING ----------
function processFrame() {
    // draw current video frame to low‑res canvas
    offCtx.drawImage(video, 0, 0, offscreen.width, offscreen.height);
    const imgData = offCtx.getImageData(0, 0, offscreen.width, offscreen.height);
    const data = imgData.data;
    let hueSum = 0;
    let count = 0;

    // sample random pixels
    for (let i = 0; i < COLOR_SAMPLE_COUNT; i++) {
        const x = Math.floor(Math.random() * offscreen.width);
        const y = Math.floor(Math.random() * offscreen.height);
        const idx = (y * offscreen.width + x) * 4;
        const r = data[idx];
        const g = data[idx + 1];
        const b = data[idx + 2];
        const hue = rgbToHue(r, g, b);
        hueSum += hue;
        count++;
    }

    const avgHue = hueSum / count;
    const freq = noteFromHue(avgHue);
    const now = audioCtx.currentTime;
    if (now - lastNoteTime > 0.2) {
        playNote(freq, now);
        lastNoteTime = now;
    }

    // derive beat interval from hue speed (simple heuristic)
    const beatSpeed = Math.abs(freq - BASE_FREQ) / BASE_FREQ;
    beatInterval = 0.2 + 0.8 * (1 - Math.min(beatSpeed, 1));
    // render kaleidoscopic fractal
    renderFractal(freq, now);
}

// ---------- COLOR UTIL ----------
function rgbToHue(r: number, g: number, b: number): number {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b);
    let h = 0;
    if (max === min) {
        h = 0;
    } else if (max === r) {
        h = ((g - b) / (max - min)) * 60;
    } else if (max === g) {
        h = ((b - r) / (max - min)) * 60 + 120;
    } else {
        h = ((r - g) / (max - min)) * 60 + 240;
    }
    return (h + 360) % 360;
}
// ------------------------------------------------

// ---------- FRACTAL RENDERER ----------
function renderFractal(freq: number, time: number) {
    const t = time % 1000;
    const scale = 0.5 + 0.5 * Math.sin(t * 0.001);
    const rot = t * 0.0005;
    const color = `hsl(${(freq / BASE_FREQ) * 360 % 360},80%,60%)`;

    ctx.save();
    ctx.translate(canvas.width / 2, canvas.height / 2);
    ctx.rotate(rot);
    ctx.scale(scale * canvas.width / 800, scale * canvas.height / 800);
    drawKaleido(0, 0, 400, 6, color);
    ctx.restore();
}

// recursive kaleidoscopic pattern
function drawKaleido(x: number, y: number, size: number, depth: number, col: string) {
    if (depth === 0) return;
    ctx.strokeStyle = col;
    ctx.lineWidth = depth;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x + size * Math.cos(Math.PI / 3), y + size * Math.sin(Math.PI / 3));
    ctx.lineTo(x + size * Math.cos(2 * Math.PI / 3), y + size * Math.sin(2 * Math.PI / 3));
    ctx.closePath();
    ctx.stroke();

    const newSize = size * 0.5;
    for (let i = 0; i < 3; i++) {
        const angle = i * (2 * Math.PI) / 3;
        const nx = x + newSize * Math.cos(angle);
        const ny = y + newSize * Math.sin(angle);
        drawKaleido(nx, ny, newSize, depth - 1, col);
    }
}
// ------------------------------------------------

// ---------- MAIN ----------
async function init() {
    // audio context must be started after user interaction
    await new Promise<void>((res) => {
        const btn = document.createElement("button");
        btn.textContent = "Start Synesthetic Experience";
        btn.style.position = "absolute";
        btn.style.top = "20px";
        btn.style.left = "20px";
        document.body.append(btn);
        btn.onclick = () => {
            audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
            masterGain = audioCtx.createGain();
            masterGain.gain.value = 0.2;
            masterGain.connect(audioCtx.destination);
            btn.remove();
            res();
        };
    });

    // webcam
    const stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false });
    video.srcObject = stream;

    // processing loop
    setInterval(processFrame, 1000 / FRAME_RATE);
}

init().catch(console.error);