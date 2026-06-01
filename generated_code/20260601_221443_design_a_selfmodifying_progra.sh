#!/usr/bin/env bash
# Self‑modifying kaleidoscope generator
# Each run:
#   1. Capture one frame from the default webcam (ffmpeg)
#   2. Extract 5 dominant colors (ImageMagick)
#   3. Build an SVG mandala using those colors
#   4. Rewrite the script (the part between __SVG_START__ and __SVG_END__) with the new SVG
#   5. Save the new script as a timestamped copy

set -euo pipefail

# ---------- CONFIG ----------
FRAME="/tmp/webcam_frame.jpg"
COLORS_COUNT=5
SVG_WIDTH=800
SVG_HEIGHT=800
# ---------------------------

# Capture a single frame (quietly)
ffmpeg -y -f v4l2 -i /dev/video0 -frames:v 1 -q:v 2 "$FRAME" < /dev/null 2>/dev/null

# Extract dominant colors (hex) into an array
mapfile -t COLORS < <(
  convert "$FRAME" -resize 200x200! -define histogram:unique-colors=true \
    -format "%c" histogram:info: |
    sed -n 's/.*#\([0-9A-Fa-f]\{6\}\).*/#\1/p' |
    head -n "$COLORS_COUNT"
)

# Fallback if extraction failed
if (( ${#COLORS[@]} == 0 )); then
  COLORS=(#ff0000 #00ff00 #0000ff #ffff00 #ff00ff)
fi

# Generate SVG mandala (simple radial pattern)
generate_svg() {
cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<svg width="${SVG_WIDTH}" height="${SVG_HEIGHT}" viewBox="0 0 ${SVG_WIDTH} ${SVG_HEIGHT}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <radialGradient id="grad" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="${COLORS[0]}" />
      <stop offset="100%" stop-color="${COLORS[1]}" />
    </radialGradient>
  </defs>
  <rect width="100%" height="100%" fill="url(#grad)"/>
EOF
  for i in {0..11}; do
    angle=$((i*30))
    cx=$((SVG_WIDTH/2))
    cy=$((SVG_HEIGHT/2))
    r=$((SVG_WIDTH/3))
    x=$((cx + r * $(bc -l <<< "c($angle*4*a(1)/180)")))
    y=$((cy + r * $(bc -l <<< "s($angle*4*a(1)/180)")))
    color="${COLORS[$((i % COLORS_COUNT))]}"
    echo "  <circle cx=\"$x\" cy=\"$y\" r=\"${SVG_WIDTH/20}\" fill=\"$color\" fill-opacity=\"0.6\"/>"
  done
cat <<EOF
</svg>
EOF
}
NEW_SVG="$(generate_svg)"

# Rewrite the script: replace the block between markers with NEW_SVG
SCRIPT_PATH="${BASH_SOURCE[0]}"
TMP_SCRIPT="$(mktemp)"
awk -v svg="$NEW_SVG" '
  BEGIN{in_svg=0}
  /__SVG_START__/ {print; print svg; in_svg=1; next}
  /__SVG_END__/   {in_svg=0}
  {if (!in_svg) print}
' "$SCRIPT_PATH" > "$TMP_SCRIPT"
chmod +x "$TMP_SCRIPT"

# Save the new version with timestamp
timestamp=$(date +"%Y%m%d_%H%M%S")
cp "$TMP_SCRIPT" "./script_${timestamp}.sh"
rm -f "$TMP_SCRIPT"

exit 0

# __SVG_START__
# (old SVG will be replaced here)
# __SVG_END__