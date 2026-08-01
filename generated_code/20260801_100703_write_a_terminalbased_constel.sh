#!/usr/bin/env bash
# ==============================================================================
# COSMIC SHELL: Terminal Constellation Generator
# Parses shell history to map command frequencies as blazing giant stars and 
# syntax anomalies/errors as expanding color nebulae.
# ==============================================================================

# Restore cursor and clear screen on exit
trap 'tput cnorm; clear; exit 0' INT TERM EXIT
tput civis
clear

# Terminal viewport setup
COLS=$(tput cols)
LINES=$(tput lines)
MAX_Y=$((LINES - 4))

# Locate shell history source file
HIST_SRC="${HISTFILE:-$HOME/.bash_history}"
[[ ! -f "$HIST_SRC" ]] && HIST_SRC="$HOME/.zsh_history"

# Render helper: outputs character at specified (x,y) coordinate with ANSI color
draw_at() {
    local x=$1 y=$2 color=$3 char=$4
    if (( x >= 1 && x <= COLS && y >= 1 && y <= MAX_Y )); then
        printf "\033[%d;%dH\033[%sm%s\033[0m" "$y" "$x" "$color" "$char"
    fi
}

# 1. Parse Shell History
declare -A CMD_COUNTS
declare -a ANOMALIES
TOTAL_CMDS=0

if [[ -f "$HIST_SRC" ]]; then
    while IFS= read -r line; do
        [[ "$line" =~ ^# ]] && continue
        [[ -z "$line" ]] && continue
        
        # Extract base command token
        cmd=$(echo "$line" | awk '{print $1}')
        [[ -z "$cmd" ]] && continue
        
        ((CMD_COUNTS["$cmd"]++))
        ((TOTAL_CMDS++))
        
        # Classify syntax errors or incomplete expressions (unmatched quotes, trailing pipes, syntax flags)
        if [[ "$line" =~ ['"'`']{1} || "$line" =~ \|\|[[:space:]]*$ || "$line" =~ ^[[:space:]]*$ ]]; then
            ANOMALIES+=("$cmd")
        fi
    done < <(tail -n 1000 "$HIST_SRC")
fi

# 2. Render Deep Space Background (Ambient faint stars)
for ((i=0; i<COLS*MAX_Y/20; "$char" "30;1" "31;1" "34;1" "36;1" "45;33") "`") "°" "·" "▒" "▓" "✦" "✧") # $rx $ry % & (( (Representing )) + 1 3. 4))]} COLS Cosmic MAX_Y Nebulae RANDOM Render anomalies) char="${faint_chars[$((RANDOM" command do done draw_at errors faint_chars="("."" i++)); nebula_chars="("░"" nebula_colors="("35;1"" num_nebulae rx="$((" ry="$((" syntax> 7 )) && num_nebulae=7
(( num_nebulae == 0 )) && num_nebulae=3

for ((n=0; n<num_nebulae; n++)); do
    cx=$(( RANDOM % (COLS - 12) + 6 ))
    cy=$(( RANDOM % (MAX_Y - 6) + 3 ))
    color=${nebula_colors[$((RANDOM % ${#nebula_colors[@]}))]}
    
    # Expand volumetric cloud particle cluster
    for ((dx=-4; dx<=4; dx++)); do
        for ((dy=-2; dy<=2; dy++)); do
            if (( (dx*dx + dy*dy*2) <= 12 && RANDOM % 100 < 65 )); then
                char=${nebula_chars[$((RANDOM % ${#nebula_chars[@]}))]}
                draw_at $((cx + dx)) $((cy + dy)) "$color" "$char"
            fi
        done
    done
done

# 4. Process Top Commands into Major Constellation Nodes
TOP_CMDS=($(for k in "${!CMD_COUNTS[@]}"; do
    echo "${CMD_COUNTS[$k]} $k"
done | sort -rn | head -n 7 | awk '{print $2}'))

TOP_COUNTS=($(for k in "${!CMD_COUNTS[@]}"; do
    echo "${CMD_COUNTS[$k]} $k"
done | sort -rn | head -n 7 | awk '{print $1}'))

declare -a STAR_X
declare -a STAR_Y
num_stars=${#TOP_CMDS[@]}

# Plot main command stars
for ((i=0; i<num_stars; i++)); do
    cmd="${TOP_CMDS[$i]}"
    count="${TOP_COUNTS[$i]}"
    
    # Evenly distribute positions across the canvas matrix
    sx=$(( (i + 1) * COLS / (num_stars + 1) + (RANDOM % 5 - 2) ))
    sy=$(( (i % 2 == 0 ? 3 : 8) + (RANDOM % (MAX_Y - 10)) ))
    
    STAR_X[$i]=$sx
    STAR_Y[$i]=$sy
    
    # High-frequency commands become blazing white giants
    if (( i < 3 )); then
        draw_at $sx $sy "97;1;5" "✹"
        draw_at $((sx-1)) $sy "97;1" "✦"
        draw_at $((sx+1)) $sy "97;1" "✦"
        draw_at $((sx - ${#cmd}/2)) $((sy + 1)) "37;1;4" "$cmd ($count)"
    else
        draw_at $sx $sy "93;1" "★"
        draw_at $((sx - ${#cmd}/2)) $((sy + 1)) "36" "$cmd"
    fi
done

# 5. Connect Major Stars to Form Constellation Bridges
for ((i=0; i<num_stars-1; i++)); do
    x1=${STAR_X[$i]}
    y1=${STAR_Y[$i]}
    x2=${STAR_X[$((i+1))]}
    y2=${STAR_Y[$((i+1))]}
    
    steps=12
    for ((s=1; s<steps; s++)); do
        lx=$(( x1 + (x2 - x1) * s / steps ))
        ly=$(( y1 + (y2 - y1) * s / steps ))
        draw_at $lx $ly "34;2" "·"
    done
done

# 6. Render HUD and Legend
tput cup $((MAX_Y + 1)) 0
printf "\033[1;30m%*s\033[0m" "$COLS" '' | tr ' ' '─'
tput cup $((MAX_Y + 2)) 2
printf "\033[1;37m[ COSMIC SHELL STAR MAP ]\033[0m \033[36mParsed Commands: %d\033[0m | \033[97;1m✹ Blazing White Giant\033[0m | \033[35m░▒ Cosmic Nebula (Errors)\033[0m" "$TOTAL_CMDS"
tput cup $((MAX_Y + 3)) 2
printf "\033[30;1mPress Ctrl+C to close viewer\033[0m"

# Hold view until interrupted
sleep infinity