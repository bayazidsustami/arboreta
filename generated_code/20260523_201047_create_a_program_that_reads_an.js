<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Word‑Music‑Mandala</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/tone/14.8.39/Tone.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/p5.js/1.9.0/p5.min.js"></script>
<style>
  body{margin:0;overflow:hidden;background:#111;color:#eee;font-family:sans-serif}
  #ui{position:absolute;top:10px;left:10px;z-index:10}
  textarea{width:300px;height:80px;background:#222;color:#eee;border:none;padding:5px}
  button{margin-top:5px;padding:5px 10px;background:#555;color:#eee;border:none;cursor:pointer}
</style>
</head>
<body>
<div id="ui">
  <textarea id="txt">The quick brown fox jumps over the lazy dog.</textarea><br>
  <button id="go">Play &amp; Visualise</button>
</div>
<script>
// ---------- Helper: deterministic hash ----------
function hashWord(w){let h=0;for(let c of w){h=((h<<5)-h)+c.charCodeAt(0);h&=0xffffffff;}return Math.abs(h);}

// ---------- Map word → note ----------
const scale = ['C4','D4','E4','F4','G4','A4','B4','C5','D5','E5','F5','G5','A5','B5'];
function wordToNote(w){return scale[hashWord(w)%scale.length];}

// ---------- Simple polarity (positive/negative) ----------
function polarity(w){ // mock: vowels -> +, consonants -> -
  let v=w.toLowerCase().replace(/[^aeiou]/g,'').length;
  return v%2===0?-1:1;
}

// ---------- Synth ----------
const synth = new Tone.PolySynth(Tone.Synth).toDestination();

// ---------- Visualisation ----------
let words=[], angles=[], radii=[];
function setup(){
  createCanvas(windowWidth,windowHeight);
  angleMode(DEGREES);
  noLoop();
}
function drawMandala(time){
  background('#111');
  translate(width/2,height/2);
  let layers=words.length;
  for(let i=0;i<layers;i++){
    push();
    rotate(frameCount*0.5+i*10);
    let r= (i+1)*30;
    let n=words[i].length;
    for(let j=0;j<n;j++){
      let a=map(j,0,n,0,360);
      push();
      rotate(a);
      stroke(lerpColor(color('#ff0099'),color('#00ffdd'),i/layers));
      line(0,0,r,0);
      // hidden glyph (first letter)
      noStroke();fill(255,30);
      textSize(12);
      text(words[i][0].toUpperCase(), r-5,5);
      pop();
    }
    pop();
  }
}
function windowResized(){resizeCanvas(windowWidth,windowHeight);}

// ---------- Main ----------
document.getElementById('go').onclick=async()=>{
  const txt=document.getElementById('txt').value;
  words=txt.match(/\b\w+\b/g)||[];
  angles=words.map(_=>random(360));
  radii=words.map(_=>random(50,200));
  // schedule notes
  await Tone.start();
  const now=Tone.now();
  words.forEach((w,i)=>{
    const note=wordToNote(w);
    const dur=polarity(w)>0?'8n':'16n';
    synth.triggerAttackRelease(note,dur,now+i*0.3);
  });
  // start visual loop
  loop();
  draw();
};

function draw(){drawMandala();}