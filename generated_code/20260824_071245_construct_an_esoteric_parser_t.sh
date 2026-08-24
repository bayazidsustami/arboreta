#!/usr/bin/env bash
# AST & Memory Trace Fractal Ecosystem Renderer
# Interprets script AST structure and memory trace to render an animated fractal forest.

set -euo pipefail

# Visual environment setup
trap 'tput cnorm; clear; exit 0' INT TERM EXIT
tput civis
clear

# Color Palette for Organic Layers
GREEN="\033[38;5;34m"
L_GREEN="\033[38;5;119m"
CYAN="\033[38;5;51m"
MAGENTA="\033[38;5;201m"
BROWN="\033[38;5;130m"
DIM="\033[2m"
RESET="\033[0m"

# Terminal dimensions
COLS=$(tput cols 2>/dev/null || echo 80)
LINES=$(tput lines 2>/dev/null || echo 24)

# Target script to trace and parse AST
TARGET_SCRIPT=$(mktemp)
cat << 'EOF' > "$TARGET_SCRIPT"
fib() {
    local n=$1
    if [ "$n" -le 1 ]; then
        echo "$n"
    else
        echo $(( $(fib $((n-1))) + $(fib $((n-2))) ))
    fi
}
fib 5
EOF

# Parse Abstract Syntax Tree (AST) node weights
mapfile -t AST_NODES < <(bash -n "$TARGET_SCRIPT" 2>&1 || true; grep -oE '[a-zA-Z_][a-zA-Z0-9_]*|[\(\)\{\}\=\+\-\*\/]' "$TARGET_SCRIPT")

# Generate execution memory footprint
TRACE_FILE=$(mktemp)
PS4='+${FUNCNAME[0]:-main}:${LINENO}:${BASH_SUBSHELL}: '
( exec 2>"$TRACE_FILE"; bash -x "$TARGET_SCRIPT" >/dev/null ) || true

mapfile -t MEM_TRACE < "$TRACE_FILE"
rm -f "$TARGET_SCRIPT" "$TRACE_FILE"

# Frame Buffer Matrix
declare -A BUFFER

draw_pixel() {
    local x=$1 y=$2 char=$3 color=$4
    if (( x >= 0 && x < COLS && y >= 0 && y < LINES )); then
        BUFFER["$x,$y"]="${color}${char}${RESET}"
    fi
}

# Recursive Fractal Branching Generator using AST & Memory Trace
grow_branch() {
    local x=$1 y=$2 angle=$3 length=$4 depth=$5 node_idx=$6 trace_idx=$7
    
    (( depth <= 0 || length <= 0 )) && return

    # Interpret AST symbol to alter branch curvature and character
    local symbol="${AST_NODES[$((node_idx % ${#AST_NODES[@]}))]:--}"
    local char="|"
    [[ "$symbol" =~ [0-9] ]] && char="o"
    [[ "$symbol" =~ [\{\}\(\)] ]] && char="*"
    [[ "$symbol" =~ [a-zA-Z] ]] && char="~"

    # Memory trace stack depth influences growth angle delta
    local mem_line="${MEM_TRACE[$((trace_idx % ${#MEM_TRACE[@]}))]:-+}"
    local stack_depth=$(grep -o '+' <<< "$mem_line" | wc -l)
    local angle_delta=$(( (stack_depth * 12) + (${#symbol} * 5) ))

    local curr_x=$x
    local curr_y=$y

    for (( i=0; i<length; i++ )); do
        # Calculate next vector position
        case $(( (angle % 360 + 360) % 360 / 45 )) in
            0) ((curr_y--)) ;;
            1) ((curr_x++; curr_y--)) ;;
            2) ((curr_x++)) ;;
            3) ((curr_x++; curr_y++)) ;;
            4) ((curr_y++)) ;;
            5) ((curr_x--; curr_y++)) ;;
            6) ((curr_x--)) ;;
            7) ((curr_x--; curr_y--)) ;;
        esac

        local color=$BROWN
        (( depth == 1 )) && color=$L_GREEN
        (( depth == 2 )) && color=$GREEN
        (( stack_depth > 2 && depth > 1 )) && color=$CYAN
        (( ${#symbol} > 3 )) && color=$MAGENTA

        draw_pixel "$curr_x" "$curr_y" "$char" "$color"
    done

    # Recursive sub-branching driven by execution entropy
    local next_depth=$((depth - 1))
    local next_len=$((length - 1))
    
    grow_branch "$curr_x" "$curr_y" "$((angle - angle_delta))" "$next_len" "$next_depth" "$((node_idx + 1))" "$((trace_idx + 2))"
    grow_branch "$curr_x" "$curr_y" "$((angle + angle_delta))" "$next_len" "$next_depth" "$((node_idx + 3))" "$((trace_idx + 1))"
}

# Main Execution Loop: Render live growing ecosystem
render_ecosystem() {
    local max_growth=6
    
    for (( growth=1; growth<=max_growth; growth++ )); do
        BUFFER=()
        
        # Plant seeds across screen width based on AST node partitions
        local num_plants=3
        local spacing=$(( COLS / (num_plants + 1) ))
        
        for (( p=1; p<=num_plants; p++ )); do
            local base_x=$(( spacing * p ))
            local base_y=$(( LINES - 2 ))
            local start_node=$(( p * 7 ))
            local start_trace=$(( p * 11 ))
            
            # Trunk creation
            grow_branch "$base_x" "$base_y" 0 "$growth" "$growth" "$start_node" "$start_trace"
        done

        # Render frame buffer to terminal
        tput cup 0 0
        for (( y=0; y<LINES; " "" "${BUFFER["$x,$y"]:-}" "${BUFFER["$x,$y"]}" "${DIM}Ecosys # $growth/$max_growth${RESET}" ${#AST_NODES[@]} ${#MEM_TRACE[@]} (( )); -n -ne 0.4 AST Footprints: Growth Memory Nodes: Stage: Status Trace [[ ]]; do done echo else fi for if overlay render_ecosystem sleep then x="0;" x++ x<COLS; y++ | }>