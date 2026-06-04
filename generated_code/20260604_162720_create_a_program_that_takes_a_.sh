#!/usr/bin/env bash
# webcam‑to‑audio‑visual poem
# requires: bash, ffmpeg, python3, numpy, opencv‑python, mido, python‑rtmidi, fluidsynth, sox

# ---------- configuration ----------
VIDEO_DEV="/dev/video0"            # webcam device
FPS=10                             # frames per second
NOTE_MIN=48                        # C3
NOTE_MAX=84                        # C6
MIDI_OUT="virtual_midi_out"        # name of virtual MIDI port
SF2="/usr/share/sounds/sf2/FluidR3_GM.sf2"  # soundfont for fluidsynth
PYTMP=$(mktemp /tmp/webcam2midi.XXXX.py)

# ---------- ensure virtual MIDI port ----------
if ! aseqnet -l | grep -q "$MIDI_OUT"; then
    aseqnet -i -o -p 128 "$MIDI_OUT" &
    sleep 1
fi

# ---------- start synthesizer ----------
fluidsynth -ni "$SF2" "$MIDI_OUT" &
FS_PID=$!
sleep 1

# ---------- embed python processor ----------
cat >"$PYTMP" <<'PYEND'
import sys, os, numpy as np, cv2, mido, time, random
from mido import Message, MidiFile, MidiTrack, second2tick

# midi setup
outport = mido.open_output(os.getenv('MIDI_OUT'), virtual=True)

def hue_char(pitch, vel, t):
    hue = int( (pitch-48)/36 * 5 )          # 0‑5 hue levels
    chars = ['.', ':', '*', 'o', 'O', '@']
    return f'\x1b[3{hue}m{chars[hue]}\x1b[0m'

def self_modify():
    src = os.path.abspath(__file__)
    with open(src, 'a') as f:
        f.write(f"# note at {time.time():.2f}\\n")

last_t = time.time()
while True:
    # read PPM header
    hdr = sys.stdin.buffer.read(15)        # P6\nW H\n255\n
    if not hdr: break
    dims = hdr.split()
    w, h = int(dims[1]), int(dims[2])
    # read raw frame
    raw = sys.stdin.buffer.read(w*h*3)
    if len(raw)!=w*h*3: break
    img = np.frombuffer(raw, dtype=np.uint8).reshape((h,w,3))
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    edges = cv2.Canny(gray,100,200)
    # simple pitch from mean edge intensity
    intensity = edges.mean()
    pitch = int(48 + intensity/255*36)
    velocity = int(30 + intensity/255*97)
    now = time.time()
    delta = now - last_t
    last_t = now
    # send midi note on/off
    outport.send(Message('note_on', note=pitch, velocity=velocity))
    time.sleep(0.05)
    outport.send(Message('note_off', note=pitch, velocity=0))
    # print ascii char
    sys.stdout.write(hue_char(pitch, velocity, now))
    sys.stdout.flush()
    # occasional self‑modification
    if random.random()<0.01:
        self_modify()
PYEND

export MIDI_OUT="$MIDI_OUT"

# ---------- main loop ----------
ffmpeg -f v4l2 -framerate $FPS -video_size 160x120 -i "$VIDEO_DEV" \
    -vf "format=rgb24,scale=80:60" -f image2pipe -vcodec rawvideo - |
    python3 "$PYTMP"

# ---------- cleanup ----------
kill $FS_PID 2>/dev/null
rm -f "$PYTMP"