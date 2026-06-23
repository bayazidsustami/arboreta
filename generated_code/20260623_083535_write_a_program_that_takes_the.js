<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Poem Audio → CA Visualizer</title>
<style>
  body,html{margin:0;background:#000;overflow:hidden}
  canvas{display:block}
  #controls{position:absolute;top:10px;left:10px;color:#fff;z-index:10}
  button{margin-right:5px}
</style>
</head>
<body>
<div id="controls">
  <input type="file" id="file" accept="audio/*">
  <button id="play">Play</button>
  <button id="rewind">⏪</button>
  <button id="forward">⏩</button>
</div>
<canvas id="c"></canvas>
<script>
// ==== Setup canvas & audio context ====
const canvas=document.getElementById('c'), ctx=canvas.getContext('2d');
function resize(){canvas.width=innerWidth;canvas.height=innerHeight}
resize();addEventListener('resize',resize);
const AudioContext=window.AudioContext||window.webkitAudioContext;
const audioCtx=new AudioContext();
let sourceNode=null, analyser=new AnalyserNode(audioCtx,{fftSize:2048});
let dataArray=new Uint8Array(analyser.frequencyBinCount);
let buffer=null, startTime=0, pausedAt=0, isPlaying=false;

// ==== Simple sentiment & meter heuristics ====
function sentimentFromSpectrum(spectrum){
  // high frequencies = excitement (+), low = calm (-)
  let sum=0, cnt=0;
  for(let i=0;i<spectrum.length;i++){
    sum+=spectrum[i]*i;
    cnt+=spectrum[i];
  }
  return cnt? (sum/cnt - spectrum.length/2)/(spectrum.length/2) : 0;
}
function meterFromAmplitude(timeDomain){
  // count zero‑crossings per frame as a crude meter proxy
  let crossings=0;
  for(let i=1;i<timeDomain.length;i++){
    if((timeDomain[i-1]<128)!=(timeDomain[i]<128)) crossings++;
  }
  return crossings/timeDomain.length;
}

// ==== Cellular Automaton ====
const CA = {
  width: 200,
  height: 200,
  cells: [],
  next: [],
  init(){
    this.cells=new Uint8Array(this.width*this.height);
    this.next=new Uint8Array(this.width*this.height);
    for(let i=0;i<this.cells.length;i++) this.cells[i]=Math.random()<0.5?1:0;
  },
  step(rule=30){
    // simple 1‑D automaton stretched vertically
    for(let y=0;y<this.height;y++){
      const row=y*this.width;
      for(let x=0;x<this.width;x++){
        const left=this.cells[row+((x-1+this.width)%this.width)];
        const cur=this.cells[row+x];
        const right=this.cells[row+((x+1)%this.width)];
        const idx=(left<<2)|(cur<<1)|right;
        this.next[row+x]= (rule>>idx)&1;
      }
    }
    [this.cells,this.next]=[this.next,this.cells];
  },
  draw(palette){
    const img=ctx.createImageData(this.width,this.height);
    const d=img.data;
    for(let i=0;i<this.cells.length;i++){
      const col=this.cells[i]?palette[1]:palette[0];
      d[i*4]=col.r;d[i*4+1]=col.g;d[i*4+2]=col.b;d[i*4+3]=255;
    }
    ctx.putImageData(img,0,0);
    // stretch to fill canvas
    ctx.imageSmoothingEnabled=false;
    ctx.drawImage(canvas,0,0,canvas.width,canvas.height);
  }
};
CA.init();

// ==== Palette driven by meter & sentiment ====
function paletteFromMood(meter,sent){
  // meter influences hue speed, sentiment influences lightness
  const baseHue=(performance.now()/1000*meter*60)%360;
  const light=0.5+sent*0.4;
  const toRGB=h=>{const c=hsl2rgb(h,0.6,light);return{r:c[0],g:c[1],b:c[2]}}
  return [toRGB((baseHue+180)%360), toRGB(baseHue)];
}
function hsl2rgb(h,s,l){
  h/=360;
  const q=l<0.5?l*(1+s):l+s-l*s;
  const p=2*l-q;
  const rgb=[h+1/3,h,h-1/3].map(t=>{if(t<0)t+=1; if(t>1)t-=1; if(t<1/6)return p+(q-p)*6*t; if(t<1/2)return q; if(t<2/3)return p+(q-p)*(2/3-t)*6; return p;});
  return rgb.map(v=>Math.round(v*255));
}

// ==== Main render loop ====
function render(){
  if(isPlaying){
    analyser.getByteFrequencyData(dataArray);
    const sentiment=sentimentFromSpectrum(dataArray);
    analyser.getByteTimeDomainData(dataArray);
    const meter=meterFromAmplitude(dataArray);
    const pal=paletteFromMood(meter,sentiment);
    const rule=Math.round( (sentiment+1)/2 * 255 ); // map sentiment to rule 0‑255
    CA.step(rule);
    CA.draw(pal);
  }
  requestAnimationFrame(render);
}
requestAnimationFrame(render);

// ==== Audio handling ====
document.getElementById('file').onchange=async e=>{
  const file=e.target.files[0];
  if(!file) return;
  const arr=await file.arrayBuffer();
  buffer=await audioCtx.decodeAudioData(arr);
  if(sourceNode) sourceNode.disconnect();
  sourceNode=audioCtx.createBufferSource();
  sourceNode.buffer=buffer;
  sourceNode.loop=true;
  sourceNode.connect(analyser).connect(audioCtx.destination);
};
document.getElementById('play').onclick=()=>{
  if(!buffer) return;
  if(!isPlaying){
    audioCtx.resume();
    if(!sourceNode) return;
    sourceNode.start(0,pausedAt);
    startTime=audioCtx.currentTime-pausedAt;
    isPlaying=true;
  }else{
    sourceNode.stop();
    pausedAt=audioCtx.currentTime-startTime;
    isPlaying=false;
    // recreate source for later resume
    sourceNode=audioCtx.createBufferSource();
    sourceNode.buffer=buffer;
    sourceNode.loop=true;
    sourceNode.connect(analyser).connect(audioCtx.destination);
  }
};
document.getElementById('rewind').onclick=()=>{ // jump back 5s
  if(!buffer) return;
  const newPos=Math.max(0,pausedAt-5);
  if(isPlaying){
    sourceNode.stop();
    sourceNode=audioCtx.createBufferSource();
    sourceNode.buffer=buffer;
    sourceNode.loop=true;
    sourceNode.connect(analyser).connect(audioCtx.destination);
    sourceNode.start(0,newPos);
    startTime=audioCtx.currentTime-newPos;
  }
  pausedAt=newPos;
};
document.getElementById('forward').onclick=()=>{ // jump forward 5s
  if(!buffer) return;
  const newPos=Math.min(buffer.duration,pausedAt+5);
  if(isPlaying){
    sourceNode.stop();
    sourceNode=audioCtx.createBufferSource();
    sourceNode.buffer=buffer;
    sourceNode.loop=true;
    sourceNode.connect(analyser).connect(audioCtx.destination);
    sourceNode.start(0,newPos);
    startTime=audioCtx.currentTime-newPos;
  }
  pausedAt=newPos;
};
</script>
</body>
</html>