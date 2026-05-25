#!/usr/bin/env ruby
# frozen_string_literal: true

# Required gems: opencv, wavefile
# Install with: gem install ruby-opencv wavefile
require 'opencv'
require 'wavefile'
require 'base64'
require 'stringio'

# ------------------- 1. Capture webcam & analyse hue -------------------
def dominant_hue(frame)
  hsv = frame.cvt_color(OpenCV::CV_BGR2HSV)
  h_channel = hsv.split[0]
  hist = OpenCV::CvMat.new(180, 1, OpenCV::CV_32SC1, 0)
  OpenCV::Cv.calc_hist([h_channel], hist, OpenCV::CV_HIST_UNIFORM, OpenCV::CV_HIST_RANGES, false)
  max_idx = 0
  max_val = hist[0, 0][0]
  1.upto(179) do |i|
    v = hist[i, 0][0]
    if v > max_val
      max_val = v
      max_idx = i
    end
  end
  max_idx # hue in [0,179]
end

def hue_to_freq(hue)
  # Map hue (0‑179) to a micro‑tonal scale between 220Hz and 880Hz
  base = 220.0
  range = 660.0
  ((hue / 179.0) * range + base)
end

cap = OpenCV::CvCapture.open
raise 'Cannot open webcam' unless cap

samples = []                     # mono audio samples
sample_rate = 44100
duration_sec = 5                # record 5 seconds
frames_needed = (duration_sec * 30).to_i  # 30 fps approx
frame_count = 0

while frame_count < frames_needed && (frame = cap.query).positive?
  hue = dominant_hue(frame)
  freq = hue_to_freq(hue)
  # simple sine wave for this frame (30 samples per frame)
  30.times do |i|
    t = (frame_count * 30 + i).to_f / sample_rate
    samples << (Math.sin(2 * Math::PI * freq * t) * 0.2) # low amplitude
  end
  frame_count += 1
end

cap.close

# ------------------- 2. Encode audio to WAV (in memory) -------------------
buffer = StringIO.new
WaveFile::Writer.new(buffer, WaveFile::Format.new(:mono, :float, sample_rate)) do |writer|
  writer.write(WaveFile::Buffer.new(samples, WaveFile::Format.new(:mono, :float, sample_rate)))
end
wav_data = Base64.strict_encode64(buffer.string)

# ------------------- 3. Build self‑contained HTML -------------------
html = <<~HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Synesthetic Loop</title>
<style>
  body { margin:0; background:#111; overflow:hidden; }
  svg { width:100vw; height:100vh; display:block; }
</style>
</head>
<body>
<audio id="tone" autoplay loop src="data:audio/wav;base64,#{wav_data}"></audio>
<svg id="kaleido" viewBox="-250 -250 500 500"></svg>
<script>
const audio = document.getElementById('tone');
const ctx = new (window.AudioContext||window.webkitAudioContext)();
let analyser = ctx.createAnalyser();
let source = ctx.createMediaElementSource(audio);
source.connect(analyser);
source.connect(ctx.destination);
analyser.fftSize = 256;
let dataArray = new Uint8Array(analyser.frequencyBinCount);
const svg = document.getElementById('kaleido');
const fragments = [];

// create 12 radial fragments
for(let i=0;i<12;i++){
  const g = document.createElementNS('http://www.w3.org/2000/svg','g');
  const path = document.createElementNS('http://www.w3.org/2000/svg','path');
  path.setAttribute('fill', `hsl(${i*30},80%,60%)`);
  g.appendChild(path);
  svg.appendChild(g);
  fragments.push({g, path});
}

// animation loop
function animate(){
  requestAnimationFrame(animate);
  analyser.getByteFrequencyData(dataArray);
  const avg = dataArray.reduce((a,b)=>a+b)/dataArray.length;
  fragments.forEach((f,idx)=>{
    const angle = (Math.PI*2/12)*idx + performance.now()/5000;
    const r = 100 + avg;
    const x = r*Math.cos(angle);
    const y = r*Math.sin(angle);
    const size = 30 + (dataArray[idx]*0.2);
    const d = `M${x} ${y} l${size} 0 l0 ${size} Z`;
    f.path.setAttribute('d', d);
    f.g.setAttribute('opacity', 0.5+0.5*Math.sin(performance.now()/1000+idx));
    f.g.setAttribute('transform', `rotate(${angle*180/Math.PI})`);
  });
}
animate();
</script>
</body>
</html>
HTML

File.write('synesthetic_loop.html', html)
puts "Generated synesthetic_loop.html – open it in a browser."