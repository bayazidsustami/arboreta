#!/usr/bin/env bash
# Evolving Typographic Labyrinth with Weeping Geometric Equations
# Triggered when typing speed matches a sleeping cat's heartbeat (~40 BPM).

set -euo pipefail

# Terminal dimensions
cols=$(tput cols)
rows=$(tput lines)

# Cleanup on exit
trap 'tput cnorm; clear; exit 0' INT TERM EXIT

# Hide cursor and clear screen
tput civis
clear

# State variables
bpm_target=40
keystroke_count=0
start_time=$(date +%s)
weeping_mode=0
weeping_timer=0

# Initialize labyrinth grid
declare -A grid
for ((y=0; y<rows; y++)); do
    for ((x=0; x<cols; x++)); do
        if ((RANDOM % 3 == 0)); then
            grid[$x,$y]="$((RANDOM % 2 ? 9484 : 9488))" # Box drawing chars
        else
            grid[$x,$y]=" "
        fi
    done
done

# Non-blocking input check function
read_key() {
    read -rsn1 -t 0.05 key 2>/dev/null || true
    if [[ -n "$key" ]]; then
        ((keystroke_count++))
        # Check current typing speed (approx over last window)
        local elapsed=$(( $(date +%s) - start_time ))
        if (( elapsed > 0 )); then
            local current_bpm=$(( (keystroke_count * 60) / elapsed ))
            # If within +/- 3 BPM of a sleeping cat (40 BPM)
            if (( current_bpm >= 37 && current_bpm <= 43 )); then
                weeping_mode=1
                weeping_timer=20
            fi
        fi
    fi
}

# Main animation loop
while true; do
    read_key

    # Render grid
    output=""
    for ((y=0; y<rows-1; y++)); do
        line=""
        for ((x=0; x<cols; x++)); do
            if (( weeping_mode == 1 )); then
                # Dissolve walls into geometric/trig equations
                if (( (x + y + weeping_timer) % 7 == 0 )); then
                    chars=("sin(θ)" "cos(φ)" "∫e^x" "∇²Ψ" "√(-1)" "λ_i")
                    line+="${chars[$((RANDOM % ${#chars[@]}))]}"
                    ((x+=5)) # Skip ahead for equation length
                else
                    line+="|"
                fi
            else
                # Standard labyrinth evolution
                if (( RANDOM % 50 == 0 )); then
                    grid[$x,$y]="$((RANDOM % 2 ? 9474 : 9472))"
                fi
                line+="$(printf \\U$(printf '%x' "${grid[$x,$y]}"))"
            fi
        done
        output+="$line\n"
    done

    # Print status footer
    footer=" [Typing Labyrinth] Target Heartbeat: ${bpm_target} BPM | Mode: "
    if (( weeping_mode == 1 )); then
        footer+="WEEPING EQUATIONS ACTIVE "
        ((weeping_timer--))
        if (( weeping_timer <= 0 )); then
            weeping_mode=0
        fi
    else
        footer+="Labyrinthine (Type to match cat heartbeat) "
    fi
    output+="$footer"

    # Draw frame at once to prevent flicker
    printf "\033[H%b" "$output"

    # Periodic reset of keystroke counter to maintain rolling average
    local now=$(date +%s)
    if (( now - start_time > 10 )); then
        start_time=$now
        keystroke_count=0
    fi
done