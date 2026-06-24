<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Audio → Surface → Swarm → Video + Reversible Code</title>
<style>
  body{margin:0;overflow:hidden;background:#111;color:#fff;font-family:sans-serif}
  #info{position:absolute;top:10px;left:10px;z-index:10}
  #download{margin-top:5px}
</style>
</head>
<body>
<div id="info">
  <input type="file" id="fileInput" accept="audio/*">
  <button id="startBtn">Start</button>
  <a id="download" href="#" download="reversible.js">Download Reversible Code</a>
</div>
<canvas id="glcanvas"></canvas>
<script>
// ==== Core utilities =========================================================
const gl = document.getElementById('glcanvas').getContext('webgl2');
if (!gl) alert('WebGL2 not supported');

// Resize canvas
function resize() {
  gl.canvas.width = window.innerWidth;
  gl.canvas.height = window.innerHeight;
  gl.viewport(0,0,gl.canvas.width,gl.canvas.height);
}
window.addEventListener('resize',resize);
resize();

// Simple shader compiler
function compile(vs,fs){
  const prog = gl.createProgram();
  const v = gl.createShader(gl.VERTEX_SHADER);
  gl.shaderSource(v,vs); gl.compileShader(v);
  const f = gl.createShader(gl.FRAGMENT_SHADER);
  gl.shaderSource(f,fs); gl.compileShader(f);
  gl.attachShader(prog,v); gl.attachShader(prog,f);
  gl.linkProgram(prog);
  return prog;
}

// ==== Audio processing =======================================================
let audioBuffer=null;
let fingerprint=null; // ARRAY of magnitude per frequency bin
function extractFingerprint(buffer){
  const fftSize=2048;
  const analyser = new (window.AudioContext||window.webkitAudioContext)();
  const source = analyser.createBufferSource();
  source.buffer = buffer;
  const analyserNode = analyser.createAnalyser();
  analyserNode.fftSize = fftSize;
  source.connect(analyserNode);
  source.start();
  const data = new Float32Array(analyserNode.frequencyBinCount);
  analyserNode.getFloatFrequencyData(data);
  source.disconnect();
  analyserNode.disconnect();
  // Normalize to [0,1]
  const min = Math.min(...data), max = Math.max(...data);
  return data.map(v=> (v-min)/(max-min) );
}

// ==== Parametric surface (a twisted torus) ==================================
const vs = `#version 300 es
in vec3 aPos;
uniform mat4 uMVP;
void main(){ gl_Position = uMVP * vec4(aPos,1.0); }`;

const fs = `#version 300 es
precision highp float;
out vec4 outColor;
void main(){ outColor = vec4(1.0); }`;

const prog = compile(vs,fs);
const posLoc = gl.getAttribLocation(prog,'aPos');
const mvpLoc = gl.getUniformLocation(prog,'uMVP');

// Generate surface vertices based on fingerprint curvature
function generateSurface(fp){
  const rows=200, cols=200;
  const verts = [];
  for(let i=0;i<=rows;i++){
    const u = i/rows * Math.PI*2;
    for(let j=0;j<=cols;j++){
      const v = j/cols * Math.PI*2;
      // base torus radii
      const R = 0.6, r = 0.2;
      // curvature modulation from fingerprint
      const idx = Math.floor((i/rows)*fp.length);
      const mod = 0.1 + 0.4*fp[idx];
      const x = (R + (r+mod*Math.sin(3*u))*Math.cos(v)) * Math.cos(u);
      const y = (R + (r+mod*Math.sin(3*u))*Math.cos(v)) * Math.sin(u);
      const z = (r+mod*Math.sin(3*u))*Math.sin(v);
      verts.push(x,y,z);
    }
  }
  return new Float32Array(verts);
}

// ==== Particle swarm =========================================================
const particleCount = 2000;
let particles = new Float32Array(particleCount*3);
let velocities = new Float32Array(particleCount*3);
function initSwarm(){
  for(let i=0;i<particleCount;i++){
    particles[i*3+0] = (Math.random()-0.5)*2;
    particles[i*3+1] = (Math.random()-0.5)*2;
    particles[i*3+2] = (Math.random()-0.5)*2;
    velocities[i*3+0] = (Math.random()-0.5)*0.01;
    velocities[i*3+1] = (Math.random()-0.5)*0.01;
    velocities[i*3+2] = (Math.random()-0.5)*0.01;
  }
}
initSwarm();

const particleVBO = gl.createBuffer();

// ==== Rendering loop =========================================================
let surfaceVBO, surfaceCount;
let startTime;
function render(){
  const now = performance.now();
  const dt = (now - startTime)/1000;
  startTime = now;
  gl.clearColor(0,0,0,1);
  gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);
  gl.enable(gl.DEPTH_TEST);

  // Update particles (simple attractor toward surface)
  for(let i=0;i<particleCount;i++){
    const px = particles[i*3+0], py=particles[i*3+1], pz=particles[i*3+2];
    // sample surface height at projection (very cheap approximation)
    const angle = Math.atan2(py,px);
    const radius = Math.hypot(px,py);
    const targetX = Math.cos(angle)*radius;
    const targetY = Math.sin(angle)*radius;
    const targetZ = Math.sin(radius*3)*0.2;
    const dx = targetX-px, dy=targetY-py, dz=targetZ-pz;
    velocities[i*3+0] += dx*0.001;
    velocities[i*3+1] += dy*0.001;
    velocities[i*3+2] += dz*0.001;
    // damp
    velocities[i*3+0] *= 0.98;
    velocities[i*3+1] *= 0.98;
    velocities[i*3+2] *= 0.98;
    particles[i*3+0] += velocities[i*3+0];
    particles[i*3+1] += velocities[i*3+1];
    particles[i*3+2] += velocities[i*3+2];
  }

  // Draw surface
  gl.useProgram(prog);
  const proj = mat4.perspective([],Math.PI/3,gl.canvas.width/gl.canvas.height,0.1,100);
  const view = mat4.lookAt([],[0,0,3],[0,0,0],[0,1,0]);
  const model = mat4.create();
  const mvp = mat4.multiply([],proj,mat4.multiply([],view,model));
  gl.uniformMatrix4fv(mvpLoc,false,mvp);
  gl.bindBuffer(gl.ARRAY_BUFFER,surfaceVBO);
  gl.enableVertexAttribArray(posLoc);
  gl.vertexAttribPointer(posLoc,3,gl.FLOAT,false,0,0);
  gl.drawArrays(gl.POINTS,0,surfaceCount);

  // Draw particles
  gl.bindBuffer(gl.ARRAY_BUFFER,particleVBO);
  gl.bufferData(gl.ARRAY_BUFFER,particles,gl.DYNAMIC_DRAW);
  gl.vertexAttribPointer(posLoc,3,gl.FLOAT,false,0,0);
  gl.drawArrays(gl.POINTS,0,particleCount);

  requestAnimationFrame(render);
}

// ==== UI handling ============================================================
document.getElementById('startBtn').onclick=async ()=>{
  const file = document.getElementById('fileInput').files[0];
  if(!file) return alert('Select audio file');
  const arrayBuf = await file.arrayBuffer();
  const ctx = new (window.AudioContext||window.webkitAudioContext)();
  audioBuffer = await ctx.decodeAudioData(arrayBuf);
  fingerprint = extractFingerprint(audioBuffer);
  const verts = generateSurface(fingerprint);
  surfaceVBO = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER,surfaceVBO);
  gl.bufferData(gl.ARRAY_BUFFER,verts,gl.STATIC_DRAW);
  surfaceCount = verts.length/3;

  // Prepare particle VBO
  gl.bindBuffer(gl.ARRAY_BUFFER,particleVBO);
  gl.bufferData(gl.ARRAY_BUFFER,particles,gl.DYNAMIC_DRAW);

  // Start render loop
  startTime = performance.now();
  requestAnimationFrame(render);

  // ---- Generate reversible code file --------------------------------------
  const source = document.documentElement.outerHTML;
  const blob = new Blob([source],'text/javascript');
  const url = URL.createObjectURL(blob);
  const dl = document.getElementById('download');
  dl.href = url;
  dl.style.display='inline';
};
</script>
<!-- Minimal mat4 implementation -->
<script>
const mat4 = {
  create:()=>new Float32Array(16).fill(0).map((v,i)=>i%5===0?1:0),
  perspective:(out,fovy,aspect,near,far)=>{
    const f=1.0/Math.tan(fovy/2), nf=1/(near-far);
    out[0]=f/aspect; out[1]=0; out[2]=0; out[3]=0;
    out[4]=0; out[5]=f; out[6]=0; out[7]=0;
    out[8]=0; out[9]=0; out[10]=(far+near)*nf; out[11]=-1;
    out[12]=0; out[13]=0; out[14]=(2*far*near)*nf; out[15]=0;
    return out;
  },
  lookAt:(out,eye,center,up)=>{
    let x0,x1,x2,y0,y1,y2,z0,z1,z2,len;
    z0=eye[0]-center[0]; z1=eye[1]-center[1]; z2=eye[2]-center[2];
    len=1/Math.hypot(z0,z1,z2); z0*=len; z1*=len; z2*=len;
    x0=up[1]*z2-up[2]*z1; x1=up[2]*z0-up[0]*z2; x2=up[0]*z1-up[1]*z0;
    len=1/Math.hypot(x0,x1,x2); x0*=len; x1*=len; x2*=len;
    y0=z1*x2-z2*x1; y1=z2*x0-z0*x2; y2=z0*x1-z1*x0;
    out[0]=x0; out[1]=y0; out[2]=z0; out[3]=0;
    out[4]=x1; out[5]=y1; out[6]=z1; out[7]=0;
    out[8]=x2; out[9]=y2; out[10]=z2; out[11]=0;
    out[12]=-(x0*eye[0]+x1*eye[1]+x2*eye[2]);
    out[13]=-(y0*eye[0]+y1*eye[1]+y2*eye[2]);
    out[14]=-(z0*eye[0]+z1*eye[1]+z2*eye[2]);
    out[15]=1;
    return out;
  },
  multiply:(out,a,b)=>{
    const a00=a[0],a01=a[1],a02=a[2],a03=a[3];
    const a10=a[4],a11=a[5],a12=a[6],a13=a[7];
    const a20=a[8],a21=a[9],a22=a[10],a23=a[11];
    const a30=a[12],a31=a[13],a32=a[14],a33=a[15];
    const b00=b[0],b01=b[1],b02=b[2],b03=b[3];
    const b10=b[4],b11=b[5],b12=b[6],b13=b[7];
    const b20=b[8],b21=b[9],b22=b[10],b23=b[11];
    const b30=b[12],b31=b[13],b32=b[14],b33=b[15];
    out[0]=b00*a00+b01*a10+b02*a20+b03*a30;
    out[1]=b00*a01+b01*a11+b02*a21+b03*a31;
    out[2]=b00*a02+b01*a12+b02*a22+b03*a32;
    out[3]=b00*a03+b01*a13+b02*a23+b03*a33;
    out[4]=b10*a00+b11*a10+b12*a20+b13*a30;
    out[5]=b10*a01+b11*a11+b12*a21+b13*a31;
    out[6]=b10*a02+b11*a12+b12*a22+b13*a32;
    out[7]=b10*a03+b11*a13+b12*a23+b13*a33;
    out[8]=b20*a00+b21*a10+b22*a20+b23*a30;
    out[9]=b20*a01+b21*a11+b22*a21+b23*a31;
    out[10]=b20*a02+b21*a12+b22*a22+b23*a32;
    out[11]=b20*a03+b21*a13+b22*a23+b23*a33;
    out[12]=b30*a00+b31*a10+b32*a20+b33*a30;
    out[13]=b30*a01+b31*a11+b32*a21+b33*a31;
    out[14]=b30*a02+b31*a12+b32*a22+b33*a32;
    out[15]=b30*a03+b31*a13+b32*a23+b33*a33;
    return out;
  }
};
</script>
</body>
</html>