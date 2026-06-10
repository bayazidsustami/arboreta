#!/usr/bin/env bash
# realtime webcam → color palette → MIDI chords → ASCII mandala → GIF+MIDI loop
# Dependencies: ffmpeg, python3, pillow, numpy, scikit-learn, mido, python-rtmidi, ImageMagick, timidity

set -euo pipefail

#-------------------- Config --------------------
FPS=10                     # frames per second for processing
DUR=10                     # seconds per loop segment
TMPDIR=$(mktemp -d)
FRAMES_DIR="$TMPDIR/frames"
ASCII_DIR="$TMPDIR/ascii"
MIDI_FILE="$TMPDIR/chords.mid"
OUT_GIF="output.gif"
OUT_MID="output.mid"
# Simple color→note map (hex to MIDI note)
declare -A COL2NOTE=(
  ["#FF0000"]=60 ["#00FF00"]=64 ["#0000FF"]=67
  ["#FFFF00"]=62 ["#FF00FF"]=65 ["#00FFFF"]=69
)

#-------------------- Helpers --------------------
palette_py() {  # $1 = image path, stdout = space-separated hex colors
python3 - <<'PY' "$1"
import sys, json
from PIL import Image
import numpy as np
from sklearn.cluster import KMeans
img = Image.open(sys.argv[1]).convert('RGB')
img = img.resize((64,64))
arr = np.array(img).reshape(-1,3)
k = KMeans(n_clusters=3, random_state=0).fit(arr)
cols = ['#%02X%02X%02X' % tuple(map(int,c)) for c in k.cluster_centers_]
print(' '.join(cols))
PY
}

midi_py() {  # $1 = space-separated hex colors, creates MIDI file $2
python3 - <<'PY' "$1" "$2"
import sys, json
from mido import Message, MidiFile, MidiTrack, MetaMessage
colors = sys.argv[1].split()
out_path = sys.argv[2]
mid = MidiFile()
track = MidiTrack()
mid.tracks.append(track)
track.append(MetaMessage('set_tempo', tempo=500000))  # 120bpm
note_map = {
  "#FF0000":60, "#00FF00":64, "#0000FF":67,
  "#FFFF00":62, "#FF00FF":65, "#00FFFF":69
}
time = 0
for c in colors:
    note = note_map.get(c.upper(), 60)
    track.append(Message('note_on', note=note, velocity=64, time=time))
    track.append(Message('note_off', note=note, velocity=64, time=480))
    time = 0
mid.save(out_path)
PY
}

mandala_py() {  # $1 = tension (0-1), $2 = output txt
python3 - <<'PY' "$1" "$2"
import sys, math, random
t = float(sys.argv[1])
out = sys.argv[2]
size = 40
lines = []
for i in range(size):
    angle = 2*math.pi*i/size
    radius = int((1+math.sin(t*math.pi))*10 + random.random()*5)
    x = int(size/2 + radius*math.cos(angle))
    y = int(size/2 + radius*math.sin(angle))
    lines.append(f"{x} {y} *")
with open(out,'w') as f:
    f.write("\n".join(lines))
PY
}

#-------------------- Capture frames --------------------
mkdir -p "$FRAMES_DIR" "$ASCII_DIR"
ffmpeg -y -f v4l2 -framerate $FPS -video_size 320x240 -i /dev/video0 -t $DUR -vf "fps=$FPS,scale=160:120" "$FRAMES_DIR/frame_%03d.png" >/dev/null 2>&1

#-------------------- Process each frame --------------------
i=0
for img in "$FRAMES_DIR"/frame_*.png; do
    # extract palette
    palette=$(palette_py "$img")
    # generate MIDI chord for this frame
    chord_mid="$TMPDIR/chord_$i.mid"
    midi_py "$palette" "$chord_mid"
    # compute tension (simple variance of notes)
    notes=$(python3 -c "import mido,sys;print(' '.join(str(m.note) for m in mido.MidiFile(sys.argv[1]).play()))" "$chord_mid")
    tension=$(python3 -c "import sys,statistics; vals=list(map(int,sys.argv[1].split())); print(min(1,statistics.stdev(vals)/30))" $notes)
    # generate ASCII mandala based on tension
    mandala_txt="$ASCII_DIR/mandala_$i.txt"
    mandala_py "$tension" "$mandala_txt"
    # render ASCII to image
    convert -size 200x200 xc:black -font DejaVu-Sans-Mono -pointsize 8 -fill white -draw "@$mandala_txt" "$ASCII_DIR/frame_$i.png"
    ((i++))
done

#-------------------- Assemble GIF --------------------
convert -delay $((100/$FPS)) -loop 0 "$ASCII_DIR"/frame_*.png "$OUT_GIF"

#-------------------- Concatenate MIDI --------------------
# Simple concat: merge all chord midis into one track
python3 - <<'PY' "$TMPDIR" "$MIDI_FILE"
import sys, mido, os
base = mido.MidiFile()
track = mido.MidiTrack()
base.tracks.append(track)
track.append(mido.MetaMessage('set_tempo', tempo=500000))
for f in sorted(os.listdir(sys.argv[1])):
    if f.endswith('.mid') and f.startswith('chord_'):
        mid = mido.MidiFile(os.path.join(sys.argv[1], f))
        for msg in mid.tracks[0]:
            if not msg.is_meta:
                track.append(msg)
base.save(sys.argv[2])
PY

#-------------------- Convert MIDI to audio (optional) --------------------
# timidity produces wav, then we can embed as .mid as requested
timidity "$MIDI_FILE" -Ow -o "$OUT_MID.wav" >/dev/null 2>&1
# embed wav as midi? skip; just keep midi file
cp "$MIDI_FILE" "$OUT_MID"

#-------------------- Cleanup --------------------
rm -rf "$TMPDIR"

echo "Created $OUT_GIF and $OUT_MID"