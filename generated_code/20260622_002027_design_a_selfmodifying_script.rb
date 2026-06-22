# Self‑modifying melodic fractal generator
# The script reads its own source, transposes the embedded melody,
# writes the updated source back, and creates an HTML visual/audio demo.

require 'json'

# === Embedded melody (MIDI numbers). The script will replace this line on each run. ===
NOTE_SEQUENCE = [60, 62, 64, 65, 67, 69, 71, 72]

# --------------------------------------------------------------------------
# 1. Parse current notes from source
src = File.read(__FILE__)
notes_line = src[/NOTE_SEQUENCE\s*=\s*\[([^\]]*)\]/, 0]
old_notes = src[/NOTE_SEQUENCE\s*=\s*\[([^\]]*)\]/, 1]
old_notes = old_notes.split(/,\s*/).map(&:to_i)

# 2. Transpose by a random non‑zero interval between -5 and +5 semitones
interval = 0
interval = rand(-5..5) while interval == 0
new_notes = old_notes.map { |n| [[n + interval, 0].max, 127].min }

# 3. Overwrite the source with the transposed melody
new_line = "NOTE_SEQUENCE = #{new_notes.inspect}"
new_src = src.sub(notes_line, new_line)
File.write(__FILE__, new_src)

# 4. Generate an HTML file that visualises the melody as a looping fractal
html = <<~HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Melodic Fractal</title>
<style>
  body{margin:0;background:#111;overflow:hidden}
  canvas{display:block}
</style>
</head>
<body>
<canvas id="c"></canvas>
<script>
const notes = #{new_notes.to_json};
const ctx = document.getElementById('c').getContext('2d');
let w, h, t = 0;
function resize(){ w = canvas.width = innerWidth; h = canvas.height = innerHeight; }
window.addEventListener('resize', resize);
resize();

function drawFractal(x, y, size, depth){
  if(depth===0) return;
  ctx.strokeStyle = `hsl(${(t*30)%360},80%,60%)`;
  ctx.lineWidth = depth;
  ctx.strokeRect(x-size/2, y-size/2, size, size);
  const newSize = size/2;
  drawFractal(x-newSize, y-newSize, newSize, depth-1);
  drawFractal(x+newSize, y-newSize, newSize, depth-1);
  drawFractal(x-newSize, y+newSize, newSize, depth-1);
  drawFractal(x+newSize, y+newSize, newSize, depth-1);
}

function animate(){
  t += 0.01;
  ctx.clearRect(0,0,w,h);
  drawFractal(w/2, h/2, Math.min(w,h)*0.8, 5);
  requestAnimationFrame(animate);
}
animate();

// ---- Audio (Web Audio API) ------------------------------------------------
const AudioContext = window.AudioContext || window.webkitAudioContext;
const ac = new AudioContext();
let idx = 0;
function playNote(freq){
  const osc = ac.createOscillator();
  const gain = ac.createGain();
  osc.type = 'sine';
  osc.frequency.value = freq;
  gain.gain.setValueAtTime(0.2, ac.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, ac.currentTime+0.5);
  osc.connect(gain).connect(ac.destination);
  osc.start();
  osc.stop(ac.currentTime+0.5);
}
function schedule(){
  const midi = notes[idx % notes.length];
  const freq = 440 * Math.pow(2, (midi-69)/12);
  playNote(freq);
  idx++;
  setTimeout(schedule, 300);
}
schedule();
</script>
</body>
</html>
HTML

File.write('melody.html', html)

# 5. Open the visualisation (best‑effort cross‑platform)
open_cmd = case RUBY_PLATFORM
           when /darwin/ then 'open'
           when /linux/  then 'xdg-open'
           when /win32|mingw/ then 'start'
           else nil
           end
system(open_cmd, 'melody.html') if open_cmd