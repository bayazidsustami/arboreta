<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Live Audio Voronoi GIF</title>
<style>body{margin:0;overflow:hidden;background:#111;color:#fff;font-family:sans-serif;}#info{position:absolute;top:10px;left:10px;z-index:10;}</style>
</head>
<body>
<div id="info">Allow microphone access. GIF will appear after 10 seconds.</div>
<canvas id="c"></canvas>
<script src="https://cdnjs.cloudflare.com/ajax/libs/gif.js/0.2.0/gif.js"></script>
<script>
(async()=>{

// ==== Setup canvas & audio ====
const canvas=document.getElementById('c');
const ctx=canvas.getContext('2d');
const resize=()=>{canvas.width=window.innerWidth;canvas.height=window.innerHeight;};
resize(); window.onresize=resize;

const stream=await navigator.mediaDevices.getUserMedia({audio:true});
const audioCtx=new (window.AudioContext||window.webkitAudioContext)();
const src=audioCtx.createMediaStreamSource(stream);
const analyser=audioCtx.createAnalyser();
analyser.fftSize=2048;
src.connect(analyser);
const buffer=new Float32Array(analyser.fftSize);
const freqData=new Uint8Array(analyser.frequencyBinCount);

// ==== Helper DSP functions ====
function autocorr(buf,rate){
  let maxShift=buf.length/2, bestOffset=-1, bestCorr=0;
  for(let offset=0; offset<maxShift; offset++){
    let corr=0;
    for(let i=0;i<maxShift;i++) corr+=buf[i]*buf[i+offset];
    if(corr>bestCorr){bestCorr=corr;bestOffset=offset;}
  }
  if(bestOffset===-1) return 0;
  const fundamental=rate/bestOffset;
  const midi=Math.round(12*Math.log2(fundamental/440)+69);
  return {freq:fundamental,midi};
}
function spectralCentroid(freqArr){
  let sumMag=0,sumFreq=0;
  for(let i=0;i<freqArr.length;i++){
    const mag=freqArr[i];
    sumMag+=mag;
    sumFreq+=mag*i;
  }
  return sumMag?sumFreq/sumMag:0;
}
let lastEnergy=0, onsetCount=0;
function detectOnset(buf){
  let energy=0;
  for(let i=0;i<buf.length;i++) energy+=buf[i]*buf[i];
  const diff=energy-lastEnergy;
  lastEnergy=energy;
  if(diff>0.0005) onsetCount++;
}

// ==== Voronoi utilities (simple mock) ====
function drawCell(x,y,size,shape,color,rotSpeed,frame){
  ctx.save();
  ctx.translate(x,y);
  ctx.rotate(rotSpeed*frame);
  ctx.fillStyle=color;
  ctx.beginPath();
  if(shape===0){ // circle
    ctx.arc(0,0,size,0,Math.PI*2);
  }else if(shape===1){ // triangle
    for(let i=0;i<3;i++){
      const a=i*2*Math.PI/3;
      ctx.lineTo(Math.cos(a)*size,Math.sin(a)*size);
    }
  }else{ // square
    ctx.rect(-size,-size,size*2,size*2);
  }
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

// ==== GIF recorder ====
const gif=new GIF({workers:2,quality:10,workerScript:'https://cdnjs.cloudflare.com/ajax/libs/gif.js/0.2.0/gif.worker.js'});
let frameNum=0;
const captureFrames=10*30; // 10 seconds @30 fps

function render(){ // called ~60 fps
  analyser.getFloatTimeDomainData(buffer);
  analyser.getByteFrequencyData(freqData);
  const pitch=autocorr(buffer,audioCtx.sampleRate);
  const centroid=spectralCentroid(freqData);
  const density=onsetCount/ (frameNum||1);
  detectOnset(buffer);
  // map pitch to shape
  const shape=Math.abs(pitch.midi)%3; // 0,1,2
  const size=10+centroid*0.05; // size modulated by centroid
  const hue=(pitch.midi%12)*30;
  const color=`hsl(${hue},80%,${50+20*density}%)`;
  const rotSpeed=0.01+0.05*density;
  ctx.clearRect(0,0,canvas.width,canvas.height);
  // simple grid of cells
  const cols=Math.ceil(canvas.width/ (size*4));
  const rows=Math.ceil(canvas.height/ (size*4));
  for(let i=0;i<cols;i++){
    for(let j=0;j<rows;j++){
      const x=i*size*4+size*2;
      const y=j*size*4+size*2;
      drawCell(x,y,size,shape,color,rotSpeed,frameNum);
    }
  }
  // capture frame for GIF
  if(frameNum<captureFrames){
    gif.addFrame(ctx, {copy:true, delay:1000/30});
  }else if(frameNum===captureFrames){
    gif.on('finished',blob=>{
      const url=URL.createObjectURL(blob);
      const img=new Image();
      img.onload=()=>{ // reverse playback sync
        const revCanvas=document.createElement('canvas');
        revCanvas.width=canvas.width; revCanvas.height=canvas.height;
        const revCtx=revCanvas.getContext('2d');
        const frames=gif.frames;
        let revIdx=frames.length-1;
        const revLoop=()=>{ // render reversed frames
          revCtx.putImageData(frames[revIdx].imageData,0,0);
          ctx.drawImage(revCanvas,0,0);
          revIdx--;
          if(revIdx<0) revIdx=frames.length-1;
          requestAnimationFrame(revLoop);
        };
        revLoop();
      };
      img.src=url;
    });
    gif.render();
  }
  frameNum++;
  requestAnimationFrame(render);
}
render();

})();</script>
</body>
</html>