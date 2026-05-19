#!/usr/bin/env bash
# musical_poem.sh – turn any text into a quirky musical score and animated spectrogram

set -euo pipefail

# ---------- Configuration ----------
SR=48000                     # sample rate
BASE_NOTE=60                 # MIDI middle C as base pitch
MIN_MIDI=21                  # piano low A
MAX_MIDI=108                 # piano high C
DUR_UNIT=0.2                 # base duration (seconds) per character
TMPDIR=$(mktemp -d)          # work directory
AUDIO="$TMPDIR/score.wav"
VIDEO="output.mp4"

# ---------- Helper: map codepoint to MIDI note & duration ----------
map_note() {
    local cp=$1
    # wrap codepoint into piano range
    local range=$((MAX_MIDI-MIN_MIDI+1))
    printf "%d" $(( (cp % range) + MIN_MIDI ))
}
map_dur() {
    local cp=$1
    # duration between 0.1 and 1.0 s, varied by low 4 bits
    local frac=$(( cp & 0xF ))
    awk "BEGIN{printf \"%.3f\", ${DUR_UNIT} + ${DUR_UNIT}*${frac}/15}"
}

# ---------- Build the audio track ----------
> "$TMPDIR/parts.txt"
i=0
while IFS= read -r -n1 char; do
    [[ -z $char ]] && break
    # get Unicode code point (handles multibyte UTF‑8)
    cp=$(printf "%d" "'$char")
    midi=$(map_note "$cp")
    freq=$(awk "BEGIN{print 440*2^(( $midi-69)/12)}")
    dur=$(map_dur "$cp")
    # generate a sine tone with sox, store as temporary wav
    part="$TMPDIR/part_$i.wav"
    sox -n -r $SR -b 16 "$part" synth "$dur" sine "$freq" vol 0.5
    echo "file '$part'" >> "$TMPDIR/parts.txt"
    ((i++))
done

# concatenate all notes
sox "$(cat $TMPDIR/parts.txt)" "$AUDIO"

# ---------- Create animated spectrogram ----------
# showspectrumpic with slide=1 creates a scrolling spectrogram video
ffmpeg -y -hide_banner -loglevel error -i "$AUDIO" -filter_complex \
"[0:a]showspectrumpic=s=800x600:slide=1:color=intensity,format=yuv420p[v]" \
-map "[v]" -r 30 -pix_fmt yuv420p "$VIDEO"

# ---------- Clean up ----------
rm -rf "$TMPDIR"
echo "Generated video: $VIDEO"