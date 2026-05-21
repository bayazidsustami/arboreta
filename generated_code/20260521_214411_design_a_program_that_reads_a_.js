<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Audio‑Mandala</title>
<style>
  body,html{margin:0;height:100%;background:#111;overflow:hidden}
  #svg{width:100%;height:100%}
  #msg{position:absolute;color:#777;top:50%;left:50%;transform:translate(-50%,-50%);font-family:sans-serif}
</style>
</head>
<body>
<div id="msg">Allow microphone access…</div>
<svg id="svg"></svg>
<script>
// ==== Setup audio ====
navigator.mediaDevices.getUserMedia({audio:true}).then(stream=>{
  const audioCtx=new (window.AudioContext||window.webkitAudioContext)();
  const source=audioCtx.createMediaStreamSource(stream);
  const analyser=audioCtx.createAnalyser();
  analyser.fftSize=2048;
  source.connect(analyser);
  const data=new Uint8Array(analyser.frequencyBinCount);
  document.getElementById('msg').remove();
  start(analyser,data);
}).catch(()=>alert('Microphone permission denied'));

// ==== Core rendering ====
function start(analyser,data){
  const svg=document.getElementById('svg');
  const width=window.innerWidth, height=window.innerHeight;
  const cx=width/2, cy=height/2;
  const maxRadius=Math.min(cx,cy)*0.9;
  const bandCount=64;               // number of frequency bands → brushstrokes
  const angleStep= (Math.PI*2)/bandCount;
  let t=0;                          // for evolving colors
  const svgNS='http://www.w3.org/2000/svg';

  // pre‑create path elements for reuse → better perf
  const paths=[];
  for(let i=0;i<bandCount;i++){
    const p=document.createElementNS(svgNS,'path');
    p.setAttribute('fill','none');
    svg.appendChild(p);
    paths.push(p);
  }

  function hueFromFreq(idx,amp){
    // map index to hue, wobble with amplitude
    return (idx/bandCount*360 + amp*0.5 + t*20)%360;
  }

  function draw(){
    requestAnimationFrame(draw);
    analyser.getByteFrequencyData(data);
    const step=Math.floor(data.length/bandCount);
    for(let i=0;i<bandCount;i++){
      const amp=data[i*step];                // 0‑255
      const radius=amp/255*maxRadius;        // amplitude → length
      const angle=i*angleStep;
      const x2=cx+Math.cos(angle)*radius;
      const y2=cy+Math.sin(angle)*radius;
      const path=paths[i];
      const d=`M${cx},${cy} L${x2},${y2}`;
      path.setAttribute('d',d);
      const hue=hueFromFreq(i,amp);
      const sat=80+amp*0.1;
      const light=40+amp*0.2;
      path.setAttribute('stroke',`hsl(${hue},${sat}%,${light}%)`);
      path.setAttribute('stroke-width',amp/64+0.5);   // thicker with amplitude
      path.setAttribute('stroke-linecap','round');
    }
    t+=0.016;
    // slowly rotate the whole mandala for self‑similar motion
    const rot=(t*30)%360;
    svg.setAttribute('transform',`rotate(${rot} ${cx} ${cy})`);
  }
  draw();
}
</script>
</body>
</html>