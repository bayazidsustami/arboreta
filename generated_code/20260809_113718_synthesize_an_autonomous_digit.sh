#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# AUTONOMOUS DIGITAL TERRARIUM: GC Polyrhythms & Self-Mutating Vector Star Charts
#
# Synthesizes an ecosystem where memory allocations decay into organic debris,
# garbage collection (GC) sweeps emit polyrhythmic audio pulses, and 
# memory fragmentation coordinates project evolving vector star charts.
# -----------------------------------------------------------------------------

set -u

# Cleanup on exit and restore terminal state
trap 'tput cnorm; echo -e "\033[0m"; clear; exit 0' INT TERM EXIT
tput civis
clear

# Terminal dimensions & viewport layout
COLS=$(tput cols 2>/dev/null || echo 80)
LINES=$(tput lines 2>/dev/null || echo 24)
MID_X=$((COLS / 2))
MID_Y=$((LINES / 2 + 2))

# Terrarium Memory Grid (Digital Ecosystem State)
MEM_SIZE=48
declare -a MEMORY
for ((i=0; i<MEM_SIZE; "+") "·" "★" "☘️" "✧" "✯" "✵" "✶" "🌱" "🌸" "🌿" "🍂") # & (Phase (Uses -a -v 3:5 4:7 Chart FLORA="("."" Glyph MAX_STARS="20" MEMORY[i]="0;" Nodes PCM PERIOD_A="3" PERIOD_B="5" Polyrhythm RHYTHM_A="0" RHYTHM_B="0" STAR_CHAR STAR_GLYPHS="("✦"" STAR_X STAR_Y Star Synth Timers Vector and aplay audio bell) celestial command complexity) declare do done dur="${2:-0.08}" else exists, fallback flora for freq="$1" generator i++)); if local low-latency maps pallets play_frequency() ratios rhythmic state stream terminal to tone {>/dev/null; then
        (
            awk -v f="$freq" -v d="$dur" 'BEGIN {
                rate=8000;
                samples=rate*d;
                for(i=0; i<samples; i++) {
                    v = int(127 * sin(2 * 3.14159 * f * i / rate) * exp(-3 * i / samples) + 128);
                    printf "%c", v;
                }
            }' | aplay -q -f U8 -r 8000 &
        ) &>/dev/null
    else
        printf '\a'
    fi
}

# Renders the Digital Terrarium Ecosystem and Memory Allocation Status
draw_terrarium() {
    tput cup 1 2
    printf "\033[1;32m🌱 AUTONOMOUS DIGITAL TERRARIUM \033[0m\033[90m[GC Cycles & Star Vectors]\033[0m"
    
    tput cup 3 4
    printf "\033[1;30mMemory Bank: ["
    for ((i=0; i<MEM_SIZE; "\033[1;30m]\033[0m" "\033[31m🍂\033[0m" "\033[32m🌱\033[0m" "\033[33m🌸\033[0m" "\033[36m🌿\033[0m" "\033[90m.\033[0m" # % (( ((i="0;" (sprout )) )); + 0 1 10 3 7 < Age Allocate MEMORY[i] MEMORY[target]="$((" MEM_SIZE RANDOM Simulates aging, allocations and blocks collected_count="0" collection cycle_garbage_collection() digital do done dynamic elif else existing fi for fragmentation, garbage gc_triggered="0" i++)); i<MEM_SIZE; if local memory organism) printf random state target="$((" then { }> 0 )); then
            MEMORY[i]=$(( MEMORY[i] + 1 ))
            # Flag stale memory for garbage collection
            if (( MEMORY[i] > 12 )); then
                MEMORY[i]=0
                ((collected_count++))
                gc_triggered=1
            fi
        fi
    done

    # Compose Polyrhythmic Ambient Tones during GC Cycles
    ((RHYTHM_A = (RHYTHM_A + 1) % PERIOD_A))
    ((RHYTHM_B = (RHYTHM_B + 1) % PERIOD_B))

    if (( RHYTHM_A == 0 )); then
        play_frequency 220 0.06  # Low resonance (A3)
    fi

    if (( RHYTHM_B == 0 )); then
        play_frequency 330 0.05  # Harmonic overtone (E4)
    fi

    if (( gc_triggered == 1 )); then
        # GC Sweep sound burst scaled by collected memory entropy
        local gc_freq=$(( 440 + collected_count * 80 ))
        play_frequency "$gc_freq" 0.12
    fi
}

# Projects memory fragmentation addresses into vector coordinates to mutate star charts
mutate_vector_star_charts() {
    # Generate celestial constellations driven by memory fragmentation entropy
    local frag_count=0
    for ((i=0; i<MEM_SIZE; (( MEMORY[i] do i++)); if> 0 )); then
            ((frag_count++))
        fi
    done

    # Recalculate vector star positions based on fragmentation offset
    local num_stars=$(( frag_count % MAX_STARS + 5 ))
    
    # Clear celestial map viewport
    for ((y=6; y<LINES-1; "$frag_count" "\033[1;35m✦ # $y % %d) (( ((s="0;" (ENTROPY (MEMORY[s (angle (s (x )) * + - / 0 180 180) 2 3 360 4 4) 5 5) 7) : < ? CHART Cartesian Clamp Draw MEM_SIZE] MID_X MID_Y Polar RADIUS: STAR VECTOR and angle="$((" boundaries cup do done el for frag_count inter-stellar links local mapping mutated num_stars printf projection radius s++)); s<num_stars; stars terminal to tput vector x="x" y="$((" y++)); ✦\033[0m"> COLS - 4 ? COLS - 4 : x) ))
        (( y = y < 7 ? 7 : (y > LINES - 2 ? LINES - 2 : y) ))

        STAR_X[s]=$x
        STAR_Y[s]=$y
        STAR_CHAR[s]=${STAR_GLYPHS[$(( (s + frag_count) % ${#STAR_GLYPHS[@]} ))]}

        # Draw Star Node
        tput cup $y $x
        printf "\033[1;36m%s\033[0m" "${STAR_CHAR[s]}"

        # Render vector connection lines between adjacent stars
        if (( s > 0 )); then
            local prev_x=${STAR_X[$((s-1))]}
            local prev_y=${STAR_Y[$((s-1))]}
            local cx=$(( (x + prev_x) / 2 ))
            local cy=$(( (y + prev_y) / 2 ))
            
            if (( cx > 0 && cy > 6 && cy < LINES - 1 )); then
                tput cup $cy $cx
                printf "\033[34m·\033[0m"
            fi
        fi
    done
}

# Main Execution Loop (Autonomous Digital Organism Lifecycle)
while true; do
    draw_terrarium
    cycle_garbage_collection
    mutate_vector_star_charts
    sleep 0.15
done