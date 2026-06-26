#!/usr/bin/env bash
# Infinite audiovisual automaton driven by webcam, sound and eye‑tracking.
# Dependencies: ffmpeg, sox, python3 (with opencv, numpy, mido, pyopengl), fluidsynth, aplay, ttyrec

# ---------- Config ----------
VIDEO_DEV="/dev/video0"
AUDIO_DEV="default"
MIDI_OUT="default"       # fluidsynth soundfont
SF2="/usr/share/sounds/sf2/FluidR3_GM.sf2"
OUTPUT="output.mkv"
FPS=30
WIDTH=640
HEIGHT=480
# --------------------------------------------------

# Cleanup on exit
cleanup() {
    kill $VID_PID $AUD_PID $EYE_PID $MIDI_PID $SHADER_PID 2>/dev/null
    wait $VID_PID $AUD_PID $EYE_PID $MIDI_PID $SHADER_PID 2>/dev/null
    rm -f "$TMP_MIDI" "$TMP_SHDR" "$TMP_AMPL"
}
trap cleanup EXIT

# Temporary files / pipes
TMP_MIDI=$(mktemp /tmp/midi.XXXX.mid)
TMP_SHDR=$(mktemp /tmp/shader.XXXX.txt)
TMP_AMPL=$(mktemp /tmp/amp.XXXX.txt)

# ---- 1. Capture webcam raw frames (RGB) ----
ffmpeg -f v4l2 -framerate $FPS -video_size ${WIDTH}x${HEIGHT} -i "$VIDEO_DEV" \
       -f rawvideo -pix_fmt rgb24 - > >(cat) &
VID_PID=$!

# ---- 2. Capture ambient sound amplitude (RMS) ----
sox -t alsa "$AUDIO_DEV" -n trim 0 1 stats : newfile : restart \
    2> "$TMP_AMPL" &
AUD_PID=$!

# ---- 3. Run eye‑tracking (simple pupil centre via OpenCV) ----
python3 - <<'PY_EYE' &
import cv2, sys, json
cap = cv2.VideoCapture(0)
while True:
    ret, frame = cap.read()
    if not ret: break
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    _, thresh = cv2.threshold(gray, 70, 255, cv2.THRESH_BINARY_INV)
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    pts = [(c.mean(axis=0)[0], c.mean(axis=0)[1]) for c in contours if cv2.contourArea(c)>30]
    # crude gaze centre = average of biggest contour
    if pts:
        x = sum(p[0] for p in pts)/len(pts)
        y = sum(p[1] for p in pts)/len(pts)
        sys.stdout.write(json.dumps({"x":x,"y":y})+"\n")
        sys.stdout.flush()
PY_EYE
EYE_PID=$!

# ---- 4. Python core: cellular automaton → MIDI + shader params ----
python3 - <<'PY_CORE' &
import sys, os, json, struct, numpy as np, mido, time
from collections import defaultdict

# shared pipes
midi_pipe = open(os.getenv('TMP_MIDI'), 'wb')
shdr_pipe = open(os.getenv('TMP_SHDR'), 'w')
amp_file = os.getenv('TMP_AMPL')

# CA parameters
W, H = int(os.getenv('WIDTH')), int(os.getenv('HEIGHT'))
grid = np.random.randint(0, 2, (H, W), dtype=np.uint8)

def next_state(g):
    # simple 2‑D Life as stand‑in for 4‑D CA
    nb = sum(np.roll(np.roll(g, i, 0), j, 1)
             for i in (-1,0,1) for j in (-1,0,1) if not (i==j==0))
    return ((g==1) & ((nb==2)|(nb==3))) | ((g==0) & (nb==3))

def amplitude():
    try:
        with open(amp_file) as f:
            lines = f.readlines()
        # parse RMS from sox stats (line starting with "RMS    amplitude")
        for l in lines[::-1]:
            if l.startswith("RMS    amplitude"):
                return float(l.split()[-1])
    except Exception:
        return 0.0

def gaze():
    try:
        line = sys.stdin.readline()
        if not line: return (W//2, H//2)
        data = json.loads(line)
        return data['x'], data['y']
    except Exception:
        return (W//2, H//2)

# MIDI note mapping (scale)
scale = [60,62,64,65,67,69,71,72]  # C major one octave
mid = mido.Message('program_change', program=0, channel=0)
mid.save(os.getenv('TMP_MIDI'))  # init empty

while True:
    # evolve CA
    grid[:] = next_state(grid)
    # read sensors
    amp = amplitude()
    gx, gy = gaze()
    # tempo adapts to amplitude (60–180 BPM)
    bpm = 60 + int(120*amp)
    # pick notes based on live cells under gaze
    cx, cy = int(gx)%W, int(gy)%H
    cells = grid[cy-2:cy+3, cx-2:cx+3].flatten()
    notes = [scale[i%len(scale)] for i, v in enumerate(cells) if v]
    # build MIDI track
    mid = mido.MidiFile()
    track = mido.MidiTrack()
    mid.tracks.append(track)
    track.append(mido.Message('control_change', control=0x20, value=bpm//2, time=0))
    tick = int(mido.bpm2tempo(bpm)/500)  # rough quarter‑note
    for n in notes[:8]:
        track.append(mido.Message('note_on', note=n, velocity=80, time=tick))
        track.append(mido.Message('note_off', note=n, velocity=0, time=tick))
    # write MIDI to pipe
    mid.save(os.getenv('TMP_MIDI'))
    # shader colour evolves with amplitude & CA density
    density = grid.mean()
    hue = int(360 * density) % 360
    sat = int(100 * amp)
    val = 80
    shdr_pipe.write(f"hsv({hue},{sat}%,{val}%)\\n")
    shdr_pipe.flush()
    time.sleep(60.0/bpm)
PY_CORE
MIDI_PID=$!

# ---- 5. Synthesise MIDI to audio (fluidsynth) ----
fluidsynth -ni "$SF2" "$TMP_MIDI" -F /tmp/midi.wav -r 44100 &
MIDI_SYNTH_PID=$!
wait $MIDI_SYNTH_PID
aplay /tmp/midi.wav &
MIDI_OUT_PID=$!

# ---- 6. Combine video, generated shader (as colour overlay) and audio into one stream ----
ffmpeg -f rawvideo -pixel_format rgb24 -video_size ${WIDTH}x${HEIGHT} -framerate $FPS -i - \
       -f lavfi -i "color=c=black:s=${WIDTH}x${HEIGHT}:d=0.1" \
       -filter_complex "\
         [0:v]format=rgb24,geq='r=lum(X,Y)':a=1[cam]; \
         [1:v]format=rgb24,color=0x$(cat "$TMP_SHDR" | head -n1 | tr -d '\\n') [shdr]; \
         [cam][shdr]overlay" \
       -c:v libx264 -preset veryfast -tune zerolatency -f matroska "$OUTPUT" &
SHADER_PID=$!

wait $VID_PID $AUD_PID $EYE_PID $MIDI_PID $SHADER_PID

# End of script. The output file "$OUTPUT" contains the synchronized audiovisual stream.