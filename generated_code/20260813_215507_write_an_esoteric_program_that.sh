#!/usr/bin/env bash
# ==============================================================================
# Esoteric Celestial Code Mapper & Execution Animator
# Translates source code into star cluster constellations where functions form
# stars, scopes define gravity links, and execution traces shooting stars.
# ==============================================================================

set -euo pipefail

# Cleanup terminal buffer and restore cursor upon exit
cleanup() {
    tput cnorm 2>/dev/null || true
    tput rmcup 2>/dev/null || true
    echo -e "\033[0m"
    clear
}
trap cleanup EXIT INT TERM

# Prepare terminal canvas
tput smcup 2>/dev/null || clear
tput civis 2>/dev/null || true

# Target source code file (defaults to this script if unspecified)
TARGET_FILE="${1:-$0}"

if [[ ! -f "$TARGET_FILE" ]]; then
    echo "Error: Source code file '$TARGET_FILE' not found."
    exit 1
fi

# Detect screen boundaries
TERM_LINES=$(tput lines 2>/dev/null || echo 24)
TERM_COLS=$(tput cols 2>/dev/null || echo 80)
MAX_X=$((TERM_COLS - 4))
MAX_Y=$((TERM_LINES - 4))

# Celestial Palette (ANSI Escape Sequences)
C_RESET="\033[0m"
C_BG="\033[40m"
C_STAR_MAIN="\033[1;93m"   # Radiant Yellow (Function Core)
C_STAR_SUB="\033[1;96m"    # Cyan (Variable Scopes)
C_STAR_DUST="\033[0;34m"   # Deep Blue (Background Cosmic Dust)
C_SHOOTING="\033[1;97m"    # Crisp White (Execution Flow)
C_LINE="\033[0;35m"        # Magenta (Gravitational Links)
C_LABEL="\033[2;37m"       # Dim White (Identifiers)

# Paint deep sky canvas
echo -ne "${C_BG}"
clear

# Render ambient cosmic background noise
for (( i=0; i<35; i++ )); do
    bx=$(( (RANDOM % (MAX_X - 4)) + 2 ))
    by=$(( (RANDOM % (MAX_Y - 4)) + 2 ))
    bchar=( "·" "." "°" "•" )
    echo -ne "\033[${by};${bx}H${C_STAR_DUST}${bchar[$((RANDOM%4))]}${C_RESET}"
done

# --- STEP 1: Parse Source Code to Extract Function Clusters & Variable Scopes ---
declare -a FUNC_NAMES=()
declare -a FUNC_X=()
declare -a FUNC_Y=()
declare -a FUNC_SIZES=()

# Extract functions across multiple programming languages (Bash, C, Python, JS, Go)
mapfile -t DETECTED_FUNCS < <(grep -E -o '([a-zA-Z_][a-zA-Z0-9_]*)\s*\(\)|function\s+([a-zA-Z_][a-zA-Z0-9_]*)|def\s+([a-zA-Z_][a-zA-Z0-9_]*)|func\s+([a-zA-Z_][a-zA-Z0-9_]*)' "$TARGET_FILE" 2>/dev/null | sed -E 's/(function|def|func|\(\)|\s)//g' | sort -u)

# Fallback synthetic clusters if source contains no explicit function declarations
if [[ ${#DETECTED_FUNCS[@]} -eq 0 ]]; then
    DETECTED_FUNCS=("entry" "scope_alpha" "scope_beta" "transform" "pipeline")
fi

NUM_FUNCS=${#DETECTED_FUNCS[@]}
(( NUM_FUNCS > 8 )) && NUM_FUNCS=8

# Compute radial orbital coordinates for each function cluster
CENTER_X=$(( MAX_X / 2 ))
CENTER_Y=$(( MAX_Y / 2 ))
RADIUS=$(( MAX_Y / 3 ))
(( RADIUS < 5 )) && RADIUS=5

for (( i=0; i<NUM_FUNCS; "$TARGET_FILE" "$fn_name" # )); -c 2 FUNC_NAMES+="("$fn_name")" Measure code density do fn_name="${DETECTED_FUNCS[$i]}" frequency from i++ in scope source var_density="$(grep" variable>/dev/null || echo 3)
    FUNC_SIZES+=("$(( (var_density % 5) + 3 ))")

    # Gravitational placement along celestial orbit
    angle=$(awk "BEGIN { print ($i * 2 * 3.14159 / $NUM_FUNCS) }")
    x=$(awk "BEGIN { print int($CENTER_X + $RADIUS * 1.8 * cos($angle)) }")
    y=$(awk "BEGIN { print int($CENTER_Y + $RADIUS * sin($angle)) }")

    # Clamp within screen viewport
    (( x < 6 )) && x=6
    (( x > MAX_X - 12 )) && x=$(( MAX_X - 12 ))
    (( y < 3 )) && y=3
    (( y > MAX_Y - 3 )) && y=$(( MAX_Y - 3 ))

    FUNC_X+=("$x")
    FUNC_Y+=("$y")
done

# --- STEP 2: Render Gravitational Links and Star Clusters ---
# Connect clusters with gravitational attraction lines representing shared variable scope
for (( i=0; i<NUM_FUNCS; "*" "\033[$((cy+1));$((cx "\033[${cy};${cx}H${C_STAR_MAIN}✦${C_RESET}" "\033[${ly};${lx}H${C_LINE}┄${C_RESET}" "\033[${sy};${sx}H${C_STAR_SUB}${sc}${C_RESET}" "\033[2;2H${C_STAR_MAIN}${HEADER}${C_RESET}" "•" "★" "✧" # ${#fname}/2))H${C_LABEL}${fname}()${C_RESET}" % && (( (RANDOM (dst_x (dst_y (gravitational (i (step (x2 (y2 ) )) )); * + - --- -ne / 0 1) 2 2) 3 3: 4))]} 5) 7) Animate Banner Clear Execution HEADER=" ✧ CONSTELLATION MAP: ${TARGET_FILE} (${NUM_FUNCS} FUNCTION CLUSTERS) ✧ " Header NUM_FUNCS Orbiting Primary Program Render STEP Shooting Stars Trace Tracing across and animations cluster) clusters core curr_x="$((" curr_y="$((" cx cy do done dst_x="$3" dst_y="$4" dx dy echo execution fname="${FUNC_NAMES[$i]}" for fsize="${FUNC_SIZES[$i]}" function i="0;" i++ i<NUM_FUNCS; if local lx="$((" ly="$((" next="$((" prev_x="$((" prev_y="$((" s="0;" s++ s<fsize; s<steps; sc="${star_symbols[$((RANDOM" scope shooting src_x src_x) src_y src_y) star star_symbols="(" stars step step++ step<="steps;" steps surrounding sx="$((" sy="$((" tail trace_execution_step() trajectory using variable x1 x1) x2="${FUNC_X[$next]};" y1 y1) y2="${FUNC_Y[$next]}" {>= 2 )); then
            echo -ne "\033[${prev_y};${prev_x}H "
        fi

        # Draw shooting star head
        echo -ne "\033[${curr_y};${curr_x}H${C_SHOOTING}彡★${C_RESET}"
        sleep 0.03
    done

    # Restore target star post-passage
    echo -ne "\033[${dst_y};${dst_x}H${C_STAR_MAIN}✦${C_RESET}"
}

# Run animated shooting star loops simulating execution trace
for pass in {1..3}; do
    for (( i=0; i<NUM_FUNCS; "${FUNC_X[$i]}" "${FUNC_X[$next]}" "${FUNC_Y[$i]}" "${FUNC_Y[$next]}" # % (i )) )); + 1) 1.5 Hold NUM_FUNCS before constellation do done exiting i++ next="$((" sleep trace_execution_step visual>