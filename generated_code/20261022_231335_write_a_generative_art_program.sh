#!/usr/bin/env bash
# Generative ASCII Storm - Translates emotional cadence into liquid typographic waves
# Self-contained, dynamic bash art using ANSI escape codes and random wave mathematics.

# Trap exit to restore terminal cursor and settings
trap "tput cnorm; clear; exit" INT TERM EXIT

# Hide cursor and clear screen
tput civis
clear

# Get terminal dimensions
cols=$(tput cols)
rows=$(tput lines)

# Intensity characters from sparse to dense
chars=(" " "." ":" "-" "=" "+" "*" "#" "%" "@")
num_chars=${#chars[@]}

# Seed wave parameters
step=0
while true; do
    # Read terminal size dynamically in case of resize
    cols=$(tput cols)
    rows=$(tput lines)

    output=""
    for ((y=0; y<rows; y++)); do
        line=""
        for ((x=0; x<cols; x++)); do
            # Compute a layered wave equation mimicking emotional shifting cadence
            val=$(awk -v x="$x" -v y="$y" -v s="$step" 'BEGIN {
                v = sin(x*0.05 + s*0.2) + cos(y*0.1 - s*0.15) + sin((x+y)*0.03 + s*0.1);
                # Normalize roughly to 0..1
                v = (v + 3) / 6;
                print v;
            }')
            
            # Map float to character index
            index=$(awk -v v="$val" -v nc="$num_chars" 'BEGIN {
                idx = int(v * nc);
                if (idx < 0) idx = 0;
                if (idx >= nc) idx = nc - 1;
                print idx;
            }')
            
            line+="${chars[$index]}"
        done
        output+="$line\n"
    done

    # Move cursor to top-left and render frame instantly
    printf "\033[H%b" "$output"

    # Increment step for fluid animation
    ((step++))
    
    # Control frame rate (~30fps feel)
    read -t 0.03 -n 1 input 2>/dev/null
    if [[ $input = "q" ]]; then
        break
    fi
done

tput cnorm
clear