#!/usr/bin/env bash
# webcam_lsystem.sh – live webcam → color‑driven L‑system → ASCII animation + sound + entropy log
# Dependencies: ffmpeg, convert (ImageMagick), jp2a, sox, awk, bc, xxd, espeak, mkfifo
# Ensure required commands exist
for cmd in ffmpeg convert jp2a sox awk bc xxd espeak; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Missing $cmd"; exit 1; }
done

# Configuration
VID_DEV="/dev/video0"
FPS=10
WIDTH=160
HEIGHT=120
FIFO="/tmp/webcam_fifo_$$"
ENTROPY_LOG="entropy.log"
SOUND_WAV="/tmp/ambient_$$.wav"

# Clean up on exit
cleanup() {
    rm -f "$FIFO" "$SOUND_WAV"
    kill $FFMPEG_PID $SOX_PID 2>/dev/null
}
trap cleanup EXIT

# Create a named pipe for raw frames (RGB24)
mkfifo "$FIFO"

# Launch ffmpeg to capture raw frames from webcam
ffmpeg -loglevel quiet -f v4l2 -framerate $FPS -video_size ${WIDTH}x${HEIGHT} -i "$VID_DEV" \
    -vf format=rgb24 -f rawvideo - > "$FIFO" &
FFMPEG_PID=$!

# Generate a continuous low‑freq ambient tone (white noise filtered)
sox -n -b 16 -c 1 "$SOUND_WAV" synth sine 30 vol 0.02 fade 0 99999 0 2>/dev/null &
SOX_PID=$!

# Play the sound in background
aplay "$SOUND_WAV" >/dev/null 2>&1 &

# L‑system defaults
AXIOM="F"
RULE_F="F"
ANGLE=45

# Helper: get dominant color from a frame (RGB triplet)
dominant_color() {
    # $1 = raw RGB frame data
    convert -size ${WIDTH}x${HEIGHT} -depth 8 rgb:- -resize 1x1! txt:- |
        awk -F'[()]' 'NR==2{print $2}' | tr -d ' '
}

# Helper: map color to a production rule (simple hue buckets)
color_to_rule() {
    # $1 = hex RGB (e.g., ff0000)
    case "${1:0:2}" in
        [Ff][Ff]) echo "F+F--F+F" ;;          # red → more branching
        00)       echo "F-F++F-F" ;;          # blue → fewer branches
        *)        echo "F" ;;                # others → identity
    esac
}

# Helper: compute entropy of a string (Shannon)
string_entropy() {
    local s=$1
    local len=${#s}
    echo "$s" | fold -w1 | sort | uniq -c | awk -v l=$len '
    { p=$1/l; sum+=-p*log(p)/log(2) } END { printf "%.4f", sum }'
}

# Main loop: read frames, update L-system, render ASCII, log entropy
while true; do
    # Read a single raw frame
    FRAME=$(dd if="$FIFO" bs=$((WIDTH*HEIGHT*3)) count=1 2>/dev/null)
    [[ -z $FRAME ]] && break

    # Extract dominant color (hex)
    COLOR_HEX=$(dominant_color <<<"$FRAME")
    # Derive new rule from color
    RULE_F=$(color_to_rule "$COLOR_HEX")

    # Simple L‑system iteration (10 steps max to keep speed)
    LSTRING="$AXIOM"
    for i in {1..8}; do
        LSTRING=${LSTRING//F/$RULE_F}
    done

    # Convert L‑system to turtle graphics commands (F = forward, + = turn right, - = turn left)
    # Render to a small PNG using ImageMagick's convert drawing primitives
    TMPIMG=$(mktemp /tmp/lsys.XXXX.png)
    convert -size 200x200 xc:black -stroke white -strokewidth 1 -draw "
        translate 100,100
        rotate 0
        path 'M 0,0 ${LSTRING//F/l}${LSTRING//+/r}${LSTRING//-/l}'
    " "$TMPIMG" 2>/dev/null

    # Convert PNG to ASCII
    ASCII=$(jp2a --width=80 --height=24 --background=dark "$TMPIMG" 2>/dev/null)
    rm -f "$TMPIMG"

    # Display
    clear
    echo "$ASCII"

    # Log entropy
    ENT=$(string_entropy "$LSTRING")
    echo "$(date +%s.%N) $ENT $COLOR_HEX $RULE_F" >> "$ENTROPY_LOG"

    # Optional: speak entropy aloud every few seconds
    if (( ${#ENT%.*} % 5 == 0 )); then
        espeak "entropy $ENT"
    fi
done