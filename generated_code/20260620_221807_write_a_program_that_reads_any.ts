import * as fs from 'fs';
import * as process from 'process';

/**
 * Reads all stdin as a UTF‑8 string.
 */
function readInput(): Promise<string> {
    return new Promise((resolve) => {
        let data = '';
        process.stdin.setEncoding('utf8');
        process.stdin.on('data', chunk => data += chunk);
        process.stdin.on('end', () => resolve(data));
    });
}

/**
 * Generates a self‑contained HTML page that:
 *  - Plays a note for each character (frequency derived from code point bits)
 *  - Draws a fractal bloom on a canvas whose parameters depend on surrounding characters
 *  - Allows export via a “Save” button.
 */
function buildHtml(text: string): string {
    const escaped = text.replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/&/g, '&amp;');
    return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Audio‑Visual Poem</title>
<style>
    body { margin:0; overflow:hidden; background:#111; color:#ddd; font-family:sans-serif; }
    #info { position:absolute; top:10px; left:10px; z-index:10; }
    #saveBtn { padding:0.4em 0.8em; margin-left:1em; }
    canvas { display:block; }
</style>
</head>
<body>
<div id="info">Input length: ${text.length}<button id="saveBtn">Save as HTML</button></div>
<canvas id="c"></canvas>
<script>
const text = \`${escaped.replace(/`/g, '\\`')}\`;
const canvas = document.getElementById('c');
const ctx = canvas.getContext('2d');
let W, H;
function resize(){ W=canvas.width=innerWidth; H=canvas.height=innerHeight; }
window.addEventListener('resize', resize);
resize();

// Web Audio setup
const AudioCtx = window.AudioContext || window.webkitAudioContext;
const audio = new AudioCtx();
function playNote(freq, dur, time) {
    const osc = audio.createOscillator();
    const gain = audio.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(freq, time);
    gain.gain.setValueAtTime(0, time);
    gain.gain.linearRampToValueAtTime(0.2, time+0.01);
    gain.gain.exponentialRampToValueAtTime(0.001, time+dur);
    osc.connect(gain).connect(audio.destination);
    osc.start(time);
    osc.stop(time+dur+0.05);
}

// Fractal bloom parameters
function hueFromChar(c){ return (c.charCodeAt(0)*37)%360; }
function sizeFromChar(c){ return 20 + (c.charCodeAt(0)%30); }
function speedFromChar(c){ return 0.5 + (c.charCodeAt(0)%100)/200; }

// Simple recursive bloom
function drawBloom(x,y,size,depth,hue){
    if (depth===0) return;
    ctx.save();
    ctx.translate(x,y);
    ctx.rotate(Math.PI*2*Math.random());
    ctx.strokeStyle = \`hsl(\${hue},80%,60%)\`;
    ctx.lineWidth = depth;
    ctx.beginPath();
    ctx.moveTo(0,0);
    ctx.lineTo(size,0);
    ctx.stroke();
    const nx = Math.cos(Math.random()*Math.PI*2)*size;
    const ny = Math.sin(Math.random()*Math.PI*2)*size;
    drawBloom(nx,ny,size*0.6,depth-1,hue);
    ctx.restore();
}

// Scheduler
let start = audio.currentTime+0.1;
for(let i=0;i<text.length;i++){
    const ch = text[i];
    const code = ch.codePointAt(0)||0;
    // frequency from lower 7 bits, map to audible range
    const freq = 200 + (code & 0x7F) * 5;
    // duration from next 3 bits
    const dur = 0.1 + ((code>>7)&0x7)*0.05;
    const t = start + i*0.15;
    playNote(freq,dur,t);
    // visual schedule
    setTimeout(()=>{
        const x = Math.random()*W;
        const y = Math.random()*H;
        const hue = hueFromChar(ch);
        const size = sizeFromChar(ch);
        const speed = speedFromChar(ch);
        const startTime = performance.now();
        function animate(now){
            const elapsed = (now-startTime)/1000;
            ctx.clearRect(0,0,W,H);
            drawBloom(x+Math.sin(elapsed*speed)*30,
                      y+Math.cos(elapsed*speed)*30,
                      size, 4, hue);
            requestAnimationFrame(animate);
        }
        animate(performance.now());
    }, (t-audio.currentTime)*1000);
}

// Export button
document.getElementById('saveBtn').onclick=()=> {
    const blob = new Blob([document.documentElement.outerHTML],{type:'text/html'});
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'audio_visual_poem.html';
    a.click();
};
</script>
</body>
</html>`;
}

(async()=>{ const txt = await readInput(); const html = buildHtml(txt); fs.writeFileSync('poem.html',html,'utf8'); console.log('Generated poem.html'); })();