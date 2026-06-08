output = <<~HTML
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Audio‑CA Fractal</title>
<style>body{margin:0;background:#000;overflow:hidden}</style>
</head>
<body>
<canvas id="c"></canvas>
<script>
const canvas=document.getElementById('c'), ctx=canvas.getContext('2d');
let W=window.innerWidth, H=window.innerHeight;
canvas.width=W;canvas.height=H;
const cols=120, rows=80;
let grid=Array.from({length:rows},()=>Array(cols).fill(0));
function toroidal(x,y){return [(x+cols)%cols,(y+rows)%rows];}
function nextState(rules,amp){
  const newg=Array.from({length:rows},()=>Array(cols).fill(0));
  for(let y=0;y<rows;y++)for(let x=0;x<cols;x++){
    let sum=0;
    for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){
      if(dx===0&&dy===0)continue;
      const [nx,ny]=toroidal(x+dx,y+dy);
      sum+=grid[ny][nx];
    }
    const idx=((sum&0xFF)+Math.floor(amp*255))&0xFF;
    newg[y][x]=rules[idx];
  }
  grid=newg;
}
function draw(){
  const cellW=W/cols, cellH=H/rows;
  for(let y=0;y<rows;y++)for(let x=0;x<cols;x++){
    const v=grid[y][x];
    ctx.fillStyle='hsl('+ (v*360/255) +',80%,50%)';
    ctx.fillRect(x*cellW, y*cellH, cellW, cellH);
  }
}
navigator.mediaDevices.getUserMedia({audio:true}).then(stream=>{
  const audioCtx=new (window.AudioContext||window.webkitAudioContext)();
  const source=audioCtx.createMediaStreamSource(stream);
  const analyser=audioCtx.createAnalyser();
  analyser.fftSize=256;
  source.connect(analyser);
  const data=new Uint8Array(analyser.frequencyBinCount);
  const rules=Array.from({length:256},()=>Math.floor(Math.random()*256));
  function loop(){
    analyser.getByteFrequencyData(data);
    let amp=0; for(let i=0;i<data.length;i++) amp+=data[i];
    amp/=data.length/255;
    nextState(rules,amp/255);
    draw();
    requestAnimationFrame(loop);
  }
  loop();
}).catch(e=>{
  ctx.fillStyle='#f00';
  ctx.font='20px sans-serif';
  ctx.fillText('Microphone access denied',10,30);
});
window.addEventListener('resize',()=>{W=canvas.width=innerWidth;H=canvas.height=innerHeight;});
</script>
</body>
</html>
HTML

File.write('audio_ca.html', output)
puts "audio_ca.html generated"