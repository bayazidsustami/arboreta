import { createRoot } from "https://esm.sh/react@18/umd/react.production.min.js";
import { render } from "https://esm.sh/react-dom@18/umd/react-dom.production.min.js";

// Setup video, canvas and audio context
const video = document.createElement("video");
video.autoplay = true;
video.playsInline = true;
video.style.display = "none";
document.body.appendChild(video);

const canvas = document.createElement("canvas");
canvas.width = 640;
canvas.height = 480;
canvas.style.width = "100%";
canvas.style.height = "100%";
canvas.style.position = "fixed";
canvas.style.top = "0";
canvas.style.left = "0";
canvas.style.zIndex = "-1";
document.body.appendChild(canvas);
const ctx = canvas.getContext("2d")!;

const audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
const masterGain = audioCtx.createGain();
masterGain.gain.value = 0.2;
masterGain.connect(audioCtx.destination);

// Simple synth: one oscillator per chord tone
function playChord(frequencies: number[]) {
  const now = audioCtx.currentTime;
  const nodes: OscillatorNode[] = frequencies.map((freq) => {
    const osc = audioCtx.createOscillator();
    osc.frequency.value = freq;
    osc.type = "sine";
    osc.connect(masterGain);
    osc.start(now);
    osc.stop(now + 0.5);
    return osc;
  });
}

// Extract dominant colors (very naive: sample grid & k‑means = 2)
function getPalette(imageData: ImageData, k = 2): number[] {
  const samples: [number, number, number][] = [];
  const step = 10;
  for (let y = 0; y < imageData.height; y += step) {
    for (let x = 0; x < imageData.width; x += step) {
      const i = (y * imageData.width + x) * 4;
      samples.push([
        imageData.data[i],
        imageData.data[i + 1],
        imageData.data[i + 2],
      ]);
    }
  }
  // initialise centroids with random samples
  let centroids = samples.slice(0, k);
  for (let iter = 0; iter < 5; iter++) {
    const groups: number[][][] = Array.from({ length: k }, () => []);
    for (const s of samples) {
      let best = 0,
        bestDist = 1e9;
      for (let i = 0; i < k; i++) {
        const c = centroids[i];
        const d =
          (s[0] - c[0]) ** 2 + (s[1] - c[1]) ** 2 + (s[2] - c[2]) ** 2;
        if (d < bestDist) {
          bestDist = d;
          best = i;
        }
      }
      groups[best].push(s);
    }
    centroids = groups.map((g) => {
      if (g.length === 0) return [0, 0, 0];
      const sum = g.reduce(
        (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]],
        [0, 0, 0]
      );
      return [sum[0] / g.length, sum[1] / g.length, sum[2] / g.length];
    });
  }
  // flatten to rgb numbers
  return centroids.flatMap((c) =>
    c.map((v) => Math.round(v))
  );
}

// Map RGB to a chord (C major = root C, major third E, fifth G)
// Simple algorithm: treat hue as root, brightness as major/minor, saturation as 7th inclusion
function rgbToChord(r: number, g: number, b: number): number[] {
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const delta = max - min;
  const hue =
    delta === 0
      ? 0
      : max === r
      ? ((g - b) / delta) % 6
      : max === g
      ? (b - r) / delta + 2
      : (r - g) / delta + 4;
  const hueDeg = ((hue * 60) + 360) % 360;
  const rootMidi = 60 + Math.round(hueDeg / 30); // 12 possible roots
  const isMajor = (max + min) / 2 > 128;
  const intervals = isMajor ? [0, 4, 7] : [0, 3, 7];
  if (delta / max > 0.5) intervals.push(10); // add minor 7th if saturated
  return intervals.map((i) => 440 * 2 ** ((rootMidi + i - 69) / 12));
}

// Animation loop: draw kaleidoscopic pattern
let angle = 0;
let speed = 0.001;
function drawKaleido(palette: number[]) {
  const w = canvas.width,
    h = canvas.height;
  ctx.save();
  ctx.translate(w / 2, h / 2);
  ctx.rotate(angle);
  const radius = Math.min(w, h) * 0.4;
  for (let i = 0; i < 12; i++) {
    ctx.rotate((Math.PI * 2) / 12);
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(radius, 0);
    ctx.arc(0, 0, radius, 0, Math.PI / 12);
    ctx.closePath();
    const col = palette.slice((i % palette.length) * 3, (i % palette.length) * 3 + 3);
    ctx.fillStyle = `rgb(${col[0]},${col[1]},${col[2]})`;
    ctx.fill();
  }
  ctx.restore();
}

// Main processing loop
async function main() {
  const stream = await navigator.mediaDevices.getUserMedia({ video: true });
  video.srcObject = stream;
  await video.play();

  const analyser = audioCtx.createAnalyser();
  analyser.fftSize = 256;
  const dataArray = new Uint8Array(analyser.frequencyBinCount);
  masterGain.connect(analyser);

  function loop() {
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
    const img = ctx.getImageData(0, 0, canvas.width, canvas.height);
    const palette = getPalette(img, 2); // 2 colors -> 6 values
    // Map each dominant color to a chord and play
    const chord = rgbToChord(palette[0], palette[1], palette[2]);
    playChord(chord);
    // Get audio amplitude to drive speed
    analyser.getByteFrequencyData(dataArray);
    const amp = dataArray.reduce((a, b) => a + b, 0) / dataArray.length;
    speed = 0.001 + (amp / 255) * 0.01;
    angle += speed;
    drawKaleido(palette);
    requestAnimationFrame(loop);
  }
  loop();
}
main().catch(console.error);