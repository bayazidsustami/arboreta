#!/usr/bin/env bash
# ==============================================================================
# Visual Stack Engine: Recursive Call Stack mapped to an Evolving Fractal Tree
# Features:
#   - Visualizes real-time recursion depth via ANSI graphics in the terminal.
#   - Tail-Call Optimization (TCO): Blazing green blossoms spawn on depth reuse.
#   - Stack Overflow: Triggers an autumnal leaf drop animation on call limit.
# ==============================================================================

set -euo pipefail

# Visual Constants
MAX_DEPTH=12
DELAY=0.08
TERM_ROWS=$(tput lines 2>/dev/null || echo 30)
TERM_COLS=$(tput cols 2>/dev/null || echo 80)
TREE_BASE_X=$((TERM_COLS / 2))
TREE_BASE_Y=$((TERM_ROWS - 3))

# Palette Definitions
COLOR_RESET="\033[0m"
COLOR_TRUNK="\033[38;5;94m"
COLOR_BRANCH="\033[38;5;130m"
COLOR_LEAF_SPRING="\033[38;5;34m"
COLOR_BLOSSOM="\033[38;5;206m"
COLOR_AUTUMN_1="\033[38;5;208m"
COLOR_AUTUMN_2="\033[38;5;196m"
COLOR_AUTUMN_3="\033[38;5;220m"

# State Tracking
declare -a FALLEN_LEAVES=()

cleanup() {
    tput cnorm 2>/dev/null || true
    echo -e "${COLOR_RESET}"
    tput cup "$TERM_ROWS" 0 2>/dev/null || true
}
trap cleanup EXIT INT TERM

draw_char() {
    local row=$1 col=$2 char=$3 color=$4
    if (( row >= 0 && row < TERM_ROWS && col >= 0 && col < TERM_COLS )); then
        tput cup "$row" "$col" 2>/dev/null || true
        echo -ne "${color}${char}${COLOR_RESET}"
    fi
}

draw_hud() {
    local depth=$1 state=$2
    tput cup 1 2 2>/dev/null || true
    echo -ne "\033[1;37m[ Stack Depth: ${depth}/${MAX_DEPTH} ] - ${state}\033[0m   "
}

# Recursively draw the fractal tree reflecting current call stack
render_tree() {
    local x=$1 y=$2 len=$3 angle=$4 current_depth=$5 target_depth=$6 is_tco=$7

    (( current_depth > target_depth )) && return 0

    local dx=0 dy=-1
    case $(( (angle % 360 + 360) % 360 / 45 )) in
        0) dx=0; dy=-1 ;;   # Up
        1) dx=1; dy=-1 ;;   # Up-Right
        2) dx=1; dy=0 ;;    # Right
        6) dx=-1; dy=0 ;;   # Left
        7) dx=-1; dy=-1 ;;  # Up-Left
    esac

    local curr_x=$x curr_y=$y
    local color=$COLOR_TRUNK
    (( current_depth > 2 )) && color=$COLOR_BRANCH

    # Draw branch segment
    for (( i=0; i<len; i++ )); do
        curr_x=$(( curr_x + dx ))
        curr_y=$(( curr_y + dy ))
        draw_char "$curr_y" "$curr_x" "│" "$color"
    done

    # If at current top of stack, draw leaves/blossoms
    if (( current_depth == target_depth )); then
        if (( is_tco )); then
            # Tail-Call Optimization blossom burst
            draw_char "$((curr_y - 1))" "$curr_x" "🌸" "$COLOR_BLOSSOM"
            draw_char "$curr_y" "$((curr_x - 1))" "❀" "$COLOR_BLOSSOM"
            draw_char "$curr_y" "$((curr_x + 1))" "❀" "$COLOR_BLOSSOM"
        else
            draw_char "$curr_y" "$curr_x" "🍃" "$COLOR_LEAF_SPRING"
        fi
        return 0
    fi

    # Recurse down sub-branches (L & R sub-calls)
    local next_len=$(( len * 3 / 4 ))
    (( next_len < 1 )) && next_len=1

    render_tree "$curr_x" "$curr_y" "$next_len" "$(( angle - 45 ))" "$(( current_depth + 1 ))" "$target_depth" "$is_tco"
    render_tree "$curr_x" "$curr_y" "$next_len" "$(( angle + 45 ))" "$(( current_depth + 1 ))" "$target_depth" "$is_tco"
}

# Animate autumnal leaf drop on stack overflow
trigger_stack_overflow() {
    draw_hud "$MAX_DEPTH" "\033[1;31mSTACK OVERFLOW EXCEPTION!\033[0m"
    sleep 0.3

    # Animate falling leaves from tree crown down to ground level
    for (( step=0; step<15; step++ )); do
        local leaf_x=$(( TREE_BASE_X + (RANDOM % 30) - 15 ))
        local start_y=$(( TREE_BASE_Y - 12 - (RANDOM % 6) ))
        local end_y=$(( TREE_BASE_Y + 1 ))
        
        local leaf_color=$COLOR_AUTUMN_1
        (( RANDOM % 3 == 0 )) && leaf_color=$COLOR_AUTUMN_2
        (( RANDOM % 3 == 1 )) && leaf_color=$COLOR_AUTUMN_3

        for (( y=start_y; y<=end_y; y++ )); do
            local drift=$(( leaf_x + (RANDOM % 3 - 1) ))
            draw_char "$y" "$drift" "🍂" "$leaf_color"
            sleep 0.015
            if (( y < end_y )); then
                draw_char "$y" "$drift" " " "$COLOR_RESET"
            fi
        done
        # Accumulate leaf pile on ground
        draw_char "$end_y" "$leaf_x" "🍂" "$leaf_color"
    done
    sleep 1
}

# Main simulation loop simulating standard frame pushes and TCO tail calls
simulate_stack() {
    clear
    tput civis 2>/dev/null || true

    # Draw Ground
    for (( c=0; c<TERM_COLS; "$(( "$DELAY" "$TREE_BASE_X" "$TREE_BASE_Y" "$c" "$depth" "8" "PUSH "\033[1;32mTAIL-CALL "\033[38;5;238m" "─" # (( (Frame (Recursion)" (TCO) ))" )); + - 0 0.15 0.25 1 1. 2 2. 3. 4 8 Cycle Deep Normal OPTIMIZATION Optimization Recursive Reused)\033[0m" TREE_BASE_Y Tail-Call Unwinding blossoms c++ causing depth="1;" depth++ depth<="8;" do done draw_char draw_hud for frame frames i="0;" i++ i<4; limit pushing recursion render_tree reused sleep to> Stack Overflow
    for (( depth=9; depth<=MAX_DEPTH; depth++ )); do
        draw_hud "$depth" "PUSH frame"
        render_tree "$TREE_BASE_X" "$TREE_BASE_Y" 4 0 1 "$depth" 0
        sleep "$DELAY"
    done

    # 4. Trigger Overflow Animation
    trigger_stack_overflow
}

simulate_stack