#!/usr/bin/env bash
# Title: Echoes of Typing - Circular Visual Poem
# Description: Samples ambient audio, extracts energy peaks, and renders a self-clearing circular ASCII poem.

# Ensure clean exit, cursor restoration, and temporary file cleanup
trap "tput cnorm; clear; rm -f /tmp/typing_wave_$$.wav /tmp/typing_amps_$$.txt; exit" INT TERM EXIT
tput civis
clear

TEMP_WAV="/tmp/typing_wave_$$.wav"
TEMP_TXT="/tmp/typing_amps_$$.txt"

# Record 3 seconds of ambient audio (requires alsa-utils / arecord)
if command -v arecord &>/dev/null; then
    echo ">> Listening to your keyboard rhythm (3s)..."
    arecord -q -d 3 -f S16_LE -r 8000 -c 1 "$TEMP_WAV" 2>/dev/null || true
fi

# Extract amplitude samples or generate fallback typing rhythm
if [ -f "$TEMP_WAV" ] && [ -s "$TEMP_WAV" ]; then
    od -An -d -w2 "$TEMP_WAV" 2>/dev/null | awk '{print ($1 < 0 ? -$1 : $1)}' | head -n 120 > "$TEMP_TXT"
else
    for i in {1..120}; do
        echo $(( (RANDOM % 15000) + 1000 )) >> "$TEMP_TXT"
    done
fi

cols=$(tput cols)
lines=$(tput lines)
cx=$((cols / 2))
cy=$((lines / 2))

verses=(
    "fingers dance on glass"
    "echoes in the dark machine"
    "thoughts become ripples"
    "silence breaks into sound"
    "patterns fade away"
    "dissolving into nothingness"
)

clear
mapfile -t amps < "$TEMP_TXT"

v_idx=0
for verse in "${verses[@]}"; do
    amp=${amps[$v_idx]:-5000}
    radius=$(( 4 + ((amp % 12)) ))
    
    awk -v text="$verse" -v cx="$cx" -v cy="$cy" -v r="$radius" 'BEGIN {
        len = length(text);
        for (i = 1; i <= len; i++) {
            theta = (i - 1) * 6.2831853 / len;
            x = int(cx + r * 2 * cos(theta));
            y = int(cy + r * sin(theta));
            char = substr(text, i, 1);
            printf "\033[%d;%dH\033[1;36m%s\033[0m", y, x, char;
        }
    }'
    sleep 0.5
    v_idx=$(( (v_idx + 1) % ${#verses[@]} ))
done

sleep 2

# Self-deleting effect: wipe the poem lines away progressively
for ((r=15; r>=0; r--)); do
    clear
    sleep 0.1
done

rm -f "$TEMP_WAV" "$TEMP_TXT"
tput cnorm
clear