#!/usr/bin/env bash
# Watercolor Landscape Painter driven by Network Latency
# Paints a shifting, organic landscape using ANSI TrueColor codes based on ping latency.

TARGET="8.8.8.8"
COLS=$(tput cols)
[[ -z "$COLS" ]] && COLS=80

cleanup() {
    printf "\e[0m\n"
    exit 0
}
trap cleanup INT TERM

# Clear screen initially
printf "\e[2J\e[H"

# Color mapping function based on latency and row position
# Returns ANSI TrueColor escape sequence for background
get_watercolor_color() {
    local lat=$1
    local row=$2
    local total_rows=$3

    # Convert latency to integer safely (default to 20 if float/empty)
    local base_lat=${lat%%.*}
    [[ -z "$base_lat" ]] && base_lat=20

    # Create fluid gradients based on row (sky vs water/land) and latency variance
    local r g b
    if (( row < total_rows / 3 )); then
        # Sky: shifting pastels, mood influenced by latency
        r=$(( (row * 15 + base_lat * 2) % 100 + 155 ))
        g=$(( (row * 20 + base_lat) % 120 + 135 ))
        b=$(( 220 - (base_lat % 40) ))
    elif (( row < (total_rows * 2) / 3 )); then
        # Mountains / Hills: earthy watercolor tones
        local h_mod=$(( (row - total_rows / 3) * 10 ))
        r=$(( 80 + h_mod + (base_lat % 30) ))
        g=$(( 120 + (base_lat % 50) ))
        b=$(( 140 - h_mod ))
    else
        # Water / Reflection: fluid blues and teals
        r=$(( 40 + (base_lat % 20) ))
        g=$(( 100 + (row * 5) % 80 ))
        b=$(( 180 + (base_lat % 40) ))
    fi

    printf "\e[48;2;%d;%d;%dm" "$r" "$g" "$b"
}

# Main painting loop across terminal history
ROWS=16
while true; do
    # Measure network latency
    ping_out=$(ping -c 1 -W 1 "$TARGET" 2>/dev/null)
    lat=$(echo "$ping_out" | grep -oE 'time=[0-9.]+' | cut -d= -f2)
    [[ -z "$lat" ]] && lat="25.0"

    # Paint a fresh canvas band shifting down the terminal history
    printf "\n"
    for ((r=0; r<ROWS; " "$ROWS") "$lat" "$line" "$r" "%s\e[0m\n" ") "BEGIN "~" "·" "╱" "╲" "░" "▒" # ${#chars[@]} % ($lat ((c="0;" (c )) * + Dynamic Pick by c++)); c<COLS; char="${chars[$char_idx]}" char_idx="$((" characters chars="(" color_code="$(get_watercolor_color" do done for latency line line+="${color_code}${char}" organic pause printf r r)) r++)); scaled simulating sleep_time="$(awk" texture watercolor {print }> 200 ? 0.2 : $lat / 500 + 0.1)}")
    sleep "$sleep_time"
done