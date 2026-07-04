<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Self‑Modifying Color‑Music Turtle</title>
<style>
  body{margin:0;overflow:hidden;background:#111;color:#fff;font-family:sans-serif}
  #canvas{position:absolute;top:0;left:0}
  #info{position:absolute;bottom:0;left:0;padding:5px;background:rgba(0,0,0,0.5)}
</style>
</head>
<body>
<canvas id="canvas"></canvas>
<div id="info">loading…</div>
<script>
// ==== Global helpers ====
const TAU = Math.PI*2;
function rand(min,max){return Math.random()*(max-min)+min}

// ==== Turtle graphics ====
class Turtle{
  constructor(ctx){this.ctx=ctx;this.x=0;this.y=0;this.angle=0;this.pen=true;this.ctx.moveTo(0,0)}
  forward(d){
    const nx=this.x+Math.cos(this.angle)*d;
    const ny=this.y+Math.sin(this.angle)*d;
    if(this.pen){this.ctx.lineTo(nx,ny)}else{this.ctx.moveTo(nx,ny)}
    this.x=nx;this.y=ny;
  }
  right(a){this.angle+=a}
  left(a){this.angle-=a}
  penUp(){this.pen=false}
  penDown(){this.pen=true}
  setColor(c){this.ctx.strokeStyle=c;this.ctx.fillStyle=c}
  reset(){this.ctx.beginPath();this.x=0;this.y=0;this.angle=0;this.ctx.moveTo(0,0)}
}

// ==== Audio ====
class Synth{
  constructor(){this.audio=new (window.AudioContext||window.webkitAudioContext)()}
  note(freq,dur=0.5){
    const o=this.audio.createOscillator();
    const g=this.audio.createGain();
    o.frequency.value=freq; o.type='sine';
    o.connect(g); g.connect(this.audio.destination);
    o.start(); g.gain.setValueAtTime(0.2, this.audio.currentTime);
    g.gain.exponentialRampToValueAtTime(0.001, this.audio.currentTime+dur);
    o.stop(this.audio.currentTime+dur);
  }
}

// ==== Main ====
(async()=>{

  const video=document.createElement('video');
  video.autoplay=true; video.playsInline=true;
  try{await navigator.mediaDevices.getUserMedia({video:true});}
  catch(e){alert('Webcam error');return}
  const stream=await navigator.mediaDevices.getUserMedia({video:{width:320,height:240}});
  video.srcObject=stream;

  const canvas=document.getElementById('canvas');
  const ctx=canvas.getContext('2d');
  const info=document.getElementById('info');

  const off=document.createElement('canvas');
  off.width=80; off.height=60;
  const offctx=off.getContext('2d');

  const turtle=new Turtle(ctx);
  const synth=new Synth();

  // map hue (0‑360) to a note in one octave (C4‑B4)
  function hueToFreq(h){
    const notes=[261.63,277.18,293.66,311.13,329.63,349.23,369.99,392.00,415.30,440.00,466.16,493.88];
    const idx=Math.floor(h/30)%12;
    return notes[idx];
  }

  // self‑modify: replace the script tag's text with a new version that stores last hue
  function selfModify(lastHue){
    const script=document.currentScript;
    const src=script.textContent;
    const newSrc=src.replace(/let lastHue = -?\\d+\\.?\\d*/,'let lastHue = '+lastHue.toFixed(2));
    const newEl=document.createElement('script');
    newEl.textContent=newSrc;
    document.body.appendChild(newEl);
    script.remove();
  }

  let lastHue= -1; // placeholder replaced at runtime

  function draw(){
    // capture frame
    offctx.drawImage(video,0,0,off.width,off.height);
    const img=offctx.getImageData(0,0,off.width,off.height);
    // simple average hue
    let r=0,g=0,b=0;
    const data=img.data;
    for(let i=0;i<data.length;i+=4){
      r+=data[i]; g+=data[i+1]; b+=data[i+2];
    }
    const cnt=data.length/4;
    r/=cnt; g/=cnt; b/=cnt;
    const max=Math.max(r,g,b), min=Math.min(r,g,b);
    let h=0;
    if(max===min) h=0;
    else if(max===r) h=( (g-b)/(max-min) )*60;
    else if(max===g) h=( 2 + (b-r)/(max-min) )*60;
    else h=( 4 + (r-g)/(max-min) )*60;
    if(h<0) h+=360;

    // visual
    ctx.clearRect(0,0,canvas.width,canvas.height);
    ctx.save();
    ctx.translate(canvas.width/2,canvas.height/2);
    turtle.setColor(`hsl(${h},80%,60%)`);
    turtle.forward(100);
    turtle.right(TAU/6);
    turtle.forward(100);
    ctx.stroke();
    ctx.restore();

    // audio
    const freq=hueToFreq(h);
    synth.note(freq,0.2);

    info.textContent=`hue=${h.toFixed(1)}°, freq=${freq.toFixed(1)}Hz`;

    // self‑modify every 30 frames
    if(frame%30===0){
      selfModify(h);
    }

    frame++;
    requestAnimationFrame(draw);
  }
  let frame=0;
  // resize canvas
  function resize(){canvas.width=window.innerWidth;canvas.height=window.innerHeight}
  window.addEventListener('resize',resize);
  resize();
  draw();
})();
</script>
</body>
</html>