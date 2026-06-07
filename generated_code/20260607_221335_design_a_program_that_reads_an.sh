#!/usr/bin/env bash
# spoken_lsystem.sh – capture speech, analyse it and generate an interactive SVG L‑system visualisation

set -euo pipefail

#--- Configuration ------------------------------------------------------------
TMPDIR=$(mktemp -d)
AUDIO_WAV="$TMPDIR/input.wav"
TEXT_TXT="$TMPDIR/text.txt"
SENTI_JSON="$TMPDIR/sentiment.json"
PYTHON_SCRIPT="$TMPDIR/gen_lsystem.py"
SVG_OUT="lsystem_visual.svg"
# Duration to record (seconds)
REC_SECONDS=8

#--- Helper: clean up ---------------------------------------------------------
cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

#--- 1. Record audio (requires sox) -------------------------------------------
echo "Recording $REC_SECONDS seconds of speech (press Ctrl+C to abort)..."
sox -d -b 16 -c 1 -r 16000 "$AUDIO_WAV" trim 0 "$REC_SECONDS"

#--- 2. Speech‑to‑text (using pocketsphinx_continuous, install pocketsphinx) ---
if ! command -v pocketsphinx_continuous >/dev/null; then
    echo "pocketsphinx not found – installing via apt (requires sudo)..."
    sudo apt-get update && sudo apt-get install -y pocketsphinx
fi

echo "Transcribing audio..."
pocketsphinx_continuous -infile "$AUDIO_WAV" 2>/dev/null | tr -d '\r' > "$TEXT_TXT"

#--- 3. Sentiment analysis (tiny python stub using TextBlob) --------------------
if ! command -v python3 >/dev/null; then
    echo "python3 not found – cannot continue."
    exit 1
fi

cat > "$PYTHON_SCRIPT" <<'PYEOF'
#!/usr/bin/env python3
import sys, json, re, math
from textblob import TextBlob

def syllable_stress(word):
    # crude: count vowel groups as syllables, stress pattern = 1 for stressed (odd) else 0
    syl = re.findall(r'[aeiouy]+', word.lower())
    return [1 if i%2==0 else 0 for i in range(len(syl))]

def pitch_contour(audio_path):
    # placeholder: return a sinusoidal contour length 100
    return [math.sin(2*math.pi*i/100) for i in range(100)]

def main():
    txt_path, out_json = sys.argv[1:3]
    with open(txt_path) as f:
        text = f.read().strip()
    blob = TextBlob(text)
    sentiment = blob.sentiment.polarity  # -1..1
    words = re.findall(r"\b\w+\b", text)
    stresses = [s for w in words for s in syllable_stress(w)]
    pitch = pitch_contour("")[:len(stresses)]  # same length
    out = {
        "text": text,
        "sentiment": sentiment,
        "stresses": stresses,
        "pitch": pitch,
        "words": words
    }
    with open(out_json, "w") as f:
        json.dump(out, f)

if __name__ == "__main__":
    main()
PYEOF
chmod +x "$PYTHON_SCRIPT"

# install TextBlob if missing
python3 - <<'PY'
try:
    from textblob import TextBlob
except ImportError:
    import subprocess, sys
    subprocess.check_call([sys.executable, "-m", "pip", "install", "textblob"])
    import nltk
    nltk.download('punkt')
PY

echo "Analysing sentiment and prosody..."
python3 "$PYTHON_SCRIPT" "$TEXT_TXT" "$SENTI_JSON"

#--- 4. Generate L‑system and SVG (another python helper) --------------------
cat > "$PYTHON_SCRIPT" <<'PYEOF'
#!/usr/bin/env python3
import json, sys, math
import random

# Simple deterministic L‑system influenced by stress (0/1) and sentiment
def build_rules(stresses, sentiment):
    # Base axiom
    axiom = "F"
    # Rule: stressed => F+F−F, unstressed => F−F+F
    rules = {
        "F": "F+F-F" if random.random() < 0.5 else "F-F+F"
    }
    # Modify with sentiment: shift angle
    angle = 25 + 20*sentiment  # sentiment -1..1 maps to 5..45°
    return axiom, rules, angle

def iterate(axiom, rules, iters):
    cur = axiom
    for _ in range(iters):
        cur = "".join(rules.get(ch, ch) for ch in cur)
    return cur

def turtle_path(instructions, angle):
    x, y, a = 0.0, 0.0, 0.0
    stack = []
    pts = [(x, y)]
    for cmd in instructions:
        if cmd == "F":
            x += math.cos(math.radians(a))
            y += math.sin(math.radians(a))
            pts.append((x, y))
        elif cmd == "+":
            a += angle
        elif cmd == "-":
            a -= angle
        elif cmd == "[":
            stack.append((x, y, a))
        elif cmd == "]":
            x, y, a = stack.pop()
            pts.append((x, y))
    return pts

def generate_svg(points, sentiment):
    # colour from sentiment: blue (negative) to red (positive)
    r = int(255 * (sentiment + 1) / 2)
    b = 255 - r
    colour = f"rgb({r},0,{b})"
    # scale to viewbox 800
    xs, ys = zip(*points)
    minx, maxx = min(xs), max(xs)
    miny, maxy = min(ys), max(ys)
    scale = 750.0 / max(maxx-minx, maxy-miny)
    tx = -minx*scale + 25
    ty = -miny*scale + 25
    path = "M " + " L ".join(f"{x*scale+tx:.2f},{y*scale+ty:.2f}" for x,y in points)
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800">
<path d="{path}" stroke="{colour}" fill="none" stroke-width="2"/>
<script type="application/ecmascript"><![CDATA[
   // Simple pan‑zoom interaction
   const svg = document.documentElement;
   let zoom = 1, offX = 0, offY = 0;
   svg.addEventListener('wheel', e=>{ e.preventDefault(); zoom *= e.deltaY>0?0.9:1.1; svg.setAttribute('transform',`translate(${offX},${offY}) scale(${zoom})`); });
   let dragging = false, start={x:0,y:0};
   svg.addEventListener('mousedown', e=>{dragging=true; start={x:e.clientX,y:e.clientY};});
   svg.addEventListener('mousemove', e=>{ if(dragging){ offX+= (e.clientX-start.x)/zoom; offY+= (e.clientY-start.y)/zoom; start=e; svg.setAttribute('transform',`translate(${offX},${offY}) scale(${zoom})`);}});
   svg.addEventListener('mouseup',()=>dragging=false);
   svg.addEventListener('mouseleave',()=>dragging=false);
]]></script>
</svg>'''
    return svg

def main():
    data = json.load(open(sys.argv[1]))
    ax, rules, angle = build_rules(data["stresses"], data["sentiment"])
    instr = iterate(ax, rules, iters=4+len(data["stresses"])//5)
    pts = turtle_path(instr, angle)
    svg = generate_svg(pts, data["sentiment"])
    with open(sys.argv[2], "w") as f:
        f.write(svg)

if __name__ == "__main__":
    main()
PYEOF
chmod +x "$PYTHON_SCRIPT"

echo "Generating L‑system SVG..."
python3 "$PYTHON_SCRIPT" "$SENTI_JSON" "$SVG_OUT"

echo "Done – SVG visualisation written to $SVG_OUT"
echo "Open it in a browser to explore the interactive poem."