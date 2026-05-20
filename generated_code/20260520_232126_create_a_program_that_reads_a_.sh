#!/usr/bin/env bash
# live_haiku_spiral.sh
# Reads a live stream of haiku‑style tweets, maps syllable counts to notes,
# draws a growing spiral, and plays the corresponding tones in real‑time.

# ----- Configuration ---------------------------------------------------------
# Twitter stream placeholder – replace with actual streaming command.
# Example: twurl "/1.1/statuses/filter.json?track=haiku" -H "Authorization: Bearer $TOKEN"
STREAM_CMD="tail -F haiku_stream.txt"   # simulate with a growing file

# Audio parameters
BPM=120
SAMPLE_RATE=44100
NOTE_DURATION=$(bc <<< "60/$BPM")       # quarter‑note length in seconds
# Simple map of syllable count (1‑7) to diatonic notes (C4‑B4)
declare -A NOTE_MAP=( [1]=C4 [2]=D4 [3]=E4 [4]=F4 [5]=G4 [6]=A4 [7]=B4 )

# Visual parameters
IMG_SIZE=800
CENTER=$((IMG_SIZE/2))
RADIUS_STEP=5        # radius growth per tweet
ANGLE_INC=0.3        # angular increment per tweet (radians)
SPIRAL_IMG="spiral.png"

# Initialise empty canvas
convert -size ${IMG_SIZE}x${IMG_SIZE} xc:black "$SPIRAL_IMG"

# State variables
tweet_count=0
current_radius=0
current_angle=0

# Function: naive syllable counter (vowel groups)
syllables() {
    python3 - <<END
import sys, re
text = sys.stdin.read().strip().lower()
# count vowel groups as syllables, minimum 1
cnt = max(1, len(re.findall(r'[aeiouy]+', text)))
print(cnt)
END
}

# Function: play a note using sox (sine wave)
play_note() {
    local note=$1
    # frequency lookup for notes C4‑B4
    case $note in
        C4) freq=261.63 ;;
        D4) freq=293.66 ;;
        E4) freq=329.63 ;;
        F4) freq=349.23 ;;
        G4) freq=392.00 ;;
        A4) freq=440.00 ;;
        B4) freq=493.88 ;;
        *) freq=440 ;;
    esac
    play -n synth $NOTE_DURATION sine $freq vol 0.2 &>/dev/null
}

# Function: draw next point on the spiral
draw_spiral() {
    local radius=$1 angle=$2 count=$3
    local x=$(bc -l <<< "$CENTER + $radius * c($angle)")
    local y=$(bc -l <<< "$CENTER + $radius * s($angle)")
    # draw a small circle at (x,y); color cycles with tweet count
    local hue=$(( (count*30) % 360 ))
    convert "$SPIRAL_IMG" -fill "hsl($hue,100%,50%)" -draw "circle $x,$y $((x+2)),$((y))" "$SPIRAL_IMG"
    # show updated canvas (requires an X display; replace with feh/imagemagick display)
    display -window root "$SPIRAL_IMG" &
}

# Main loop: read live tweets, process, and output audio/visuals
$STREAM_CMD | while IFS= read -r tweet; do
    # Assume tweet text is on a single line; ignore non‑haiku lines
    syllable_count=$(echo "$tweet" | syllables)
    note=${NOTE_MAP[$syllable_count]:-A4}
    play_note "$note"

    # Update spiral geometry
    ((tweet_count++))
    current_radius=$((tweet_count * RADIUS_STEP))
    current_angle=$(bc <<< "$tweet_count * $ANGLE_INC")
    draw_spiral "$current_radius" "$current_angle" "$tweet_count"
done