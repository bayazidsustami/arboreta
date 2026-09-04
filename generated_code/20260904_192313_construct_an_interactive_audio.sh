#!/usr/bin/env bash
# Terminal Interactive Audio-Visualizer: Bytebeat Audio & ASCII Fractal Trees
# Keystrokes serve as pitch modifiers, dynamically rendering growing fractal
# trees while streaming synthesized bytebeat audio in real-time.

# Cleanup terminal settings and subprocesses on exit
cleanup() {
    printf "\e[?25h\e[0m\e[2J\e[H"
    stty echo icanon
    kill 0 2>/dev/null
    exit 0
}
trap cleanup EXIT INT TERM

# Initialize terminal state (hide cursor, raw non-canonical input)
stty -echo -icanon time 0 min 0
printf "\e[?25l\e[2J"

# Default state variables
PITCH=1
PITCH_FILE=$(mktemp)
echo "$PITCH" > "$PITCH_FILE"

# Background Process: Bytebeat Audio Synthesizer
# Generates raw 8-bit, 8kHz PCM audio continuously output to speaker device
(
    t=0
    # Locate appropriate audio playback utility
    AUDIO_CMD=""
    if command -v aplay >/dev/null 2>&1; then
        AUDIO_CMD="aplay -q -r 8000 -f U8"
    elif command -v afplay >/dev/null 2>&1; then
        AUDIO_CMD="afplay -r 8000 -f u8"
    elif command -v play >/dev/null 2>&1; then
        AUDIO_CMD="play -q -r 8000 -c 1 -t u8 - -q"
    fi

    # Fallback to direct device writing if no utility is installed
    if [ -z "$AUDIO_CMD" ]; then
        if [ -w /dev/audio ]; then
            AUDIO_CMD="cat > /dev/audio"
        elif [ -w /dev/dsp ]; then
            AUDIO_CMD="cat > /dev/dsp"
        else
            exit 1
        fi
    fi

    # Audio synthesis loop using bytebeat formula modified by interactive pitch
    while true; do
        p=$(cat "$PITCH_FILE" 2>/dev/null || echo 1)
        # Bytebeat formula: t * pitch & (t >> 5 | t >> 8) ^ (t >> 4)
        awk -v t="$t" -v p="$p" 'BEGIN {
            for (i=0; i<1024; i++) {
                v = int((t + i) * p)
                sample = bitand(v, bitor(rshift(t+i, 5), rshift(t+i, 8)))
                sample = bitxor(sample, rshift(t+i, 4))
                printf "%c", bitand(sample, 255)
            }
        }' 2>/dev/null
        t=$((t + 1024))
    done | $AUDIO_CMD 2>/dev/null
) &

# Visualizer Functions: Recursive ASCII Fractal Tree Generator
draw_tree() {
    local x=$1 y=$2 len=$3 angle=$4 depth=$5 color=$6
    (( depth <= 0 || len <= 0 )) && return

    local rad dx dy i nx ny
    # Convert angle (0-360) to polar displacement
    rad=$(awk "BEGIN { print $angle * 0.01745329 }")
    dx=$(awk "BEGIN { print cos($rad) }")
    dy=$(awk "BEGIN { print sin($rad) }")

    nx=$x
    ny=$y

    # Render trunk/branch line segment
    for (( i=0; i<len; i++ )); do
        nx=$(awk "BEGIN { print $x + $dx * $i }")
        ny=$(awk "BEGIN { print $y - $dy * $i }")
        
        local ix=$(awk "BEGIN { print int($nx + 0.5) }")
        local iy=$(awk "BEGIN { print int($ny + 0.5) }")

        if (( ix >= 1 && ix <= COLS && iy >= 1 && iy <= LINES )); then
            printf "\e[%d;%dH\e[38;5;%dm█" "$iy" "$ix" "$color"
        fi
    done

    # Recursively branch left and right
    local nlen=$(( len - 1 ))
    local ndepth=$(( depth - 1 ))
    local ncolor=$(( (color + 36) % 231 + 17 ))

    draw_tree "$nx" "$ny" "$nlen" $(( angle - 25 )) "$ndepth" "$ncolor"
    draw_tree "$nx" "$ny" "$nlen" $(( angle + 25 )) "$ndepth" "$ncolor"
}

# Main Event Loop: Keyboard input capture and visual engine updates
DEPTH=1
COLOR=34

while true; do
    # Terminal Dimensions
    COLS=$(tput cols 2>/dev/null || echo 80)
    LINES=$(tput lines 2>/dev/null || echo 24)

    # Poll keyboard input non-blockingly
    read -r -n 1 key 2>/dev/null

    if [ -n "$key" ]; then
        case "$key" in
            q|Q) cleanup ;;
            1) PITCH=1 ;;
            2) PITCH=2 ;;
            3) PITCH=3 ;;
            4) PITCH=4 ;;
            5) PITCH=5 ;;
            6) PITCH=6 ;;
            7) PITCH=7 ;;
            8) PITCH=8 ;;
            9) PITCH=9 ;;
            +) PITCH=$((PITCH + 1)) ;;
            -) PITCH=$((PITCH > 1 ? PITCH - 1 : 1)) ;;
            *) 
               # Convert character byte code to pitch modifier dynamically
               PITCH=$(( (LC_CTYPE=C printf '%d' "'$key") % 12 + 1 )) 
               ;;
        esac
        echo "$PITCH" > "$PITCH_FILE"
        DEPTH=$(( (PITCH % 6) + 2 ))
        COLOR=$(( (PITCH * 30) % 200 + 20 ))
    fi

    # Render dynamic frame
    printf "\e[2J"
    
    # Header HUD
    printf "\e[1;2H\e[1;36m=== BASH BYTEBEAT FRACTAL VISUALIZER ==="
    printf "\e[2;2H\e[33mPress [1-9] or Keys to shift Pitch & Grow Tree | [Q] to Quit"
    printf "\e[3;2H\e[32mCurrent Pitch Frequency Multiplier: %d" "$PITCH"

    # Compute base position and draw visual tree layout
    BASE_X=$(( COLS / 2 ))
    BASE_Y=$(( LINES - 2 ))
    TRUNK_LEN=$(( DEPTH + 1 ))

    draw_tree "$BASE_X" "$BASE_Y" "$TRUNK_LEN" 90 "$DEPTH" "$COLOR"

    # Sleep slightly to regulate visual frame rates
    sleep 0.05
done