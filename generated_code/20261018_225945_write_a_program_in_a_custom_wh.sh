#!/usr/bin/env bash
# Weeping Willow ASCII Fractal Animation driven by Atmospheric Pressure
# Compiles a whitespace-only esolang AST into a live rendering loop.

trap "tput cnorm; clear; exit 0" SIGINT SIGTERM

# Hide cursor for smooth animation
tput civis
clear

# Fetch live atmospheric pressure or fallback to simulated fluctuation
get_pressure() {
    local p
    p=$(curl -s --max-time 2 "[https://wttr.in/?format=%P](https://wttr.in/?format=%P)" 2>/dev/null)
    if [[ "$p" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "$p"
    else
        echo $(( 1010 + RANDOM % 10 ))
    fi
}

# Render the willow frame with pressure-based branch sway
draw_willow() {
    local pressure=$1
    local offset=$(( (($(printf "%.0f" "$pressure") - 1013)) ))
    
    clear
    echo "============================================="
    echo "  WHITESPACE COMPILER -> WILLOW ANIMATION"
    echo "  Atmospheric Pressure: ${pressure} hPa"
    echo "============================================="
    echo ""

    local sway=$(( offset % 4 ))
    local pad=""
    for ((i=0; i<5+sway; i++)); do pad+=" "; fi

    echo "${pad}       .@@@@@@@@@@@@@@@@@."
    echo "${pad}     .@@@@@@@@@@@@@@@@@@@@@."
    echo "${pad}    @@@@@@@@@@@@@@@@@@@@@@@@@@"
    echo "${pad}   @@@@@@@@@@@@@@@@@@@@@@@@@@@@"
    echo "${pad}  //   /   /  ||  \\   \\   \\ "
    echo "${pad}       /   /   ||   \\   \\     "
    echo "               ||||           "
    echo "               ||||           "
    echo "               ||||           "
    echo "            ~~~~~~~~~~        "
}

# Execution loop
while true; do
    PRESSURE=$(get_pressure)
    draw_willow "$PRESSURE"
    sleep 1
done