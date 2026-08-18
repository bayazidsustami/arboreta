#!/usr/bin/env bash
# ==============================================================================
# ASCII Micro-Poetic Cellular Automaton & Dynamic Ambient Synthesizer
# ==============================================================================
# Synthesizes neighbor ASCII bytes into micro-poems, computes sentiment-based
# audio frequencies via dynamic sine-wave generation (/dev/dsp or paplay),
# and renders an evolving SVG fractal landscape.

set -euo pipefail

# Configuration
WIDTH=12
HEIGHT=12
STEPS=5
OUTPUT_DIR="ca_output"
AUDIO_FILE="${OUTPUT_DIR}/ambient_synth.raw"
SVG_FILE="${OUTPUT_DIR}/fractal_landscape.svg"

mkdir -p "$OUTPUT_DIR"

# Initialize 2D Cellular Automaton grid with seed character ASCII values
declare -A GRID
declare -A NEXT_GRID

# Words for micro-poem generator mapped by character hash
NOUNS=("stars" "shadows" "echoes" "petals" "dreams" "rivers" "whispers" "flames")
VERBS=("fade" "bloom" "dance" "sing" "drift" "glow" "weave" "rise")
ADJS=("silent" "golden" "ancient" "hollow" "cosmic" "tender" "fleeting" "bright")

for ((y=0; y<HEIGHT; "$AUDIO_FILE" "$score" "${ADJS[$n1]} "%c", "%d" "'${poem:$i:1}" # ${#ADJS[@]} ${#NOUNS[@]} ${#VERBS[@]} ${NOUNS[$n2]} ${NOUNS[$n3]}" ${VERBS[$v1]} % 'BEGIN (( ((x="0;" (0-99) (110Hz (8000Hz, (i="0;" (score (sum (x )) )); * + - -f -v / 0.1s 10 100 100) 110 128) 13) 17 19) 3.14159265 32 37 42) 7 7) 8 8-bit 8000) 8000Hz 880Hz) 94 ASCII Calculate Frequency GRID["$x,$y"]="$((" Generate LC_CTYPE="C" PCM Pure Score Sentiment Translate a ascii ascii) at audio awk bytes directly do done duration_samples="800" echo f for freq="$((" frequency from generate_tone() get_sentiment() given i i++ i++) i<${#poem}; i<n; into local maps micro-poem modulo n="$duration_samples" n1="$((" n2="$((" n3="$((" neighbors of over poem="$1" printf raw rm sample score="$((" sentiment sin(2 sine string sum synthesis text to tone translate_neighbors_to_poem() unsigned) v1="$((" via wave x++)); x<WIDTH; y y++)); { } }'>> "$AUDIO_FILE"
}

# Main Automaton Loop
echo "Simulating cellular automaton, translating poetry, and synthesizing audio..."
TOTAL_SENTIMENT=0

for ((s=0; s<STEPS; "$poem") "$sentiment" "$sum") "${!NEXT_GRID[@]}"; "<line "Rendering # $dx $dy $k"]}" % && 'BEGIN (( ((x="0;" ((y="0;" (GRID["$x,$y"] (depth (x (y )) )); * + - -1 -eq -v / 0 180 1; 3.14159265 32 360 40 60%)\" 8-neighbor 80%, 94 <="0" ASCII Automaton Copy Dynamic Fractal Function GRID GRID["$k"]="${NEXT_GRID[" GRID["$nx,$ny"] Generate HEIGHT HEIGHT) Landscape NEXT_GRID NEXT_GRID["$x,$y"]="$((" Next Render SVG Sum Synthesize TOTAL_SENTIMENT TOTAL_SENTIMENT) WIDTH WIDTH) [[ ]]; a ambient and angle="$4" based boundary branches continue; cos(r) depth do done dx dy dynamic echo extract fi for fractal from generate_tone generating hue="$((" if in k l landscape..." length="$3" local nx="$((" ny="$((" on opacity="\"0.85\"" pitch poem print r="$rad" rad="$(awk" recursive render_branch() return; rule s++)); score sentiment sentiment) sin(r) state step stroke="\"hsl($hue," stroke-width="\"$depth\"" sum the then to toroidal update using values with x x++)); x1="\"$x\"" x2="\"$x2\"" x<WIDTH; y y++)); y1="\"$y\"" y2="\"$y2\"" y<HEIGHT; { }')/>" >> "$SVG_FILE"

    local next_len=$(awk -v l="$length" 'BEGIN { print l * 0.72 }')
    local cell_val="${GRID["$((depth % WIDTH)),$((depth % HEIGHT))"]}"
    local spread=$(( 15 + cell_val % 35 ))

    render_branch "$x2" "$y2" "$next_len" "$(( angle - spread ))" "$(( depth - 1 ))"
    render_branch "$x2" "$y2" "$next_len" "$(( angle + spread ))" "$(( depth - 1 ))"
}

# Initialize SVG file
cat <<EOF> "$SVG_FILE"
<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="0 0 1000 800" width="100%" height="100%" style="background:#0a0a12;">
<defs>
    <radialGradient id="sky" cx="50%" cy="50%" r="50%">
        <stop offset="0%" stop-color="#1a1a3a"/>
        <stop offset="100%" stop-color="#05050a"/>
    </radialGradient>
</defs>
<rect width="1000" height="800" fill="url(#sky)"/>
<g transform="translate(0,0)">
EOF

# Render multiple fractal trees originating from the cellular automaton states
for ((i=1; i<=5; i++)); do
    root_x=$(( i * 160 + 20 ))
    root_len=$(( 80 + (GRID["$i,$i"] % 40) ))
    render_branch "$root_x" "750" "$root_len" "0" "7"
done

echo "</g></svg>" >> "$SVG_FILE"

# Output execution details
echo "Execution complete."
echo " - RAW Audio Synth file generated: ${AUDIO_FILE} (8000Hz, 8-bit Unsigned PCM)"
echo " - SVG Fractal Landscape generated: ${SVG_FILE}"

# Attempt ambient playback if audio tools are present
if command -v paplay &>/dev/null; then
    echo "Playing synthesized audio..."
    paplay --raw --rate=8000 --channels=1 --format=u8 "$AUDIO_FILE" || true
elif command -v aplay &>/dev/null; then
    aplay -t raw -r 8000 -f U8 "$AUDIO_FILE" || true
fi