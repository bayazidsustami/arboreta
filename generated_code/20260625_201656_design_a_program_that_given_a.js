<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Audio‑Reactive Voronoi SVG</title>
<style>
  body,html{margin:0;height:100%;overflow:hidden;background:#111}
  svg{position:absolute;width:100%;height:100%}
</style>
</head>
<body>
<svg id="canvas"></svg>
<script>
(async()=>{

// ---------- Audio setup ----------
const audioCtx = new (window.AudioContext||window.webkitAudioContext)();
const analyser = audioCtx.createAnalyser();
analyser.fftSize = 2048;
const data = new Float32Array(analyser.frequencyBinCount);

// Get microphone (or any live audio source)
const stream = await navigator.mediaDevices.getUserMedia({audio:true});
audioCtx.createMediaStreamSource(stream).connect(analyser);

// ---------- Voronoi helpers ----------
function randPoint(){return {x:Math.random()*w, y:Math.random()*h};}
function distance(a,b){
  const dx=a.x-b.x, dy=a.y-b.y;
  return Math.hypot(dx,dy);
}
function voronoi(points){
  const cells=[];
  for(let i=0;i<points.length;i++){
    const path=[];
    for(let a=0;a<points.length;a++)if(a!==i){
      // perpendicular bisector between points[i] and points[a]
      const mx=(points[i].x+points[a].x)/2;
      const my=(points[i].y+points[a].y)/2;
      const dx=points[a].x-points[i].x;
      const dy=points[a].y-points[i].y;
      const norm=Math.hypot(dx,dy);
      const nx=-dy/norm, ny=dx/norm; // outward normal
      // clip polygon slice
      const newPath=[];
      for(let j=0;j<path.length;j++){
        const P=path[j], Q=path[(j+1)%path.length];
        const sideP = (P.x-mx)*nx+(P.y-my)*ny;
        const sideQ = (Q.x-mx)*nx+(Q.y-my)*ny;
        if(sideP<=0) newPath.push(P);
        if(sideP*sideQ<0){
          const t=sideP/(sideP-sideQ);
          newPath.push({x:P.x+t*(Q.x-P.x), y:P.y+t*(Q.y-P.y)});
        }
      }
      if(path.length===0){
        // start with whole canvas rectangle
        newPath.push({x:0,y:0},{x:w,y:0},{x:w,y:h},{x:0,y:h});
      }
      path.splice(0,path.length,...newPath);
    }
    cells.push(path);
  }
  return cells;
}

// ---------- Visual mapping ----------
const svg=document.getElementById('canvas');
const w=window.innerWidth, h=window.innerHeight;
svg.setAttribute('viewBox',`0 0 ${w} ${h}`);

const POINT_COUNT=12; // number of Voronoi seeds (one per overtone band)
let points=Array.from({length:POINT_COUNT},randPoint);
let cells=voronoi(points);

// create SVG paths
const paths=cells.map(poly=>{
  const p=document.createElementNS('http://www.w3.org/2000/svg','path');
  p.setAttribute('stroke','none');
  svg.appendChild(p);
  return p;
});

// generate a palette based on overtone hierarchy
const baseHue=200; // cool blue
function hueForBand(i){
  // each overtone shifts hue by golden angle
  const golden=137.508;
  return (baseHue + i*golden)%360;
}

// map frequency to band
function freqToBand(f){
  // log‑scale mapping roughly 20 Hz‑20000 Hz
  const logf=Math.log2(f/20);
  const maxBand=Math.log2(20000/20);
  return Math.min(POINT_COUNT-1, Math.floor(logf/maxBand*POINT_COUNT));
}

// animate
function animate(){
  requestAnimationFrame(animate);
  analyser.getFloatFrequencyData(data);
  // find dominant frequency
  let maxIdx=0, maxVal=-Infinity;
  for(let i=0;i<data.length;i++){
    if(data[i]>maxVal){maxVal=data[i];maxIdx=i;}
  }
  const dominantFreq=audioCtx.sampleRate/2 * maxIdx / data.length;
  const band=freqToBand(dominantFreq);

  // move the seed of the active band in a circular orbit
  const t=performance.now()/1000;
  const radius=80;
  points[band].x = w/2 + Math.cos(t*2+band)*radius;
  points[band].y = h/2 + Math.sin(t*2+band)*radius;

  // gently jitter others
  for(let i=0;i<POINT_COUNT;i++)if(i!==band){
    points[i].x += (Math.random()-0.5)*0.5;
    points[i].y += (Math.random()-0.5)*0.5;
    points[i].x = Math.max(0,Math.min(w,points[i].x));
    points[i].y = Math.max(0,Math.min(h,points[i].y));
  }

  cells=voronoi(points);
  // update SVG paths and colors
  cells.forEach((poly,i)=>{
    const d=poly.map((p,idx)=> (idx===0?'M':'L')+p.x+' '+p.y).join('')+'Z';
    paths[i].setAttribute('d',d);
    // gradient hue pulses with tempo (using rms)
    const rms=Math.sqrt(data.reduce((s,v)=>s+v*v,0)/data.length);
    const hue=hueForBand(i);
    const sat=60+40*Math.sin(t+ i);
    const light=50+30*Math.sin(t*0.7 + i);
    const alpha=0.5+0.5*Math.min(1,rms/60);
    paths[i].setAttribute('fill',`hsla(${hue},${sat}%,${light}%,${alpha})`);
  });
}
animate();

})();</script>
</body>
</html>