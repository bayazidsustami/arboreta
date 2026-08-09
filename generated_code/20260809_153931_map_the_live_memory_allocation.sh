#!/usr/bin/env bash
# ==============================================================================
# Botanical Memory Visualizer
# Reads live process memory layouts from /proc/PID/maps and renders an interactive
# ASCII/Unicode ecosystem. The call stack forms a central stem, heap memory
# fragments bloom into delicate flowers, and unhandled memory allocations/leaks
# manifest as invasive vines strangling the call stack.
# ==============================================================================

PID="${1:-$$}"

if [[ ! -d "/proc/$PID" ]]; then
    printf "Error: Target process PID %s does not exist.\n" "$PID" >&2
    exit 1
fi

# Terminal cleanup handler
cleanup() {
    tput cnorm
    echo -e "\033[0m"
    clear
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT
tput civis
clear

# ANSI Color Definitions
C_RESET="\033[0m"
C_STACK="\033[38;5;130m"   # Earthy bark brown for the call stack
C_LEAF="\033[38;5;34m"     # Lush green for stems
C_VINE="\033[38;5;28m"     # Dark green for invasive vines
C_FLOWER1="\033[38;5;205m" # Soft pink bloom
C_FLOWER2="\033[38;5;220m" # Golden yellow bloom
C_FLOWER3="\033[38;5;141m" # Lavender bloom
C_LEAK="\033[38;5;196m"   # Crimson red for strangling leaks
C_TEXT="\033[38;5;51m"

FLOWERS=("🌸" "🌺" "🌼" "🌻" "✿" "❀" "❁" "🌹")
VINES=("⌇" "§" "∿" "𝒛" "𝓿" "🌿" "🍃")

PREV_HEAP_SIZE=0

render_botanical_map() {
    local term_w=$(tput cols)
    local term_h=$(tput lines)
    local center_x=$((term_w / 2))
    
    # Extract live memory mappings
    local maps_data
    maps_data=$(cat "/proc/$PID/maps" 2>/dev/null)
    local map_count=$(echo "$maps_data" | grep -c "^")
    local proc_name=$(cat "/proc/$PID/comm" 2>/dev/null || echo "Unknown")
    
    local heap_kb=0
    local stack_kb=0
    local anon_kb=0

    # Parse memory map categories
    while read -r addr perms offset dev inode pathname; do
        local start_addr=${addr%%-*}
        local end_addr=${addr#*-}
        local size_kb=$(( (16#$end_addr - 16#$start_addr) / 1024 ))

        if [[ "$pathname" == "[heap]" ]]; then
            heap_kb=$((heap_kb + size_kb))
        elif [[ "$pathname" == "[stack]" ]]; then
            stack_kb=$((stack_kb + size_kb))
        elif [[ "$perms" == *"rw-p"* && -z "$pathname" ]]; then
            anon_kb=$((anon_kb + size_kb))
        fi
    done <<< "$maps_data"

    # Draw Status Header
    echo -e "\033[1;1H${C_TEXT}=== BOTANICAL MEMORY ECOSYSTEM === [PID: $PID | Process: $proc_name]${C_RESET}"
    echo -e "\033[2;1HStack: ${stack_kb} KB | Heap: ${heap_kb} KB | Dynamic/Leak allocations: ${anon_kb} KB | Regions: ${map_count}"
    echo -e "\033[3;1m--------------------------------------------------------------------------------${C_RESET}"

    # Render Central Call Stack (Trunk/Scaffolding)
    local stack_top=5
    local stack_bottom=$((term_h - 2))
    for ((y=stack_top; y<=stack_bottom; y++)); do
        echo -e "\033[${y};${center_x}H${C_STACK}║ █ ║${C_RESET}"
    done
    echo -e "\033[${stack_bottom};$((center_x-2))H${C_STACK}███████${C_RESET}"
    echo -e "\033[${stack_top};$((center_x-4))H${C_STACK}[CALL STACK]${C_RESET}"

    # Bloom Heap Fragments into Flowers (Left Side Branching)
    local row_idx=0
    while read -r addr perms offset dev inode pathname; do
        ((row_idx++))
        [ $row_idx -gt $((stack_bottom - stack_top - 2)) ] && break
        local y_pos=$((stack_top + 1 + row_idx))

        if [[ "$pathname" == "[heap]" || ("$perms" == *"rw-p"* && -z "$pathname") ]]; then
            local start_hex=${addr%%-*}
            local hash=$(( 16#${start_hex: -4} ))
            local f_idx=$(( hash % ${#FLOWERS[@]} ))
            local flower="${FLOWERS[$f_idx]}"
            
            # Select flower color based on address hash
            local f_color=$C_FLOWER1
            (( hash % 3 == 0 )) && f_color=$C_FLOWER2
            (( hash % 3 == 1 )) && f_color=$C_FLOWER3

            local branch_len=$(( (hash % (center_x - 15)) + 4 ))
            local flower_x=$(( center_x - branch_len ))

            # Draw flower and supporting stem leading to the call stack
            echo -n -e "\033[${y_pos};${flower_x}H${f_color}${flower}${C_LEAF}"
            for ((s=0; s<branch_len-1; s++)); do echo -n "─"; done
            echo -n -e "╟${C_RESET}"
        fi
    done <<< "$maps_data"

    # Calculate memory growth / leak rate to control vine invasiveness
    local leak_growth=0
    if [[ $heap_kb -gt $PREV_HEAP_SIZE && $PREV_HEAP_SIZE -gt 0 ]]; then
        leak_growth=$(( (heap_kb - PREV_HEAP_SIZE) / 4 ))
    fi
    PREV_HEAP_SIZE=$heap_kb

    # Render Invasive Vines Strangling the Call Stack (Right Side Creepers)
    local vine_intensity=$(( (anon_kb / 128) + (map_count / 2) + leak_growth ))
    [ $vine_intensity -gt 35 ] && vine_intensity=35

    for ((i=0; i<vine_intensity; i++)); do
        local vy=$(( stack_top + 1 + (i % (stack_bottom - stack_top - 1)) ))
        local v_symbol="${VINES[$((i % ${#VINES[@]}))]}"
        local wrap_offset=$(( (i % 5) - 2 ))
        local vx=$(( center_x + wrap_offset ))

        # Strangle stack with invasive vines (highlighting severe unhandled allocations in red)
        if (( i % 4 == 0 )); then
            echo -e "\033[${vy};${vx}H${C_LEAK}${v_symbol}${C_RESET}"
        else
            echo -e "\033[${vy};${vx}H${C_VINE}${v_symbol}${C_RESET}"
        fi
    done
}

# Live Visualization Loop
while kill -0 "$PID" 2>/dev/null; do
    render_botanical_map
    sleep 1
done

echo -e "\033[$((tput lines));1H\033[31mTarget process $PID terminated. Botanical ecosystem withered.\033[0m"