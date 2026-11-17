#!/usr/bin/env bash
# Baroque Tapestry of OS Memory: A Recursive Fractal Lace Visualizer
# Renders live system memory allocation into an ever-growing generative ANSI art tapestry.

trap "tput cnorm; clear; exit 0" INT TERM
tput civis
clear

# Baroque color palette (golds, crimsons, deep indians, cyans)
colors=(33 93 196 208 201 51 220 129)

# Read memory utilization percentage from /proc/meminfo
get_mem_factor() {
    if [[ -r /proc/meminfo ]]; then
        local total avail
        total=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
        avail=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
        echo $(( ( (total - avail) * 100 ) / total ))
    else
        echo 42
    fi
}

# Recursive lace weaving function
draw_lace() {
    local depth=$1
    local seed=$2
    if (( depth <= 0 )); then
        return
    fi
    
    local char_set=("✦" "✧" "❖" "◈" "╱" "╲" "═" "║" "•" "·")
    local idx=$(( (seed + depth + MEM_VAL) % ${#char_set[@]} ))
    local color_idx=$(( (seed + depth) % ${#colors[@]} ))
    
    printf "\e[38;5;%sm%s\e[0m" "${colors[color_idx]}" "${char_set[idx]}"
    
    # Recursive branches creating fractal lace structures
    draw_lace $((depth - 1)) $((seed * 3 + 1))
    draw_lace $((depth - 1)) $((seed * 5 + 3))
}

iter=0
cols=$(tput cols)
lines=$(tput lines)

while true; do
    MEM_VAL=$(get_mem_factor)
    
    # Header display
    tput cup 0 0
    echo -e "\e[1;33m[ BAROQUE MEMORY TAPESTRY ]\e[0m Memory Pressure: \e[1;31m${MEM_VAL}%\e[0m | Weave: ${iter} "
    
    # Expand tapestry rows dynamically
    max_row=$(( iter + 2 ))
    (( max_row > lines )) && max_row=$lines
    
    for ((r=2; r<max_row; r++)); do
        tput cup $r 0
        for ((c=0; c<cols; c+=2)); do
            seed=$(( (r * c + iter + MEM_VAL) % 997 ))
            depth=$(( (MEM_VAL % 3) + 2 ))
            draw_lace $depth $seed
        done
    done
    
    iter=$((iter + 1))
    sleep 0.1
done