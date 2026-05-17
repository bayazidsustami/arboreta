#!/bin/bash

# --- THE CHAOTIC POETRY ENGINE ---
# A simulation of a double pendulum's chaotic trajectory determining
# word order and emotional valence through y-axis crossings.

set -e

# 1. The Lexicon: Words categorized by emotional "weight"
# Joyful (High/Positive) vs Melancholic (Low/Negative)
JOYFUL=("sunlight" "dancing" "golden" "rhythm" "whisper" "soaring" "bright" "eternal" "breath" "bloom")
SAD=("shadow" "echo" "broken" "silent" "void" "drifting" "cold" "fading" "hollow" "lost")
NEUTRAL=("stone" "wind" "path" "time" "river" "mountain" "cloud" "star" "leaf" "dust")

# The Poem Structure: Stanzas of mixed words to be reordered
POEM_DATA=(
    "the sky turns gold"
    "a soft wind blows"
    "life finds a way"
    "darkness meets the light"
    "time flows like water"
)

# 2. Double Pendulum Simulation (Simplified Chaotic Mapping)
# We simulate the angular positions (theta1, theta2) using a simplified 
# Euler integration of a chaotic map to avoid heavy floating-point math 
# requirements in pure Bash, while maintaining chaotic sensitivity.
simulate_chaos() {
    local iterations=100
    local crossings=0
    local trajectory=()
    
    # Initial state (chaotic seeds)
    local th1=1.5
    local th2=1.0
    local dt=0.1
    local g=9.8
    local m1=1.0
    local m2=1.0
    local l1=1.0
    local l2=1.0

    for ((i=0; i<iterations; i++)); do
        # Chaotic step: Use a non-linear mapping to simulate angular velocity changes
        # We use a sine-based chaotic attractor approximation
        local prev_th1=$th1
        th1=$(echo "scale=4; $th1 + (0.1 * s($th2) * c($th1))" | bc -l 2>/dev/null || echo "$th1 + 0.05")
        th2=$(echo "scale=4; $th2 + (0.1 * s($th1) * c($th2))" | bc -l 2>/dev/null || echo "$th2 + 0.03")
        
        # Calculate virtual Y position: y = l1*sin(th1) + l2*sin(th2)
        # In a real pendulum, y is the vertical component.
        # We check for y-axis crossings: sign change in the 'x' component (l1*sin(th1) + l2*sin(th2))
        # Here we use a proxy: if the sin sum crosses zero.
        local y_pos=$(echo "scale=4; s($th1) + s($th2)" | bc -l)
        
        # Detect crossing (sign change)
        if (( $(echo "$y_pos > 0" | bc -l) )) && [[ "$PREV_Y" < "0" ]]; then
            ((crossings++))
        elif (( $(echo "$y_pos < 0" | bc -l) )) && [[ "$PREV_Y" > "0" ]]; then
            ((crossings++))
        fi
        PREV_Y=$y_pos

        # Store trajectory value for word shuffling (normalized 0-1)
        # Use the absolute value of the angle to create a "path"
        local val=$(echo "scale=4; ($th1 + $th2) / 4" | bc -l)
        trajectory+=("$val")
    done

    echo "$crossings|${trajectory[*]}"
}

# 3. The Poem Generator
generate_poem() {
    local result=$(simulate_chaos)
    local crossings=$(echo "$result" | cut -d'|' -f1)
    local path=(${result#*|})
    
    # Determine Emotional Tone based on y-axis crossings
    # Low crossings = Melancholic, Medium = Neutral, High = Joyful
    local tone="NEUTRAL"
    if [ "$crossings" -lt 5 ]; then
        tone="SAD"
    elif [ "$crossings" -gt 15 ]; then
        tone="JOYFUL"
    fi

    echo "--- CHAOTIC POEM GENERATED ---"
    echo "Simulation State: $crossings crossings | Tone: $tone"
    echo "------------------------------"
    sleep 1

    for line in "${POEM_DATA[@]}"; do
        # Split line into words
        read -r -a words <<< "$line"
        
        # Create a shuffled array based on the "particle path"
        # We use the trajectory values to pick indices
        local new_line=()
        local len=${#words[@]}
        
        # We use a subset of the path for each line to determine permutation
        for ((i=0; i<len; i++)); do
            # Extract a value from the path, map it to an index
            local idx_val=${path[$(( (i * 10) % ${#path[@]} ))]}
            # Convert float-ish string to integer index via awk
            local target_idx=$(awk -v v="$idx_val" -v l="$len" 'BEGIN {print int(abs(v) * l) % l}')
            
            # To ensure uniqueness/shuffling, we pick a word and swap
            # But for true "particle path" logic, we'll use the path to 'pluck' words
            new_line+=("${words[$target_idx]}")
        done

        # Emotional Infusion: Replace words based on tone
        local final_line=""
        for word in "${new_line[@]}"; do
            local rand=$((RANDOM % 10))
            if [ "$rand" -eq 0 ]; then
                case $tone in
                    "JOYFUL") word="${JOYFUL[$((RANDOM % 10))]}" ;;
                    "SAD")    word="${SAD[$((RANDOM % 10))]}" ;;
                    "NEUTRAL") word="${NEUTRAL[$((RANDOM % 10))]}" ;;
                esac
            fi
            final_line+="$word "
        done

        echo "$final_line"
        sleep 0.3
    done
    echo "------------------------------"
}

# Helper function for awk abs
abs() { echo "$1" | sed 's/-//'; }
export -f abs

# Start the process
generate_poem