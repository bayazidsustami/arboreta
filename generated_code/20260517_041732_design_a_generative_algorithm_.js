<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Haunting LED Symphony</title>
<style>body{margin:0;background:#000;overflow:hidden;}canvas{display:block;}</style>
</head>
<body>
<canvas id="c"></canvas>
<script>
// === Configuration ===
const lyricsDB = [
  "Shadows whisper soft goodbye", "Echoes fade in midnight blue", "Starlight drips like rain on stone",
  "Lost voices haunt the empty hall", "Silence bleeds midnight's crimson dawn"
];
const COLORS = ["#092235","#143141","#0b3854","#052F5E","#001B2D"];
const MAX_BRIGHTNESS = 1; // 0-1
const NUM_LIGHTS = 50;

// Get canvas context
const canvas=document.getElementById('c');
const ctx=canvas.getContext('2d');
resize();
window.addEventListener('resize',resize);

// Flashlight objects
class Light {
  constructor(){
    this.x=Math.random()*canvas.width;
    this.y=Math.random()*canvas.height;
    this.radius=10+Math.random()*20;
    this.baseHue=Math.random()*360;
    this.phase=Math.random()*Math.PI*2;
  }
  update(time){
    // Rhythm from pseudo audio: sine waves modulated by time and random phase
    const freq = 0.5+Math.random()*0.5; // Hz
    const val = Math.sin(freq*time+this.phase);
    const brightness = (val+1)/2*MAX_BRIGHTNESS;
    const hue = (this.baseHue + val*30 + time*0.05)%360;
    const color = `hsl(${hue},100%,${50+brightness*30}%)`;
    drawCircle(this.x,this.y,this.radius,color);
  }
}

const lights=[];
for(let i=0;i<NUM_LIGHTS;i++) lights.push(new Light());

// Render loop
let start=performance.now();
function animate(){
  const current=performance.now();
  const elapsed=(current-start)/1000;
  ctx.fillStyle="#000";
  ctx.globalAlpha=0.1; // trail effect
  ctx.fillRect(0,0,canvas.width,canvas.height);
  ctx.globalAlpha=1;
  lights.forEach(l=>l.update(elapsed));
  requestAnimationFrame(animate);
}
animate();

// Utility: draw circle with glow
function drawCircle(x,y,r,color){
  ctx.save();
  ctx.translate(x,y);
  ctx.shadowBlur=20;
  ctx.shadowColor=color;
  ctx.fillStyle=color;
  ctx.beginPath();
  ctx.arc(0,0,r,0,Math.PI*2);
  ctx.fill();
  ctx.restore();
}

// Map lyric lines to lights: each line changes color palette
let lyricIndex=0;
setInterval(()=>{ // every 5s switch lyric-driven hue shifts
  const line=lyricsDB[lyricIndex%lyricsDB.length];
  const hash=Math.abs(hashCode(line))%360;
  lights.forEach(l=>l.baseHue=hash);
  lyricIndex++;
},5000);

// Simple hash function for string
function hashCode(str){let h=0;for(let i=0;i<str.length;i++){h=(h<<5)-h+str.charCodeAt(i);h|=0;}return h;}
function resize(){
  canvas.width=window.innerWidth;
  canvas.height=window.innerHeight;
}
</script>
</body>
</html>