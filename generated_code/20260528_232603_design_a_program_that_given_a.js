<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Sentiment‑Audio Voxel CA</title>
<style>body{margin:0;overflow:hidden;background:#000}</style>
</head>
<body>
<canvas id="c"></canvas>
<script>
// Load three.js and sentiment library dynamically
function load(src){return new Promise(r=>{const s=document.createElement('script');s.src=src; s.onload=r; document.body.appendChild(s);});}
Promise.all([
  load('https://cdn.jsdelivr.net/npm/three@0.163/build/three.min.js'),
  load('https://cdn.jsdelivr.net/npm/three@0.163/examples/jsm/controls/OrbitControls.js'),
  load('https://cdn.jsdelivr.net/npm/sentiment@5.0.2/build/sentiment.min.js')
]).then(init);

function init(){
  // ---------- SETUP ----------
  const canvas=document.getElementById('c');
  const renderer=new THREE.WebGLRenderer({canvas, antialias:true});
  const scene=new THREE.Scene();
  const cam=new THREE.PerspectiveCamera(60,innerWidth/innerHeight,0.1,1000);
  cam.position.set(30,30,30);
  const controls=new THREE.OrbitControls(cam,renderer.domElement);
  const light=new THREE.DirectionalLight(0xffffff,1);
  light.position.set(10,20,10);
  scene.add(light);
  const gridSize=30; const voxelSize=1;
  const voxels=new Map(); // key=>mesh
  const geometry=new THREE.BoxGeometry(voxelSize,voxelSize,voxelSize);
  // ---------- SENTIMENT ----------
  const sentiment=new Sentiment(); // global from lib
  let sentimentScore=0;
  // placeholder text input (replace with any source)
  const textInput=`The rain whispered secrets as the night drummed on, melancholy mingling with hope.`;
  sentimentScore=sentiment.analyze(textInput).comparative; // range ~[-1,1]
  // map to CA bias
  let caBias=sentimentScore*0.5; // influences rule mutation

  // ---------- AUDIO ----------
  const audioCtx=new (window.AudioContext||window.webkitAudioContext)();
  const analyser=audioCtx.createAnalyser();
  analyser.fftSize=256;
  const dataArray=new Uint8Array(analyser.frequencyBinCount);
  // load a music track (CORS‑friendly)
  fetch('https://cdn.jsdelivr.net/gh/mdn/webaudio-examples/beat-detection/audio/loop.wav')
    .then(r=>r.arrayBuffer())
    .then(buf=>audioCtx.decodeAudioData(buf))
    .then(buf=>{
      const source=audioCtx.createBufferSource();
      source.buffer=buf;
      source.loop=true;
      source.connect(analyser).connect(audioCtx.destination);
      source.start();
    });

  // ---------- CELLULAR AUTOMATON ----------
  // simple binary CA on a 3‑D lattice, rule encoded as 8‑bit number
  let rule=0b01101110; // initial
  function mutateRule(volume){
    // volume 0‑255 → tweak random bits
    const change=Math.round(volume/64); // 0‑4 bits
    for(let i=0;i<change;i++){
      const bit=1<<Math.floor(Math.random()*8);
      rule^=bit; // toggle
    }
    // bias from sentiment
    if(caBias>0) rule|=1; else rule&=~1;
  }

  // ---------- VOXEL HANDLING ----------
  function setVoxel(x,y,z,alive){
    const key=`${x},${y},${z}`;
    if(alive){
      if(!voxels.has(key)){
        const mat=new THREE.MeshStandardMaterial({color:new THREE.Color().setHSL(Math.random(),0.8,0.5)});
        const mesh=new THREE.Mesh(geometry,mat);
        mesh.position.set(x*voxelSize, y*voxelSize, z*voxelSize);
        scene.add(mesh);
        voxels.set(key,mesh);
      }
    }else{
      const m=voxels.get(key);
      if(m){scene.remove(m); voxels.delete(key);}
    }
  }

  // initialize random seed
  for(let x=0;x<gridSize;x++)for(let y=0;y<gridSize;y++)for(let z=0;z<gridSize;z++){
    if(Math.random()<0.05) setVoxel(x,y,z,true);
  }

  // ---------- MAIN LOOP ----------
  function animate(){
    requestAnimationFrame(animate);
    // audio analysis
    analyser.getByteFrequencyData(dataArray);
    const volume=dataArray.reduce((a,b)=>a+b)/dataArray.length;
    mutateRule(volume);
    // CA step
    const toToggle=[];
    voxels.forEach((mesh,key)=>{
      const [x,y,z]=key.split(',').map(Number);
      // count 6‑neighbour alive cells
      let cnt=0;
      const nb=[[1,0,0],[-1,0,0],[0,1,0],[0,-1,0],[0,0,1],[0,0,-1]];
      for(const [dx,dy,dz] of nb){
        if(voxels.has(`${x+dx},${y+dy},${z+dz}`)) cnt++;
      }
      // rule: bit index = cnt (0‑5) ; if bit set stay alive else die
      const survive = (rule>>cnt)&1;
      if(!survive) toToggle.push([x,y,z,false]);
      // birth
      for(const [dx,dy,dz] of nb){
        const nx=x+dx, ny=y+dy, nz=z+dz;
        if(nx<0||ny<0||nz<0||nx>=gridSize||ny>=gridSize||nz>=gridSize) continue;
        const nKey=`${nx},${ny},${nz}`;
        if(voxels.has(nKey)) continue;
        // count neighbours of neighbour
        let ncnt=0;
        for(const [dx2,dy2,dz2] of nb){
          if(voxels.has(`${nx+dx2},${ny+dy2},${nz+dz2}`)) ncnt++;
        }
        const birth = (rule>>ncnt)&1;
        if(birth) toToggle.push([nx,ny,nz,true]);
      }
    });
    toToggle.forEach(([x,y,z,alive])=>setVoxel(x,y,z,alive));
    // render
    renderer.setSize(innerWidth,innerHeight);
    renderer.render(scene,cam);
  }
  animate();

  // ---------- EXPORT ----------
  // press 'e' to download current frame sequence as glTF (placeholder)
  window.addEventListener('keydown',e=>{
    if(e.key==='e'){
      const exporter=new THREE.GLTFExporter();
      exporter.parse(scene, gltf=>{
        const blob=new Blob([JSON.stringify(gltf)],{type:'model/gltf+json'});
        const a=document.createElement('a');
        a.href=URL.createObjectURL(blob);
        a.download='voxel_scene.gltf';
        a.click();
      });
    }
  });
}
</script>
</body>
</html>