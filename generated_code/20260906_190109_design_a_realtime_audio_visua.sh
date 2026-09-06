#!/usr/bin/env bash
# Generative Memory Landscape & Thread Erosion Visualizer
# Parses live system memory and process threads into an evolving, audio-reactive ASCII visualizer.

# Exit cleanly on interrupt
trap 'tput cnorm; clear; exit 0' INT TERM

# Prepare terminal: hide cursor, clear screen
tput civis
clear

# Symbols for geological landscape layers (dense rock -> high peaks -> vegetation -> sky)
LANDSCAPE_CHARS=(" " "░" "▒" "▓" "█" "▲" "∩" "♠" "♣" "•")
# Symbols representing thread activity / erosion impact
EROSION_CHARS=("≈" "░" "▒" "▓" "█" "x" "*" "#" "%" "@")

# Initialize audio phase for synthesized ambient tones
audio_phase=0

# Function to synthesize dynamic ambient audio pulses via audio device
play_generative_tone() {
    local cpu_load=$1
    local mem_load=$2
    
    # Calculate audio frequency based on CPU/Mem load (150Hz to 850Hz)
    local freq=$(( 150 + (cpu_load * 5) + (mem_load * 2) ))
    
    # Synthesize raw PCM audio (8kHz, 8-bit unsigned) in background if /dev/dsp or aplay exists
    if command -v aplay >/dev/null 2>&1; then
        (
            # Generate 0.15s pulse of audio using mathematical wave synthesis
            perl -e '
                my $freq = '$freq';
                my $duration = 0.15;
                my $rate = 8000;
                my $samples = $rate * $duration;
                for (my $i = 0; $i < $samples; $i++) {
                    my $t = $i / $rate;
                    my $v = 128 + 127 * sin(2 * 3.14159 * $freq * $t) * exp(-3 * $t);
                    print pack("C", $v);
                }
            ' 2>/dev/null | aplay -q -r 8000 -f U8 2>/dev/null
        ) &
    fi
}

# Main generative rendering loop
while true; do
    # Fetch terminal size dynamically
    term_cols=$(tput cols 2>/dev/null || echo 80)
    term_rows=$(tput lines 2>/dev/null || echo 24)
    
    # Parse live memory usage (%)
    mem_info=$(free 2>/dev/null | awk '/Mem:/ {print int($3/$2 * 100)}')
    mem_load=${mem_info:-50}
    
    # Parse total active threads across top processes
    thread_count=$(ps -eo nlwp 2>/dev/null | awk '{s+=$1} END {print s}')
    thread_count=${thread_count:-100}
    
    # Get active thread CPU consumption vector (top 8 thread-heavy processes)
    read -r -a top_threads <<< "$(ps -eo %cpu --sort=-%cpu 2>/dev/null | tail -n +2 | head -n 8 | awk '{print int($1)}' | tr '\n' ' ')"
    cpu_top=${top_threads[0]:-10}
    
    # Audio-visual synchronization pulse
    play_generative_tone "$cpu_top" "$mem_load"
    
    # Move cursor to top-left for smooth buffer redraw
    tput cup 0 0
    
    # Header display: System telemetry
    echo -ne "\033[1;36m═══ GENERATIVE MEMORY LANDSCAPE ═══\033[0m Memory Usage: \033[1;32m${mem_load}%\033[0m | Active Threads: \033[1;33m${thread_count}\033[0m | Peak CPU: \033[1;31m${cpu_top}%\033[0m\n"
    
    view_rows=$(( term_rows - 3 ))
    
    # Generate spatial terrain columns dynamically
    for (( r=0; r<view_rows; r++ )); do
        line=""
        for (( c=0; c<term_cols; c++ )); do
            # Mathematical terrain generator using multi-sine waves modulated by Memory %
            sine_wave=$(( (c * 10 / term_cols) + (audio_phase) ))
            base_elevation=$(( (mem_load * view_rows / 150) + (r) ))
            
            # Map top thread CPU loads to geographical ridge features across the horizon
            thread_idx=$(( c * 8 / term_cols ))
            thread_cpu=${top_threads[$thread_idx]:-5}
            
            # Erosion calculation: CPU activity erodes terrain height
            erosion_factor=$(( thread_cpu / 15 ))
            effective_elevation=$(( base_elevation - erosion_factor ))
            
            if [ "$r" -gt "$(( view_rows - effective_elevation - 2 ))" ]; then
                # Geological layers based on depth
                depth=$(( r - (view_rows - effective_elevation) ))
                
                if [ "$depth" -lt 0 ]; then
                    # Eroding crest/peak with thread activity
                    char_idx=$(( (thread_cpu + audio_phase) % ${#EROSION_CHARS[@]} ))
                    color="\033[31m" # Red erosion
                    char="${EROSION_CHARS[$char_idx]}"
                elif [ "$depth" -eq 0 ]; then
                    # Surface features
                    char_idx=$(( (mem_load / 10) % ${#LANDSCAPE_CHARS[@]} ))
                    color="\033[32m" # Green vegetation
                    char="${LANDSCAPE_CHARS[$char_idx]}"
                elif [ "$depth" -lt 4 ]; then
                    # Mid-strata rock
                    color="\033[33m" # Yellow rock
                    char="▓"
                else
                    # Deep bedrock
                    color="\033[34m" # Blue bedrock
                    char="█"
                fi
                line+="${color}${char}\033[0m"
            else
                # Sky / Atmosphere reactive to thread noise
                if [ $(( (c + r + audio_phase) % 17 )) -eq 0 ] && [ "$thread_cpu" -gt 25 ]; then
                    line+="\033[1;30m·\033[0m" # Dynamic atmospheric dust
                else
                    line+=" "
                fi
            fi
        done
        echo -e "$line"
    done
    
    # Status bar bottom footer
    echo -ne "\033[1;30m[Press Ctrl+C to exit] • Live System Process Threads → Geological Erosion Vector Engine\033[0m"
    
    # Advance generative time phase
    audio_phase=$(( (audio_phase + 1) % 360 ))
    
    # Refresh rate limit (~10 FPS)
    sleep 0.1
done