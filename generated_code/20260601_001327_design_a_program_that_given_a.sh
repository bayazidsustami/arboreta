#!/usr/bin/env bash
# Live webcam → color → note → sound + kaleido ASCII art
# Dependencies: ffmpeg, imagemagick (convert), sox, aplay, img2txt (caca-utils), awk, sed

# ---- Configuration ---------------------------------------------------------
# Device and capture size
CAM="/dev/video0"
WIDTH=160
HEIGHT=120
FPS=5

# Scale: map 12 hues (0‑360°) to a chromatic scale starting at C4
NOTES=(C4 Cs4 D4 Ds4 E4 F4 Fs4 G4 Gs4 A4 As4 B4)

# Duration (seconds) of each generated tone
TONE_DUR=0.2

# Temporary FIFO for audio pipeline
AUDIO_FIFO=$(mktemp -u)
mkfifo "$AUDIO_FIFO"
# Play audio in background
aplay -q "$AUDIO_FIFO" &
AUDIO_PID=$!

# ---- Helper functions ------------------------------------------------------
# Convert RGB hex to hue (0‑360)
rgb2hue() {
    local r=$1 g=$2 b=$3
    r=$(awk "BEGIN{print $r/255}")
    g=$(awk "BEGIN{print $g/255}")
    b=$(awk "BEGIN{print $b/255}")
    max=$(awk "BEGIN{print ($r>$g?$r:$g)>$b?($r>$g?$r:$g):$b}")
    min=$(awk "BEGIN{print ($r<$g?$r:$g)<$b?($r<$g?$r:$g):$b}")
    delta=$(awk "BEGIN{print $max-$min}")
    if (( $(awk "BEGIN{print $delta==0}") )); then echo 0; return; fi
    case $max in
        $r) hue=$(awk "BEGIN{print (60*(($g-$b)/$delta)+360)%360}") ;;
        $g) hue=$(awk "BEGIN{print (60*(($b-$r)/$delta)+120)%360}") ;;
        *)  hue=$(awk "BEGIN{print (60*(($r-$g)/$delta)+240)%360}") ;;
    esac
    printf "%.0f\n" "$hue"
}

# Map hue to nearest note index
hue2note() {
    local hue=$1
    local idx=$(( (hue * 12 / 360) % 12 ))
    echo "${NOTES[$idx]}"
}

# Generate a single tone and append to FIFO
playnote() {
    local note=$1
    # sox synth with equal temperament (A4=440Hz)
    sox -n -b 16 -c 1 -r 44100 "$AUDIO_FIFO" synth "$TONE_DUR" "$note" >/dev/null 2>&1 &
}

# Produce kaleido ASCII art colored by interval (simple hue shift)
kaleido() {
    local img=$1 prev_hue=$2
    # Convert to ASCII using img2txt
    ascii=$(img2txt -W $WIDTH -H $HEIGHT --colors "$img" 2>/dev/null)
    # Extract dominant hue from image (reuse previous calculation)
    hue=$prev_hue
    # Apply ANSI color based on hue (0‑255 color cube)
    color=$(( (hue * 255 / 360) + 16 ))
    # Wrap each line with color code
    while IFS= read -r line; do
        printf "\e[38;5;%dm%s\e[0m\n" "$color" "$line"
    done <<<"$ascii"
}

# ---- Main loop -------------------------------------------------------------
# Capture raw frames, pipe through while‑read loop
ffmpeg -f v4l2 -framerate $FPS -video_size ${WIDTH}x${HEIGHT} -i "$CAM" -vf format=rgb24 -vcodec rawvideo -pix_fmt rgb24 -f rawvideo - \
| while read -r -d '' -n $((WIDTH*HEIGHT*3)) frame; do
    # Save current frame to temp PNG
    img=$(mktemp --suffix=.png)
    printf "%s" "$frame" | convert -size ${WIDTH}x${HEIGHT} rgb:- "$img"

    # Get dominant color (most frequent)
    dom_color=$(convert "$img" -resize 1x1 txt:- | grep -o '#[0-9A-Fa-f]\{6\}')
    r=$((16#${dom_color:1:2}))
    g=$((16#${dom_color:3:2}))
    b=$((16#${dom_color:5:2}))

    hue=$(rgb2hue $r $g $b)
    note=$(hue2note $hue)

    # Play note
    playnote "$note"

    # Render kaleido ASCII art
    clear
    kaleido "$img" "$hue"

    rm -f "$img"
done

# Cleanup
kill "$AUDIO_PID" 2>/dev/null
rm -f "$AUDIO_FIFO"