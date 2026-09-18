#!/bin/bash
# Celestial Aquarium: Procedural ASCII fish driven by kernel memory usage.
# Self-contained Bash script utilizing ANSI escape sequences and /proc/meminfo.

# Ensure cursor is restored and screen is cleared on exit
trap 'tput cnorm; clear; exit' INT TERM
tput civis
clear

# Retrieve terminal dimensions
cols=$(tput cols)
rows=$(tput lines)

# Initialize procedural fish attributes (X positions, Y positions, directions)
fish_x=(10 30 50)
fish_y=(5 12 18)
fish_dir=(1 -1 1)

while true; do
    # Fetch live kernel memory usage percentage
    if [ -f /proc/meminfo ]; then
        total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
        avail=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
        [ -z "$total" ] && total=1000000
        [ -z "$avail" ] && avail=500000
        mem_ratio=$(( (total - avail) * 100 / total ))
    else
        mem_ratio=50
    fi

    # Reset cursor to top-left to minimize flicker
    printf "\033[H"
    
    # Render header with live telemetry
    printf "=== KERNEL CELESTIAL AQUARIUM | Memory Pressure: %2d%% ===" "$mem_ratio"
    
    # Update and render each fish
    for i in {0..2}; do
        # Movement speed and direction influenced by memory fluctuations
        speed=$(( (mem_ratio / 20) + 1 ))
        fish_x[i]=$(( fish_x[i] + (fish_dir[i] * speed) ))
        
        # Screen boundary check & horizontal bounce
        if [ ${fish_x[i]} -ge $((cols - 8)) ] || [ ${fish_x[i]} -le 1 ]; then
            fish_dir[i]=$(( -fish_dir[i] ))
        fi
        
        # Vertical oscillation driven by memory load and position
        base_y=$(( (i * 6) + 4 ))
        wave=$(( (mem_ratio + fish_x[i]) % 7 - 3 ))
        fish_y[i]=$(( base_y + wave ))
        
        # Keep fish within vertical bounds
        if [ ${fish_y[i]} -ge $((rows - 2)) ]; then fish_y[i]=$((rows - 2)); fi
        if [ ${fish_y[i]} -le 2 ]; then fish_y[i]=3; fi
        
        # Select ASCII art based on swim direction
        if [ ${fish_dir[i]} -gt 0 ]; then
            fish_art=">°)))><"
        else
            fish_art="><(((°<"
        fi
        
        # Draw fish at calculated coordinates
        printf "\033[%d;%dH%s" "${fish_y[i]}" "${fish_x[i]}" "$fish_art"
    done
    
    # Render ambient celestial background stars affected by memory drift
    star_x=$(( (RANDOM % (cols - 2)) + 1 ))
    star_y=$(( (RANDOM % (rows - 4)) + 3 ))
    printf "\033[%d;%dH." "$star_y" "$star_x"
    
    # Frame pacing
    sleep 0.08
done