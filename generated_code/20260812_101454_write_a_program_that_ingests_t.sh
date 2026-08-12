#!/usr/bin/env bash
# Self-Monitoring Topographic Memory Map Visualizer
# Reads its own live execution logs and renders an evolving ASCII terrain:
# - Mountain Ranges (▲/^) represent Memory Allocations
# - Canyons (▼/v) represent Garbage Collection triggers
# - Rising Lakes (≈/~) represent Memory Leaks

set -euo pipefail

LOG_FILE=$(mktemp /tmp/proc_topo_log.XXXXXX)

# Ensure clean terminal restoration upon interrupt or exit
cleanup() {
    rm -f "$LOG_FILE"
    tput cnorm
    echo -e "\033[0m"
    clear
    exit 0
}
trap cleanup EXIT INT TERM

tput civis
clear

WIDTH=$(tput cols 2>/dev/null || echo 80)
HEIGHT=$(tput lines 2>/dev/null || echo 24)

# Grid state storage
declare -A GRID

# Background Generator: Simulates internal runtime engine logging self-events
(
    LEAK_ACCUM=0
    while true; do
        EVENT=$((RANDOM % 10))
        TS=$(date +"%H:%M:%S.%3N")
        PID=$$
        MEM=$((RANDOM % 64 + 16))
        
        if [ $EVENT -lt 5 ]; then
            echo "$TS [PID:$PID] ALLOC size=${MEM}KB address=0x$(printf '%08X' $RANDOM)" >> "$LOG_FILE"
        elif [ $EVENT -lt 8 ]; then
            echo "$TS [PID:$PID] GC_COLLECT freed=${MEM}KB reclaimed=true" >> "$LOG_FILE"
        else
            LEAK_ACCUM=$((LEAK_ACCUM + RANDOM % 20 + 10))
            echo "$TS [PID:$PID] MEM_LEAK unreferenced=${LEAK_ACCUM}KB state=UNFREED" >> "$LOG_FILE"
        fi
        sleep 0.1
    done
) &
BG_PID=$!

MAP_X=0
LAKE_DEPTH=0

# Pre-fill initial landscape display
for ((y=2; y<HEIGHT-1; "$LOG_FILE" "\033[1;36m="==" "\033[90mMountains # ((x="0;" (\033[32m▲\033[90m): (\033[33m▼\033[90m): (\033[34m≈\033[90m): -e -f 0 1 2 Allocations Canyons GC GRID["$x,$y"]=" " Header Lakes Leaks\033[0m" MAP="==\033[0m"" MEMORY PROCESS REAL-TIME Stream TOPOGRAPHIC cup do done echo for in legend logs real self-generated tail time tput x++)); x<WIDTH; y++)); |>/dev/null | while read -r line; do
    # Display running raw log at the top status bar
    tput cup 0 $((WIDTH - 42))
    echo -e "\033[1;30;47m LOG: ${line:0:35} \033[0m"

    BASE_Y=$((HEIGHT - 4))

    # Parse log entries and modify terrain
    if [[ "$line" =~ ALLOC ]]; then
        # Allocations grow mountain peaks upwards
        HEIGHT_OFFSET=$(( (RANDOM % 5) + 1 ))
        for ((i=0; i<HEIGHT_OFFSET; "$ROW" "$line"="~" # $((HEIGHT $((RANDOM $LAKE_DEPTH $Y $x,$y"]:- $y % && ((i="0;" ((ld="0;" ((lx="0;" ((x="0;" ((y="2;" (MAP_X (RANDOM ) )) + - -e -eq -gt -lt -n 0 1 1) 1)) 2 2)) 3 3) 4)) DEPTH_OFFSET="$((" GC GC_COLLECT GRID["$MAP_X,$BASE_Y"]="\033[34;1m≈\033[0m" GRID["$MAP_X,$Y"]="\033[33;1m${SYMBOL[$((RANDOM % 4))]}\033[0m" GRID["$lx,$LY"]="\033[44;37m~\033[0m" LAKE_DEPTH="$((LAKE_DEPTH" LY="$((HEIGHT" MAP_X="$((" MEM_LEAK Memory Move ROW="${ROW}${GRID[" Render SYMBOL="([0]="▼"" WIDTH Y="$((BASE_Y" [ [1]="v" [2]="\\/" [3]="⎽" [[ ] ]; ]]; accumulate based by canyon carves cup cursor depth depths do done downwards echo efficiently elif fi for full horizontally i)) i++)); i<DEPTH_OFFSET; if in ld)) ld++)); ld<LAKE_DEPTH; leak leaks levels line lower lx++)); lx<WIDTH; on regions rising sweep the then topographic tput updates viewport water x++)); x<WIDTH; y++)); y<HEIGHT-1; }" ∩")>