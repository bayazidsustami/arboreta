# Audio-Visual Quine: Generates HTML/JS containing its own source code,
# which renders a scrolling spectrogram and synthesizes a harmonic chord sequence 
# embedded with DTMF signals encoding the source text.

html_template = <<'HTML'
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Audio-Visual Quine</title>
<style>
  body { margin: 0; background: #050505; color: #00ffcc; font-family: monospace; overflow: hidden; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; }
  canvas { border: 1px solid #00ffcc; box-shadow: 0 0 20px rgba(0,255,204,0.2); }
  #info { margin-top: 10px; font-size: 12px; opacity: 0.8; }
</style>
</head>
<body>
<canvas id="c" width="800" height="400"></canvas>
<div id="info">Click anywhere to start Audio-Visual Quine</div>
<script>
const SOURCE = %s;

let audioCtx, started = false;
const canvas = document.getElementById('c');
const ctx = canvas.getContext('2d');
const W = canvas.width, H = canvas.height;

// DTMF Frequencies (Hz)
const dtmfRow = [697, 770, 852, 941];
const dtmfCol = [1209, 1336, 1477, 1633];
const dtmfMap = {
  '1':[0,0],'2':[0,1],'3':[0,2],'A':[0,3],
  '4':[1,0],'5':[1,1],'6':[1,2],'B':[1,3],
  '7':[2,0],'8':[2,1],'9':[2,2],'C':[2,3],
  '*':[3,0],'0':[3,1],'#':[3,2],'D':[3,3]
};

function getDTMF(char) {
  let code = char.charCodeAt(0).toString(16).toUpperCase();
  if (code.length === 1) code = '0' + code;
  return [dtmfMap[code[0]] || [0,0], dtmfMap[code[1]] || [0,0]];
}

let charIdx = 0;
const offscreen = document.createElement('canvas');
offscreen.width = W; offscreen.height = H;
const offCtx = offscreen.getContext('2d');
offCtx.fillStyle = '#050505';
offCtx.fillRect(0, 0, W, H);

function drawSpectrogram() {
  offCtx.drawImage(offscreen, -2, 0);
  offCtx.fillStyle = '#050505';
  offCtx.fillRect(W - 2, 0, 2, H);
  
  if (started) {
    const char = SOURCE[charIdx % SOURCE.length];
    offCtx.fillStyle = '#00ffcc';
    offCtx.font = '16px monospace';
    offCtx.fillText(char, W - 15, H / 2);
    
    // Render frequency markers
    const [[r1, c1], [r2, c2]] = getDTMF(char);
    const freqs = [dtmfRow[r1], dtmfCol[c1], dtmfRow[r2], dtmfCol[c2]];
    offCtx.fillStyle = '#ff0055';
    freqs.forEach(f => {
      const y = H - (f / 2000) * H;
      offCtx.fillRect(W - 4, y, 4, 2);
    });
  }
  
  ctx.drawImage(offscreen, 0, 0);
  requestAnimationFrame(drawSpectrogram);
}

function playNextTone() {
  if (!started) return;
  const char = SOURCE[charIdx % SOURCE.length];
  charIdx++;
  
  const now = audioCtx.currentTime;
  const duration = 0.15;
  
  // Harmonic Pad Chord
  const chord = [220, 277.18, 329.63, 440]; // A Major Harmonic Spectrum
  chord.forEach(freq => {
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(freq, now);
    gain.gain.setValueAtTime(0.02, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + duration);
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    osc.start(now);
    osc.stop(now + duration);
  });

  // DTMF Acoustic Coupling
  const [[r1, c1], [r2, c2]] = getDTMF(char);
  [dtmfRow[r1], dtmfCol[c1], dtmfRow[r2], dtmfCol[c2]].forEach(freq => {
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(freq, now);
    gain.gain.setValueAtTime(0.05, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + duration);
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    osc.start(now);
    osc.stop(now + duration);
  });

  setTimeout(playNextTone, duration * 1000);
}

window.addEventListener('click', () => {
  if (started) return;
  started = true;
  audioCtx = new (window.AudioContext || window.webkitAudioContext)();
  document.getElementById('info').innerText = 'Playing Audio-Visual Quine DTMF Stream...';
  playNextTone();
});

drawSpectrogram();
</script>
</body>
</html>
HTML

# Quine self-formatting logic
quine_code = sprintf(html_template, html_template.inspect)

# Outputs the fully executable audio-visual HTML quine file
File.write("quine.html", quine_code)
puts quine_code