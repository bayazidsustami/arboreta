<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Kaleido Lisp</title>
<style>body{margin:0;overflow:hidden;background:#000}</style>
</head>
<body>
<video id="v" autoplay playsinline style="display:none"></video>
<canvas id="c"></canvas>
<script>
// grab webcam
const video = document.getElementById('v');
navigator.mediaDevices.getUserMedia({video:{facingMode:"user"}})
  .then(s=>video.srcObject=s).catch(console.error);

// canvas setup
const canvas = document.getElementById('c');
const ctx = canvas.getContext('2d');
function resize(){canvas.width=innerWidth;canvas.height=innerHeight;}
window.onresize=resize;resize();

// simple Lisp‑like interpreter
let ENV = {
  // base primitives
  'draw-rect': ([x,y,w,h,c])=>{ctx.fillStyle=c;ctx.fillRect(x,y,w,h);}
};
function evalLisp(expr){
  if(typeof expr!=='object')return expr;
  const [fn,...args]=expr;
  const f=ENV[fn];
  if(!f) return;
  return f(args.map(evalLisp));
}

// dominant colour extraction (simple averaging)
function dominantColor(){
  ctx.drawImage(video,0,0,canvas.width,canvas.height);
  const img=ctx.getImageData(0,0,canvas.width,canvas.height).data;
  let r=0,g=0,b=0,cnt=0;
  for(let i=0;i<img.length;i+=4){
    r+=img[i];g+=img[i+1];b+=img[i+2];cnt++;
  }
  return `rgb(${r/cnt>>0},${g/cnt>>0},${b/cnt>>0})`;
}

// haiku line generator (three‑syllable‑two‑syllable‑three‑syllable pattern)
const syllables=["crimson","azure","emerald","violet","golden","silver","indigo","scarlet","amber","obsidian"];
function haikuLine(color){
  const rand=()=>syllables[Math.floor(Math.random()*syllables.length)];
  return `${rand()} ${rand()} ${rand()}`;
}

// self‑modifying rule creator
function morph(){
  const col=dominantColor();
  const name=haikuLine(col).replace(/\s+/g,'-'); // function name
  // new function draws a circle with the current palette
  ENV[name]=([x,y,r])=>{ctx.beginPath();ctx.arc(x,y,r,0,2*Math.PI);ctx.fillStyle=col;ctx.fill();};
  // schedule next mutation
  setTimeout(morph,2000);
}

// main render loop: evaluate a tiny program using the newest function
function render(){
  ctx.clearRect(0,0,canvas.width,canvas.height);
  const keys=Object.keys(ENV);
  const fn=keys[Math.floor(Math.random()*keys.length)];
  // program: (fn x y size)
  const prog=[fn,Math.random()*canvas.width,Math.random()*canvas.height,20+Math.random()*30];
  evalLisp(prog);
  requestAnimationFrame(render);
}

// start after video is ready
video.onloadeddata=()=>{
  morph();
  render();
};
</script>
</body>
</html>