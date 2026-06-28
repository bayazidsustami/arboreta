<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Skyline → MIDI → L‑System</title>
<style>
  body,html{margin:0;overflow:hidden;background:#111;color:#eee;font-family:sans-serif}
  #canvas{display:block}
  #upload{position:absolute;top:10px;left:10px;z-index:10}
</style>
</head>
<body>
<input type="file" id="upload" accept="image/*">
<canvas id="canvas"></canvas>
<script src="https://cdnjs.cloudflare.com/ajax/libs/tone/14.8.35/Tone.js"></script>
<script>
// ---------- Helpers ----------
function getImageData(img){
  const off=document.createElement('canvas');
  off.width=img.width;off.height=img.height;
  const ctx=off.getContext('2d');
  ctx.drawImage(img,0,0);
  return ctx.getImageData(0,0,off.width,off.height);
}
function silhouette(data){
  const w=data.width,h=data.height;
  const out=new Uint8ClampedArray(w*h);
  for(let x=0;x<w;x++){
    // scan from bottom up to find first opaque pixel -> skyline height
    for(let y=h-1;y>=0;y--){
      const i=(y*w+x)*4;
      const a=data.data[i+3];
      if(a>127){
        out[x]=h-y;break;
      }
    }
  }
  return {heights:out,width:w,height:h};
}
function heightsToNotes(heights){
  const notes=[];
  const scale=['C4','D4','E4','F4','G4','A4','B4','C5']; // simple major
  const max=Math.max(...heights);
  for(let i=0;i<heights.length;i++){
    const h=heights[i];
    if(!h)continue;
    const pitch=scale[Math.floor((h/max)*scale.length)];
    const dur=0.1+0.4*(h/max);
    const vel=0.3+0.7*(h/max);
    notes.push({time:i*0.1,pitch,dur,vel});
  }
  return notes;
}

// ---------- L‑System ----------
class LSystem{
  constructor(axiom, rules){
    this.sentence=axiom;
    this.rules=rules;
  }
  iterate(){
    let next='';
    for(const ch of this.sentence){
      next+=this.rules[ch]||ch;
    }
    this.sentence=next;
  }
}
function drawLSystem(ctx,lsys,angle,len){
  ctx.save();
  ctx.translate(ctx.canvas.width/2,ctx.canvas.height);
  ctx.strokeStyle='#fff';
  ctx.lineWidth=1;
  const stack=[];
  for(const ch of lsys.sentence){
    switch(ch){
      case 'F':
        ctx.beginPath();
        ctx.moveTo(0,0);
        ctx.lineTo(0,-len);
        ctx.stroke();
        ctx.translate(0,-len);
        break;
      case '+':
        ctx.rotate(angle);
        break;
      case '-':
        ctx.rotate(-angle);
        break;
      case '[':
        stack.push({x:ctx.getTransform().e,y:ctx.getTransform().f,rot:ctx.getTransform().b});
        ctx.save();
        break;
      case ']':
        ctx.restore();
        break;
    }
  }
  ctx.restore();
}

// ---------- Main ----------
const canvas=document.getElementById('canvas');
const ctx=canvas.getContext('2d');
function resize(){canvas.width=window.innerWidth;canvas.height=window.innerHeight;}
window.addEventListener('resize',resize);
resize();

let synth=new Tone.PolySynth(Tone.Synth).toDestination();
let now=Tone.now();

document.getElementById('upload').onchange=async e=>{
  const file=e.target.files[0];
  if(!file)return;
  const img=new Image();
  img.src=URL.createObjectURL(file);
  await img.decode();
  const src=getImageData(img);
  const {heights,width}=silhouette(src);
  const notes=heightsToNotes(heights);
  // schedule notes
  notes.forEach(n=>synth.triggerAttackRelease(n.pitch,n.dur,n.time+now,n.vel));
  // build L‑system based on notes count
  const axiom='F';
  const rules={'F':'F[+F]F[-F]F'};
  const lsys=new LSystem(axiom,rules);
  const iterations=Math.min(5,Math.floor(notes.length/20)+1);
  for(let i=0;i<iterations;i++)lsys.iterate();
  // animate sync to transport
  Tone.Transport.start();
  function animate(){
    ctx.clearRect(0,0,canvas.width,canvas.height);
    // color evolves with time
    const hue=(Tone.now()*30)%360;
    ctx.strokeStyle=`hsl(${hue},80%,60%)`;
    drawLSystem(ctx,lsys,Math.PI/7,canvas.height/30);
    requestAnimationFrame(animate);
  }
  animate();
};
</script>
</body>
</html>