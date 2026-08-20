#!/usr/bin/env bash
# Terminal Generative Music & Process ASCII Bonsai
# Translates CPU usage into MIDI polyrhythms while RAM controls Bonsai growth.

set -e

# Cleanup terminal on exit
cleanup() {
    printf "\e[?25h\e[0m\e[2J\e[1;1H"
    exit 0
}
trap cleanup EXIT INT TERM

# Required dependencies check
for cmd in ps awk aplay; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: Required command '$cmd' not found." >&2
        exit 1
    fi
done

# Prepare screen
printf "\e[?25l\e[2J"

# Musical scale frequencies (Pentatonic Scale in C: C4, D4, E4, G4, A4, C5, D5, E5)
SCALE=(261.63 293.66 329.63 392.00 440.00 523.25 587.33 659.25)
SAMPLE_RATE=8000

# Generate PCM audio buffer for a specific frequency and duration (in samples)
gen_note() {
    local freq=$1
    local samples=$2
    awk -v f="$freq" -v r="$SAMPLE_RATE" -v s="$samples" '
    BEGIN {
        for (i = 0; i < s; i++) {
            # Sine wave with exponential decay envelope
            t = i / r
            env = exp(-4.0 * t)
            val = sin(2 * 3.14159265 * f * t) * env
            # Convert float -1..1 to unsigned 8-bit integer (0..255)
            byte = int((val + 1) * 127.5)
            printf "%c", byte
        }
    }'
}

# Main event loop
TICKS=0
while true; do
    # Fetch top system stats: CPU% and RAM%
    read -r CPU_USAGE RAM_USAGE < <(ps -eo %cpu,%mem --no-headers | awk '{c+=$1; m+=$2} END {print int(c), int(m)}')

    # Render Screen Header
    printf "\e[1;1H\e[1;36m=== ALGORITHMIC PROCESS BONSAI & POLYRHYTHMIC SYNTH ===\e[0m"
    printf "\e[2;1H\e[33mSystem CPU Usage: %3d%%  |  RAM Usage: %3d%%\e[0m" "$CPU_USAGE" "$RAM_USAGE"

    # --- VISUALIZER: ASCII Bonsai Tree ---
    # RAM consumption dictates Bonsai health (Low RAM = Lush Green, High RAM = Wilting)
    printf "\e[4;1H"
    if [ "$RAM_USAGE" -lt 30 ]; then
        COLOR="\e[1;32m" # Vibrant Green
        LEAF_CHAR="@"
    elif [ "$RAM_USAGE" -lt 65 ]; then
        COLOR="\e[0;32m" # Muted Green
        LEAF_CHAR="*"
    elif [ "$RAM_USAGE" -lt 85 ]; then
        COLOR="\e[1;33m" # Autumn Yellow/Orange
        LEAF_CHAR="%"
    else
        COLOR="\e[1;31m" # Wilting Red
        LEAF_CHAR="."
    fi

    # Draw Canopy based on health
    printf "${COLOR}"
    printf "         %s%s%s%s%s         \n" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR"
    printf "       %s%s%s%s%s%s%s%s%s       \n" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR"
    printf "     %s%s%s%s%s%s%s%s%s%s%s%s%s     \n" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR"
    printf "       %s%s%s%s%s%s%s%s%s       \n" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR" "$LEAF_CHAR"

    # Draw Trunk and Pot
    printf "\e[0;33m"
    printf "          (  )          \n"
    printf "           ||           \n"
    printf "          /  \\          \n"
    printf "         /    \\         \n"
    printf "\e[1;34m"
    printf "     [==============]   \n"
    printf "      \\____________/    \n\e[0m"

    # Display Top CPU Processes driving the audio patterns
    printf "\e[15;1H\e[1;35mActive Process Polyrhythmic Drivers:\e[0m\n"
    ps -eo pid,comm,%cpu --sort=-%cpu | head -n 5 | tail -n 4 | awk '{printf " PID: %-6s CMD: %-15s CPU: %s%%\n", $1, $2, $3}'

    # --- AUDIO: Algorithmic Polyrhythmic Pattern Generation ---
    # Poly-rhythm step calculation derived from CPU load & current loop tick
    INDEX1=$(( (TICKS + CPU_USAGE) % 8 ))
    INDEX2=$(( (TICKS * 3 + CPU_USAGE / 2) % 8 ))

    FREQ1=${SCALE[$INDEX1]}
    FREQ2=${SCALE[$INDEX2]}

    # Play polyrhythmic dyad (combining frequencies concurrently into raw sound)
    (
        gen_note "$FREQ1" 1200 &
        gen_note "$FREQ2" 1200 &
        wait
    ) | aplay -q -r $SAMPLE_RATE -f U8 2>/dev/null &

    TICKS=$((TICKS + 1))
    sleep 0.2
done