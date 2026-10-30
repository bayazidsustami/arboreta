#!/usr/bin/env bash
# Generative Audio-Visual Cybernetic Flora Synthesizer
# Translates local network latency spikes into surrealist terminal ASCII art and pulses.

TARGET="1.1.1.1"
clear

while true; do
    # Measure network latency in milliseconds
    LATENCY=$(ping -c 1 -W 1 "$TARGET" 2>/dev/null | grep -oE 'time=[0-9.]+' | cut -d= -f2 | cut -d. -f1)
    [[ -z "$LATENCY" ]] && LATENCY=42

    # Map latency to dynamic ANSI color codes
    COLOR=$(( (LATENCY % 7) + 31 ))

    # Emit a cybernetic audio pulse via terminal bell
    printf "\a"

    # Render fluctuating surrealist cybernetic flora based on latency fluctuation
    clear
    echo -e "\033[1;${COLOR}m"
    echo "    _______________________________________"
    echo "   [ CYBER-FLORA SYNTHESIZER // LATENCY: ${LATENCY}ms ]"
    echo "    ---------------------------------------"
    echo "         ,---."
    echo "        /     \\"
    echo "       |  (${LATENCY}) |"
    echo "        \\     /"
    echo "         \`---'"
    echo "          /|\\"
    echo "         / | \\"
    echo "        /_/ \\_\\"
    echo "\033[0m"

    sleep 1
done