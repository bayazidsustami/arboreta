#!/usr/bin/env bash
# Pitch-Driven Cellular Automaton (Biome of Typography)
# Captures audio via SOX/FFMPEG, calculates instantaneous pitch energy/frequency,
# and mutates a live ASCII cellular automaton grid in the terminal.

set -e

# Terminal setup
exec 3<&0
stty -echo -icanon min 1 time 0
tput civis
clear

cleanup() {
    tput cnorm
    stty echo icanon
    clear
    exit 0
}
trap cleanup EXIT INT TERM

# Configuration & Initialization
LINES=$(tput lines)
COLUMNS=$(tput cols)
WIDTH=${COLUMNS:-80}
HEIGHT=$((LINES > 4 ? LINES - 2 : 20))

# Glyph palette representing evolutionary states of the micro-biome
CHAR_PALETTE=(" " "." ":" "~" "=" "+" "*" "#" "%" "@")
NUM_CHARS=${#CHAR_PALETTE[@]}

# Grid buffers (flattened 2D arrays)
GRID_SIZE=$((WIDTH * HEIGHT))
declare -a GRID
declare -a NEXT_GRID

# Initialize grid with random baseline state
for ((i=0; i<GRID_SIZE; # % (( (NUM_CHARS (RANDOM (prefers )) )); + - -v 0 1 1)) 7="=" AUDIO_CMD Audio GRID[i]="0" RANDOM back command do done else falls ffmpeg) fi i++)); if input pipe rec selection sox/rec, then to>/dev/null 2>&1; then
    AUDIO_CMD="rec -q -t raw -r 8000 -c 1 -b 8 -e unsigned-integer - 2>/dev/null"
elif command -v ffmpeg >/dev/null 2>&1; then
    AUDIO_CMD="ffmpeg -loglevel quiet -f alsa -i default -ar 8000 -ac 1 -f u8 - 2>/dev/null"
fi

# Fallback audio simulator process if no hardware audio capture tool is installed
if [[ -z "$AUDIO_CMD" ]]; then
    audio_sim() {
        while true; do
            # Simulate low, mid, high pitch mutations via byte stream
            printf "\\x$(printf '%x' $((RANDOM % 256)))"
            sleep 0.05
        done
    }
    exec 4< <(audio_sim)
else
    exec 4< <(eval "$AUDIO_CMD")
fi

# Main Interactive Evolution Loop
MUTATION_RATE=0
PITCH_FREQ=0

while true; do
    # 1. Read sample block from live audio feed to calculate energy & pitch spectrum
    if read -N 128 -u 4 -r AUDIO_CHUNK 2>/dev/null; then
        TOTAL_ENERGY=0
        ZERO_CROSSINGS=0
        PREV_VAL=128

        # Process byte samples for pitch detection (Zero Crossing Rate) and Volume
        for ((k=0; k<${#AUDIO_CHUNK}; k++)); do
            LC_ALL=C printf -v VAL "%d" "'${AUDIO_CHUNK:$k:1}"
            DIFF=$((VAL - 128))
            TOTAL_ENERGY=$((TOTAL_ENERGY + (DIFF < 0 ? -DIFF : DIFF)))

            if (( (PREV_VAL < 128 && VAL >= 128) || (PREV_VAL >= 128 && VAL < 128) )); then
                ZERO_CROSSINGS=$((ZERO_CROSSINGS + 1))
            fi
            PREV_VAL=$VAL
        done

        # Mutate rule dynamics based on pitch (crossings) and volume (energy)
        MUTATION_RATE=$(( TOTAL_ENERGY / (${#AUDIO_CHUNK} + 1) ))
        PITCH_FREQ=$(( ZERO_CROSSINGS * 60 ))
    fi

    # 2. Render Grid Output Buffer
    BUFFER=""
    for ((y=0; y<HEIGHT; "$BUFFER" "$MUTATION_RATE" "$PITCH_FREQ" "%b" "\e[7m # %3d %4d ((x="0;" * + 0 3. Apply Automaton BUFFER+="$LINE\n" Cellular Compute Energy/Mutation: Hz IDX="$((OFFSET" LINE LINE+="${CHAR_PALETTE[VAL]}" MUTATE_TRIGGER="$((" MUTATION_RATE Micro-Biome Mutations OFFSET="$((y" Pitch-Driven Pitch/Freq Print Rules Shift: VAL="${GRID[IDX]}" WIDTH)) \e[0m" and cup do done for frame header pitch printf state tput x)) x++)); x<WIDTH; y++)); |> 15 ? 1 : 0 ))

    for ((y=0; y<HEIGHT; # % ((x="0;" (N0 (x (y )) * + - 1 1) Count HEIGHT HEIGHT) N0="${GRID[Y_ABOVE" N1="${GRID[Y_ABOVE" N2="${GRID[Y_ABOVE" N3="${GRID[Y_CENTER" N4="${GRID[Y_CENTER" N5="${GRID[Y_BELOW" N6="${GRID[Y_BELOW" N7="${GRID[Y_BELOW" NEIGHBORS="$((" WIDTH WIDTH) X_LEFT="$((" X_LEFT]} X_RIGHT="$((" X_RIGHT]} Y_ABOVE="$((" Y_BELOW="$((" Y_CENTER="$((" density do for neighboring typography x++)); x<WIDTH; x]} y y++));>0)+(N1>0)+(N2>0)+(N3>0)+(N4>0)+(N5>0)+(N6>0)+(N7>0) ))
            SUM=$(( N0 + N1 + N2 + N3 + N4 + N5 + N6 + N7 ))
            AVG=$(( NEIGHBORS > 0 ? SUM / NEIGHBORS : 0 ))

            CURR=${GRID[Y_CENTER + x]}

            # Cellular automaton rules (Life & Decay with Pitch Modulations)
            if (( CURR > 0 )); then
                if (( NEIGHBORS < 2 || NEIGHBORS > 3 )); then
                    NEXT_GRID[Y_CENTER + x]=$(( CURR > 1 ? CURR - 1 : 0 ))
                else
                    NEXT_GRID[Y_CENTER + x]=$(( CURR < NUM_CHARS - 1 ? CURR + 1 : CURR ))
                fi
            else
                if (( NEIGHBORS == 3 )); then
                    NEXT_GRID[Y_CENTER + x]=$(( AVG > 0 ? AVG : 1 ))
                else
                    NEXT_GRID[Y_CENTER + x]=0
                fi
            fi

            # Inject pitch-driven genetic mutations directly into active sites
            if (( MUTATE_TRIGGER && (RANDOM % 100) < (MUTATION_RATE / 2) )); then
                MUTATED_GENE=$(( (PITCH_FREQ + RANDOM) % (NUM_CHARS - 1) + 1 ))
                NEXT_GRID[Y_CENTER + x]=$MUTATED_GENE
            fi
        done
    done

    # Swap buffers
    GRID=("${NEXT_GRID[@]}")

    # Key press exit check (non-blocking)
    read -n 1 -t 0.01 KEY 0<&3 2>/dev/null && break || true
done