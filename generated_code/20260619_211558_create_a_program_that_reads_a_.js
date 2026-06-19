<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Webcam‑Audio‑SVG Kaleidoscope</title>
<style>
  body,html{margin:0;padding:0;background:#111;overflow:hidden}
  #video{display:none}
  #canvas{display:none}
  svg{position:absolute;top:0;left:0;width:100%;height:100%}
</style>
</head>
<body>
<video id="video" autoplay playsinline></video>
<canvas id="canvas"></canvas>
<svg id="svg"></svg>

<script>
// ==== Setup webcam ====
const video = document.getElementById('video');
navigator.mediaDevices.getUserMedia({ video:true, audio:false })
  .then(s=>video.srcObject=s)
  .catch(e=>alert('Webcam error: '+e));

// ==== Canvas for pixel analysis ====
const canvas = document.getElementById('canvas');
const ctx = canvas.getContext('2d');

// ==== Web Audio (Tone.js minimal) ====
class Synth{
  constructor(){
    this.ctx=new (window.AudioContext||window.webkitAudioContext)();
    this.osc=this.ctx.createOscillator();
    this.gain=this.ctx.createGain();
    this.osc.type='sine';
    this.osc.connect(this.gain).connect(this.ctx.destination);
    this.osc.start();
    this.setFreq(220);
  }
  setFreq(f){
    this.osc.frequency.setTargetAtTime(f, this.ctx.currentTime, 0.02);
  }
  setVolume(v){
    this.gain.gain.setTargetAtTime(v, this.ctx.currentTime, 0.02);
  }
}
const synth=new Synth();

// ==== SVG Kaleidoscope ====
const svg=document.getElementById('svg');
const NS='http://www.w3.org/2000/svg';
let paths=[];

// create initial geometric petals
function initKaleido(){
  for(let i=0;i<12;i++){
    const p=document.createElementNS(NS,'path');
    p.setAttribute('stroke','hsl('+i*30+',80%,60%)');
    p.setAttribute('stroke-width','2');
    p.setAttribute('fill','none');
    svg.appendChild(p);
    paths.push(p);
  }
}
initKaleido();

// ==== Mapping hue→note (circle of fifths) ====
const baseFreq=220; // A3
function hueToFreq(h){
  // 12 positions around circle, each a perfect fifth (7 semitones)
  const steps=Math.round(h/30)%12; // 0‑11
  const semitone = (steps*7)%12;
  return baseFreq*Math.pow(2, semitone/12);
}

// ==== Main loop ====
function tick(){
  if(video.readyState===video.HAVE_ENOUGH_DATA){
    // size canvas to video
    if(canvas.width!==video.videoWidth){
      canvas.width=video.videoWidth;
      canvas.height=video.videoHeight;
    }
    ctx.drawImage(video,0,0);
    const {data}=ctx.getImageData(0,0,canvas.width,canvas.height);
    // compute average hue
    let r=0,g=0,b=0, cnt=0;
    for(let i=0;i<data.length;i+=4){
      r+=data[i]; g+=data[i+1]; b+=data[i+2]; cnt++;
    }
    r/=cnt; g/=cnt; b/=cnt;
    const max=Math.max(r,g,b), min=Math.min(r,g,b);
    let hue=0;
    if(max!==min){
      const d=max-min;
      if(max===r) hue=((g-b)/d)%6;
      else if(max===g) hue=((b-r)/d)+2;
      else hue=((r-g)/d)+4;
      hue*=60;
      if(hue<0) hue+=360;
    }
    // audio
    const freq=hueToFreq(hue);
    synth.setFreq(freq);
    synth.setVolume(0.2+0.3*Math.abs(Math.sin(Date.now()*0.001)));
    // SVG driven by waveform (simple sine for demo)
    const t=Date.now()*0.001;
    paths.forEach((p,i)=>{
      const a=i*Math.PI/6;
      const r=150+50*Math.sin(t+i);
      const x1=window.innerWidth/2+r*Math.cos(a);
      const y1=window.innerHeight/2+r*Math.sin(a);
      const x2=window.innerWidth/2+r*Math.cos(a+Math.PI);
      const y2=window.innerHeight/2+r*Math.sin(a+Math.PI);
      p.setAttribute('d',`M${x1},${y1} Q${window.innerWidth/2+80*Math.cos(t*2),${window.innerHeight/2+80*Math.sin(t*2)} ${x2},${y2}`);
    });
  }
  requestAnimationFrame(tick);
}
tick();
</script>
</body>
</html>