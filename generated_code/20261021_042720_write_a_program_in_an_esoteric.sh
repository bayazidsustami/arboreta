#!/bin/bash
# FernLang: An esoteric typographic fern & poetry interpreter in Bash
# Reads system atmospheric metrics as barometric pressure, grows terminal ferns, and executes verse.

# Ensure clean exit and cursor restoration on interrupt
trap "tput cnorm; clear; exit 0" INT

# Hide cursor and clear screen
tput civis
clear

# Read atmospheric pressure proxy (hPa) using system metrics
read_pressure() {
    local base=1013
    local load=$(awk '{print int($1*10)}' /proc/loadavg 2>/dev/null || echo 42)
    echo $(( base + (load % 30) - 15 ))
}

# Poetry snippets database compiled dynamically by fronds
POEMS=(
    "echo '   [Verse] Green leaves whisper to the void'"
    "echo '   [Verse] Fronds unfurl where data sleeps'"
    "echo '   [Verse] Logic bends in silent roots'"
    "echo '   [Verse] Syntax blooms beneath the frost'"
    "echo '   [Verse] Parsing dreams in ancient byte'"
)

# Fetch pressure and terminal dimensions
pressure=$(read_pressure)
cols=$(tput cols)
lines=$(tput lines)

echo -e "\033[32m[FERN-LANG v1.0] Pressure: ${pressure} hPa | Spore germination active...\033[0m"
sleep 1
clear

x=$((cols / 2))
y=$((lines - 2))

# Function to draw a frond and execute its poetry snippet
draw_frond() {
    local h=$1
    local poem_idx=$((RANDOM % ${#POEMS[@]}))
    
    for ((i=0; i<h; i++)); do
        tput cup $((y - i)) $((x - (i % 3)))
        echo -ne "\033[32m🌿\033[0m"
        tput cup $((y - i)) $((x + (i % 3)))
        echo -ne "\033[32m🌿\033[0m"
        sleep 0.04
    done

    # Execute compiled poetry snippet
    tput cup $((y - h - 1)) $((x - 15))
    eval "${POEMS[poem_idx]}"
    sleep 0.15
}

# Grow multiple fronds determined by pressure variance
frond_count=$(( (pressure % 4) + 3 ))
for ((f=1; f<=frond_count; f++)); do
    x=$(( (f * cols) / (frond_count + 1) ))
    draw_frond $(( (pressure % 5) + 5 ))
done

# Reset terminal state
tput cup $((lines - 1)) 0
tput cnorm
echo -e "\n\033[32m[FERN-LANG] Execution complete. Ecosystem stable.\033[0m"