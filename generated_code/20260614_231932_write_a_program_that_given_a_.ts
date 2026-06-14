import { Voronoi } from "https://cdn.jsdelivr.net/npm/d3-delaunay@6/+esm";
import * as Tone from "https://cdn.jsdelivr.net/npm/tone@14/+esm";

async function main() {
  // ==== Set up video ====
  const video = document.createElement("video");
  video.autoplay = true;
  video.playsInline = true;
  video.style.display = "none";
  document.body.appendChild(video);

  const stream = await navigator.mediaDevices.getUserMedia({ video: true });
  video.srcObject = stream;

  // ==== Canvas for processing frames ====
  const procCanvas = document.createElement("canvas");
  const procCtx = procCanvas.getContext("2d")!;
  procCanvas.width = 160; // low‑res for speed
  procCanvas.height = 120;
  document.body.appendChild(procCanvas);
  procCanvas.style.position = "absolute";
  procCanvas.style.left = "-9999px";

  // ==== Canvas for Voronoi visualization ====
  const visCanvas = document.createElement("canvas");
  const visCtx = visCanvas.getContext("2d")!;
  visCanvas.width = window.innerWidth;
  visCanvas.height = window.innerHeight;
  document.body.appendChild(visCanvas);
  visCanvas.style.position = "fixed";
  visCanvas.style.top = "0";
  visCanvas.style.left = "0";

  // ==== Audio synth ====
  const synth = new Tone.PolySynth(Tone.Synth, {
    oscillator: { type: "sine" },
    envelope: { attack: 0.01, decay: 0.2, sustain: 0.4, release: 1 },
  }).toDestination();

  await Tone.start();

  // === Helper: get dominant hues via simple quantization ===
  function extractHues(imgData: ImageData): number[] {
    const hueBins = new Array(360).fill(0);
    const data = imgData.data;
    for (let i = 0; i < data.length; i += 4) {
      const r = data[i],
        g = data[i + 1],
        b = data[i + 2];
      // Convert to HSV quickly
      const max = Math.max(r, g, b);
      const min = Math.min(r, g, b);
      const delta = max - min;
      let h = 0;
      if (delta !== 0) {
        if (max === r) h = ((g - b) / delta) % 6;
        else if (max === g) h = (b - r) / delta + 2;
        else h = (r - g) / delta + 4;
        h = Math.round(h * 60);
        if (h < 0) h += 360;
      }
      hueBins[h]++;
    }
    // pick top 5 hues
    const top: number[] = [];
    for (let i = 0; i < 5; i++) {
      let maxIdx = hueBins.indexOf(Math.max(...hueBins));
      top.push(maxIdx);
      hueBins[maxIdx] = -1; // exclude next time
    }
    return top;
  }

  // === Map hue to chord (simple diatonic mapping) ===
  const scale = ["C", "D", "E", "F", "G", "A", "B"]; // major
  function hueToChord(hue: number): string {
    const degree = Math.floor((hue / 360) * 7);
    const root = scale[degree % 7];
    const type = degree % 2 === 0 ? "maj7" : "m7";
    return `${root}${type}`;
  }

  // === Voronoi setup ===
  let points: [number, number][] = [];
  const pointCount = 200;

  function initVoronoi() {
    points = [];
    for (let i = 0; i < pointCount; i++) {
      points.push([
        Math.random() * visCanvas.width,
        Math.random() * visCanvas.height,
      ]);
    }
  }
  initVoronoi();

  // === Audio‑driven cell deformation ===
  const analyser = Tone.context.createAnalyser();
  synth.connect(analyser);
  const fftArray = new Uint8Array(analyser.frequencyBinCount);

  function animate() {
    // ---- Process video frame ----
    procCtx.drawImage(video, 0, 0, procCanvas.width, procCanvas.height);
    const imgData = procCtx.getImageData(0, 0, procCanvas.width, procCanvas.height);
    const hues = extractHues(imgData);

    // ---- Play chords based on hues ----
    const now = Tone.now();
    hues.forEach((h, idx) => {
      const chord = hueToChord(h);
      // simple arpeggio of chord tones
      const notes = chord.split(" ");
      synth.triggerAttackRelease(
        notes.map((n) => n + "4"),
        "8n",
        now + idx * 0.2
      );
    });

    // ---- Update Voronoi cells based on audio amplitude ----
    analyser.getByteFrequencyData(fftArray);
    const amp = fftArray.reduce((a, b) => a + b, 0) / fftArray.length / 255; // 0‑1

    // move points slightly according to amplitude
    points = points.map(([x, y]) => {
      const angle = Math.random() * Math.PI * 2;
      const dist = amp * 20;
      return [
        (x + Math.cos(angle) * dist + visCanvas.width) % visCanvas.width,
        (y + Math.sin(angle) * dist + visCanvas.height) % visCanvas.height,
      ];
    });

    const voronoi = Voronoi.from(points);
    const diagram = voronoi.render();

    // ---- Draw Voronoi ----
    visCtx.clearRect(0, 0, visCanvas.width, visCanvas.height);
    visCtx.strokeStyle = "rgba(255,255,255,0.5)";
    visCtx.lineWidth = 1;
    for (let i = 0; i < diagram.edges.length; i++) {
      const e = diagram.edges[i];
      if (e == null) continue;
      visCtx.beginPath();
      visCtx.moveTo(e[0][0], e[0][1]);
      visCtx.lineTo(e[1][0], e[1][1]);
      visCtx.stroke();
    }

    requestAnimationFrame(animate);
  }

  animate();
}

main().catch(console.error);