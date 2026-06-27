#!/usr/bin/env bash
# live_mandala.sh – webcam → colors → notes → ascii mandala → sonnet log
# Requires: ffmpeg, ImageMagick (convert), sox (play), awk, sed, tput

# ---------- CONFIG ----------
CAM="/dev/video0"                # webcam device
FRAMERATE=5                      # frames per second to process
PALETTE_SIZE=5                   # number of dominant colors per frame
SCALE=("C" "D" "E" "F" "G" "A" "B")  # custom musical scale
NOTE_DUR=0.3                     # seconds per note
LOGFILE="sonnet.log"             # poetic log
# ---------- END CONFIG ----------

# Initialize sonnet buffer (14 lines, iambic pentameter hint)
declare -a SONNET=(
"Upon the lens the fleeting light does dance,"
"The hues that slip through sensors paint a trance,"
"In chords of C to B they rise and fall,"
"Each note a brushstroke on the silent hall."
"Mandala spirals, drawn by unseen hand,"
"While verses weave where pixel meets the land."
"Colors speak in tones the ear cannot hear,"
"Yet screen and soul align, the code draws near."
"The script, a bard, composes in its kiss,"
"Each frame a stanza, each beat a gentle bliss."
"Thus art and sound entwine in looping rite,"
"While bashful loops repeat the neon night."
"Let verses bloom as mandalas spin anew,"
"And Shakespeare smiles from bytes of midnight hue."
)

# function: log current state as a sonnet stanza (4 lines per frame)
log_state() {
    local frame=$1 note=$2 color=$3
    {
        echo "Frame $frame: color $color mapped to note $note."
        echo "Mandala pattern shifted by $(printf '%d' "'$note") steps."
        echo "The chorus of pixels sings a silent aria."
        echo "Thus the canvas breathes in binary chiaroscuro."
    } >>"$LOGFILE"
}

# function: generate a simple ASCII mandala influenced by a numeric seed
draw_mandala() {
    local seed=$1 size=21
    local i j r
    clear
    for ((i=0; i<size; i++)); do
        for ((j=0; j<size; j++)); do
            # polar coordinates centered
            r=$(awk -v x=$i -v y=$j -v c=$size 'BEGIN{
                cx=cy=c/2;
                dx=x-cx; dy=y-cy;
                rad=sqrt(dx*dx+dy*dy);
                ang=atan2(dy,dx);
                printf "%f %f", rad, ang;
            }')
            rad=$(echo $r | cut -d' ' -f1)
            ang=$(echo $r | cut -d' ' -f2)
            # pattern varies with seed and angle
            if (( $(awk -v rad=$rad -v ang=$ang -v s=$seed 'BEGIN{
                val=int(rad*10+ang*5+s)%2;
                print val;
            }') )); then
                printf "*"
            else
                printf " "
            fi
        done
        printf "\n"
    done
}

# cleanup on exit
trap 'tput cnorm; stty echo; exit' INT TERM EXIT
tput civis   # hide cursor
stty -echo   # no echo for cleaner display

frame=0
while true; do
    ((frame++))
    # Capture single frame
    ffmpeg -f v4l2 -i "$CAM" -vframes 1 -q:v 2 -hide_banner -loglevel error -y frame.jpg 2>/dev/null

    # Extract dominant colors (hex) using ImageMagick
    mapfile -t colors < <(convert frame.jpg -resize 100x100! -colors "$PALETTE_SIZE" -unique-colors txt:- |
        awk -F'|' '/^#/{gsub(/ /,"",$2); print $2}' | head -n "$PALETTE_SIZE")
    # Pick first dominant as representative
    dominant=${colors[0]:-#000000}
    # Convert hex to simple index (0-6) for scale
    # Hash the string, mod by length of SCALE
    idx=$(echo -n "$dominant" | md5sum | awk '{print substr($1,1,8)}' | \
        awk '{printf "%d", strtonum("0x"$1)}')
    note_idx=$(( idx % ${#SCALE[@]} ))
    note=${SCALE[$note_idx]}

    # Play note (simple sine tone)
    play -n synth $NOTE_DUR sin ${note_idx}0.5 >/dev/null 2>&1 &

    # Draw mandala influenced by note index
    draw_mandala "$note_idx"

    # Log poetic state
    log_state "$frame" "$note" "$dominant"

    # throttle to framerate
    sleep "$(awk "BEGIN {print 1/$FRAMERATE}")"
done