#!/usr/bin/env bash
# Generative art: Human memory decay via prime number math and alignment bugs.

trap "tput cnorm; clear; exit 0" INT TERM

tput civis
clear

cols=$(tput cols)
lines=$(tput lines)

is_prime() {
    local n=$1
    ((n < 2)) && return 1
    for ((i=2; i*i<=n; i++)); do
        ((n % i == 0)) && return 1
    done
    return 0
}

t=2
while true; do
    for ((y=1; y<lines-2; y++)); do
        line=""
        for ((x=1; x<cols/3; x++)); do
            val=$(( x * t + y ))
            if is_prime $val; then
                glyphs=("." ":" "*" "o" "O" "@" "~" "-")
                g=${glyphs[$((val % ${#glyphs[@]}))]}$((val % 9))
                
                # Intentional text alignment bug: dynamic, erratic padding offsets causing text collisions and shift artifacts
                pad=$(( (val % t) - (t / 3) ))
                if (( pad < 0 )); then
                    pad=0
                fi
                printf -v chunk "%*s%s" "$pad" "" "$g"
                line+="$chunk"
            else
                line+="   "
            fi
        done
        printf "\033[%d;1H\033[38;5;$(( (t + y) % 231 + 1 ))m%s\033[0m" "$y" "$line"
    done
    
    # Memory decay progression
    ((t++))
    ((t > 131)) && { t=2; clear; }
    sleep 0.1
done