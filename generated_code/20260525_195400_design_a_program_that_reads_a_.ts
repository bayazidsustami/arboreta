import { create, all } from 'mathjs';
import * as tf from '@tensorflow/tfjs';
import * as facemesh from '@tensorflow-models/face-landmarks-detection';

// ----- configuration ---------------------------------------------------------
const VIDEO_WIDTH = 640;
const VIDEO_HEIGHT = 480;
const FPS = 30;

// Mapping of simplified emotions to chords (root, type, tension)
const EMOTION_CHORD_MAP: Record<string, {root: string; type: string; tension: number}> = {
  happy:    {root: 'C',  type: 'major',     tension: 0},
  sad:      {root: 'A',  type: 'minor',     tension: 2},
  angry:    {root: 'E',  type: 'diminished',tension: 3},
  surprised:{root: 'G',  type: 'major7',    tension: 1},
  neutral:  {root: 'D',  type: 'sus2',      tension: 0},
};

// ----- math helpers -----------------------------------------------------------
const math = create(all);
function lerp(a: number, b: number, t: number) { return a + (b - a) * t; }

// ----- DOM setup --------------------------------------------------------------
const video = document.createElement('video');
video.width = VIDEO_WIDTH;
video.height = VIDEO_HEIGHT;
video.autoplay = true;
video.playsInline = true;
document.body.appendChild(video);

const svgNS = 'http://www.w3.org/2000/svg';
const svg = document.createElementNS(svgNS, 'svg');
svg.setAttribute('viewBox', `0 0 ${VIDEO_WIDTH} ${VIDEO_HEIGHT}`);
svg.style.position = 'absolute';
svg.style.top = '0';
svg.style.left = '0';
svg.style.width = '100%';
svg.style.height = '100%';
svg.style.pointerEvents = 'none';
document.body.appendChild(svg);

// ----- webcam ---------------------------------------------------------------
async function initWebcam() {
  const stream = await navigator.mediaDevices.getUserMedia({ video: { width: VIDEO_WIDTH, height: VIDEO_HEIGHT } });
  video.srcObject = stream;
  await new Promise(res => video.onloadedmetadata = () => res(null));
}

// ----- emotion detection ------------------------------------------------------
let model: facemesh.FaceLandmarksDetector;
async function loadModel() {
  model = await facemesh.load(facemesh.SupportedPackages.mediapipeFacemesh);
}

// Very crude emotion estimator based on mouth openness and eyebrow raise
function estimateEmotion(landmarks: facemesh.Keypoint[]): string {
  const mouthTop = landmarks[13];
  const mouthBottom = landmarks[14];
  const leftEyebrow = landmarks[70];
  const rightEyebrow = landmarks[300];

  const mouthOpen = Math.hypot(mouthBottom.x - mouthTop.x, mouthBottom.y - mouthTop.y);
  const browDist = Math.hypot(leftEyebrow.x - rightEyebrow.x, leftEyebrow.y - rightEyebrow.y);

  if (mouthOpen > 0.06) return 'surprised';
  if (mouthOpen > 0.04) return 'happy';
  if (browDist < 0.02) return 'angry';
  if (mouthOpen < 0.02) return 'sad';
  return 'neutral';
}

// ----- music / chord logic ----------------------------------------------------
interface Chord {
  root: string;
  type: string;
  tension: number; // 0‑3 determines animation speed
}
let currentChord: Chord = {root: 'C', type: 'major', tension: 0};

// Simple function to convert chord to a hue (0‑360) and speed factor
function chordToVisuals(chord: Chord) {
  const hueMap: Record<string, number> = {C:0, D:30, E:60, F:120, G:180, A:240, B:300};
  const baseHue = hueMap[chord.root] ?? 0;
  const typeShift = chord.type.includes('minor') ? 120 : chord.type.includes('diminished') ? 240 : 0;
  const hue = (baseHue + typeShift) % 360;
  const speed = lerp(0.5, 2.0, chord.tension / 3);
  return {hue, speed};
}

// ----- mandala generation -----------------------------------------------------
let mandalaGroup = document.createElementNS(svgNS, 'g');
svg.appendChild(mandalaGroup);
let lastRender = performance.now();

function drawMandala(hue: number, speed: number, delta: number) {
  const radius = 150;
  const points = 8;
  const angleStep = (Math.PI * 2) / points;
  const time = performance.now() / 1000 * speed;

  mandalaGroup.innerHTML = '';
  for (let i = 0; i < points; i++) {
    const angle = i * angleStep + time;
    const x = VIDEO_WIDTH/2 + Math.cos(angle) * radius;
    const y = VIDEO_HEIGHT/2 + Math.sin(angle) * radius;

    const path = document.createElementNS(svgNS, 'path');
    const innerRadius = radius * 0.5;
    const x2 = VIDEO_WIDTH/2 + Math.cos(angle + Math.PI) * innerRadius;
    const y2 = VIDEO_HEIGHT/2 + Math.sin(angle + Math.PI) * innerRadius;

    const d = `M${x},${y} Q${VIDEO_WIDTH/2},${VIDEO_HEIGHT/2} ${x2},${y2}`;
    path.setAttribute('d', d);
    path.setAttribute('stroke', `hsl(${hue},70%,60%)`);
    path.setAttribute('stroke-width', '2');
    path.setAttribute('fill', 'none');
    mandalaGroup.appendChild(path);
  }
}

// ----- main loop --------------------------------------------------------------
async function main() {
  await initWebcam();
  await loadModel();

  async function step() {
    const now = performance.now();
    const delta = now - lastRender;
    if (delta >= 1000 / FPS) {
      const predictions = await model.estimateFaces({input: video, returnTensors: false, flipHorizontal: false});
      if (predictions.length > 0) {
        const emotion = estimateEmotion(predictions[0].scaledMesh as facemesh.Keypoint[]);
        const chordInfo = EMOTION_CHORD_MAP[emotion] ?? EMOTION_CHORD_MAP['neutral'];
        currentChord = {root: chordInfo.root, type: chordInfo.type, tension: chordInfo.tension};
      }

      const {hue, speed} = chordToVisuals(currentChord);
      drawMandala(hue, speed, delta);
      lastRender = now;
    }
    requestAnimationFrame(step);
  }
  step();
}

main().catch(console.error);