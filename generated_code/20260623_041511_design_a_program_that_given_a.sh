#!/usr/bin/env bash
# realtime audio‑visual feedback sculpture
# dependencies: ffmpeg, python3, numpy, scipy, pillow, imageio, ffmpeg‑filters (v4.4+)

# ---------- CONFIG ----------
VIDEO_DEV="/dev/video0"          # webcam device
AUDIO_RATE=48000                # audio sampling rate
FFT_SIZE=1024                   # size for spectral analysis
OVERLAY_SIZE="640x480"           # size of generated overlay
FRAMERATE=30                    # output framerate
TMPDIR=$(mktemp -d)             # temporary workspace
PY_SCRIPT="$TMPDIR/processor.py"
OVERLAY_IMG="$TMPDIR/overlay.png"

# ---------- Python processor ----------
cat >"$PY_SCRIPT" <<'PY'
import sys, json, time, math, numpy as np
from scipy.signal import find_peaks
from PIL import Image, ImageDraw
from collections import deque

# parameters (must match Bash)
FFT_SIZE = int(sys.argv[1])
OVERLAY_W, OVERLAY_H = map(int, sys.argv[2].split('x'))
MAX_QUEUE = 4  # seconds of audio history

audio_buf = deque(maxlen=MAX_QUEUE * 48000)  # 48kHz default
last_beat = 0

def spectral_centroid(buf):
    mags = np.abs(np.fft.rfft(buf * np.hanning(len(buf))))**2
    freqs = np.fft.rfftfreq(len(buf), d=1/48000)
    if mags.sum() == 0: return 0
    return (freqs * mags).sum() / mags.sum()

def beat_detect(cent):
    global last_beat
    now = time.time()
    # simple threshold on centroid change
    if abs(cent - beat_detect.prev) > 200 and now - last_beat > 0.3:
        last_beat = now
        beat_detect.prev = cent
        return True
    beat_detect.prev = cent
    return False
beat_detect.prev = 0

def lsystem(axiom, rules, depth, angle):
    # very compact L‑system interpreter (turtle graphics)
    import cmath
    stack = []
    pos = complex(OVERLAY_W/2, OVERLAY_H/2)
    heading = -cmath.pi/2
    path = [pos]
    for _ in range(depth):
        nxt = ''
        for ch in axiom:
            nxt += rules.get(ch, ch)
        axiom = nxt
    for ch in axiom:
        if ch == 'F':
            pos += cmath.rect(5, heading)
            path.append(pos)
        elif ch == '+':
            heading += math.radians(angle)
        elif ch == '-':
            heading -= math.radians(angle)
        elif ch == '[':
            stack.append((pos, heading))
        elif ch == ']':
            pos, heading = stack.pop()
    return path

def render(path, filename):
    img = Image.new('RGBA', (OVERLAY_W, OVERLAY_H), (0,0,0,0))
    draw = ImageDraw.Draw(img)
    pts = [(p.real, p.imag) for p in path]
    if pts:
        draw.line(pts, fill=(255,255,255,180), width=2)
    img.save(filename)

while True:
    # read raw audio chunk from stdin (16‑bit little endian)
    raw = sys.stdin.buffer.read(FFT_SIZE * 2)
    if len(raw) < FFT_SIZE * 2: break
    audio = np.frombuffer(raw, dtype=np.int16).astype(np.float32)
    audio_buf.extend(audio)
    if len(audio_buf) < FFT_SIZE: continue

    # spectral centroid
    cent = spectral_centroid(np.array(audio_buf)[-FFT_SIZE:])
    # mutate L‑system parameters
    depth = int(3 + (cent % 3000) / 1000)   # 3‑5
    angle = 25 + (cent % 360) / 10          # 25‑61
    # simple rule set
    axiom = "F"
    rules = {"F": "F+F-F-F+F"}
    # on beat mutate rule
    if beat_detect(cent):
        rules["F"] = "F[+F]F[-F]F"

    path = lsystem(axiom, rules, depth, angle)
    render(path, filename=filename:=sys.argv[3])
    # inform bash that a new frame is ready
    sys.stdout.write(json.dumps({"t":time.time()}) + "\n")
    sys.stdout.flush()
PY

# ---------- start audio pipeline ----------
# ffmpeg captures video+audio, splits audio to pipe for python, video to pipe for overlay
ffmpeg -f v4l2 -framerate $FRAMERATE -video_size $OVERLAY_SIZE -i $VIDEO_DEV \
    -f alsa -ac 1 -ar $AUDIO_RATE -i default \
    -filter_complex "[0:v]format=rgba,setsar=1[v]" \
    -map "[v]" -map 1:a -c:v rawvideo -pix_fmt yuv420p -f rawvideo - | \
# feed raw video to a while‑read loop
while read -r -d '' -n 1 ; do :; done &

# ---------- launch Python processor ----------
# pipe raw 16‑bit audio to processor, receive JSON notifications
ffmpeg -f alsa -ac 1 -ar $AUDIO_RATE -i default -f s16le -ac 1 -ar $AUDIO_RATE - \
    | python3 "$PY_SCRIPT" "$FFT_SIZE" "$OVERLAY_SIZE" "$OVERLAY_IMG" &
PY_PID=$!

# ---------- overlay loop ----------
# watch for new overlay images and composite onto live video
while true; do
    # wait for processor to write a new frame (simple polling)
    sleep 0.033  # ~30 fps
    if [[ -f "$OVERLAY_IMG" ]]; then
        # composite overlay onto latest video frame
        ffmpeg -f rawvideo -pixel_format yuv420p -video_size $OVERLAY_SIZE -framerate $FRAMERATE -i - \
            -i "$OVERLAY_IMG" -filter_complex "[0][1]overlay=0:0:format=auto" -f sdl "Feedback Sculpture"
    fi
done

# cleanup on exit
trap "kill $PY_PID; rm -rf $TMPDIR" EXIT