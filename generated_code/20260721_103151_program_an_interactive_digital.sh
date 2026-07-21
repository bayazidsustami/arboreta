#!/usr/bin/env bash
# Digital Bonsai Tree: Driven by CPU Thermal Events & Page Faults
# Uses ANSI terminal graphics to grow a bonsai tree dynamically.
# Growth & Branching -> Driven by Thermal Events (/sys/class/thermal or random proxy)
# Falling Leaves      -> Driven by Page Fault delta from /proc/vmstat

set -u

# Terminal setup and cleanup
cleanup() {
    tput cnorm # Show cursor
    clear
    exit 0
}
trap cleanup SIGINT SIGTERM

tput civis # Hide cursor
clear

# Screen Dimensions
WIDTH=$(tput cols)
HEIGHT=$(tput lines)
GROUND_Y=$((HEIGHT - 3))
TRUNK_X=$((WIDTH / 2))

# Color Definitions (256-color)
BROWN="\033[38;5;130m"
GREEN1="\033[38;5;34m"
GREEN2="\033[38;5;40m"
GREEN3="\033[38;5;118m"
PINK="\033[38;5;206m" # Cherry blossom / leaf
POT_COLOR="\033[38;5;124m"
RESET="\033[0m"

# Utility: Draw at (x, y)
draw_at() {
    local x=$1 y=$2 char=$3 color=$4
    if (( x > 1 && x < WIDTH && y > 1 && y < HEIGHT )); then
        printf "\033[%d;%dH%b%s%b" "$y" "$x" "$color" "$char" "$RESET"
    fi
}

# Draw Pot
draw_pot() {
    local px=$TRUNK_X py=$GROUND_Y
    draw_at $((px - 6)) $py "┌───────────┐" "$POT_COLOR"
    draw_at $((px - 6)) $((py + 1)) " └─────────┘ " "$POT_COLOR"
}

# Read CPU Temperature
get_temp() {
    local temp=0
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp=$((temp / 1000))
    else
        # Fallback pseudo-thermal simulation based on load
        temp=$(( 40 + RANDOM % 30 ))
    fi
    echo "$temp"
}

# Read Major/Minor Page Faults Total
get_page_faults() {
    if [[ -f /proc/vmstat ]]; then
        awk '/pgfault/ {s+=$2} END {print s}' /proc/vmstat
    else
        echo "$RANDOM"
    fi
}

# Tree state arrays
declare -a LEAF_X LEAF_Y
LEAF_COUNT=0

# Trunk / Branch state
curr_x=$TRUNK_X
curr_y=$((GROUND_Y - 1))
height_growth=0
max_height=15

draw_pot

# Initial tracking state
last_faults=$(get_page_faults)

while true; do
    temp=$(get_temp)
    current_faults=$(get_page_faults)
    
    # Calculate page faults delta
    fault_delta=$((current_faults - last_faults))
    last_faults=$current_faults

    # Thermal effect on growth rate (Higher temp = faster/more chaotic growth)
    # Sleep interval dynamically scales inversely with temperature
    sleep_time=$(awk -v t="$temp" 'BEGIN { delay = 1.0 - (t - 30) * 0.015; if (delay < 0.1) delay = 0.1; print delay }')

    # Grow Trunk / Branches based on Thermal Activity
    if (( height_growth < max_height )); then
        # Thermal variance alters branch direction
        thermal_angle=$(( (temp + RANDOM) % 3 - 1 )) # -1 (left), 0 (up), 1 (right)
        
        # Color deepens/shifts with temp
        trunk_color=$BROWN
        if (( temp > 65 )); then
            trunk_color="\033[38;5;166m" # Heat-stressed orange-brown
        fi

        draw_at $curr_x $curr_y "█" "$trunk_color"
        
        # Move up and apply horizontal drift
        (( curr_y-- ))
        (( curr_x += thermal_angle ))
        (( height_growth++ ))

        # Add foliage along branches
        if (( RANDOM % 2 == 0 )); then
            leaf_color=$GREEN1
            (( temp > 50 )) && leaf_color=$GREEN2
            (( temp > 70 )) && leaf_color=$GREEN3
            
            draw_at $((curr_x - 1)) $curr_y "♣" "$leaf_color"
            draw_at $((curr_x + 1)) $curr_y "♣" "$leaf_color"

            # Register leaves as potential falling candidates
            LEAF_X+=($((curr_x - 1)) $((curr_x + 1)))
            LEAF_Y+=($curr_y $curr_y)
            (( LEAF_COUNT += 2 ))
        fi
    fi

    # Trigger falling leaves based on Page Faults
    if (( fault_delta > 0 && LEAF_COUNT > 0 )); then
        # Drop pixels (leaves) proportional to page fault frequency
        drops=$(( fault_delta % 5 + 1 ))
        for (( i=0; i<drops; i++ )); do
            idx=$(( RANDOM % LEAF_COUNT ))
            lx=${LEAF_X[$idx]}
            ly=${LEAF_Y[$idx]}

            # Animate leaf falling down to the ground
            if (( ly < GROUND_Y )); then
                draw_at $lx $ly " " "$RESET" # Clear old position
                
                # Drift downwards with wind simulation
                drift=$(( RANDOM % 3 - 1 ))
                new_x=$(( lx + drift ))
                new_y=$(( ly + 1 ))

                draw_at $new_x $new_y "•" "$PINK"
                
                # Update leaf array position
                LEAF_X[$idx]=$new_x
                LEAF_Y[$idx]=$new_y
            fi
        done
    fi

    # Thermal Status Monitor Overlay
    draw_at 2 2 "CPU Temp: ${temp}°C  | Page Faults Δ: ${fault_delta}  " "$GREEN3"

    sleep "$sleep_time"
done