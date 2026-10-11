#!/usr/bin/env bash
# Watercolor Weather Portrait Generator via Kernel Panic Pigment Simulation
# Renders an evolving organic watercolor bleed in the terminal using local weather
# conditions and simulated kernel panic logs as pigment droplets.

set -euo pipefail

# Retrieve terminal dimensions
cols=$(tput cols 2>/dev/null || echo 80)
rows=$(tput lines 2>/dev/null || echo 24)

# Fetch local weather or fallback to gentle atmospheric conditions
weather_data=$(curl -s --max-time 2 "[https://wttr.in/?format=%t+%C](https://wttr.in/?format=%t+%C)" 2>/dev/null || echo "+15°C Rain")
temp=$(echo "$weather_data" | grep -oE '[+-]?[0-9]+' || echo "15")

# Derive organic watercolor base palettes from temperature
if [ "$temp" -lt 0 ]; then
    r_base=40; g_base=80; b_base=160   # Glacial indigo & frost blue
elif [ "$temp" -gt 25 ]; then
    r_base=190; g_base=90; b_base=40  # Warm terracotta & amber sunset
else
    r_base=70; g_base=130; b_base=95  # Rainy moss & slate gray
fi

# Prepare terminal view
printf "\e[?25l\e[2J"

cleanup() {
    printf "\e[0m\e[?25h\n"
    exit 0
}
trap cleanup INT TERM EXIT

# Kernel panic log source generator representing pigment composition
get_panic_pigment() {
    local panics=(
        "Kernel panic - not syncing: Fatal exception in interrupt droplet"
        "CPU: 4 PID: 1337 Comm: watercolor-daemon Not tainted 6.1.0-art"
        "Hardware error intercepted: thermal pigment overflow on node 0"
        "VFS: Unable to mount root filesystem on unknown-block canvas"
        "BUG: soft lockup - CPU#0 stuck for 22s! [cloud:precipitation]"
        "Oops: 0000 [#1] PREEMPT SMP NOPTI watercolor bleed active"
        "RIP: 0010:organic_diffusion+0x1a/0x50"
    )
    echo "${panics[$RANDOM % ${#panics[@]}]}"
}

# Initialize canvas grid
declare -A grid
for ((y=1; y<=rows-3; y++)); do
    for ((x=1; x<=cols; x++)); do
        grid[$y,$x]=0
    done
done

# Artistic evolution simulation loop
total_steps=50
for ((step=1; step<=total_steps; step++)); do
    # Inject kernel panic log text as a fresh pigment droplet source
    panic_line=$(get_panic_pigment)
    drop_x=$(( (RANDOM % (cols - 30)) + 5 ))
    drop_y=$(( (RANDOM % (rows - 6)) + 3 ))
    
    for ((i=0; i<${#panic_line} && (drop_x+i)<cols; i++)); do
        char="${panic_line:$i:1}"
        if [ "$char" != " " ]; then
            grid[$drop_y,$((drop_x+i))]=120
        fi
    done

    # Render frame header
    printf "\e[H"
    printf "\e[1;36m[Weather: %s] [Step: %d/%d] [Pigment: Kernel Panic Logs]\e[0m\n\n" "$weather_data" "$step" "$total_steps"

    # Compute diffusion and draw watercolor canvas
    declare -A next_grid
    for ((y=1; y<=rows-3; y++)); do
        line_output=""
        for ((x=1; x<=cols; x++)); do
            val=${grid[$y,$x]:-0}
            
            if [ $val -gt 0 ]; then
                intensity=$(( val > 255 ? 255 : val ))
                r=$(( r_base * intensity / 100 > 255 ? 255 : r_base * intensity / 100 ))
                g=$(( g_base * intensity / 100 > 255 ? 255 : g_base * intensity / 100 ))
                b=$(( b_base * intensity / 100 > 255 ? 255 : b_base * intensity / 100 ))
                
                if [ $intensity -gt 80 ]; then
                    glyph="█"
                elif [ $intensity -gt 45 ]; then
                    glyph="▓"
                elif [ $intensity -gt 20 ]; then
                    glyph="▒"
                else
                    glyph="░"
                fi
                
                line_output+="\e[38;2;${r};${g};${b}m${glyph}\e[0m"
                
                # Decay pigment density
                decayed=$(( val - 10 ))
                [ $decayed -lt 0 ] && decayed=0
                next_grid[$y,$x]=$decayed
                
                # Organic capillary bleed into neighboring cells
                for dy in -1 0 1; do
                    for dx in -1 0 1; do
                        ny=$((y+dy)); nx=$((x+dx))
                        if [ $ny -ge 1 ] && [ $ny -le $((rows-3)) ] && [ $nx -ge 1 ] && [ $nx -le cols ]; then
                            cur=${next_grid[$ny,$nx]:-${grid[$ny,$nx]:-0}}
                            next_grid[$ny,$nx]=$(( cur + decayed / 7 ))
                        fi
                    done
                done
            else
                line_output+=" "
                next_grid[$y,$x]=0
            fi
        done
        printf "%s\n" "$line_output"
    done
    
    # Update grid state for next evolution frame
    for ((y=1; y<=rows-3; y++)); do
        for ((x=1; x<=cols; x++)); do
            grid[$y,$x]=${next_grid[$y,$x]:-0}
        done
    done

    sleep 0.1
done

printf "\n\e[32mWatercolor portrait evolution complete.\e[0m\n"