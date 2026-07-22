#!/usr/bin/env bash
# Ecosystem Simulator: Memory Leaks (Invasive Flora) vs Garbage Collector (Grazing Herd)
#
# Mechanics:
# - Unreferenced memory leaks spawn randomly across the heap (terminal screen) as growing flora (🌱, 🌿, 🌸, 🍄).
# - Autonomous GC threads (grazing sheep 🐑) wander the terminal, detecting and consuming "dead" flora to reclaim heap memory.
# - Clean, self-contained terminal ANSI animation.

export LC_ALL=C

# Terminal dimensions
LINES=$(tput lines 2>/dev/null || echo 24)
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Flora states (Invasive digital growth stages)
FLORA_STAGES=("🌱" "🌿" "☘️" "🌸" "🍄")

# Herd (GC threads) states
GC_ICONS=("🐑" "🐏")

# Global state files for process communication
STATE_DIR=$(mktemp -d /tmp/heap_sim.XXXXXX)
TRAP_CLEANUP() {
    rm -rf "$STATE_DIR"
    tput cnorm # restore cursor
    clear
    exit 0
}
trap TRAP_CLEANUP SIGINT SIGTERM EXIT

# Initialize screen and hide cursor
tput civis
clear

# Create shared memory heap simulation file
HEAP_FILE="$STATE_DIR/heap"
touch "$HEAP_FILE"

# Draw border/header
draw_ui() {
    tput cup 0 0
    echo -ne "\033[1;32m[ HEAP MEMORY ECOSYSTEM SIMULATOR ]\033[0m  Leaks: \033[31mInvasive Flora\033[0m | GC: \033[36mGrazing Herd (Press Ctrl+C to stop)\033[0m"
}

# --- Thread 1: Memory Leak Generator (Spawns Invasive Flora) ---
leak_generator() {
    while true; do
        sleep $(awk -v min=0.3 -v max=1.2 'BEGIN{srand(); print min+rand()*(max-min)}')
        
        # Pick random unallocated coordinate
        local r=$((2 + RANDOM % (LINES - 3)))
        local c=$((1 + RANDOM % (COLUMNS - 2)))
        
        # Spawn memory leak (Flora stage 0)
        echo "$r $c 0" >> "$HEAP_FILE"
    done
}

# --- Thread 2: Ecosystem Engine (Grows Flora & Renders Heap) ---
ecosystem_engine() {
    while true; do
        draw_ui
        
        if [ -s "$HEAP_FILE" ]; then
            local new_heap=""
            while read -r r c stage; do
                # Random chance to evolve flora
                if [ $((RANDOM % 3)) -eq 0 ] && [ "$stage" -lt $((${#FLORA_STAGES[@]} - 1)) ]; then
                    stage=$((stage + 1))
                fi
                
                # Render flora on screen
                tput cup "$r" "$c"
                echo -ne "\033[32m${FLORA_STAGES[$stage]}\033[0m"
                
                new_heap+="$r $c $stage\n"
            done < "$HEAP_FILE"
            
            echo -ne "$new_heap" > "$HEAP_FILE"
        fi
        
        sleep 0.2
    done
}

# --- Thread 3+: Autonomous Garbage Collector (GC Grazers) ---
gc_worker() {
    local gc_id=$1
    local r=$((3 + gc_id * 3))
    local c=$((5 + gc_id * 10))
    local icon_idx=0

    while true; do
        # Clear previous position render if empty
        tput cup "$r" "$c"
        echo -ne "  "
        
        # Autonomous movement towards nearest flora or random wander
        local target_r=-1
        local target_c=-1
        local min_dist=99999
        
        if [ -s "$HEAP_FILE" ]; then
            while read -r fr fc stage; do
                local dist=$(( (r - fr)**2 + (c - fc)**2 ))
                if [ $dist -lt $min_dist ]; then
                    min_dist=$dist
                    target_r=$fr
                    target_c=$fc
                fi
            done < "$HEAP_FILE"
        fi

        # Move towards target or roam
        if [ $target_r -ne -1 ]; then
            [ $r -lt $target_r ] && r=$((r + 1))
            [ $r -gt $target_r ] && r=$((r - 1))
            [ $c -lt $target_c ] && c=$((c + 1))
            [ $c -gt $target_c ] && c=$((c - 1))
        else
            r=$((r + (RANDOM % 3 - 1)))
            c=$((c + (RANDOM % 3 - 1)))
        fi

        # Keep within boundaries
        [ $r -lt 2 ] && r=2
        [ $r -ge $((LINES - 1)) ] && r=$((LINES - 2))
        [ $c -lt 1 ] && c=1
        [ $c -ge $((COLUMNS - 1)) ] && c=$((COLUMNS - 2))

        # Check for GC Sweep (Harvest/Deallocate dead memory at position)
        if [ -s "$HEAP_FILE" ]; then
            grep -v "^$r $c " "$HEAP_FILE" > "$HEAP_FILE.tmp" 2>/dev/null
            mv "$HEAP_FILE.tmp" "$HEAP_FILE"
        fi

        # Draw GC Grazer
        icon_idx=$(( (icon_idx + 1) % ${#GC_ICONS[@]} ))
        tput cup "$r" "$c"
        echo -ne "\033[1;36m${GC_ICONS[$icon_idx]}\033[0m"

        sleep 0.25
    done
}

# Spawn background threads
leak_generator &
ecosystem_engine &

# Spawn GC Herd (4 autonomous threads)
for i in {1..4}; do
    gc_worker "$i" &
done

# Keep main script alive
wait