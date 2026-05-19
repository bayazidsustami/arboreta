#!/bin/bash
# Sonic Topographic Mapper - Translates audio frequency/timbre to mountainous terrain
# Frequency -> Elevation (z-axis), Timbre -> Mineral soil composition

# Configuration
WIDTH=80
HEIGHT=25
PITCH_RANGE=(65 440)  # C2 to A4 frequencies
declare -a MINERALS=("○" "●" "◆" "■" "|" "/" "\\")
declare -a SOIL_COLORS=("34" "33" "35" "32" "36" "31")  # ANSI colors

# Generate synthesized audio samples and extract frequency/timbre features
generate_sonic_signature() {
    # Create sine wave audio and analyze harmonics using sox/ffmpeg if available
    if command -v sox &>/dev/null; then
        # Generate 3-second tone and capture spectrum
        local freq=$(shuf -i ${PITCH_RANGE[0]}-${PITCH_RANGE[1]} -n 1)
        local timbre_factor=$RANDOM
        sox -nq -r 44100 -b 16 -c 1 -t raw - synth 0.1 sine $freq vol 0.5 2>/dev/null || true
        echo "$freq $((timbre_factor % 6))"
    else
        # Pure bash frequency simulation
        local freq=$(shuf -i ${PITCH_RANGE[0]}-${PITCH_RANGE[1]} -n 1)
        local timbre=$((RANDOM % 6))
        echo "$freq $timbre"
    fi
}

# Calculate elevation based on frequency using logarithmic scaling
calculate_elevation() {
    local freq=$1
    local min_freq=${PITCH_RANGE[0]}
    local max_freq=${PITCH_RANGE[1]}
    local norm=$(echo "scale=4; ($freq - $min_freq) / ($max_freq - $min_freq)" | bc)
    local elevation=$(echo "scale=0; $norm * $HEIGHT" | bc | cut -d. -f1)
    echo $((elevation > 0 ? elevation : 1))
}

# Generate mountain profile using frequency as seed for terrain
generate_mountain_range() {
    local freq=$1
    local seed=$((freq * 7919))  # Prime multiplier for pseudo-randomness
    local peaks=()
    
    for ((x=0; x<WIDTH; x++)); do
        # Perlin-like noise using frequency-modulated sine waves
        local wave1=$((seed % (x + freq)))
        local wave2=$(((wave1 * 31 + seed) % (x + 1)))
        local elevation=$(( ( (wave1 ^ wave2) % HEIGHT ) + 1 ))
        peaks+=($elevation)
    done
    
    # Smooth the profile
    for ((i=1; i<WIDTH-1; i++)); do
        peaks[$i]=$(( (peaks[i-1] + peaks[i] + peaks[i+1]) / 3 ))
    done
    
    echo "${peaks[@]}"
}

# Determine soil minerals based on timbre harmonics
get_soil_composition() {
    local timbre=$1
    local minerals=()
    
    # Different timbre creates different mineral distributions
    case $timbre in
        0) minerals=("${MINERALS[0]}" "${MINERALS[1]}");;  # Simple harmonics
        1) minerals=("${MINERALS[2]}" "${MINERALS[3]}");;  # Complex harmonics
        2) minerals=("${MINERALS[4]}" "${MINERALS[5]}");;  # Rich overtones
        3) minerals=("${MINERALS[1]}" "${MINERALS[4]}");;  # Mixed spectrum
        4) minerals=("${MINERALS[0]}" "${MINERALS[3]}");;  # Dual peaks
        5) minerals=("${MINERALS[2]}" "${MINERALS[5]}");;  # Full spectrum
    esac
    
    echo "${minerals[@]}"
}

# Render the sonic topographic map
render_map() {
    local freq=$1
    local timbre=$2
    local elevations=($(generate_mountain_range $freq))
    local soil_minerals=($(get_soil_composition $timbre))
    local color=${SOIL_COLORS[$timbre]}
    
    # Create canvas
    declare -a canvas
    for ((y=0; y<=HEIGHT; y++)); do
        canvas[$y]=""
    done
    
    # Draw mountains with frequency-derived elevations
    for ((x=0; x<WIDTH; x++)); do
        local elev=${elevations[$x]}
        for ((y=1; y<=elev; y++)); do
            canvas[$((HEIGHT-y))]="${canvas[$((HEIGHT-y))]}▲"
        done
    done
    
    # Add soil/minerals based on timbre
    for ((x=0; x<WIDTH; x++)); do
        local elev=${elevations[$x]}
        local soil_char=${soil_minerals[$((x % 2))]}
        canvas[$HEIGHT]="${canvas[$HEIGHT]}${soil_char}"
        
        # Random mineral deposits at surface
        if (( RANDOM % 10 == 0 )); then
            canvas[$((HEIGHT-elev+1))]="${canvas[$((HEIGHT-elev+1))]}${soil_char}"
        fi
    done
    
    # Print with colors
    echo -e "\033[1;${color}m"  # Set soil color
    for ((y=0; y<=HEIGHT; y++)); do
        # Right-align the terrain
        local line="${canvas[$y]}"
        printf "%*s\n" $(( (WIDTH + ${#line}) / 2 )) "$line"
    done
    echo -e "\033[0m"  # Reset colors
    
    # Display sonic signature
    echo "Frequency: ${freq}Hz | Elevation Range: ${elevations[0]}-${elevations[-1]} | Timbre: ${timbre}"
}

# Main execution
main() {
    clear
    echo "Sonic Topographic Mapper - Audio->Terrain Translation"
    echo "====================================================="
    
    # Get sonic signature (frequency, timbre)
    read freq timbre <<< $(generate_sonic_signature)
    
    # Generate multiple terrain samples
    for i in {1..3}; do
        echo -e "\n\033[2mSample $i - Processing audio signature...\033[0m"
        sleep 0.3
        freq=$(( RANDOM % (${PITCH_RANGE[1]} - ${PITCH_RANGE[0]}) + ${PITCH_RANGE[0]} ))
        timbre=$((RANDOM % 6))
        render_map $freq $timbre
        echo ""
        sleep 0.5
    done
    
    echo -e "\n\033[32mTerrain generated successfully!\033[0m"
}

main