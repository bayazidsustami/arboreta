<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Synesthetic Mandala</title>
<style>
  body,html{margin:0;height:100%;overflow:hidden;background:#111;color:#fff;font-family:sans-serif}
  #canvas{position:absolute;top:0;left:0;width:100%;height:100%}
  #info{position:absolute;bottom:5px;left:5px;font-size:12px}
</style>
</head>
<body>
<canvas id="canvas"></canvas>
<div id="info">Click to start</div>
<script>
(async()=>{

// ==== Setup video stream ====
const video=document.createElement('video');
video.autoplay=true;video.playsInline=true;
try{
  const stream=await navigator.mediaDevices.getUserMedia({video:{facingMode:"environment"}});
  video.srcObject=stream;
}catch(e){alert('Camera error');return;}

// ==== Canvas & Audio ====
const canvas=document.getElementById('canvas');
const ctx=canvas.getContext('2d');
const audioCtx=new (window.AudioContext||window.webkitAudioContext)();
let tempo=120; // BPM, will vary with brightness

// resize handler
function resize(){canvas.width=innerWidth;canvas.height=innerHeight;}
resize();addEventListener('resize',resize);

// ==== Helper: simple K‑means (k=5) ====
function getPalette(imgData,k=5){
  const data=imgData.data, n=data.length/4;
  // random initial centroids
  let centroids=[];
  for(let i=0;i<k;i++){
    const idx=Math.floor(Math.random()*n);
    centroids.push([data[idx*4],data[idx*4+1],data[idx*4+2]]);
  }
  for(let iter=0;iter<10;iter++){
    const clusters=Array.from({length:k},()=>[]);
    for(let i=0;i<n;i++){
      const p=[data[i*4],data[i*4+1],data[i*4+2]];
      let best=0, bestDist=Infinity;
      for(let c=0;c<k;c++){
        const d=(p[0]-centroids[c][0])**2+(p[1]-centroids[c][1])**2+(p[2]-centroids[c][2])**2;
        if(d<bestDist){bestDist=d;best=c;}
      }
      clusters[best].push(p);
    }
    centroids=clusters.map(cl=>cl.length?cl.reduce((a,b)=>[a[0]+b[0],a[1]+b[1],a[2]+b[2]],[0,0,0]).map(v=>v/cl.length):[0,0,0]);
  }
  return centroids.map(c=>`rgb(${c[0]|0},${c[1]|0},${c[2]|0})`);
}

// ==== Map hue to scale degree ====
function hueToDegree(h){
  const scale=[0,2,4,5,7,9,11]; // major diatonic
  return scale[Math.floor(h/360*scale.length)]%12;
}

// ==== Build chord from palette ====
function paletteToChord(palette){
  const notes=palette.map(col=>{
    const ctx=document.createElement('canvas').getContext('2d');
    ctx.fillStyle=col;const rgb=ctx.fillStyle.match(/\d+/g).map(Number);
    const hue=rgbToHsl(...rgb)[0];
    return 60+ hueToDegree(hue); // MIDI note around middle C
  });
  // ensure unique intervals
  const root=notes[0];
  const intervals=notes.map(n=> (n-root+12)%12).sort((a,b)=>a-b);
  return {root,intervals};
}

// ==== RGB → HSL helper ====
function rgbToHsl(r,g,b){
  r/=255;g/=255;b/=255;
  const max=Math.max(r,g,b),min=Math.min(r,g,b);
  let h, s, l=(max+min)/2;
  if(max===min){h=s=0;}
  else{
    const d=max-min;
    s=l>0.5?d/(2-max-min):d/(max+min);
    switch(max){
      case r:h=(g-b)/d+(g<b?6:0);break;
      case g:h=(b-r)/d+2;break;
      case b:h=(r-g)/d+4;break;
    }
    h*=60;
  }
  return [h,s,l];
}

// ==== Play chord ====
function playChord(chord){
  const now=audioCtx.currentTime;
  chord.intervals.forEach(int=> {
    const osc=audioCtx.createOscillator();
    const gain=audioCtx.createGain();
    const freq=440*Math.pow(2,(chord.root+int-69)/12);
    osc.type='sine';
    osc.frequency.value=freq;
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    gain.gain.setValueAtTime(0,now);
    gain.gain.linearRampToValueAtTime(0.15,now+0.01);
    gain.gain.exponentialRampToValueAtTime(0.001,now+1.5);
    osc.start(now);
    osc.stop(now+1.6);
  });
}

// ==== Draw mandala layer derived from chord ====
function drawLayer(chord){
  const {width,height}=canvas;
  const cx=width/2, cy=height/2;
  const maxR=Math.min(width,height)/2;
  const layer= Math.random()*0.5+0.5;
  const rot=Math.random()*Math.PI*2;
  const speed= (chord.intervals.reduce((a,b)=>a+b,0)/chord.intervals.length+1)*0.001;
  ctx.save();
  ctx.translate(cx,cy);
  ctx.rotate(rot);
  const steps=chord.intervals.length*12;
  for(let i=0;i<steps;i++){
    const angle=i*2*Math.PI/steps;
    const r=maxR*layer*Math.abs(Math.sin(chord.intervals[i%chord.intervals.length]*Math.PI/12+performance.now()*speed));
    ctx.beginPath();
    ctx.arc(r*Math.cos(angle),r*Math.sin(angle),r*0.05,0,2*Math.PI);
    ctx.fillStyle=`hsl(${(chord.root*30+i*12)%360},70%,60%)`;
    ctx.fill();
  }
  ctx.restore();
}

// ==== Main loop ====
let frameCount=0;
function loop(){
  if(video.readyState===video.HAVE_ENOUGH_DATA){
    // capture frame
    const temp=document.createElement('canvas');
    const tctx=temp.getContext('2d');
    temp.width=video.videoWidth;
    temp.height=video.videoHeight;
    tctx.drawImage(video,0,0);
    const imgData=tctx.getImageData(0,0,temp.width,temp.height);
    const palette=getPalette(imgData,5);
    const chord=paletteToChord(palette);
    playChord(chord);
    drawLayer(chord);
    // adjust tempo based on average brightness
    const avgBright=imgData.data.reduce((s,i,idx)=> (idx%4===0)?s+i: s,0)/(imgData.width*imgData.height);
    tempo=60+avgBright/2;
  }
  frameCount++;
  requestAnimationFrame(loop);
}

// ==== Start on click ====
document.getElementById('info').onclick=()=>{audioCtx.resume();document.getElementById('info').style.display='none';loop();};

})();
</script>
</body>
</html>