import { AudioContext, AnalyserNode, MediaStreamAudioSourceNode } from "web-audio-api";
import * as THREE from "three";
import { STLExporter } from "three/examples/jsm/exporters/STLExporter.js";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";

//--- SETTINGS --------------------------------------------------------
const FFT_SIZE = 2048;
const UPDATE_RATE = 30; // Hz
const L_SYSTEM_ITER = 5;
const BRANCH_ANGLE_BASE = Math.PI / 4;
const SEGMENT_LENGTH_BASE = 5;
const EXPORT_FPS = 30;

//--- GLOBALS ---------------------------------------------------------
let audioCtx: AudioContext;
let analyser: AnalyserNode;
let dataArray: Float32Array;
let canvas: HTMLCanvasElement;
let renderer: THREE.WebGLRenderer;
let scene: THREE.Scene;
let camera: THREE.PerspectiveCamera;
let controls: OrbitControls;
let lSystemString = "";
let geometry = new THREE.Geometry();
let lineMesh: THREE.Line;
let lastExportTime = 0;
let recorder: MediaRecorder;
let recordedChunks: BlobPart[] = [];

//--- AUDIO ANALYSIS ---------------------------------------------------
function initAudio(stream: MediaStream) {
    audioCtx = new AudioContext();
    const source = audioCtx.createMediaStreamSource(stream) as MediaStreamAudioSourceNode;
    analyser = audioCtx.createAnalyser();
    analyser.fftSize = FFT_SIZE;
    source.connect(analyser);
    dataArray = new Float32Array(analyser.frequencyBinCount);
}

// spectral centroid (weighted mean frequency)
function getSpectralCentroid(): number {
    analyser.getFloatFrequencyData(dataArray);
    let sumMag = 0, sumFreq = 0;
    const nyquist = audioCtx.sampleRate / 2;
    const binFreq = nyquist / dataArray.length;
    for (let i = 0; i < dataArray.length; i++) {
        const mag = Math.pow(10, dataArray[i] / 20); // linear magnitude
        sumMag += mag;
        sumFreq += mag * i * binFreq;
    }
    return sumMag ? sumFreq / sumMag : 0;
}

// simple tempo estimator (energy peak detection)
let energyHistory: number[] = [];
function estimateTempo(): number {
    analyser.getFloatTimeDomainData(dataArray);
    const energy = dataArray.reduce((a, b) => a + b * b, 0) / dataArray.length;
    energyHistory.push(energy);
    if (energyHistory.length > 43) energyHistory.shift(); // ~1s at 43fps
    const peaks = energyHistory.filter((e, i, arr) => i > 0 && i < arr.length - 1 && e > arr[i - 1] && e > arr[i + 1] && e > 0.001);
    const bpm = peaks.length * 60; // rough per second
    return bpm;
}

// placeholder for key & tension (random walk)
let key = 0; // 0‑11 semitones
function updateKey() {
    key = (key + (Math.random() > 0.975 ? 1 : 0)) % 12;
}
function getTension(): number {
    return Math.abs(Math.sin(Date.now() * 0.001));
}

//--- L‑SYSTEM ---------------------------------------------------------
function generateLSystem(angle: number, length: number) {
    const axiom = "F";
    const rules: Record<string, string> = { "F": "F[+F]F[-F]F" };
    let str = axiom;
    for (let i = 0; i < L_SYSTEM_ITER; i++) {
        str = str.replace(/[F\+\-\[\]]/g, c => rules[c] ?? c);
    }
    lSystemString = str;
    buildGeometry(str, angle, length);
}

// turn L‑system string into line geometry
function buildGeometry(str: string, angle: number, length: number) {
    const stack: { pos: THREE.Vector3; quat: THREE.Quaternion }[] = [];
    const pos = new THREE.Vector3(0, 0, 0);
    const quat = new THREE.Quaternion();
    geometry = new THREE.Geometry();
    for (const ch of str) {
        switch (ch) {
            case "F":
                const next = pos.clone().add(new THREE.Vector3(0, length, 0).applyQuaternion(quat));
                geometry.vertices.push(pos.clone(), next.clone());
                pos.copy(next);
                break;
            case "+":
                quat.multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 0, 1), angle));
                break;
            case "-":
                quat.multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 0, 1), -angle));
                break;
            case "[":
                stack.push({ pos: pos.clone(), quat: quat.clone() });
                break;
            case "]":
                const saved = stack.pop();
                if (saved) {
                    pos.copy(saved.pos);
                    quat.copy(saved.quat);
                }
                break;
        }
    }
    const mat = new THREE.LineBasicMaterial({ vertexColors: true });
    const colors = [];
    for (let i = 0; i < geometry.vertices.length; i++) {
        const c = new THREE.Color().setHSL((i / geometry.vertices.length + key / 12) % 1, 0.7, 0.5);
        colors.push(c);
    }
    geometry.colors = colors;
    if (lineMesh) scene.remove(lineMesh);
    lineMesh = new THREE.LineSegments(geometry, mat);
    scene.add(lineMesh);
}

//--- THREE.JS SETUP ----------------------------------------------------
function initThree() {
    canvas = document.createElement("canvas");
    document.body.appendChild(canvas);
    renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
    renderer.setSize(window.innerWidth, window.innerHeight);
    scene = new THREE.Scene();
    scene.background = new THREE.Color(0x111111);
    camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.1, 1000);
    camera.position.set(0, 50, 100);
    controls = new OrbitControls(camera, renderer.domElement);
    const light = new THREE.DirectionalLight(0xffffff, 1);
    light.position.set(0, 100, 100);
    scene.add(light);
}

//--- ANIMATION LOOP ---------------------------------------------------
function animate() {
    requestAnimationFrame(animate);
    const centroid = getSpectralCentroid();
    const tempo = estimateTempo();
    updateKey();
    const tension = getTension();

    const angle = BRANCH_ANGLE_BASE * (1 + tension);
    const length = SEGMENT_LENGTH_BASE * (1 + (tempo / 120));
    generateLSystem(angle, length);

    // color gradient already incorporates key
    lineMesh.material?.color?.setHSL((centroid / (audioCtx.sampleRate / 2) + key / 12) % 1, 0.8, 0.6);
    controls.update();
    renderer.render(scene, camera);
}

//--- VIDEO EXPORT ------------------------------------------------------
function startRecording() {
    const stream = canvas.captureStream(EXPORT_FPS);
    recorder = new MediaRecorder(stream, { mimeType: "video/webm; codecs=vp9" });
    recorder.ondataavailable = e => recordedChunks.push(e.data);
    recorder.start();
}
function stopRecording() {
    recorder.stop();
    recorder.onstop = () => {
        const blob = new Blob(recordedChunks, { type: "video/webm" });
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = "lsystem_music.webm";
        a.click();
    };
}

//--- STL EXPORT --------------------------------------------------------
function exportSTL() {
    const exporter = new STLExporter();
    const stlString = exporter.parse(lineMesh);
    const blob = new Blob([stlString], { type: "application/octet-stream" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "lsystem_snapshot.stl";
    a.click();
}

//--- UI ---------------------------------------------------------------
function createUI() {
    const btnRec = document.createElement("button");
    btnRec.textContent = "Start Recording";
    btnRec.onclick = () => { startRecording(); btnRec.textContent = "Stop Recording"; btnRec.onclick = () => { stopRecording(); btnRec.textContent = "Start Recording"; btnRec.onclick = arguments.callee; }; };
    document.body.appendChild(btnRec);

    const btnSTL = document.createElement("button");
    btnSTL.textContent = "Export STL (current)";
    btnSTL.onclick = exportSTL;
    document.body.appendChild(btnSTL);
}

//--- ENTRY -------------------------------------------------------------
navigator.mediaDevices.getUserMedia({ audio: true }).then(stream => {
    initAudio(stream);
    initThree();
    createUI();
    animate();
}).catch(err => console.error("Audio init error:", err));