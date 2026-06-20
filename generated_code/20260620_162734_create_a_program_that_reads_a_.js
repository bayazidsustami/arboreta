<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Audio‑L‑System Kaleidoscope</title>
<style>
  body,html{margin:0;background:#111;overflow:hidden}
  canvas{display:none}
  #svg{position:absolute;top:0;left:0;width:100%;height:100%}
</style>
</head>
<body>
<video id="cam" autoplay muted playsinline style="display:none"></video>
<canvas id="tmp"></canvas>
<svg id="svg" viewBox="0 0 800 800"></svg>

<script type="module">
import * as tf from 'https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@4.10.0/dist/tf.min.js';
import * as facemesh from 'https://cdn.jsdelivr.net/npm/@tensorflow-models/face-landmarks-detection';
import * as pitch from 'https://cdn.jsdelivr.net/npm/@tonejs/pitch-detect@1.0.2/dist/pitchdetect.min.js';

//---- Global objects ---------------------------------------------------------
const video = document.getElementById('cam');
const canvas = document.getElementById('tmp');
const ctx = canvas.getContext('2d');
const svg = document.getElementById('svg');
const width = 800, height = 800;
svg.setAttribute('width', width);
svg.setAttribute('height', height);

// L‑system basics
const axiom = 'F';
const rules = {};               // filled dynamically from pitch
let current = axiom;
let iteration = 0;

// Mapping pitch → rule (simple: each semitone gets a different angle)
function pitchToRule(freq) {
  if (!freq) return null;
  const semitone = Math.round(12 * Math.log2(freq / 440)) + 69; // MIDI note
  const angle = (semitone % 12) * 30; // 0‑330°
  const cmd = `F+[-F${angle}][+F${angle}]`;
  rules['F'] = cmd;
}

// Draw L‑system onto SVG (kaleidoscopic by rotating copies)
function renderLSystem() {
  svg.innerHTML = '';
  const path = document.createElementNS('http://www.w3.org/2000/svg','path');
  const stack = [];
  let x=width/2, y=height/2, angle=0;
  let d = 5; // step length
  let dPath = `M${x},${y}`;
  for (let ch of current) {
    if (ch==='F') {
      const rad = angle*Math.PI/180;
      x += d*Math.cos(rad);
      y += d*Math.sin(rad);
      dPath+=` L${x},${y}`;
    } else if (ch==='+') {
      const a = parseInt(ch.next?.match(/\d+/))||15;
      angle+=a;
    } else if (ch==='-') {
      const a = parseInt(ch.next?.match(/\d+/))||15;
      angle-=a;
    } else if (ch==='[') {
      stack.push({x,y,angle});
    } else if (ch===']') {
      const s=stack.pop();
      x=s.x; y=s.y; angle=s.angle;
    }
  }
  path.setAttribute('d',dPath);
  path.setAttribute('stroke','white');
  path.setAttribute('fill','none');
  path.setAttribute('stroke-width',2);
  svg.appendChild(path);

  // Kaleidoscope: rotate copies
  const copies = 6;
  for(let i=1;i<copies;i++){
    const clone = path.cloneNode();
    const rot = (360/copies)*i;
    clone.setAttribute('transform',`rotate(${rot} ${width/2} ${height/2})`);
    svg.appendChild(clone);
  }
}

// Update visual style from facial expression
function applyFaceStyle(landmarks){
  // simple: mouth openness controls thickness, eye openness controls hue
  const mouth = landmarks[13]; // lower lip
  const mouthTop = landmarks[0];
  const eyeL = landmarks[33];
  const eyeR = landmarks[263];
  const mouthOpen = Math.hypot(mouth[0]-mouthTop[0], mouth[1]-mouthTop[1]);
  const eyeDist = Math.hypot(eyeL[0]-eyeR[0], eyeL[1]-eyeR[1]);
  const stroke = Math.min(10, Math.max(1, mouthOpen/2));
  const hue = Math.round((eyeDist/100)*360)%360;
  svg.querySelectorAll('path').forEach(p=>{p.setAttribute('stroke-width',stroke);p.setAttribute('stroke',`hsl(${hue},80%,60%)`);});
}

// Main loop ---------------------------------------------------------------
let detector, faceModel;
async function init(){
  // webcam
  const stream = await navigator.mediaDevices.getUserMedia({video:{width:640,height:480},audio:true});
  video.srcObject = stream;
  await video.play();

  // set canvas size
  canvas.width = video.videoWidth;
  canvas.height = video.videoHeight;

  // audio pitch
  const audioCtx = new (window.AudioContext||window.webkitAudioContext)();
  const source = audioCtx.createMediaStreamSource(stream);
  const analyser = audioCtx.createAnalyser();
  source.connect(analyser);
  const pitchDetect = new pitch.PitchDetector(analyser, audioCtx.sampleRate);
  
  // face mesh
  faceModel = await facemesh.load(facemesh.SupportedPackages.mediapipeFacemesh);
  
  // animation
  function loop(){
    // draw current video frame to canvas for face analysis
    ctx.drawImage(video,0,0,canvas.width,canvas.height);
    const img = ctx.getImageData(0,0,canvas.width,canvas.height);
    faceModel.estimateFaces({input: img}).then(faces=>{
      if(faces.length){
        applyFaceStyle(faces[0].keypoints);
      }
    });

    // pitch detection
    const freq = pitchDetect.getPitch();
    if(freq){
      pitchToRule(freq);
      // iterate L‑system every 30 frames ~ 0.5s
      if(++iteration%30===0){
        current = current.replace(/F/g, rules['F']||'F');
        renderLSystem();
      }
    }
    requestAnimationFrame(loop);
  }
  renderLSystem(); // initial draw
  loop();
}
init();
</script>
</body>
</html>