#!/usr/bin/env bash
# Generative Art Engine: Git Commit Ecosystem & Wildfire Visualizer
# Translates git log history into a procedural terminal forest.
# Lush trees grow on features/successes; wildfires spark on errors/fixes/reverts.

# Ensure we are inside a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: This script must be run inside a Git repository."
    exit 1
fi

# Setup terminal display and cleanup trap
tput civis
trap "tput cnorm; clear; exit" INT TERM EXIT
clear

COLS=$(tput cols)
ROWS=$(tput lines)
MAX_Y=$((ROWS - 5))

# ANSI Color codes
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
CYAN="\e[36m"
RESET="\e[0m"

echo -e "${CYAN}=== PROCEDURAL ECOSYSTEM INITIALIZED ===${RESET}"
echo -e "Translating Git commit history into a living forest...\n"
sleep 1
clear

# Draw forest boundary box
tput cup 3 0
echo -e "${CYAN}┌$(printf '─%.0s' $(seq 1 $((COLS-2))))┐${RESET}"
for ((i=4; i<=ROWS-3; i++)); do
    tput cup $i 0
    echo -e "${CYAN}│$(printf ' %.0s' $(seq 1 $((COLS-2))))│${RESET}"
done
tput cup $((ROWS-2)) 0
echo -e "${CYAN}└$(printf '─%.0s' $(seq 1 $((COLS-2))))┘${RESET}"

# Fetch commit history chronologically
git log --oneline --reverse --no-merges -n 60 | while read -r hash msg; do
    # Display current commit header
    tput cup 1 2
    echo -e "${CYAN}[COMMIT: $hash]${RESET} ${msg:0:50}                                        "

    # Analyze commit message sentiment/type to determine ecosystem impact
    if echo "$msg" | grep -qiE "fix|bug|error|fail|revert|crash|patch"; then
        EVENT="WILDFIRE"
        COLOR=$RED
        CHAR="🔥"
    elif echo "$msg" | grep -qiE "feat|add|create|release|merge|success|pass"; then
        EVENT="LUSH FOREST"
        COLOR=$GREEN
        CHAR="🌲"
    else
        EVENT="GROWTH"
        COLOR=$YELLOW
        CHAR="🌿"
    fi

    # Generate pseudo-random coordinates within the framed forest
    X=$(( (RANDOM % (COLS - 6)) + 3 ))
    Y=$(( (RANDOM % (MAX_Y - 6)) + 5 ))

    # Render primary ecosystem event
    tput cup $Y $X
    echo -ne "$COLOR$CHAR$RESET"

    # If wildfire, simulate spread to neighboring coordinates
    if [ "$EVENT" = "WILDFIRE" ]; then
        for dy in -1 0 1; do
            for dx in -2 0 2; do
                ny=$((Y + dy))
                nx=$((X + dx))
                if [ $ny -ge 5 ] && [ $ny -le $MAX_Y ] && [ $nx -gt 2 ] && [ $nx -lt $((COLS-2)) ]; then
                    tput cup $ny $nx
                    echo -ne "${RED}🔥${RESET}"
                fi
            done
        done
    fi

    # Update ecosystem status bar at the bottom
    tput cup $((ROWS - 1)) 2
    echo -ne "${CYAN}STATUS:${RESET} Event: $EVENT | Coords: ($X,$Y) | Time: $(date +%T)     "

    # Pacing delay for generative art visualization
    sleep 0.25
done

# Hold display stable upon completion
tput cup $((ROWS - 1)) 2
echo -e "${GREEN}Ecosystem stabilization complete. Press Ctrl+C to exit.          ${RESET}"
while true; do
    sleep 1
done