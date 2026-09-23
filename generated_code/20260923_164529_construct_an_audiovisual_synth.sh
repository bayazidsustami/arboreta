#!/usr/bin/env bash
# Audiovisual Browser Cache Synthesizer: Clockwork Galaxies to Black Holes
# Reads browser cache entropy, transforming raw byte streams into a procedural cosmic sonnet and terminal visualizer.

# Locate a valid browser cache directory or fallback to system entropy
CACHE_DIRS=(
    "$HOME/.cache/google-chrome/Default/Cache/Cache_Data"
    "$HOME/Library/Caches/Google/Chrome/Default/Cache"
    "$HOME/.mozilla/firefox"
)

TARGET="/dev/urandom"
for d in "${CACHE_DIRS[@]}"; do
    if [ -d "$d" ]; then
        TARGET="$d"
        break
    fi
done

# Extract raw bytes from cache or entropy source
if [ "$TARGET" = "/dev/urandom" ]; then
    BYTES=$(head -c 32 /dev/urandom | od -An -tu1)
else
    BYTES=$(find "$TARGET" -type f 2>/dev/null | head -n 5 | xargs cat 2>/dev/null | head -c 32 | od -An -tu1)
    [ -z "$BYTES" ] && BYTES=$(head -c 32 /dev/urandom | od -An -tu1)
fi

read -ra NUMS <<< "$BYTES"

# Sonnet stanzas detailing the collapse of clockwork galaxies
Q1=(
    "Brass gears spin wild within the starry deep,"
    "A cosmic watch ticks down its final hour,"
    "The iron orbits falter and grow steep,"
    "As velvet void consumes the titan's power."
)
Q2=(
    "Golden pendulums fracture in the cold,"
    "Nebular springs unwind their ancient fire,"
    "The heavy secrets that the spheres withhold,"
    "Drown silent in the gravitational pyre."
)
Q3=(
    "A ticking heart of hyper-dense despair,"
    "Swallows the dial, the hands, the measured light,"
    "No second remains hanging in the air,"
    "Just absolute and event-driven night."
)
CPL=(
    "Time turns its wheels inward upon the core,"
    "And clockwork heavens tick, then beat no more."
)

clear
echo -e "\033[36m[*] Scanning browser cache entropy streams...\033[0m"
sleep 0.6
echo -e "\033[35m[*] Initiating gravitational collapse sequence...\033[0m\n"
sleep 0.8

idx=0
render_stanza() {
    local -n stz=$1
    for line in "${stz[@]}"; do
        val=${NUMS[idx]:-$((RANDOM % 256))}
        color=$((31 + (val % 7)))
        echo -e "\033[1;${color}m$line\033[0m"
        printf "\033[33m"
        for ((c=0; c<(val % 15) + 3; c++)); do printf "•"; done
        printf "\033[0m\n"
        ((idx++))
        sleep 0.25
    done
    echo ""
}

render_stanza Q1
render_stanza Q2
render_stanza Q3
render_stanza CPL

echo -e "\033[1;31m[!] SYNTHESIS COMPLETE: EVENT HORIZON REACHED [!]\033[0m"