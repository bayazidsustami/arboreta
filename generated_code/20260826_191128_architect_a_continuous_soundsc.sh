#!/usr/bin/env bash
# Continuous Soundscape Generator & Visual Star Map Lipogrammatic Archiver
# Translates ping latency to audio tones (soundscape) and ASCII star maps while logging without the letter 'e'.

trap 'stty echo echoe icanon icanon controls; tput cnorm; exit 0' INT TERM EXIT

# Set up terminal interface
tput civis 2>/dev/null || true
clear

HOST="${1:-8.8.8.8}"
LOG_FILE="archive_lipogram.log"

# Audio speaker tone generation using /dev/audio, /dev/dsp, or system beep/speaker routines
play_tone() {
    local freq=$1
    local ms=$2
    if command -v speaker-test >/dev/null 2>&1; then
        speaker-test -t sine -f "$freq" -l 1 >/dev/null 2>&1 &
        local pid=$!
        ( sleep 0.08 && kill -9 $pid 2>/dev/null ) &
    elif printf "\a" >/dev/tty 2>/dev/null; then
        printf "\a"
    fi
}

# Lipogrammatic Logger (Strict constraint: Writes poetic logs avoiding the letter 'e')
# Poetry pattern avoids 'e' / 'E' entirely
write_lipogram_log() {
    local ms=$1
    local char=$2
    local poem_line=""

    case $(( RANDOM % 5 )) in
        0) poem_line="A star dark in a calm sky, ping $ms ms." ;;
        1) poem_line="High pitch rings, $char shines back on high." ;;
        2) poem_line="Signals spin, null, sound and light align." ;;
        3) poem_line="Ping $ms ms, a spark instantly glowing." ;;
        4) poem_line="No stop, focus on giant cosmos." ;;
    esac

    # Ensure no 'e' or 'E' slips through (filtering just in case)
    poem_line=$(echo "$poem_line" | tr -d 'eE')
    echo "$(date +%H:%M:%S) | $poem_line" >> "$LOG_FILE"
}

# Drawing Star Map
draw_star() {
    local latency=$1
    local width=$(tput cols 2>/dev/null || echo 80)
    local height=$(tput lines 2>/dev/null || echo 24)
    
    local x=$(( RANDOM % (width - 2) + 1 ))
    local y=$(( RANDOM % (height - 4) + 1 ))
    
    local symbol="*"
    local color="\033[1;32m" # Green
    
    if [ "$latency" -lt 20 ]; then
        symbol="."
        color="\033[1;34m" # Blue
    elif [ "$latency" -lt 60 ]; then
        symbol="+"
        color="\033[1;36m" # Cyan
    elif [ "$latency" -lt 120 ]; then
        symbol="*"
        color="\033[1;33m" # Yellow
    else
        symbol="#"
        color="\033[1;31m" # Red
    fi

    # Render star at x, y
    tput cup "$y" "$x"
    printf "${color}${symbol}\033[0m"

    # Status Bar
    tput cup "$((height - 1))" 0
    printf "\033[7m Latency: %4d ms | Star: %s (%d,%d) | Archiving Lipogram to %s \033[0m" "$latency" "$symbol" "$x" "$y" "$LOG_FILE"
}

# Main Event Loop
while true; do
    # Extract ping latency in milliseconds
    PING_RES=$(ping -c 1 -W 1 "$HOST" 2>/dev/null | grep -oP 'time=\K[0-9.]+' || echo "100")
    LATENCY=$(printf "%.0f" "$PING_RES" 2>/dev/null || echo "100")
    
    # Map latency to pitch frequency (200Hz - 1200Hz)
    FREQ=$(( 200 + LATENCY * 5 ))
    if [ "$FREQ" -gt 2000 ]; then FREQ=2000; fi

    # Generate Soundscape
    play_tone "$FREQ" 50

    # Render Visual Star Map
    draw_star "$LATENCY"

    # Archive execution log as lipogrammatic poetry (No 'e')
    write_lipogram_log "$LATENCY" "*"

    sleep 0.2
done