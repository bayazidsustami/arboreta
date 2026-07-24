#!/usr/bin/env bash
# ==============================================================================
# DECAYING ECOSYSTEM: Interactive Generative Terminal Art
# Monitors local system logs (journalctl / dmesg / syslog) and renders them as
# a living visual biosphere. Errors ignite wildfires; success events grow flora.
# ==============================================================================

# Restore terminal settings on exit
cleanup() {
    tput cnorm
    stty echo
    tput rmcup 2>/dev/null || clear
    exit 0
}
trap cleanup EXIT INT TERM

# Initialize alternate buffer & raw terminal mode
tput smcup 2>/dev/null || clear
tput civis
stty -echo -icanon time 0 min 0

COLS=$(tput cols)
LINES=$(tput lines)
(( GRID_H = LINES - 2 ))
(( GRID_W = COLS ))

# Grid state storage
declare -A GRID    # Character display
declare -A COLOR   # ANSI Color code
declare -A AGE     # Lifetime counter for decay

# Color Palette Definitions
RED="\033[38;5;196m"
ORANGE="\033[38;5;208m"
YELLOW="\033[38;5;220m"
GREEN="\033[38;5;46m"
CYAN="\033[38;5;51m"
ASH="\033[38;5;240m"
RESET="\033[0m"

# Render header status bar
draw_header() {
    tput cup 0 0
    echo -ne "\033[1;37;44m VISUAL ECOSYSTEM | [Q]uit | [C]lear | [F]ire | [S]prout ${RESET}"
    printf '%*s' "$((COLS - 52))" "" | tr ' ' ' '
}

# Sprout a fractal tree structure recursively
sprout_flora() {
    local x=$1 y=$2 depth=$3
    [[ $depth -le 0 || $x -lt 1 || $x -ge $((GRID_W-1)) || $y -lt 1 || $y -ge $((GRID_H-1)) ]] && return

    local char="|"
    [[ $depth -eq 1 ]] && char="*"
    [[ $depth -eq 2 ]] && char="Y"

    GRID["$x,$y"]=$char
    COLOR["$x,$y"]=$([[ $depth -eq 1 ]] && echo "$CYAN" || echo "$GREEN")
    AGE["$x,$y"]=25

    # Branch upward and outwards
    sprout_flora $((x + (RANDOM % 3 - 1))) $((y - 1)) $((depth - 1))
    if (( RANDOM % 2 == 0 )); then
        sprout_flora $((x + (RANDOM % 3 - 1))) $((y - 1)) $((depth - 1))
    fi
}

# Ignite a spreading wildfire effect
ignite_fire() {
    local x=$1 y=$2 intensity=$3
    [[ $intensity -le 0 || $x -lt 1 || $x -ge $((GRID_W-1)) || $y -lt 1 || $y -ge $((GRID_H-1)) ]] && return

    GRID["$x,$y"]="^"
    COLOR["$x,$y"]=$RED
    AGE["$x,$y"]=10

    for dx in -1 0 1; do
        for dy in -1 0 1; do
            if (( RANDOM % 3 == 0 )); then
                local nx=$((x + dx)) ny=$((y + dy))
                GRID["$nx,$ny"]="*"
                COLOR["$nx,$ny"]=$ORANGE
                AGE["$nx,$ny"]=6
            fi
        done
    done
}

# Map log events into visual art phenomena
process_log_line() {
    local line="$1"
    local rx=$(( (RANDOM % (GRID_W - 4)) + 2 ))
    local ry=$(( GRID_H - 1 ))

    if echo "$line" | grep -iqE "err|fail|warn|crit|fatal|deny"; then
        # Errors generate spreading fire in upper canopy
        ignite_fire "$rx" "$(( (RANDOM % (GRID_H / 2)) + 2 ))" 3
    else
        # Normal process ticks sprout green flora at ground level
        sprout_flora "$rx" "$ry" 4
    fi
}

# Source system events (fallback to simulated ticker if restricted)
stream_logs() {
    if command -v journalctl &>/dev/null; then
        journalctl -fn 0 2>/dev/null
    elif [[ -f /var/log/syslog ]]; then
        tail -f -n 0 /var/log/syslog 2>/dev/null
    elif [[ -f /var/log/system.log ]]; then
        tail -f -n 0 /var/log/system.log 2>/dev/null
    else
        while true; do
            if (( RANDOM % 5 == 0 )); then
                echo "ERROR systemd-core: sub-system failure"
            else
                echo "INFO process-manager: heartbeat pulse active"
            fi
            sleep 0.4
        done
    fi
}

# Reset active canvas
clear_grid() {
    GRID=()
    COLOR=()
    AGE=()
    tput clear
    draw_header
}

# Create pipe for background log ingestion
PIPE=$(mktemp -u)
mkfifo "$PIPE"
exec 3<>"$PIPE"
rm -f "$PIPE"

stream_logs >&3 &
LOG_PID=$!

clear_grid

# Main interactive engine loop
while true; do
    # 1. Ingest non-blocking log inputs
    if read -t 0.02 -u 3 log_line; then
        process_log_line "$log_line"
    fi

    # 2. Ingest manual keyboard interactions
    if read -t 0.01 -n 1 key; then
        case "$key" in
            q|Q) break ;;
            c|C) clear_grid ;;
            f|F) ignite_fire $((RANDOM % (GRID_W - 4) + 2)) $((RANDOM % (GRID_H - 4) + 2)) 3 ;;
            s|S) sprout_flora $((RANDOM % (GRID_W - 4) + 2)) $((GRID_H - 1)) 4 ;;
        esac
    fi

    # 3. Dynamic Life & Decay Cycle Simulation
    for key in "${!AGE[@]}"; do
        (( AGE["$key"]-- ))
        local_age=${AGE["$key"]}

        IFS=',' read -r x y <<< "$key"

        if (( local_age <= 0 )); then
            # Decay from active element into lingering ash, then fade
            if [[ "${GRID[$key]}" != "." ]]; then
                GRID["$key"]="."
                COLOR["$key"]=$ASH
                AGE["$key"]=5
            else
                unset GRID["$key"]
                unset COLOR["$key"]
                unset AGE["$key"]
                tput cup "$y" "$x"
                echo -ne " "
            fi
        else
            # Render active element
            tput cup "$y" "$x"
            echo -ne "${COLOR[$key]}${GRID[$key]}${RESET}"
        fi
    done

    sleep 0.02
done