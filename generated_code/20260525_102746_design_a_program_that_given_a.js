<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Synesthetic Voronoi</title>
<style>
  body,html{margin:0;overflow:hidden;background:#000}
  #video,canvas{display:none}
  #voronoi{position:absolute;top:0;left:0;width:100%;height:100%}
</style>
</head>
<body>
<video id="video" autoplay playsinline></video>
<canvas id="capture"></canvas>
<canvas id="voronoi"></canvas>

<script>
// ------- Setup webcam -------
const video = document.getElementById('video');
navigator.mediaDevices.getUserMedia({video:true}).then(stream=>video.srcObject=stream);

// ------- Canvas for processing -------
const captureCanvas = document.getElementById('capture');
const captureCtx = captureCanvas.getContext('2d');

// ------- Voronoi rendering -------
const vorCanvas = document.getElementById('voronoi');
const vorCtx = vorCanvas.getContext('2d');
function resize(){ [captureCanvas,vorCanvas].forEach(c=>{c.width=window.innerWidth;c.height=window.innerHeight});}
window.onresize=resize; resize();

// ------- Audio synth -------
const audioCtx = new (window.AudioContext||window.webkitAudioContext)();
let masterGain = audioCtx.createGain();
masterGain.gain.value = 0.2;
masterGain.connect(audioCtx.destination);

// Custom microtonal scale (12‑tone just intonation)
const scale = [1,16/15,9/8,6/5,5/4,4/3,45/32,3/2,8/5,5/3,9/5,15/8];

// Map hue (0‑360) to scale degree + octave
function hueToFreq(hue){
  const degree = Math.floor(hue/30)%12;
  const octave = Math.floor(hue/360*2); // 0‑1 octave above base
  const base = 220; // A3
  return base*scale[degree]*Math.pow(2,octave);
}

// Play a note
function playNote(freq, vel){
  const osc = audioCtx.createOscillator();
  const gain = audioCtx.createGain();
  osc.type='sine';
  osc.frequency.value = freq;
  gain.gain.setValueAtTime(vel, audioCtx.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime+0.3);
  osc.connect(gain).connect(masterGain);
  osc.start();
  osc.stop(audioCtx.currentTime+0.31);
}

// ------- Simple dominant‑color extraction (median cut approximation) -------
function getDominantColors(imgData, count){
  const data = imgData.data, len=data.length;
  const samples=[];
  for(let i=0;i<len;i+=4*10){ // sample every 10th pixel
    samples.push([data[i],data[i+1],data[i+2]]);
  }
  // k‑means (k=count)
  let centroids=Array.from({length:count},()=>samples[Math.floor(Math.random()*samples.length)]);
  for(let iter=0;iter<5;iter++){
    const buckets=Array.from({length:count},()=>[]);
    for(const p of samples){
      let best=0,bd=Infinity;
      for(let i=0;i<count;i++){
        const c=centroids[i];
        const d=(p[0]-c[0])**2+(p[1]-c[1])**2+(p[2]-c[2])**2;
        if(d<bd){bd=d;best=i;}
      }
      buckets[best].push(p);
    }
    centroids=centroids.map((c,i)=> {
      const b=buckets[i];
      if(b.length===0) return c;
      const sum=b.reduce((a,v)=>[a[0]+v[0],a[1]+v[1],a[2]+v[2]],[0,0,0]);
      return [sum[0]/b.length,sum[1]/b.length,sum[2]/b.length];
    });
  }
  return centroids;
}

// ------- Voronoi animation driven by music ----------
let sites=[];
let lastTime=0;
function initSites(n){
  sites=[];
  for(let i=0;i<n;i++){
    sites.push({x:Math.random()*vorCanvas.width,
                y:Math.random()*vorCanvas.height,
                vx:0,vy:0,
                hue:Math.random()*360,
                size:30});
  }
}
initSites(80);

function animate(time){
  const dt=(time-lastTime)/1000||0.016;
  lastTime=time;

  // Clear
  vorCtx.clearRect(0,0,vorCanvas.width,vorCanvas.height);

  // Update sites based on recent color/motion
  const motionIntensity = recentIntensity; // from audio callbacks
  sites.forEach(s=>{
    // random walk biased by intensity
    const angle=Math.random()*2*Math.PI;
    const speed=motionIntensity*30*dt;
    s.vx+=Math.cos(angle)*speed;
    s.vy+=Math.sin(angle)*speed;
    // damping
    s.vx*=0.98; s.vy*=0.98;
    s.x+=s.vx; s.y+=s.vy;
    // wrap
    if(s.x<0)s.x+=vorCanvas.width;
    if(s.x>vorCanvas.width)s.x-=vorCanvas.width;
    if(s.y<0)s.y+=vorCanvas.height;
    if(s.y>vorCanvas.height)s.y-=vorCanvas.height;
    // hue drift
    s.hue=(s.hue+motionIntensity*30*dt)%360;
  });

  // Delaunay & Voronoi
  const points = sites.flatMap(s=>[s.x,s.y]);
  const delaunay = d3.Delaunay.from(points);
  const vor = delaunay.voronoi([0,0,vorCanvas.width,vorCanvas.height]);

  // Draw cells
  sites.forEach((s,i)=>{
    const path = new Path2D(vor.cellPolygon(i));
    vorCtx.fillStyle = `hsl(${s.hue},80%,60%)`;
    vorCtx.fill(path);
    // optional outline
    vorCtx.strokeStyle = 'rgba(0,0,0,0.2)';
    vorCtx.lineWidth = 1;
    vorCtx.stroke(path);
  });

  requestAnimationFrame(animate);
}

// ------- Process video each frame -------
let recentIntensity=0;
function process(){
  const w=video.videoWidth, h=video.videoHeight;
  if(w===0||h===0){requestAnimationFrame(process);return;}
  captureCanvas.width=w; captureCanvas.height=h;
  captureCtx.drawImage(video,0,0,w,h);
  const img = captureCtx.getImageData(0,0,w,h);
  const colors = getDominantColors(img,5);
  // map each dominant color to a note, also compute intensity
  let intensity=0;
  colors.forEach(c=>{
    const r=c[0],g=c[1],b=c[2];
    const hue = Math.atan2(Math.sqrt(3)*(g-b),2*r-g-b)*180/Math.PI;
    const hueNorm = (hue<0?hue+360:hue);
    const freq = hueToFreq(hueNorm);
    const vel = (r+g+b)/ (3*255);
    intensity+=vel;
    if(audioCtx.state==='suspended') audioCtx.resume();
    playNote(freq, vel*0.5);
  });
  recentIntensity = intensity/ colors.length; // smoothed for animation
  requestAnimationFrame(process);
}

// ------- Load D3 Delaunay from CDN -------
const script=document.createElement('script');
script.src='https://unpkg.com/d3-delaunay@6';
script.onload=()=>{requestAnimationFrame(animate);process();};
document.body.appendChild(script);
</script>
</body>
</html>