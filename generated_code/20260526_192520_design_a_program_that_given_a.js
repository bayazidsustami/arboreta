<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>MIDI → Fractal SVG</title>
<script src="https://cdn.jsdelivr.net/npm/@tonejs/midi@2.0.27/build/TonejsMIDI.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/tone@14.8.39/build/Tone.min.js"></script>
<style>
body{font-family:sans-serif;text-align:center;background:#111;color:#eee}
#svgContainer{margin:auto;width:80vw;height:80vh}
</style>
</head>
<body>
<h1>Upload a MIDI file</h1>
<input type="file" id="fileInput" accept=".mid,.midi">
<div id="svgContainer"></div>
<script>
// Helper: map value from one range to another
function map(v,inMin,inMax,outMin,outMax){
  return outMin+(v-inMin)*(outMax-outMin)/(inMax-inMin);
}

// Create fractal (simple recursive L‑system) based on tonal/rhythmic data
function createFractal(data){
  const ns="http://www.w3.org/2000/svg";
  const svg=document.createElementNS(ns,"svg");
  svg.setAttribute("viewBox","-200 -200 400 400");
  svg.style.width="100%";
  svg.style.height="100%";
  const path=document.createElementNS(ns,"path");
  path.setAttribute("stroke","#0ff");
  path.setAttribute("fill","none");
  path.setAttribute("stroke-width","1");
  svg.appendChild(path);
  
  // generate points
  const points=[];
  const angleStep=data.density*0.1;
  let angle=0, radius=0;
  for(let i=0;i<data.notes.length;i++){
    const n=data.notes[i];
    radius+=map(n.velocity,0,127,0.5,5);
    angle+=angleStep+map(n.noteNumber%12,0,11,0,0.2);
    const x=radius*Math.cos(angle);
    const y=radius*Math.sin(angle);
    points.push([x,y]);
  }
  // build path string
  const d=points.reduce((s,[x,y],i)=>s+(i?"L":"M")+x.toFixed(2)+" "+y.toFixed(2),"");
  path.setAttribute("d",d);
  return {svg,path,points};
}

// Animate fractal during playback
function animateFractal(fractal,part){
  const {path,points}=fractal;
  let index=0;
  part.callback=(time,ev)=>{
    const p=points[index%points.length];
    path.setAttribute("transform","translate("+p[0]+" "+p[1]+") rotate("+(index%360)+") scale("+map(ev.velocity,0,1,0.5,2)+")");
    index++;
  };
}

// Process MIDI → SVG + Audio
document.getElementById('fileInput').addEventListener('change',async e=>{
  const file=e.target.files[0];
  if(!file)return;
  const array=await file.arrayBuffer();
  const midi=new Tone.Midi(array);
  // Extract flat list of notes with timing
  const notes=[];
  midi.tracks.forEach(t=>t.notes.forEach(n=>notes.push(n)));
  notes.sort((a,b)=>a.time-b.time);
  const density=notes.reduce((c,n)=>c+ (n.duration>0?1/ n.duration:0),0);
  const data={notes, density};
  const fractal=createFractal(data);
  const container=document.getElementById('svgContainer');
  container.innerHTML='';
  container.appendChild(fractal.svg);
  
  // Build Tone.js Part to schedule notes
  const synth=new Tone.PolySynth(Tone.Synth).toDestination();
  const part=new Tone.Part((time,ev)=>{ synth.triggerAttackRelease(ev.noteName,ev.duration,time); }, notes.map(n=>({time:n.time, noteName:n.name, duration:n.duration, velocity:n.velocity/127})));
  part.start(0);
  animateFractal(fractal,part);
  await Tone.start();
  Tone.Transport.start();
});
</script>
</body>
</html>