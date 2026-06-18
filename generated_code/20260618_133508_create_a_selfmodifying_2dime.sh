#!/usr/bin/env bash
# cellular_art.sh – self‑modifying 2‑D cellular automaton art generator
# Usage: ./cellular_art.sh input.png output.png
# Requires: ImageMagick (convert), Python3

set -euo pipefail

if (( $# != 2 )); then
    echo "Usage: $0 INPUT.PNG OUTPUT.PNG" >&2
    exit 1
fi

INFILE=$1
OUTFILE=$2
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# 1. Dump grayscale intensities to a binary matrix (uint8)
convert "$INFILE" -colorspace Gray -depth 8 gray:"$TMPDIR/pixels.raw"

# 2. Determine image dimensions
read WIDTH HEIGHT < <(identify -format "%w %h" "$INFILE")

# 3. Run the automaton core in Python (self‑modifying via exec)
python3 - <<'PY' "$TMPDIR/pixels.raw" "$WIDTH" "$HEIGHT" "$TMPDIR/trails.png"
import sys, os, numpy as np, random, math
raw_path, w, h, out_png = sys.argv[1:5]
w, h = int(w), int(h)

# load intensity matrix (rule‑weights)
grid = np.fromfile(raw_path, dtype=np.uint8).reshape((h, w))

# parameters
agents = 500                      # number of brush agents
steps  = w * h * 2               # total evolution steps
colors = [(255,0,0), (0,255,0), (0,0,255), (255,255,0), (255,0,255), (0,255,255)]

# initialise agents on random positions with random directions
pos = np.column_stack((np.random.randint(0,w,agents),
                       np.random.randint(0,h,agents)))
theta = np.random.rand(agents) * 2*math.pi

# canvas for trails (RGBA)
canvas = np.zeros((h, w, 4), dtype=np.uint8)

def step(i):
    global pos, theta, canvas
    # each agent reads weight under it, turns proportionally
    y, x = pos[:,1], pos[:,0]
    weights = grid[y, x].astype(np.float32) / 255.0
    theta += (weights - 0.5) * math.pi   # turn left/right
    # move forward
    dx = np.cos(theta)
    dy = np.sin(theta)
    pos[:,0] = (pos[:,0] + np.round(dx)).astype(int) % w
    pos[:,1] = (pos[:,1] + np.round(dy)).astype(int) % h
    # leave a colored pixel
    for a in range(agents):
        col = colors[a % len(colors)]
        canvas[pos[a,1], pos[a,0], :3] = col
        canvas[pos[a,1], pos[a,0], 3] = 255  # opaque

for i in range(steps):
    step(i)

# blend trails onto original grayscale (as background)
bg = np.repeat(grid[:, :, None], 3, axis=2)
bg = np.dstack((bg, np.full_like(grid, 255)))  # opaque gray bg
result = np.where(canvas[:, :, 3:4]==255, canvas, bg)

# save PNG
from PIL import Image
Image.fromarray(result, 'RGBA').save(out_png)
PY

# 4. Overlay trails on original for visual output
convert "$INFILE" "$TMPDIR/trails.png" -compose over -composite "$OUTFILE"

echo "Artwork saved to $OUTFILE"