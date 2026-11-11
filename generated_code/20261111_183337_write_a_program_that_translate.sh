#!/usr/bin/env bash
# Ambient Sound Evolutionary Ancestral Watercolor Simulator in Bash
# Translates microphone input (or fallback entropy) into a shifting cellular automaton 
# rendering an ethereal, watercolor-style portrait of a forgotten ancestor using ANSI color.

set -euo pipefail
trap 'tput cnorm; clear; exit 0' INT TERM

# Dimensions
COLS=${COLUMNS:-80}
ROWS=${LINES:-24}
WIDTH=$((COLS > 60 ? 60 : COLS))
HEIGHT=$((ROWS > 20 ? 20 : ROWS))

tput civis
clear

# Initialize grid (0 or 1) with a ghostly central silhouette (ancestor shape)
declare -A grid
for ((y=0; y<HEIGHT; y++)); do
    for ((x=0; x<WIDTH; x++)); do
        dx=$((x - WIDTH/2))
        dy=$((y - HEIGHT/2))
        if (( dx*dx*4 + dy*dy*9 < (WIDTH*HEIGHT)/4 )); then
            grid[$x,$y]=$((RANDOM % 2))
        else
            grid[$x,$y]=0
        fi
    done
done

# Color palettes for watercolor feel (Sepia, Indigo, Faded Rose)
palettes=(
    "38;5;94"  # Sepia brown
    "38;5;137" # Muted clay
    "38;5;66"  # Faded slate blue
    "38;5;109" # Pale water blue
    "38;5;181" # Dusty rose
)

get_sound_energy() {
    if command -v arecord &>/dev/null; then
        local val
        val=$(arecord -d 1 -f S16_LE -c 1 -r 4000 -q 2>/dev/null | od -An -tu2 -N 64 | awk '{s+=$1} END {print s+0}')
        echo $((val % 100))
    elif command -v rec &>/dev/null; then
        local val
        val=$(rec -n trim 0 0.1 stat 2>&1 | grep "RMS Amplitude" | awk '{print int($3*1000)}')
        echo $((val % 100))
    else
        echo $((RANDOM % 50))
    fi
}

while true; do
    energy=$(get_sound_energy)
    mutation=$(( (energy % 5) + 1 ))

    # Evolve Cellular Automaton with sound-modulated rules
    declare -A next_grid
    for ((y=0; y<HEIGHT; y++)); do
        for ((x=0; x<WIDTH; x++)); do
            sum=0
            for ((dy=-1; dy<=1; dy++)); do
                for ((dx=-1; dx<=1; dx++)); do
                    if ((dx != 0 || dy != 0)); then
                        nx=$(( (x + dx + WIDTH) % WIDTH ))
                        ny=$(( (y + dy + HEIGHT) % HEIGHT ))
                        sum=$((sum + ${grid[$nx,$ny]:-0}))
                    fi
                done
            done

            current=${grid[$x,$y]:-0}
            if (( current == 1 )); then
                if (( sum == 2 || sum == 3 || (energy > 40 && sum == 4) )); then
                    next_grid[$x,$y]=1
                else
                    next_grid[$x,$y]=0
                fi
            else
                if (( sum == 3 || (energy > 60 && sum == 4) )); then
                    next_grid[$x,$y]=1
                else
                    next_grid[$x,$y]=0
                fi
            fi

            if (( RANDOM % 200 < mutation )); then
                next_grid[$x,$y]=$(( 1 - ${next_grid[$x,$y]} ))
            fi
        done
    done

    for ((y=0; y<HEIGHT; y++)); do
        for ((x=0; x<WIDTH; x++)); do
            grid[$x,$y]=${next_grid[$x,$y]}
        done
    done

    # Render Watercolor Portrait using density characters and ANSI Colors
    tput cup 0 0
    echo -ne "\033[H"
    echo -e "\033[1;30m=== ANCESTRAL WATERCOLOR RESONANCE (Sound Energy: $energy) ===\033[0m"

    for ((y=0; y<HEIGHT; y+=2)); do
        line=""
        for ((x=0; x<WIDTH; x+=2)); do
            p1=${grid[$x,$y]:-0}
            p2=${grid[$x+1,$y]:-0}
            p3=${grid[$x,$y+1]:-0}
            p4=${grid[$x+1,$y+1]:-0}
            
            val=$((p1 + p2*2 + p3*4 + p4*8))
            color_idx=$(( (x + y + energy) % ${#palettes[@]} ))
            color=${palettes[$color_idx]}

            case $val in
                0) char=" " ;;
                1) char="░" ;;
                2) char="▒" ;;
                3) char="▓" ;;
                4) char="⠂" ;;
                5) char="⠆" ;;
                6) char="⠖" ;;
                7) char="⠶" ;;
                8) char="⠧" ;;
                9) char="⠷" ;;
                10) char="⣾" ;;
                *) char="█" ;;
            esac

            line+="\033[$color${char}\033[0m"
        done
        echo -e "$line"
    done

    sleep 0.15
done