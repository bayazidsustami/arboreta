#!/usr/bin/env bash
# ==============================================================================
# Title:      Git Heraldic Tapestry Pipeline
# Description: Continuously renders local git history as a slowly decaying
#              Unicode tapestry of medieval shields, sigils, and woven text.
# ==============================================================================

# Ensure safe execution
set -uo pipefail

# Heraldic symbols and ANSI color palettes
symbols=("⚜" "⚔" "🛡" "🦁" "🦅" "👑" "✝" "☩" "⚡" "⚓")
colors=("\e[31m" "\e[33m" "\e[32m" "\e[34m" "\e[35m" "\e[36m" "\e[37m")
reset="\e[0m"
decay_chars=("█" "▓" "▒" "░" " ")

# Verify git repository presence
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: This script must be run inside a Git repository." >&2
    exit 1
fi

# Clear screen and hide cursor for a clean rendering surface
clear
tput civis
trap 'tput cnorm; clear; exit 0' INT TERM

iteration=0

while true; do
    # Reset cursor to top-left for smooth live updates
    printf "\e[H"
    
    echo -e "${colors[1]}╔══════════════════════════════════════════════════════════╗${reset}"
    echo -e "${colors[1]}║        DIGITAL HERALDRY: THE GIT CHRONICLE TAPESTRY      ║${reset}"
    echo -e "${colors[1]}╚══════════════════════════════════════════════════════════╝${reset}\n"

    # Fetch recent commit history
    commits=$(git log --oneline -n 10 --format="%h %s")
    
    line_num=0
    while IFS=read -r commit; do
        [[ -z "$commit" ]] && continue
        
        hash="${commit%% *}"
        msg="${commit#* }"
        
        # Derive heraldic sigil from commit hash checksum
        hash_val=$(( 0x${hash:0:2} ))
        sym_idx=$(( hash_val % ${#symbols[@]} ))
        col_idx=$(( hash_val % ${#colors[@]} ))
        
        sym="${symbols[$sym_idx]}"
        col="${colors[$col_idx]}"
        
        # Simulate time-based decay across the tapestry weave
        woven_msg=""
        for (( i=0; i<${#msg}; i++ )); do
            char="${msg:i:1}"
            # Decay probability increases with line depth and iteration age
            if (( (i + line_num * 2 + iteration) % (12 - line_num < 3 ? 3 : 12 - line_num) == 0 )); then
                decay_idx=$(( (line_num + iteration) % ${#decay_chars[@]} ))
                woven_msg+="${decay_chars[$decay_idx]}"
            else
                woven_msg+="$char"
            fi
        done

        # Render heraldic shield node alongside the decaying text fiber
        printf " 🛡️ [%s%s%s] %s ── %s%s%s\n" "$col" "$hash" "$reset" "$col$sym$reset" "$col" "$woven_msg" "$reset"
        
        ((line_num++))
    done <<< "$commits"

    echo -e "\n${reset} [Weaving threads... Press Ctrl+C to seal the vault] "
    
    ((iteration++))
    sleep 2
done