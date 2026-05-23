#!/usr/bin/env bash
#================================================================
# kaleido_sentiment.sh
# A self‑contained pipeline that:
#   1. Captures webcam video (ffmpeg)
#   2. Extracts frames and runs an open‑source emotion model (Python + fer)
#   3. Analyzes a background audio file (ffmpeg + python)
#   4. Generates a dynamic SVG animation (Python)
#   5. Serves the result with a minimal HTTP server.
#================================================================

set -euo pipefail

#--- Config ----------------------------------------------------
WEBCAM_DEVICE=${WEBCAM_DEVICE:-/dev/video0}      # Linux V4L2 device
FRAME_RATE=${FRAME_RATE:-10}                     # frames per second to analyse
DURATION=${DURATION:-30}                         # seconds of capture
AUDIO_FILE=${AUDIO_FILE:-ambient.wav}           # ambient soundscape (must exist)
OUT_DIR=${OUT_DIR:-kaleido_output}
PORT=${PORT:-8080}
#----------------------------------------------------------------

mkdir -p "$OUT_DIR"

#--- 1. Capture webcam video + audio ----------------------------
# Store video as raw frames (png) and raw audio (wav)
ffmpeg -y -f v4l2 -framerate "$FRAME_RATE" -i "$WEBCAM_DEVICE" \
       -t "$DURATION" -vf "scale=320:240" "$OUT_DIR/frame_%04d.png" >/dev/null 2>&1 &
VID_PID=$!

ffmpeg -y -f avfoundation -i ":$AUDIO_FILE" -t "$DURATION" -ac 1 -ar 22050 "$OUT_DIR/audio.wav" >/dev/null 2>&1 &
AUD_PID=$!

wait $VID_PID $AUD_PID

#--- 2. Emotion detection per frame (Python) -------------------
cat > "$OUT_DIR/emotion.py" <<'PYEOF'
import sys, json, pathlib
import numpy as np
from fer import FER
from PIL import Image

model = FER(mtcnn=True)
frames = sorted(pathlib.Path('.').glob('frame_*.png'))
out = {}
for p in frames:
    img = np.array(Image.open(p))
    res = model.top_emotion(img)
    out[p.name] = res[0] if res else "neutral"
print(json.dumps(out))
PYEOF

pushd "$OUT_DIR" >/dev/null
EMO_JSON=$(python3 emotion.py)
popd >/dev/null

#--- 3. Audio spectrum analysis (Python) -----------------------
cat > "$OUT_DIR/audio_fft.py" <<'PYEOF'
import sys, json, numpy as np, scipy.io.wavfile as wav
rate, data = wav.read('audio.wav')
# mono, short FFT windows
win = 1024
step = win//2
spec = []
for i in range(0, len(data)-win, step):
    fft = np.abs(np.fft.rfft(data[i:i+win]*np.hanning(win)))
    spec.append(float(np.mean(fft)))
# normalize
mx = max(spec) or 1
spec = [v/mx for v in spec]
print(json.dumps(spec))
PYEOF

pushd "$OUT_DIR" >/dev/null
FFT_JSON=$(python3 audio_fft.py)
popd >/dev/null

#--- 4. Build SVG animation (Python) ---------------------------
cat > "$OUT_DIR/generate_svg.py" <<'PYEOF'
import json, pathlib, math
frames = sorted(pathlib.Path('.').glob('frame_*.png'))
with open('emotions.json') as f:
    emotions = json.load(f)
with open('audio_fft.json') as f:
    audio = json.load(f)

def hue_from_emotion(em):
    mapping = {
        "angry": 0, "disgust": 120, "fear": 240,
        "happy": 60, "sad": 180, "surprise": 300,
        "neutral": 30
    }
    return mapping.get(em, 30)

svg_elems = []
size = 320
for i, p in enumerate(frames):
    em = emotions[p.name]
    hue = hue_from_emotion(em)
    amp = audio[i] if i < len(audio) else 0.5
    scale = 0.5 + amp*0.5
    rot = (i*5) % 360
    img_href = p.name
    elem = f'''<image href="{img_href}" width="{size}" height="{size}"
        transform="translate({size/2},{size/2}) rotate({rot}) scale({scale}) translate(-{size/2},-{size/2})"
        style="filter:url(#hue{hue});"/>'''
    svg_elems.append(elem)

# define hue filters
filter_defs = ''
for h in range(0,361,30):
    filter_defs += f'''<filter id="hue{h}"><feColorMatrix type="hueRotate" values="{h}"/></filter>'''

svg = f'''<svg width="{size}" height="{size}" viewBox="0 0 {size} {size}" xmlns="http://www.w3.org/2000/svg">
<defs>{filter_defs}</defs>
{''.join(svg_elems)}
</svg>'''
open('animation.svg','w').write(svg)
PYEOF

# write JSON helpers
echo "$EMO_JSON" > "$OUT_DIR/emotions.json"
echo "$FFT_JSON" > "$OUT_DIR/audio_fft.json"

pushd "$OUT_DIR" >/dev/null
python3 generate_svg.py
popd >/dev/null

#--- 5. Assemble interactive web page ---------------------------
cat > "$OUT_DIR/index.html" <<'HTMLEOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"><title>Kaleido Sentiment</title>
<style>
body{margin:0;background:#111;display:flex;flex-direction:column;align-items:center;color:#eee}
#player{margin-top:10px}
svg{max-width:100%;height:auto;cursor:pointer}
.highlight{stroke:#fff;stroke-width:4}
</style>
</head>
<body>
<h1>Kaleidoscopic Sentiment Visualizer</h1>
<audio id="player" controls src="audio.wav"></audio>
<div id="container">
<img id="frame" src="" style="display:none">
<object id="anim" type="image/svg+xml" data="animation.svg"></object>
</div>
<script>
const audio = document.getElementById('player');
const anim = document.getElementById('anim');
const frames = Array.from({length: ${DURATION*FRAME_RATE}}, (_,i)=>`frame_${String(i+1).padStart(4,'0')}.png`);
let cur = 0;

// sync animation to audio time
audio.addEventListener('timeupdate',()=> {
    const idx = Math.min(frames.length-1, Math.floor(audio.currentTime*${FRAME_RATE}));
    if (idx!==cur){ cur=idx; loadFrame(idx);}
});
function loadFrame(i){
    const obj = anim.contentDocument;
    if (!obj) return;
    const imgs = obj.querySelectorAll('image');
    imgs.forEach((im,j)=>{ im.style.opacity = (j===i)?1:0.2; });
}
anim.addEventListener('load',()=>loadFrame(0));
</script>
</body>
</html>
HTMLEOF

#--- 6. Serve ----------------------------------------------------
cd "$OUT_DIR"
python3 -m http.server "$PORT"