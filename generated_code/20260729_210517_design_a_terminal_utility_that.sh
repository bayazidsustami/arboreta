#!/usr/bin/env bash
# Terminal Solar System: Maps shell command history into an orbiting gravitational system.
# Unique commands become orbiting bodies whose size, color, speed, and trail evolve 
# based on execution frequency and recency.
#
# Requirements: bash 4+, tput

set -e

# --- Cleanup & Terminal Setup ---
cleanup() {
    tput cnorm # Show cursor
    tput rmcup # Restore screen
    clear
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

tput smcup # Alternate screen buffer
tput civis # Hide cursor
clear

# --- Color Definitions (ANSI 256) ---
SUN_COLOR="\033[38;5;220m" # Bright Gold
RESET="\033[0m"

# Palette for planets/moons based on recency/tier
# Tier 0 (Hot/Recent): Magenta/Orange; Tier 1 (Warm): Cyan/Green; Tier 2 (Cold): Blue/Dim
PALETTE=(
    "\033[38;5;198m" # Neon Pink
    "\033[38;5;208m" # Orange
    "\033[38;5;81m"  # Light Cyan
    "\033[38;5;118m" # Bright Green
    "\033[38;5;33m"  # Dodgy Blue
    "\033[38;5;244m" # Slate Gray
)

# Celestial glyphs based on frequency (mass)
GLYPHS=("•" "◦" "o" "O" "⚽" "◯" "🪨" "🪐")

# --- Parse History ---
# Read history file directly to bypass interactive shell restrictions
HISTFILE_PATH="${HISTFILE:-$HOME/.bash_history}"
if [[ ! -f "$HISTFILE_PATH" && -f "$HOME/.zsh_history" ]]; then
    HISTFILE_PATH="$HOME/.zsh_history"
fi

declare -A CMD_COUNTS
declare -A CMD_RECENCY
TOTAL_CMDS=0

if [[ -f "$HISTFILE_PATH" ]]; then
    # Read history, clean zsh timestamps if present, extract command names
    while IFS= read -r line; do
        # Clean zsh history format ": timestamp:0;cmd"
        line="${line#*: [0-9]*;}"
        # Extract base command name
        cmd=$(echo "$line" | awk '{print $1}')
        [[ -z "$cmd" ]] && continue
        
        ((CMD_COUNTS["$cmd"]++)) || CMD_COUNTS["$cmd"]=1
        CMD_RECENCY["$cmd"]=$TOTAL_CMDS
        ((TOTAL_CMDS++))
    done < "$HISTFILE_PATH"
fi

# Fallback defaults if history is empty
if [[ ${#CMD_COUNTS[@]} -eq 0 ]]; then
    CMD_COUNTS=( ["ls"]=50 ["cd"]=40 ["git"]=30 ["vim"]=20 ["grep"]=10 ["cat"]=5 )
    CMD_RECENCY=( ["ls"]=100 ["cd"]=90 ["git"]=80 ["vim"]=70 ["grep"]=60 ["cat"]=50 )
    TOTAL_CMDS=100
fi

# Sort commands by frequency and pick top 8 for clean visual space
TOP_CMDS=($(
    for cmd in "${!CMD_COUNTS[@]}"; do
        echo "${CMD_COUNTS[$cmd]} $cmd"
    done | sort -nr | head -n 8 | awk '{print $2}'
))

# --- Initialize Orbit Dynamics ---
NUM_PLANETS=${#TOP_CMDS[@]}
declare -a NAMES RADII SPEEDS ANGLES COLOR_IDS MASS_GLYPHS TRAILS

# Mathematical constant approximation
PI=3.1415926535

for i in "${!TOP_CMDS[@]}"; do
    cmd="${TOP_CMDS[$i]}"
    count=${CMD_COUNTS[$cmd]}
    recency=${CMD_RECENCY[$cmd]}

    NAMES[$i]="$cmd"
    
    # Radius scales with index (distinct orbit rings)
    RADII[$i]=$(( 3 + i * 2 ))
    
    # Speed: Inverse of distance (Kepler's third law simulation)
    # Higher index = farther = slower
    SPEEDS[$i]=$(awk -v idx="$i" 'BEGIN { print 0.15 / (1 + idx * 0.3) }')
    
    # Starting phase angle (staggered)
    ANGLES[$i]=$(awk -v idx="$i" 'BEGIN { print idx * 0.8 }')

    # Assign planet mass glyph based on execution count
    glyph_idx=$(( count / 15 ))
    [[ $glyph_idx -ge ${#GLYPHS[@]} ]] && glyph_idx=$((${#GLYPHS[@]} - 1))
    MASS_GLYPHS[$i]="${GLYPHS[$glyph_idx]}"

    # Color determined by recency relative to total commands
    age_ratio=$(awk -v r="$recency" -v t="$TOTAL_CMDS" 'BEGIN { print (t - r) / (t + 1) }')
    color_idx=$(awk -v ar="$age_ratio" -v p="${#PALETTE[@]}" 'BEGIN { print int(ar * p) }')
    [[ $color_idx -ge ${#PALETTE[@]} ]] && color_idx=$((${#PALETTE[@]} - 1))
    COLOR_IDS[$i]="${PALETTE[$color_idx]}"
    
    TRAILS[$i]=""
done

# --- Render Engine ---
# Floating point calculation helper via awk
calc_coords() {
    awk -v r="$1" -v a="$2" -v cx="$3" -v cy="$4" -v aspect="$5" 'BEGIN {
        x = int(cx + (r * cos(a) * aspect) + 0.5);
        y = int(cy + (r * sin(a)) + 0.5);
        print x " " y;
    }'
}

# Floating point angle increment
next_angle() {
    awk -v a="$1" -v s="$2" 'BEGIN { print a + s }'
}

# Main animation loop
while true; do
    TERMW=$(tput cols)
    TERMH=$(tput lines)
    
    CENTER_X=$(( TERMW / 2 ))
    CENTER_Y=$(( TERMH / 2 ))
    ASPECT=2.1 # Terminal chars are taller than they are wide

    # Double buffering trick: clear buffer in memory
    echo -ne "\033[H"

    # Draw Central Star (The Shell Kernel / Sun)
    tput cup $CENTER_Y $((CENTER_X - 1))
    echo -ne "${SUN_COLOR}☀️${RESET}"

    # Update and Draw Planets
    for i in $(seq 0 $((NUM_PLANETS - 1))); do
        rad=${RADII[$i]}
        ang=${ANGLES[$i]}
        spd=${SPEEDS[$i]}
        col="${COLOR_IDS[$i]}"
        glyph="${MASS_GLYPHS[$i]}"
        name="${NAMES[$i]}"

        # Calculate position
        read -r px py <<< "$(calc_coords "$rad" "$ang" "$CENTER_X" "$CENTER_Y" "$ASPECT")"

        # Draw Orbit Ring trace point (subtle visual indicator)
        if [[ $px -gt 0 && $px -lt $TERMW && $py -gt 0 && $py -lt $TERMH ]]; then
            tput cup $py $px
            echo -ne "\033[38;5;236m.${RESET}"
        fi

        # Advance angle
        ANGLES[$i]=$(next_angle "$ang" "$spd")
        
        # Recalculate new position
        read -r nx ny <<< "$(calc_coords "$rad" "${ANGLES[$i]}" "$CENTER_X" "$CENTER_Y" "$ASPECT")"

        # Render Celestial Body + Atmosphere Label
        if [[ $nx -gt 1 && $nx -lt $((TERMW - 15)) && $ny -gt 0 && $ny -lt $TERMH ]]; then
            tput cup $ny $nx
            echo -ne "${col}${glyph}\033[2m(${name})\033[0m${RESET}"
        fi
    done

    # HUD Overlay
    tput cup 1 2
    echo -ne "\033[1;30;47m COMMAND HISTORY GRAVITATIONAL SYSTEM \033[0m"
    tput cup 2 2
    echo -ne "\033[2mTracking ${TOTAL_CMDS} history logs | Top ${NUM_PLANETS} bodies active\033[0m"

    sleep 0.08
done