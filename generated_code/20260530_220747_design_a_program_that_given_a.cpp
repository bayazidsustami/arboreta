#include <iostream>
#include <string>

int main() {
    // Emit a self‑contained HTML page.
    std::cout << R"(<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Audio‑Driven Rube‑Goldberg</title>
<style>
  body{margin:0;background:#111;color:#eee;font-family:sans-serif;overflow:hidden}
  #svgRoot{width:100vw;height:100vh}
  #poem{position:absolute;bottom:10px;left:10px;font-size:1.2em;max-width:40%}
</style>
</head>
<body>
<svg id="svgRoot" viewBox="0 0 800 600"></svg>
<div id="poem"></div>
<script>
// ---- Audio analysis -------------------------------------------------
const audioCtx = new (window.AudioContext||window.webkitAudioContext)();
navigator.mediaDevices.getUserMedia({audio:true}).then(stream=>{
  const source = audioCtx.createMediaStreamSource(stream);
  const analyser = audioCtx.createAnalyser();
  analyser.fftSize = 256;
  source.connect(analyser);
  const freqData = new Uint8Array(analyser.frequencyBinCount);
  // ---- Visual elements ------------------------------------------------
  const svg = document.getElementById('svgRoot');
  const gears = [];
  const colours = ['#ff5555','#ffb86c','#f1fa8c','#50fa7b','#8be9fd','#bd93f9','#ff79c6'];
  const N = 8; // number of frequency bands / gears
  for(let i=0;i<N;i++){
    const g=document.createElementNS('http://www.w3.org/2000/svg','g');
    const r=30;
    const cx=100+ i*80;
    const cy=300;
    const circle=document.createElementNS('http://www.w3.org/2000/svg','circle');
    circle.setAttribute('cx',0);
    circle.setAttribute('cy',0);
    circle.setAttribute('r',r);
    circle.setAttribute('fill',colours[i%colours.length]);
    g.appendChild(circle);
    g.setAttribute('transform',`translate(${cx},${cy})`);
    svg.appendChild(g);
    gears.push({g,angle:0,rate:0});
  }
  const poemDiv=document.getElementById('poem');
  const vocab=["whisper","cog","echo","spring","metal","pulse","silence","gear","ray","forge"];
  // ---- Main loop ------------------------------------------------------
  function render(){
    analyser.getByteFrequencyData(freqData);
    for(let i=0;i<N;i++){
      const band = freqData[i*2]; // rough mapping
      const speed = band/255*0.2; // angular velocity
      gears[i].rate = speed;
      gears[i].angle += speed;
      gears[i].g.setAttribute('transform',
        `translate(${100+i*80},300) rotate(${gears[i].angle*180/Math.PI})`);
    }
    // generate poem line from current speeds
    const words = gears.map(g=>vocab[Math.floor(g.rate*10)%vocab.length]);
    poemDiv.textContent = words.join(' ') + '.';
    requestAnimationFrame(render);
  }
  render();
}).catch(err=>console.error('Audio error:',err));
</script>
</body>
</html>)";
    return 0;
}