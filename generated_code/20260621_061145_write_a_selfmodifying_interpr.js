#!/usr/bin/env node
/* Self‑modifying CA‑Mandala interpreter
   Reads a poem, builds a 1‑D cellular automaton kernel per line,
   animates an ASCII “mandala”, then rewrites itself embedding the final
   mandala as a hidden Easter‑egg comment. */

const fs = require('fs');
const path = require('path');

// ----- Configuration -------------------------------------------------
const POEM_FILE = process.argv[2] || 'poem.txt'; // pass poem filename
const WIDTH = 61;  // odd for symmetry
const HEIGHT = 30;
const FPS = 10;

// ----- Helper: generate kernel from a line ---------------------------
function lineToKernel(line) {
  // map characters to -1,0,1 based on vowel/consonant/space
  const map = { a:1, e:1, i:1, o:1, u:1 };
  const arr = [...line.toLowerCase()].filter(c=>c!==' ');
  const kernel = [];
  for (let i=0;i<3;i++) {
    const ch = arr[i]||' ';
    kernel[i] = map[ch] ? 1 : (ch===' ' ? 0 : -1);
  }
  return kernel;
}

// ----- Build full kernel list from poem -------------------------------
function buildKernels(poem) {
  const lines = poem.split(/\r?\n/).filter(l=>l.trim().length);
  const kernels = lines.map(lineToKernel);
  // ensure odd length kernel, pad with zeros
  return kernels.map(k=>k.length===3?k:[0,0,0]);
}

// ----- Cellular automaton step ----------------------------------------
function caStep(state, kernel) {
  const newState = new Array(state.length);
  const len = state.length;
  for (let i=0;i<len;i++) {
    const left = state[(i-1+len)%len];
    const center = state[i];
    const right = state[(i+1)%len];
    const sum = left*kernel[0] + center*kernel[1] + right*kernel[2];
    newState[i] = sum>0?1:(sum<0?-1:0);
  }
  return newState;
}

// ----- Rendering -------------------------------------------------------
function render(state) {
  const chars = { '-1':'·', '0':' ', '1':'*' };
  return state.map(v=>chars[v]).join('');
}

// ----- Main ----------------------------------------------------------------
(async()=>{

  // read poem (fallback to built‑in example)
  let poem;
  try { poem = fs.readFileSync(POEM_FILE,'utf8'); }
  catch { poem = "Roses are red\nViolets are blue\nLife is a loop\nForever true"; }

  const kernels = buildKernels(poem);
  let state = new Array(WIDTH).fill(0);
  state[Math.floor(WIDTH/2)] = 1; // seed

  let frame = 0;
  const frames = [];

  const interval = setInterval(()=>{
    // pick kernel cyclically
    const kernel = kernels[frame % kernels.length];
    state = caStep(state, kernel);
    const line = render(state);
    // place line vertically centered
    const y = Math.floor(HEIGHT/2) + Math.floor((frame%HEIGHT)-HEIGHT/2);
    frames[y] = (frames[y]||' '.repeat(WIDTH)).split('');
    for(let i=0;i<WIDTH;i++) frames[y][i]=line[i];
    process.stdout.write('\x1b[2J\x1b[0;0H'); // clear screen
    for(let r=0;r<HEIGHT;r++) {
      const row = frames[r] ? frames[r].join('') : ' '.repeat(WIDTH);
      process.stdout.write(row+'\n');
    }
    frame++;
    if(frame>FPS*10){ // after 10 seconds stop
      clearInterval(interval);
      embedEasterEgg(frames);
    }
  }, 1000/FPS);

  // ----- Self‑modification ------------------------------------------------
  function embedEasterEgg(frames){
    const art = frames.map(r=>r?r.join(''):''.repeat(WIDTH)).join('\n');
    const src = fs.readFileSync(__filename,'utf8');
    const newSrc = src.replace(
      /\/\*EASTER_EGG_START\*\/[\s\S]*?\/\*EASTER_EGG_END\*\//,
      `/*EASTER_EGG_START*/\n${art}\n/*EASTER_EGG_END*/`
    );
    fs.writeFileSync(__filename,newSrc,'utf8');
    console.log('\nEaster‑egg embedded into source code.');
    process.exit(0);
  }

})();

/*EASTER_EGG_START*/
/*EASTER_EGG_END*/