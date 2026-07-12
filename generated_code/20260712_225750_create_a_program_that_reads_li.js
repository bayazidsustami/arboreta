<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>EEG L‑System Fractal Poem</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/p5.js/1.9.0/p5.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/tone/14.8.39/Tone.min.js"></script>
<style>body{margin:0;overflow:hidden;background:#111}</style>
</head>
<body>
<script>
// ==== SETTINGS ====
const LSYSTEM = {
  axiom: "F",
  rules: { "F": "F[+F]F[-F]F" }, // basic tree
  angle: Math.PI/7,
  length: 120,
  shrink: 0.7
};

// ==== GLOBALS ====
let eegData = {alpha:0,beta:0,theta:0,gamma:0,delta:0};
let synth, filter;
let angle = LSYSTEM.angle;
let length = LSYSTEM.length;

// ==== INITIALISE AUDIO ====
function initAudio() {
  synth = new Tone.PolySynth(Tone.Synth).toDestination();
  filter = new Tone.Filter(800, "lowpass").toDestination();
  synth.connect(filter);
}

// ==== MOCK EEG (replace with real Bluetooth later) ====
async function startEEG() {
  // Attempt to connect to an OpenBCI Cyton via Web Bluetooth (optional)
  // If unavailable, fallback to synthetic data.
  try {
    const device = await navigator.bluetooth.requestDevice({
      filters: [{services:['c18e7c1a-0718-4231-b3b1-42d908bc2fa7']}]
    });
    const server = await device.gatt.connect();
    // implementation specific to device...
  } catch (e) {
    // no device, start mock generator
    setInterval(() => {
      eegData = {
        delta: random(0,1),
        theta: random(0,1),
        alpha: random(0,1),
        beta:  random(0,1),
        gamma: random(0,1)
      };
    }, 100);
  }
}

// ==== L‑SYSTEM GENERATOR ====
function generate(grammar, depth) {
  let str = grammar.axiom;
  for (let i=0;i<depth;i++) {
    str = str.replace(/[A-Z]/g, ch=>grammar.rules[ch]||ch);
  }
  return str;
}

// ==== DRAW ====
function setup() {
  createCanvas(windowWidth, windowHeight);
  colorMode(HSB, 360, 100, 100, 100);
  initAudio();
  startEEG();
  frameRate(30);
}

function draw() {
  background(0,0,5);
  translate(width/2, height);
  // Map EEG to parameters
  angle = map(eegData.theta,0,1,PI/12,PI/3);
  length = map(eegData.alpha,0,1,80,200);
  const depth = floor(map(eegData.beta,0,1,3,6));
  const hueShift = map(eegData.gamma,0,1,0,360);
  stroke((hueShift+frameCount)%360,80,90);
  noFill();
  const grammar = {
    axiom: LSYSTEM.axiom,
    rules: LSYSTEM.rules
  };
  const commands = generate(grammar, depth);
  drawLSystem(commands, length);
  // SOUND: map delta to filter cutoff, gamma to synth density
  filter.frequency.rampTo(map(eegData.delta,0,1,300,2000),0.1);
  if (frameCount%10===0) {
    const note = Tone.Frequency(Math.round(random(40,70)), "midi");
    synth.triggerAttackRelease(note, "8n", undefined, map(eegData.gamma,0,1,0.2,0.8));
  }
}

// Recursive turtle drawing
function drawLSystem(cmd, len) {
  push();
  for (let c of cmd) {
    switch(c){
      case "F":
        line(0,0,0,-len);
        translate(0,-len);
        break;
      case "+":
        rotate(angle);
        break;
      case "-":
        rotate(-angle);
        break;
      case "[":
        push();
        break;
      case "]":
        pop();
        break;
    }
  }
  pop();
}

// Resize handling
function windowResized(){resizeCanvas(windowWidth,windowHeight);}

</script>
</body>
</html>