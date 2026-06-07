import { Tone } from "https://cdn.skypack.dev/tone@14.7.77";
import * as faceapi from "https://cdn.jsdelivr.net/npm/@vladmandic/face-api@1.0.2/dist/face-api.esm.js";

type RGB = [number, number, number];

(async () => {
  // ── Setup video stream ───────────────────────────────────────────────────────
  const video = document.createElement("video");
  video.autoplay = true;
  video.playsInline = true;
  document.body.appendChild(video);
  const stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false });
  video.srcObject = stream;

  // ── Canvas for pixel analysis ───────────────────────────────────────────────
  const canvas = document.createElement("canvas");
  const ctx = canvas.getContext("2d") as CanvasRenderingContext2D;
  document.body.appendChild(canvas);
  canvas.style.display = "none";

  // ── SVG container for mandala ───────────────────────────────────────────────
  const svgNS = "http://www.w3.org/2000/svg";
  const svg = document.createElementNS(svgNS, "svg");
  svg.setAttribute("width", "100%");
  svg.setAttribute("height", "100%");
  svg.style.position = "absolute";
  svg.style.top = "0";
  svg.style.left = "0";
  document.body.appendChild(svg);

  // ── Load face‑api model (for smile detection) ───────────────────────────────
  await faceapi.nets.tinyFaceDetector.loadFromUri("https://cdn.jsdelivr.net/npm/@vladmandic/face-api/model/");
  await faceapi.nets.faceExpressionNet.loadFromUri("https://cdn.jsdelivr.net/npm/@vladmandic/face-api/model/");

  // ── Pentatonic scale (C major) ───────────────────────────────────────────────
  const pentatonic = ["C4", "D4", "E4", "G4", "A4"];
  const synth = new Tone.PolySynth(Tone.Synth).toDestination();

  // ── Audio analyser for spectral flux ────────────────────────────────────────
  const analyser = Tone.context.createAnalyser();
  analyser.fftSize = 256;
  const bufferLength = analyser.frequencyBinCount;
  const prevSpectrum = new Float32Array(bufferLength);
  const audioGain = new Tone.Gain(0.5).toDestination();
  synth.connect(analyser);
  synth.connect(audioGain);

  // ── Helper: Euclidean distance between two RGB colors ───────────────────────
  const dist = (a: RGB, b: RGB) => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);

  // ── K‑means (k=5) for dominant palette ───────────────────────────────────────
  const getPalette = (imgData: ImageData, k = 5): RGB[] => {
    const pixels: RGB[] = [];
    const data = imgData.data;
    for (let i = 0; i < data.length; i += 4) {
      pixels.push([data[i], data[i + 1], data[i + 2]]);
    }
    // Initialise centroids randomly
    const centroids: RGB[] = [];
    for (let i = 0; i < k; i++) {
      centroids.push(pixels[Math.floor(Math.random() * pixels.length)]);
    }
    // Iterate
    for (let iter = 0; iter < 10; iter++) {
      const clusters: RGB[][] = Array.from({ length: k }, () => []);
      for (const p of pixels) {
        let best = 0;
        let bestDist = dist(p, centroids[0]);
        for (let c = 1; c < k; c++) {
          const d = dist(p, centroids[c]);
          if (d < bestDist) {
            bestDist = d;
            best = c;
          }
        }
        clusters[best].push(p);
      }
      for (let c = 0; c < k; c++) {
        if (clusters[c].length === 0) continue;
        const sum = clusters[c].reduce((acc, val) => [acc[0] + val[0], acc[1] + val[1], acc[2] + val[2]], [0, 0, 0]);
        centroids[c] = [sum[0] / clusters[c].length, sum[1] / clusters[c].length, sum[2] / clusters[c].length] as RGB;
      }
    }
    return centroids;
  };

  // ── Map a color to a note (by hue) ─────────────────────────────────────────────
  const colorToNote = (c: RGB): string => {
    const hue = Math.atan2(
      Math.sqrt(3) * (c[1] - c[2]),
      2 * c[0] - c[1] - c[2]
    ) * (180 / Math.PI);
    const normHue = (hue + 360) % 360;
    const idx = Math.floor((normHue / 360) * pentatonic.length);
    return pentatonic[idx];
  };

  // ── Draw mandala based on audio flux and smile confidence ─────────────────────
  const drawMandala = (flux: number, smileConf: number) => {
    svg.innerHTML = "";
    const size = Math.min(window.innerWidth, window.innerHeight);
    const layers = 6;
    for (let i = 0; i < layers; i++) {
      const path = document.createElementNS(svgNS, "path");
      const radius = (size / 2) * (0.2 + i * 0.12);
      const points = 12;
      let d = "";
      for (let p = 0; p <= points; p++) {
        const angle = (Math.PI * 2 * p) / points + (i * Math.PI) / 7;
        const rMod = radius + Math.sin(Tone.now() * 0.7 + i) * flux * 30;
        const x = size / 2 + rMod * Math.cos(angle);
        const y = size / 2 + rMod * Math.sin(angle);
        d += p === 0 ? `M${x},${y}` : `L${x},${y}`;
      }
      d += "Z";
      path.setAttribute("d", d);
      const hue = (i * 60 + Tone.now() * 10) % 360;
      path.setAttribute("stroke", `hsl(${hue},80%,60%)`);
      const baseWidth = 2 + flux * 10;
      path.setAttribute("stroke-width", `${baseWidth * (1 + smileConf)}`);
      path.setAttribute("fill", "none");
      svg.appendChild(path);
    }
  };

  // ── Main loop ────────────────────────────────────────────────────────────────
  const process = async () => {
    if (video.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA) {
      const w = video.videoWidth, h = video.videoHeight;
      canvas.width = w; canvas.height = h;
      ctx.drawImage(video, 0, 0, w, h);
      const img = ctx.getImageData(0, 0, w, h);
      const palette = getPalette(img);
      // Play notes from palette
      const now = Tone.now();
      palette.forEach((c, i) => {
        const note = colorToNote(c);
        synth.triggerAttackRelease(note, "8n", now + i * 0.2);
      });

      // Smile detection
      const detections = await faceapi.detectAllFaces(video, new faceapi.TinyFaceDetectorOptions()).withFaceExpressions();
      let smileConf = 0;
      if (detections.length) {
        smileConf = detections[0].expressions.happy;
      }

      // Spectral flux
      const spectrum = new Float32Array(bufferLength);
      analyser.getFloatFrequencyData(spectrum);
      let flux = 0;
      for (let i = 0; i < bufferLength; i++) {
        const diff = spectrum[i] - prevSpectrum[i];
        flux += diff > 0 ? diff : 0;
        prevSpectrum[i] = spectrum[i];
      }
      flux = Math.min(flux / 100, 1); // normalise

      // Draw mandala
      drawMandala(flux, smileConf);
    }
    requestAnimationFrame(process);
  };

  // ── Start audio context on user interaction ───────────────────────────────────
  const start = () => {
    Tone.start();
    process();
    document.removeEventListener("click", start);
  };
  document.addEventListener("click", start);
})();