#!/usr/bin/env bash
# ==============================================================================
# Fungal Heap & Microtonal Synthesizer
# Continuously allocates dynamic memory (heap leak), parses allocations into
# microtonal sound synthesis (via raw PCM / ALSA), and renders blossoming
# fungal hyphae in terminal space proportional to runtime memory growth.
# ==============================================================================

# Audio IPC FIFO setup
AUDIO_PIPE="/tmp/hyphae_audio_$$"
mkfifo "$AUDIO_PIPE" 2>/dev/null

# Cleanup on exit: restore cursor, kill audio background task, remove FIFO
cleanup() {
    tput cnorm 2>/dev/null
    kill 0 2>/dev/null
    rm -f "$AUDIO_PIPE" 2>/dev/null
    printf "\033[0m\033[?25h\n"
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# Terminal setup: hide cursor, clear screen
tput civis 2>/dev/null || printf "\033[?25l"
clear

# Background microtonal audio worker: reads Hz frequencies and synthesizes 24-EDO PCM stream
(
    while read -r FREQ; do
        if [[ -n "$FREQ" && "$FREQ" -gt 0 ]]; then
            # Generate 0.12s microtonal sine tone at target pitch using awk
            awk -v freq="$FREQ" -v rate=8000 -v dur=0.12 '
            BEGIN {
                pi = 3.14159265359;
                samples = rate * dur;
                for (i = 0; i < samples; i++) {
                    t = i / rate;
                    # Soft envelope smoothing to eliminate clicking
                    env = 1.0;
                    if (i < 80) env = i / 80;
                    else if (i > samples - 80) env = (samples - i) / 80;
                    
                    val = 127 + 60 * env * sin(2 * pi * freq * t);
                    printf "%c", val;
                }
            }' 2>/dev/null
        fi
    done < "$AUDIO_PIPE" | aplay -q -f U8 -r 8000 -c 1 2>/dev/null
) &

# Terminal bounds
COLS=$(tput cols 2>/dev/null || echo 80)
LINES=$(tput lines 2>/dev/null || echo 24)

# Global heap simulator array
declare -a HEAP_LEAK=()

# Hyphae growth node state representation
# Array elements: "x,y,dx,dy,energy,color_code"
TIPS=()

# Seed initial fungal spore in screen center
CENTER_X=$((COLS / 2))
CENTER_Y=$((LINES / 2))
TIPS+=("$CENTER_X,$CENTER_Y,0,-1,12,82")

# Microtonal scale tuning base (24-EDO Quarter-Tone scale based on C3)
BASE_FREQ=130.81

# Hyphae characters for organic rendering
HYPHAE_CHARS=("╭" "╮" "╯" "╰" "│" "─" "╱" "╲" "╎" "✦" "🪻" "🌸")

ITERATION=0
while true; do
    ((ITERATION++))

    # 1. PARSE / ALLOCATE RUNTIME HEAP (Simulated Memory Leak)
    # Append high-entropy heap blocks to grow process dynamic footprint
    LEAK_BLOCK=$(head -c 256 /dev/urandom | base64 2>/dev/null)
    HEAP_LEAK+=("$LEAK_BLOCK")
    
    # Read actual process heap/RSS page footprint if procfs is available
    if [[ -r "/proc/$$/statm" ]]; then
        MEM_PAGES=$(awk '{print $2}' /proc/$$/statm 2>/dev/null)
    else
        MEM_PAGES=${#HEAP_LEAK[@]}
    fi
    HEAP_BYTES=$((${#HEAP_LEAK[@]} * 350))

    # 2. PARSE HEAP ALLOCATION INTO MICROTONAL MIDI/AUDIO SCORE
    # Hash raw memory payload + page metrics into 24-EDO microtonal frequency
    # Scale formula: f = f0 * 2^(step / 24)
    HASH_VAL=$(echo "$LEAK_BLOCK" | cksum | awk '{print $1}')
    QUARTER_TONE_STEP=$(( (HASH_VAL + MEM_PAGES) % 48 ))
    MICRO_FREQ=$(awk -v base="$BASE_FREQ" -v step="$QUARTER_TONE_STEP" 'BEGIN { printf "%.0f", base * (2 ^ (step / 24.0)) }')

    # Emit microtonal pitch event to PCM sound engine
    if [[ -p "$AUDIO_PIPE" ]]; then
        echo "$MICRO_FREQ" > "$AUDIO_PIPE" 2>/dev/null
    fi

    # 3. VISUALIZE MEMORY LEAK AS BLOSSOMING FUNGAL HYPHAE
    # Memory footprint directly modulates fungal bifurcation (branching) rate
    BRANCH_CHANCE=$(( 5 + MEM_PAGES / 40 ))
    [[ $BRANCH_CHANCE -gt 50 ]] && BRANCH_CHANCE=50

    NEW_TIPS=()
    for tip in "${TIPS[@]}"; do
        IFS=',' read -r x y dx dy energy col <<< "$tip"

        # Render hypha element at terminal position
        if [[ $x -ge 1 && $x -le $COLS && $y -ge 1 && $y -le $LINES ]]; then
            CHAR_IDX=$(( (x + y + ITERATION) % 8 ))
            CHAR="${HYPHAE_CHARS[$CHAR_IDX]}"
            printf "\033[%d;%dH\033[38;5;%dm%s\033[0m" "$y" "$x" "$col" "$CHAR"
        fi

        # Compute next directional step via memory-influenced random walk
        RND=$((RANDOM % 100))
        if [[ $RND -lt 30 ]]; then
            dx=$(( (RANDOM % 3) - 1 ))
        elif [[ $RND -lt 60 ]]; then
            dy=$(( (RANDOM % 3) - 1 ))
        fi
        [[ $dx -eq 0 && $dy -eq 0 ]] && dy=-1

        nx=$((x + dx))
        ny=$((y + dy))

        # Clamp hyphae within terminal canvas bounds
        [[ $nx -lt 1 ]] && nx=1 && dx=1
        [[ $nx -gt $COLS ]] && nx=$COLS && dx=-1
        [[ $ny -lt 1 ]] && ny=1 && dy=1
        [[ $ny -gt $LINES ]] && ny=$LINES && dy=-1

        ((energy--))

        if [[ $energy -gt 0 ]]; then
            NEW_TIPS+=("$nx,$ny,$dx,$dy,$energy,$col")
        else
            # Terminal bloom when hypha tip exhausts energy
            printf "\033[%d;%dH\033[38;5;201m✦\033[0m" "$y" "$x"
        fi

        # Memory leak pressure induces hyphae branching (fungal hyphae explosion)
        if [[ $((RANDOM % 100)) -lt $BRANCH_CHANCE ]]; then
            NEW_COL=$(( 82 + (MEM_PAGES + RANDOM) % 125 ))
            NEW_ENERGY=$(( 6 + RANDOM % 16 ))
            NDX=$(( (RANDOM % 3) - 1 ))
            NDY=$(( (RANDOM % 3) - 1 ))
            NEW_TIPS+=("$x,$y,$NDX,$NDY,$NEW_ENERGY,$NEW_COL")
        fi
    done

    TIPS=("${NEW_TIPS[@]}")

    # Respawn spore if all active tips perish
    if [[ ${#TIPS[@]} -eq 0 ]]; then
        RX=$(( 1 + RANDOM % COLS ))
        RY=$(( 1 + RANDOM % LINES ))
        TIPS+=("$RX,$RY,0,1,14,118")
    fi

    # Real-time Telemetry HUD
    printf "\033[1;1H\033[44;37m HEAP ALLOCATED: %'d B | MEM PAGES: %d | MICROTONAL PITCH: %d Hz (24-EDO) | HYPHAE TIPS: %d \033[0m" \
        "$HEAP_BYTES" "$MEM_PAGES" "$MICRO_FREQ" "${#TIPS[@]}"

    sleep 0.08
done