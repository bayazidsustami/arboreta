package main

import (
	"log"
	"net/http"
	"strings"
)

func main() {
	// Serve a single page that does all the work in the browser.
	const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Live Mandala</title>
<style>
  body{margin:0;background:#111;color:#eee;display:flex;flex-direction:column;align-items:center;justify-content:center;height:100vh;overflow:hidden}
  #canvas{display:none}
  svg{width:100vw;height:100vh}
</style>
</head>
<body>
<canvas id="canvas" width="320" height="240"></canvas>
<svg id="mandala"></svg>
<script>
(async()=>{

// ---------- audio ----------
const audioCtx = new (window.AudioContext||window.webkitAudioContext)();
const analyser = audioCtx.createAnalyser();
analyser.fftSize = 256;
const dataArray = new Uint8Array(analyser.frequencyBinCount);
navigator.mediaDevices.getUserMedia({audio:true}).then(stream=>{
  const source = audioCtx.createMediaStreamSource(stream);
  source.connect(analyser);
}).catch(()=>console.warn('no mic'));

function getAudioLevel(){
  analyser.getByteFrequencyData(dataArray);
  let sum=0;
  for(let v of dataArray) sum+=v;
  return sum/dataArray.length/255; // 0..1
}

// ---------- video ----------
const video = document.createElement('video');
video.autoplay = true;
video.playsInline = true;
await navigator.mediaDevices.getUserMedia({video:true}).then(s=>video.srcObject=s);
await new Promise(r=>video.onloadedmetadata=r);
const canvas = document.getElementById('canvas');
const ctx = canvas.getContext('2d');

// ---------- color extraction ----------
function dominantColors(imgData, k=3){
  // simple k‑means on RGB
  const pixels = [];
  for(let i=0;i<imgData.data.length;i+=4){
    pixels.push([imgData.data[i],imgData.data[i+1],imgData.data[i+2]]);
  }
  // init centroids randomly
  const centroids = [];
  for(let i=0;i<k;i++) centroids.push(pixels[Math.floor(Math.random()*pixels.length)]);
  for(let iter=0;iter<10;iter++){
    const clusters = Array.from({length:k},()=>[]);
    for(let p of pixels){
      let best=0,dist=Infinity;
      for(let c=0;c<k;c++){
        const d=Math.hypot(p[0]-centroids[c][0],p[1]-centroids[c][1],p[2]-centroids[c][2]);
        if(d<dist){dist=d;best=c}
      }
      clusters[best].push(p);
    }
    for(let c=0;c<k;c++){
      if(clusters[c].length===0) continue;
      const sum=[0,0,0];
      for(let p of clusters[c]){sum[0]+=p[0];sum[1]+=p[1];sum[2]+=p[2];}
      centroids[c]=sum.map(v=>v/clusters[c].length);
    }
  }
  return centroids.map(c=>`rgb(${c[0]|0},${c[1]|0},${c[2]|0})`);
}

// ---------- L‑system ----------
function generateLSystem(axiom, rules, iterations){
  let str=axiom;
  for(let i=0;i<iterations;i++){
    let next='';
    for(let ch of str){
      next+=rules[ch]||ch;
    }
    str=next;
  }
  return str;
}

// ---------- drawing ----------
const svg = document.getElementById('mandala');
function drawMandala(colors, audioLevel){
  const size = Math.min(window.innerWidth,window.innerHeight);
  const center = size/2;
  const radius = size*0.4;
  const pathCount = 12;
  const path = [];
  const lsys = generateLSystem('F',{'F':'F+F−F−F+F'},2);
  const angleStep = 360/pathCount;
  const strokeBase = 2;
  svg.innerHTML = '';
  for(let i=0;i<pathCount;i++){
    const hue = i%colors.length;
    const pathEl = document.createElementNS('http://www.w3.org/2000/svg','path');
    const d = [];
    let x=center, y=center;
    let dir=0;
    const step=radius/lsys.length;
    d.push(`M${x},${y}`);
    for(let ch of lsys){
      if(ch==='F'){
        x+=step*Math.cos(dir*Math.PI/180);
        y+=step*Math.sin(dir*Math.PI/180);
        d.push(`L${x},${y}`);
      }else if(ch==='+'){
        dir+=30;
      }else if(ch==='−'){
        dir-=30;
      }
    }
    pathEl.setAttribute('d',d.join(''));
    pathEl.setAttribute('fill','none');
    const w = strokeBase + audioLevel*8;
    pathEl.setAttribute('stroke',colors[hue]);
    pathEl.setAttribute('stroke-width',w);
    pathEl.setAttribute('transform',`rotate(${i*angleStep},${center},${center})`);
    svg.appendChild(pathEl);
  }
}

// ---------- main loop ----------
function loop(){
  ctx.drawImage(video,0,0,canvas.width,canvas.height);
  const imgData = ctx.getImageData(0,0,canvas.width,canvas.height);
  const colors = dominantColors(imgData,3);
  const audioLevel = getAudioLevel();
  drawMandala(colors,audioLevel);
  requestAnimationFrame(loop);
}
loop();

})()
</script>
</body>
</html>`
	// Serve the page at root
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		ioWriteString(w, html)
	})
	log.Println("Open http://localhost:8080 in a browser")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

// small helper to avoid importing fmt just for WriteString
func ioWriteString(w http.ResponseWriter, s string) {
	_, _ = w.Write([]byte(s))
}