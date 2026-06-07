#!/usr/bin/env bash
# poet2fractal.sh – turn a spoken poem into a synced Morse‑audio / L‑system video

set -euo pipefail

# --- configuration -----------------------------------------------------------
POEM_WAV="${1:-poem.wav}"          # input spoken poem (wav)
OUT_VIDEO="poem_fractal.mp4"       # final output
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR"

# --- 1. Speech‑to‑text ---------------------------------------------------------
# Requires pocketsphinx_continuous (install pocketsphinx)
echo "Transcribing audio..."
pocketsphinx_continuous -infile "$POEM_WAV" -time yes 2>/dev/null |
    awk '/sil/ {next} {print $5}' > "$TMPDIR/transcript.txt"

# --- 2. Sentiment analysis ----------------------------------------------------
# Uses python + textblob (pip install textblob)
echo "Analyzing sentiment..."
python3 - <<'PY' "$TMPDIR/transcript.txt" "$TMPDIR/sentiment.txt"
import sys, json
from textblob import TextBlob
txt = open(sys.argv[1]).read()
blob = TextBlob(txt)
pol = blob.sentiment.polarity   # -1..1
# Map polarity to hue (0=red, 120=green)
hue = int((pol+1)*60)           # 0..120
open(sys.argv[2], 'w').write(str(hue))
PY

HUE=$(cat "$TMPDIR/sentiment.txt")

# --- 3. Convert text to Morse code --------------------------------------------
declare -A MORSE=(
    [A]=.- [B]=-... [C]=-.-. [D]=-.. [E]=. [F]=..-. [G]=--. [H]=....
    [I]=.. [J]=.--- [K]=-.- [L]=.-.. [M]=-- [N]=-. [O]=--- [P]=.--.
    [Q]=--.- [R]=.-. [S]=... [T]=- [U]=..- [V]=...- [W]=.-- [X]=-..-
    [Y]=-.-- [Z]=--..
    [0]=----- [1]=.---- [2]=..--- [3]=...-- [4]=....- [5]=.....
    [6]=-.... [7]=--... [8]=---.. [9]=----.
)

echo "Generating Morse audio..."
MORSE_TXT="$TMPDIR/morse.txt"
while IFS= read -r line; do
    for ((i=0;i<${#line};i++)); do
        ch=${line:i:1}
        ch=${ch^^}
        [[ ${MORSE[$ch]+_} ]] && echo -n "${MORSE[$ch]} " >> "$MORSE_TXT"
    done
    echo "" >> "$MORSE_TXT"
done < "$TMPDIR/transcript.txt"

# Create tone for dot/dash using sox
DOT=0.08   # seconds
DASH=0.24
FREQ=800   # Hz

SOX_DOT="$TMPDIR/dot.wav"
SOX_DASH="$TMPDIR/dash.wav"
sox -n -r 44100 -c 1 "$SOX_DOT" synth "$DOT" sine "$FREQ" vol 0.8 >/dev/null
sox -n -r 44100 -c 1 "$SOX_DASH" synth "$DASH" sine "$FREQ" vol 0.8 >/dev/null

# Build audio sequence
SEQ="$TMPDIR/seq.txt"
> "$SEQ"
while read -r code; do
    for ((i=0;i<${#code};i++)); do
        c=${code:i:1}
        case "$c" in
            .) echo "$SOX_DOT" >> "$SEQ" ;;
            -) echo "$SOX_DASH" >> "$SEQ" ;;
            \ ) echo "silence.wav" >> "$SEQ" ;; # placeholder
        esac
        # intra‑element gap
        sox -n -r 44100 -c 1 -n synth 0.06 trim 0 "$SOX_DOT" >/dev/null 2>&1
    done
    # letter gap
    sox -n -r 44100 -c 1 -n synth 0.2 trim 0 "$SOX_DOT" >/dev/null 2>&1
done < "$MORSE_TXT"

# Concatenate all pieces
MORSE_AUDIO="$TMPDIR/morse.wav"
sox $(cat "$SEQ") "$MORSE_AUDIO" >/dev/null 2>&1

# --- 4. Generate chiptune reinterpretation ------------------------------------
# Very simple square‑wave melody using sox (placeholder)
CHIPTUNE_AUDIO="$TMPDIR/chiptune.wav"
sox -n -r 44100 -c 1 "$CHIPTUNE_AUDIO" synth 5 sine 440 vol 0.5 \
    remix - fade 0 5 0 >/dev/null

# Mix both audios
MIXED_AUDIO="$TMPDIR/mixed.wav"
sox -m "$MORSE_AUDIO" "$CHIPTUNE_AUDIO" "$MIXED_AUDIO" >/dev/null 2>&1

# --- 5. L‑system fractal generation -------------------------------------------
# Parameters: simple binary tree L‑system
python3 - <<'PY' "$TMPDIR" "$HUE"
import sys, math, os
import matplotlib.pyplot as plt
from matplotlib import colors

out_dir = sys.argv[1]
hue = int(sys.argv[2])
rgb = colors.hsv_to_rgb((hue/360.0, 1.0, 0.8))

# L‑system
axiom = "F"
rules = {"F":"F[+F]F[-F]F"}
angle = 25
iterations = 5
path = axiom
for _ in range(iterations):
    path = "".join(rules.get(c,c) for c in path)

# Drawing
stack = []
x, y = 0, 0
theta = -90
positions = [(x,y)]
lines = []
for cmd in path:
    if cmd == "F":
        nx = x + math.cos(math.radians(theta))
        ny = y + math.sin(math.radians(theta))
        lines.append(((x,y),(nx,ny)))
        x, y = nx, ny
        positions.append((x,y))
    elif cmd == "+":
        theta += angle
    elif cmd == "-":
        theta -= angle
    elif cmd == "[":
        stack.append((x,y,theta))
    elif cmd == "]":
        x, y, theta = stack.pop()

plt.figure(figsize=(6,6), facecolor='black')
for (x0,y0),(x1,y1) in lines:
    plt.plot([x0,x1],[y0,y1], color=rgb, linewidth=0.5)

plt.axis('off')
plt.tight_layout()
frame_path = os.path.join(out_dir, "frame_%04d.png")
plt.savefig(frame_path, dpi=150, transparent=True)
plt.close()
PY

# Duplicate the single frame to match audio length (30 fps)
FPS=30
DURATION=$(soxi -D "$MIXED_AUDIO")
FRAMES=$(printf "%.0f" "$(echo "$DURATION * $FPS" | bc)")
mkdir -p "$TMPDIR/frames"
ffmpeg -y -loop 1 -i "$TMPDIR/frame_0000.png" -c:v libx264 -t "$DURATION" -vf "fps=$FPS,format=yuv420p" "$TMPDIR/frames/frames_%04d.png" >/dev/null 2>&1

# --- 6. Assemble final video ---------------------------------------------------
echo "Creating video..."
ffmpeg -y -r $FPS -i "$TMPDIR/frames/frames_%04d.png" -i "$MIXED_AUDIO" -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest "$OUT_VIDEO" >/dev/null 2>&1

echo "Done: $OUT_VIDEO"
rm -rf "$TMPDIR"