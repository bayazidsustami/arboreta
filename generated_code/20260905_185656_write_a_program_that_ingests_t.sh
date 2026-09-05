#!/usr/bin/env bash
# ASCII Stained-Glass Window with Procedural Decay
# Reads CPU frequency/usage, computes mathematically symmetrical patterns,
# and decays the canvas when vowel keys are pressed.

# Visual & Terminal Settings
WIDTH=39
HEIGHT=19
CENTER_X=$((WIDTH / 2))
CENTER_Y=$((HEIGHT / 2))

# Color Palette (ANSI 256-color)
PALETTE=(196 202 208 220 46 33 21 93 129 201)
DECAY_PALETTE=(234 236 238 240 242)

# State Variables
DECAY_FACTOR=0
SYMBOL_SET=('✦' '❖' '☸' '✤' '✥' '❋' '█' '▓' '▒' '░')

# Terminal Cleanup & Setup
trap 'tput cnorm; stty echo; clear; exit 0' INT TERM EXIT
tput civis
stty -echo -icanon min 0 time 0
clear

# Function to extract system frequency/CPU metric
get_cpu_freq() {
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]]; then
        cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq
    else
        # Fallback using process count and uptime noise as frequency proxy
        echo $(( ($(date +%s%N | cut -b1-7) % 2000000) + 1000000 ))
    fi
}

# Main Event & Render Loop
while true; do
    # 1. Read System Frequency Metric
    FREQ=$(get_cpu_freq)
    FREQ_NORM=$(( (FREQ / 10000) % 100 + 1 ))

    # 2. Non-blocking Input Reading for Vowels (Decay Trigger)
    read -n 1 -t 0.05 KEY 2>/dev/null
    if [[ "$KEY" =~ [aeiouAEIOU] ]]; then
        DECAY_FACTOR=$((DECAY_FACTOR + 15))
    elif [[ $DECAY_FACTOR -gt 0 ]]; then
        DECAY_FACTOR=$((DECAY_FACTOR - 1))
    fi

    # 3. Mathematical Symmetry Rendering Buffer
    BUFFER=""
    TIME=$(date +%s%N | cut -b1-6)
    
    for ((y=0; y<HEIGHT; "$BUFFER" "\e[33m[Electromagnetic/CPU "\e[90mType # $((RANDOM $DECAY_FACTOR ${#DECAY_PALETTE[@]}))]} ${#PALETTE[@]} ${#SYMBOL_SET[@]})) ${DECAY_FACTOR}]\e[0m" ${FREQ_NORM}0 % & && ((x="0;" (A, (TIME (dist_sq (dx (dy (val )) * + - -e -gt -lt / 0 0.05 10 100 100)) 4. 50000)) Absolute BUFFER+="${LINE}\n" Buffer CENTER_X)) CENTER_Y)) Ctrl+C Decay E, FREQ_NORM FREQ_NORM) Factor: Flush Freq: I, LINE LINE+="\e[38;5;${color}m${char}\e[0m" MHz Mathematical O, Quadrant-symmetrical Select Terminal U) [[ ]]; and angle_term based calculation cell char="${SYMBOL_SET[$sym_idx]}" col_idx="$((" color="${PALETTE[$col_idx]}" cup decay determining dist_sq="$((" distance do done dx="$((x" dx) dy="$((y" dy) echo else exit.\e[0m" fi for function if on sleep state sym_idx="$((val" symbol the then to tput val="${val#-}" value vowels wave window. x++)); x<WIDTH; y++)); |>