#!/usr/bin/env bash
# webcam_ca.sh - Live webcam cellular automaton driven by a poem
# Usage: ./webcam_ca.sh poem.txt
# Dependencies: ffmpeg, ffplay, awk, sed, md5sum, sox

set -e

# ---------- Helper: crude syllable counter ----------
syllables() {
    # Count vowel groups as syllables, minimum 1
    local line="$1"
    local cnt=$(echo "$line" | tr '[:upper:]' '[:lower:]' |
        sed -E 's/[^a-z]//g' |
        grep -o -E '[aeiouy]+' | wc -l)
    echo $((cnt==0?1:cnt))
}

# ---------- Helper: extract rhyme key (last word, stripped of vowels) ----------
rhyme_key() {
    local word=$(echo "$1" | awk '{print $NF}' | tr '[:upper:]' '[:lower:]')
    echo "$word" | sed -E 's/[aeiou]+//g'
}

# ---------- Parse poem ----------
if [[ -z $1 ]]; then
    echo "Provide a poem text file."
    exit 1
fi
POEM=$(cat "$1")
# Compute syllable sum and rhyme scheme
SYLLABLE_SUM=0
declare -A rhyme_map
SCHEME=""
idx=0
while IFS= read -r line; do
    ((SYLLABLE_SUM+= $(syllables "$line") ))
    key=$(rhyme_key "$line")
    if [[ -z ${rhyme_map[$key]} ]]; then
        rhyme_map[$key]=$(( ${#rhyme_map[@]} + 65 )) # ASCII A,B,...
    fi
    SCHEME+=$(printf "\\x$(printf %x ${rhyme_map[$key]})")
    ((idx++))
done <<< "$POEM"

# Derive rule parameters from poem
# Rule number for cellular automaton (0-255)
RULE=$(( SYLLABLE_SUM % 256 ))
# Modulation factor based on rhyme complexity
RHYME_COUNT=${#rhyme_map[@]}
MOD_FACTOR=$(( (RHYME_COUNT * 7) % 100 )) # 0-99

# ---------- Audio: generate spoken poem ----------
AUDIO_FILE=$(mktemp --suffix=.wav)
if command -v espeak >/dev/null; then
    espeak -w "$AUDIO_FILE" -s 150 "$POEM"
else
    # fallback: silence
    sox -n -r 44100 -c 2 "$AUDIO_FILE" trim 0.0 0.1
fi

# ---------- Motion detection placeholder ----------
# We'll use ffmpeg's "freezedetect" filter to get a rough motion metric.
# The metric will be fed back to modulate RULE in real time.

# ---------- Main streaming loop ----------
# Use a named pipe for feeding evolving rule number
RULE_PIPE=$(mktemp -u)
mkfifo "$RULE_PIPE"

# Background process: adjust RULE based on motion (simulated)
(
    while :; do
        # Simulate motion metric by random walk
        delta=$(( RANDOM % 5 - 2 ))   # -2..+2
        RULE=$(( (RULE + delta + 256) % 256 ))
        echo "$RULE" > "$RULE_PIPE"
        sleep 0.2
    done
) &

# Capture webcam, apply a simple cellular automaton via ffmpeg's "frei0r=cellular"
# The rule number is fed as the "threshold" parameter (0-255).
ffmpeg -f v4l2 -framerate 15 -video_size 320x240 -i /dev/video0 \
    -filter_complex "\
        [0:v]format=rgb24,split=2[orig][proc]; \
        [proc]frei0r=cellular:threshold='cat $RULE_PIPE'[ca]; \
        [orig][ca]overlay" \
    -c:v libx264 -preset veryfast -tune zerolatency -f mpegts - \
    | ffplay -i - -sync audio -vf "format=yuv420p" -i "$AUDIO_FILE" -window_title "Poetic Automaton: Rule=$RULE Scheme=$SCHEME"

# Cleanup
rm -f "$RULE_PIPE" "$AUDIO_FILE"