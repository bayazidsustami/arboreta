import { createNoise2D } from "https://cdn.skypack.dev/simplex-noise@3.0.0";

/**
 * Simple sentiment analysis using word lists.
 */
const positiveWords = new Set(["love", "happy", "joy", "great", "awesome", "good"]);
const negativeWords = new Set(["hate", "sad", "bad", "angry", "terrible", "worst"]);

/**
 * L‑system definition.
 */
interface LSystem {
  axiom: string;
  rules: Map<string, string>;
  angle: number;
  iterations: number;
}

/**
 * Global state.
 */
let audioContext: AudioContext;
let analyser: AnalyserNode;
let dataArray: Uint8Array;
let sentiment = 0; // -1 .. 0 .. 1
let lsystems: LSystem[] = [];
let svg: SVGSVGElement;
let lastRender = 0;

/**
 * Initialize webcam + audio, create SVG container.
 */
async function init() {
  const stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
  const video = document.createElement("video");
  video.srcObject = stream;
  video.autoplay = true;
  video.muted = true;
  video.style.position = "absolute";
  video.style.left = "-9999px";
  document.body.appendChild(video);

  audioContext = new AudioContext();
  const source = audioContext.createMediaStreamSource(stream);
  analyser = audioContext.createAnalyser();
  analyser.fftSize = 2048;
  source.connect(analyser);
  dataArray = new Uint8Array(analyser.frequencyBinCount);

  // SVG canvas
  svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("width", "100%");
  svg.setAttribute("height", "100%");
  svg.style.position = "fixed";
  svg.style.top = "0";
  svg.style.left = "0";
  document.body.appendChild(svg);

  // start speech recognition
  startSpeechRecognition();

  requestAnimationFrame(render);
}

/**
 * Speech recognition + sentiment extraction.
 */
function startSpeechRecognition() {
  const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
  if (!SpeechRecognition) return;
  const rec = new SpeechRecognition();
  rec.continuous = true;
  rec.interimResults = false;
  rec.lang = "en-US";

  rec.onresult = (e: SpeechRecognitionEvent) => {
    const transcript = Array.from(e.results)
      .map(r => r[0].transcript)
      .join(" ")
      .toLowerCase();
    let score = 0;
    const words = transcript.split(/\s+/);
    for (const w of words) {
      if (positiveWords.has(w)) score += 1;
      else if (negativeWords.has(w)) score -= 1;
    }
    sentiment = Math.max(-1, Math.min(1, score / words.length));
    mutateLSystems();
  };
  rec.start();
}

/**
 * Create or mutate L‑systems based on sentiment.
 */
function mutateLSystems() {
  // keep 3 systems, create if missing
  while (lsystems.length < 3) lsystems.push(randomLSystem());

  // mutate rules lightly
  for (const sys of lsystems) {
    for (const [k, v] of sys.rules) {
      if (Math.random() < 0.2) {
        const newV = mutateString(v);
        sys.rules.set(k, newV);
      }
    }
    // sentiment influences iterations
    sys.iterations = 3 + Math.round(sentiment * 2);
  }
}

/**
 * Generate a random L‑system.
 */
function randomLSystem(): LSystem {
  const axiom = "F";
  const rules = new Map<string, string>([
    ["F", Math.random() < 0.5 ? "F+F--F+F" : "F[-F]F[+F]F"]
  ]);
  return { axiom, rules, angle: 25 + Math.random() * 20, iterations: 3 };
}

/**
 * Small mutation of a production string.
 */
function mutateString(s: string): string {
  const chars = s.split("");
  const idx = Math.floor(Math.random() * chars.length);
  const ops = ["+", "-", "[", "]"];
  chars[idx] = ops[Math.floor(Math.random() * ops.length)];
  return chars.join("");
}

/**
 * Generate turtle graphics path from L‑system string.
 */
function generatePath(sys: LSystem, scale: number): string {
  let str = sys.axiom;
  for (let i = 0; i < sys.iterations; i++) {
    let nxt = "";
    for (const ch of str) {
      nxt += sys.rules.get(ch) ?? ch;
    }
    str = nxt;
  }

  let x = 0, y = 0, angle = -90;
  const stack: { x: number; y: number; angle: number }[] = [];
  const path: string[] = ["M0,0"];
  for (const ch of str) {
    switch (ch) {
      case "F":
        const rad = (angle * Math.PI) / 180;
        x += Math.cos(rad) * scale;
        y += Math.sin(rad) * scale;
        path.push(`L${x},${y}`);
        break;
      case "+":
        angle += sys.angle;
        break;
      case "-":
        angle -= sys.angle;
        break;
      case "[":
        stack.push({ x, y, angle });
        break;
      case "]":
        const saved = stack.pop();
        if (saved) ({ x, y, angle } = saved);
        path.push(`M${x},${y}`);
        break;
    }
  }
  return path.join(" ");
}

/**
 * Main render loop.
 */
function render(timestamp: number) {
  if (timestamp - lastRender < 30) {
    requestAnimationFrame(render);
    return;
  }
  lastRender = timestamp;

  analyser.getByteFrequencyData(dataArray);
  const avgFreq = dataArray.reduce((a, b) => a + b, 0) / dataArray.length;
  const pitch = Math.max(...dataArray);
  const amplitude = avgFreq / 255;

  // clear previous
  while (svg.firstChild) svg.removeChild(svg.firstChild);

  const noise = createNoise2D();
  const centerX = window.innerWidth / 2;
  const centerY = window.innerHeight / 2;

  lsystems.forEach((sys, i) => {
    const scale = 5 + amplitude * 20 + noise(i, timestamp * 0.001) * 10;
    const d = generatePath(sys, scale);
    const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
    path.setAttribute("d", d);
    const hue = (pitch + i * 60) % 360;
    const sat = 70 + sentiment * 30;
    const light = 50 + amplitude * 30;
    path.setAttribute(
      "stroke",
      `hsl(${hue},${sat}%,${light}%)`
    );
    path.setAttribute("fill", "none");
    path.setAttribute("stroke-width", `${1 + amplitude * 4}`);
    path.setAttribute(
      "transform",
      `translate(${centerX},${centerY}) rotate(${timestamp * 0.02 + i * 30})`
    );
    svg.appendChild(path);
  });

  requestAnimationFrame(render);
}

// start everything
init().catch(console.error);