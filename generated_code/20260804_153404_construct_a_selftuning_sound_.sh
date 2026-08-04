#!/usr/bin/env bash
# ==============================================================================
# Binary Topology Sound Synthesizer & Geometric State Visualizer
# Converts executable binaries into an evolving ambient audio soundscape 
# and renders an ASCII geometric phase portrait on the terminal screen.
# ==============================================================================

set -euo pipefail

# Default binary to self or bash if none supplied
TARGET_FILE="${1:-/bin/bash}"

if [[ ! -f "$TARGET_FILE" ]]; then
    echo "Error: File '$TARGET_FILE' not found." >&2
    exit 1
fi

# Terminal setup & cleanup trap
cleanup() {
    # Restore cursor, reset colors, clear screen, kill background jobs
    printf "\e[?25h\e[0m\e[2J\e[H"
    kill 0 2>/dev/null || true
    exit 0
}
trap cleanup EXIT INT TERM

# Ensure audio tool is available (aplay or ffplay)
AUDIO_CMD=""
if command -v aplay &>/dev/null; then
    AUDIO_CMD="aplay -q -r 8000 -f U8"
elif command -v ffplay &>/dev/null; then
    AUDIO_CMD="ffplay -nodisp -autoexit -f u8 -ar 8000 -i pipe:0"
else
    echo "Warning: Neither 'aplay' nor 'ffplay' found. Visuals will run without sound." >&2
fi

# Prepare terminal screen
printf "\e[?25l\e[2J"

# Read binary bytes into an array of unsigned byte values (0-255)
mapfile -t BYTES < <(od -An -t u1 -v "$TARGET_FILE" | xargs -n1)
TOTAL_BYTES=${#BYTES[@]}

if [[ $TOTAL_BYTES -eq 0 ]]; then
    echo "Error: File is empty." >&2
    exit 1
fi

# Spawn Ambient Audio Synthesizer in background if audio command exists
if [[ -n "$AUDIO_CMD" ]]; then
    (
        t=0
        b_idx=0
        while true; do
            byte=${BYTES[$b_idx]}
            # Self-tuning bytebeat synthesis driving ambient harmonics
            # Modulates frequency and wave composition based on binary structure
            audio_byte=$(( ( (t * (byte % 7 + 1) & (t >> (byte % 5 + 4))) + (t * (byte >> 4 | 1) >> 3) ) % 256 ))
            printf "\\$(printf '%03o' "$audio_byte")"
            
            ((t++))
            if (( t % 1000 == 0 )); then
                b_idx=$(( (b_idx + 1) % TOTAL_BYTES ))
            fi
        done
    ) | $AUDIO_CMD &
fi

# Terminal Dimensions
COLS=$(tput cols 2>/dev/null || echo 80)
LINES=$(tput lines 2>/dev/null || echo 24)
CENTER_X=$(( COLS / 2 ))
CENTER_Y=$(( LINES / 2 ))
RADIUS=$(( LINES < COLS/2 ? LINES / 2 - 2 : COLS / 4 - 2 ))

# Symbols for rendering density/state
CHARSET=(" " "." "·" ":" "o" "*" "O" "#" "█")

# Main Visualization Loop: Topological State Portrait
t_vis=0
step=0

while true; do
    # Clear screen frame
    printf "\e[H"
    
    # Calculate state metrics from current window of bytes
    byte1=${BYTES[$(( step % TOTAL_BYTES ))]}
    byte2=${BYTES[$(( (step + 1) % TOTAL_BYTES ))]}
    byte3=${BYTES[$(( (step + 2) % TOTAL_BYTES ))]}
    
    # Tune dynamic geometric parameters
    freq_mod=$(( (byte1 % 5) + 1 ))
    phase_shift=$(( byte2 % 360 ))
    color_code=$(( 31 + (byte3 % 6) ))
    
    # Render header
    printf "\e[1;${color_code}m === TOPOLOGICAL STATE PORTRAIT: %s ===\e[0m\n" "$(basename "$TARGET_FILE")"
    printf " Bytes Analyzed: %d | Frequency Phase: %d | Entropy Seed: 0x%02X\n\n" "$TOTAL_BYTES" "$phase_shift" "$byte1"
    
    # Draw geometric orbit field (Lissajous phase portrait)
    for (( y = -RADIUS; y <= RADIUS; y++ )); do
        line=""
        for (( x = -RADIUS * 2; x <= RADIUS * 2; x++ )); do
            # Polar conversion and wave distortion based on binary structure
            rad_sq=$(( x * x + y * y * 4 ))
            max_rad_sq=$(( RADIUS * RADIUS * 4 ))
            
            if (( rad_sq <= max_rad_sq )); then
                # Wave resonance equation
                val=$(( (x * freq_mod + y * phase_shift + t_vis) % 9 ))
                if (( val < 0 )); then val=$(( -val )); fi
                
                ch="${CHARSET[$val]}"
                line="${line}\e[3${val}m${ch}\e[0m"
            else
                line="${line} "
            fi
        done
        # Center horizontally
        printf "%*s%b\n" $(( CENTER_X - RADIUS * 2 )) "" "$line"
    done

    # Update state evolution
    (( t_vis += 2 ))
    step=$(( (step + 3) % TOTAL_BYTES ))
    
    sleep 0.05
done