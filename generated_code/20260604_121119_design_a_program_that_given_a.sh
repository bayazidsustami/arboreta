#!/usr/bin/env bash
# ------------------------------------------------------------
# livecam2music.sh – webcam → colors → notes → fractal SVG → MIDI + GIF
# ------------------------------------------------------------
# Dependencies: ffmpeg, imagemagick (convert), sox, python3, numpy,
#   opencv-python, mido, cairosvg, ffmpeg (for GIF), aplay (optional)
# ------------------------------------------------------------

set -euo pipefail

# Configurable parameters
DURATION=15                # seconds to capture
FPS=10                     # frames per second for analysis
PALETTE=5                  # number of dominant colors per frame
MIDI_TEMPO=120             # beats per minute
SVG_SIZE=800               # width/height of SVG canvas
GIF_FPS=15                 # output GIF frame rate

# Temporary workspace
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# 1. Capture webcam video (raw)
ffmpeg -y -f v4l2 -framerate "$FPS" -video_size 640x480 -i /dev/video0 \
       -t "$DURATION" -c:v libx264 -pix_fmt yuv420p "$TMPDIR/video.mp4"

# 2. Extract frames as PNG
ffmpeg -i "$TMPDIR/video.mp4" -vf "fps=$FPS" "$TMPDIR/frame_%04d.png"

# 3. Python helper: colors → notes, generate MIDI and SVG frames
cat > "$TMPDIR/process.py" <<'PYTHON'
import sys, os, json, subprocess
from pathlib import Path
import numpy as np
import cv2
from sklearn.cluster import KMeans
import mido
from mido import Message, MidiFile, MidiTrack
import math
import cairosvg

# config (mirrored from bash)
PALETTE = int(os.getenv('PALETTE', 5))
MIDI_TEMPO = int(os.getenv('MIDI_TEMPO', 120))
SVG_SIZE = int(os.getenv('SVG_SIZE', 800))
FPS = int(os.getenv('FPS', 10))

# harmonic lattice: map hue (0-360) to MIDI note (C3=48 .. B5=83)
def hue_to_midi(hue):
    # simple linear mapping across two octaves
    return int(48 + (hue / 360.0) * 35)

def midi_to_freq(note):
    return 440.0 * 2**((note-69)/12.0)

# create empty MIDI
mid = MidiFile(ticks_per_beat=480)
track = MidiTrack()
mid.tracks.append(track)
track.append(mido.MetaMessage('set_tempo', tempo=mido.bpm2tempo(MIDI_TEMPO)))

frame_paths = sorted(Path(sys.argv[1]).glob('frame_*.png'))
svg_frames = []

for i, fp in enumerate(frame_paths):
    img = cv2.imread(str(fp))
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    h, w, _ = img.shape
    # reshape for clustering
    pixels = img.reshape(-1, 3)
    kmeans = KMeans(n_clusters=PALETTE, random_state=0).fit(pixels)
    centers = kmeans.cluster_centers_.astype(int)

    # pick dominant hue from first centroid
    r, g, b = centers[0]
    hue = cv2.cvtColor(np.uint8([[[r,g,b]]]), cv2.COLOR_RGB2HSV)[0][0][0]
    note = hue_to_midi(hue)
    freq = midi_to_freq(note)

    # MIDI: note on/off 0.5 beat each frame
    tick = int(480 * (60/MIDI_TEMPO) * 0.5)  # half-beat duration
    track.append(Message('note_on', note=note, velocity=64, time=0))
    track.append(Message('note_off', note=note, velocity=64, time=tick))

    # 4. Generate fractal SVG driven by freq (e.g., L-system depth)
    depth = int(2 + (freq % 5))
    angle = (freq % 360) * math.pi/180
    # simple recursive tree as placeholder
    def branch(x, y, len_, ang, d):
        if d==0: return ''
        x2 = x + len_ * math.cos(ang)
        y2 = y + len_ * math.sin(ang)
        line = f'<line x1="{x}" y1="{y}" x2="{x2}" y2="{y2}" stroke="hsl({int(hue)},80%,60%)" stroke-width="{d}"/>'
        return line + branch(x2, y2, len_*0.7, ang-angle, d-1) + branch(x2, y2, len_*0.7, ang+angle, d-1)

    svg_body = branch(SVG_SIZE/2, SVG_SIZE, SVG_SIZE/3, -math.pi/2, depth)
    svg_content = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{SVG_SIZE}" height="{SVG_SIZE}" viewBox="0 0 {SVG_SIZE} {SVG_SIZE}">
<rect width="100%" height="100%" fill="black"/>
{svg_body}
</svg>'''
    svg_path = Path(sys.argv[2]) / f'svg_{i:04d}.svg'
    svg_path.write_text(svg_content)
    svg_frames.append(str(svg_path))

# write MIDI
mid.save(sys.argv[3])
# output list of SVG frames for later GIF conversion
print('\n'.join(svg_frames))
PYTHON

# Export vars for Python
export PALETTE FPS MIDI_TEMPO SVG_SIZE

# Run Python processing
SVG_LIST=$(
python3 "$TMPDIR/process.py" "$TMPDIR" "$TMPDIR/svg_frames" "$TMPDIR/output.mid"
)

# 5. Convert SVG frames to PNG (for GIF)
mkdir -p "$TMPDIR/png_frames"
i=0
while read -r svg; do
    png="$TMPDIR/png_frames/frame_${i:0>4}.png"
    cairosvg "$svg" -o "$png" -f png -w "$SVG_SIZE" -h "$SVG_SIZE"
    ((i++))
done <<< "$SVG_LIST"

# 6. Assemble animated GIF (fractal background)
ffmpeg -y -framerate "$GIF_FPS" -i "$TMPDIR/png_frames/frame_%04d.png" -vf "scale=$SVG_SIZE:$SVG_SIZE" "$TMPDIR/fractal.gif"

# 7. Visualize audio waveform as scrolling typographic poem
# Generate a simple sine wave from MIDI (using fluidsynth is heavy, we synthesize)
# Here we use sox to create a dummy waveform based on note frequencies
# Create raw audio from notes
python3 - <<PYTHON
import mido, numpy as np, wave, sys, os
mid = mido.MidiFile(os.getenv('TMPDIR') + '/output.mid')
sr = 44100
audio = np.zeros(int(sr*float(os.getenv('DURATION'))), dtype=np.float32)
t = np.arange(len(audio))/sr
for msg in mid: 
    if msg.type=='note_on' and msg.velocity>0:
        freq = 440.0*2**((msg.note-69)/12.0)
        dur = 0.5  # seconds per note (approx)
        start = int(msg.time/480 * 60/float(os.getenv('MIDI_TEMPO')) * sr)
        end = start + int(dur*sr)
        audio[start:end] += 0.3*np.sin(2*np.pi*freq*np.arange(end-start)/sr)
audio = np.clip(audio, -1, 1)
wav_path = os.getenv('TMPDIR') + '/audio.wav'
with wave.open(wav_path, 'w') as wf:
    wf.setnchannels(1); wf.setsampwidth(2); wf.setframerate(sr)
    wf.writeframes((audio*32767).astype('<i2').tobytes())
PYTHON

# Create poem frames (scrolling text)
POEM="Colorful whispers\\nfrom the lens\\nbeat by beat\\nnotes bloom\\nas fractals rise"
mkdir -p "$TMPDIR/poem_frames"
convert -size "${SVG_SIZE}x${SVG_SIZE}" xc:none -font Liberation-Sans -pointsize 24 -fill white -gravity center \
        -annotate 0 "$POEM" "$TMPDIR/poem_frames/blank.png"

# Overlay poem onto fractal GIF with waveform visualization using ffmpeg
ffmpeg -y -i "$TMPDIR/fractal.gif" -i "$TMPDIR/audio.wav" -filter_complex "
[0:v]setpts=PTS-STARTPTS[bg];
[1:a]aformat=channel_layouts=mono,showwavespic=s=${SVG_SIZE}x100:mode=line:colors=white[wf];
[bg][wf]overlay=0:H-100[bgwf];
[bgwf]drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf:text='${POEM}':fontcolor=white:fontsize=24:x='(w-text_w)/2':y='h-120':enable='between(t,0,${DURATION})'[out]
" -map "[out]" -map 1:a -c:v libvpx -c:a libvorbis -shortest "$TMPDIR/final.webm"

# 8. Export results
mkdir -p output
cp "$TMPDIR/output.mid" "output/music.mid"
cp "$TMPDIR/fractal.gif" "output/fractal.gif"
cp "$TMPDIR/final.webm" "output/visualization.webm"

echo "Done. Files in ./output:"
ls -1 output