import { Color } from 'three';
import * as Tone from 'tone';
import * as THREE from 'three';

// ----- CONFIG -----
const VIDEO_WIDTH = 640;
const VIDEO_HEIGHT = 480;
const PALETTE_SIZE = 5; // number of dominant colors per frame
const FRAMES_PER_UPDATE = 5; // how many video frames before re‑evaluate music/fractal

// ----- GLOBAL STATE -----
let video: HTMLVideoElement;
let canvas2d: HTMLCanvasElement;
let ctx2d: CanvasRenderingContext2D;
let renderer: THREE.WebGLRenderer;
let scene: THREE.Scene;
let camera: THREE.PerspectiveCamera;
let lsystemString = 'F';
let lsystemRules: Record<string, string> = { F: 'F[+F]F[-F]F' };
let step = 5;
let angle = Math.PI / 6;
let chordIndex = 0;

// ----- UTILS -----
function getDominantColors(imgData: ImageData, count: number): string[] {
    // Very naive k‑means like approach using quantization
    const data = imgData.data;
    const buckets: Record<string, number> = {};
    for (let i = 0; i < data.length; i += 4) {
        const r = Math.round(data[i] / 32) * 32;
        const g = Math.round(data[i + 1] / 32) * 32;
        const b = Math.round(data[i + 2] / 32) * 32;
        const key = `${r},${g},${b}`;
        buckets[key] = (buckets[key] || 0) + 1;
    }
    const sorted = Object.entries(buckets).sort((a, b) => b[1] - a[1]);
    return sorted.slice(0, count).map(v => `rgb(${v[0]})`);
}

function mapColorToChord(color: string): string {
    // Simple mapping: hue ranges to diatonic chords
    const c = new Color(color);
    const hue = c.getHSL().h * 360;
    const chords = ['C', 'Dm', 'Em', 'F', 'G', 'Am', 'Bdim'];
    const idx = Math.floor((hue / 360) * chords.length) % chords.length;
    return chords[idx];
}

// ----- SETUP VIDEO -----
async function initVideo() {
    video = document.createElement('video');
    video.width = VIDEO_WIDTH;
    video.height = VIDEO_HEIGHT;
    video.autoplay = true;
    video.playsInline = true;
    const stream = await navigator.mediaDevices.getUserMedia({ video: true });
    video.srcObject = stream;
    await video.play();

    canvas2d = document.createElement('canvas');
    canvas2d.width = VIDEO_WIDTH;
    canvas2d.height = VIDEO_HEIGHT;
    ctx2d = canvas2d.getContext('2d')!;
}

// ----- SETUP THREE.JS -----
function initThree() {
    renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setSize(window.innerWidth, window.innerHeight);
    document.body.appendChild(renderer.domElement);

    scene = new THREE.Scene();
    scene.background = new THREE.Color(0x111111);

    camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 1, 1000);
    camera.position.set(0, 0, 200);
    scene.add(camera);
}

// ----- L‑SYSTEM DRAWING -----
function drawLSystem() {
    // Remove previous geometry
    while (scene.children.length > 1) scene.remove(scene.children[1]);

    const material = new THREE.LineBasicMaterial({ color: 0xffffff });
    const points: THREE.Vector3[] = [];
    const stack: { pos: THREE.Vector3; dir: THREE.Vector3 }[] = [];

    let pos = new THREE.Vector3(0, -80, 0);
    let dir = new THREE.Vector3(0, 1, 0);
    points.push(pos.clone());

    for (const char of lsystemString) {
        if (char === 'F') {
            const next = pos.clone().add(dir.clone().multiplyScalar(step));
            points.push(next.clone());
            pos.copy(next);
        } else if (char === '+') {
            dir.applyAxisAngle(new THREE.Vector3(0, 0, 1), angle);
        } else if (char === '-') {
            dir.applyAxisAngle(new THREE.Vector3(0, 0, 1), -angle);
        } else if (char === '[') {
            stack.push({ pos: pos.clone(), dir: dir.clone() });
        } else if (char === ']') {
            const popped = stack.pop();
            if (popped) {
                pos.copy(popped.pos);
                dir.copy(popped.dir);
                points.push(pos.clone());
            }
        }
    }

    const geometry = new THREE.BufferGeometry().setFromPoints(points);
    const line = new THREE.Line(geometry, material);
    scene.add(line);
}

// ----- MUSIC SETUP -----
const synth = new Tone.PolySynth(Tone.Synth).toDestination();

function playChord(chord: string) {
    const now = Tone.now();
    const notes = Tone.Frequency(chord, 'midi')
        .transpose([0, 2, 4, 7]) // make a simple 4‑note voicing
        .map(f => f.toFrequency());
    synth.triggerAttackRelease(notes, '2n', now);
}

// ----- MAIN LOOP -----
let frameCount = 0;
async function mainLoop() {
    ctx2d.drawImage(video, 0, 0, VIDEO_WIDTH, VIDEO_HEIGHT);
    const imgData = ctx2d.getImageData(0, 0, VIDEO_WIDTH, VIDEO_HEIGHT);
    const palette = getDominantColors(imgData, PALETTE_SIZE);
    const chords = palette.map(mapColorToChord);

    // Update music every few frames
    if (frameCount % FRAMES_PER_UPDATE === 0) {
        const chord = chords[chordIndex % chords.length];
        playChord(chord);
        chordIndex++;

        // Modulate L‑system based on chord tension (simple: major -> more growth)
        const tension = chord.includes('m') ? 0.8 : 1.2;
        angle = (Math.PI / 6) * tension;
        // evolve L‑system string
        lsystemString = lsystemString.replace(/F/g, match => lsystemRules[match] || match);
        drawLSystem();
    }

    renderer.render(scene, camera);
    frameCount++;
    requestAnimationFrame(mainLoop);
}

// ----- INITIALISATION -----
(async () => {
    await initVideo();
    initThree();
    drawLSystem();
    await Tone.start(); // unlock audio on user gesture
    mainLoop();
})();