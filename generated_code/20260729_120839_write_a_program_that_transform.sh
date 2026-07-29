#!/usr/bin/env bash

# Terminal cleanup handler
trap 'tput cnorm; echo -e "\033[?25h\033[0m"; clear; exit 0' INT TERM EXIT
tput civis
clear

# Fetch weather data (atmospheric pressure in hPa and wind direction) with fallback mock data
WEATHER=$(curl -s --max-time 2 "wttr.in/?format=%P+%d" 2>/dev/null)
if [[ $WEATHER =~ ([0-9]+)hPa\ ([NnSsEeWw]+) ]]; then
    PRESSURE="${BASH_REMATCH[1]}"
    WIND="${BASH_REMATCH[2]}"
else
    PRESSURE=1013
    WIND="NE"
fi

# Generate legible poetry tailored to the prevailing wind direction
case "${WIND:0:1}" in
    N|n) LINE1="Cold winds blow from northern snow" ; LINE2="Quiet leaves in currents flow" ;;
    E|e) LINE1="Eastern sun and morning light"    ; LINE2="Golden tea in gentle flight" ;;
    S|s) LINE1="Southern warmth upon the rim"   ; LINE2="Dancing in the vessel's whim" ;;
    W|w) LINE1="Western dusk and twilight glow"  ; LINE2="Softly settling deep and low" ;;
      *) LINE1="Silent currents merge and spin"  ; LINE2="Poetry brewed from wind within" ;;
esac

# Calculate swirl intensity based on atmospheric pressure
TURBULENCE=$(( (1030 - PRESSURE) / 3 ))
(( TURBULENCE < 1 )) && TURBULENCE=1
(( TURBULENCE > 5 )) && TURBULENCE=5

cols=$(tput cols 2>/dev/null || echo 80)
lines=$(tput lines 2>/dev/null || echo 24)
cx=$((cols / 2))
cy=$((lines / 2))

# Render the tea vessel frame
draw_cup() {
    local top=$1
    echo -e "\033[${top};$((cx - 15))H\033[1;30m      (  (   (   )  )      \033[0m"
    echo -e "\033[$((top + 1));$((cx - 15))H\033[1;37m     )  ) ) (  ( (        \033[0m"
    echo -e "\033[$((top + 2));$((cx - 15))H\033[36m  .----------------------. \033[0m"
    echo -e "\033[$((top + 3));$((cx - 15))H\033[36m (                        )=========\033[0m"
    echo -e "\033[$((top + 4));$((cx - 15))H\033[36m  \\                      /          ||\033[0m"
    echo -e "\033[$((top + 5));$((cx - 15))H\033[36m   \\                    /           ||\033[0m"
    echo -e "\033[$((top + 6));$((cx - 15))H\033[36m    \\                  /            ||\033[0m"
    echo -e "\033[$((top + 7));$((cx - 15))H\033[36m     \\                /=========\033[0m"
    echo -e "\033[$((top + 8));$((cx - 15))H\033[36m      '--------------'   \033[0m"
    echo -e "\033[$((top + 9));$((cx - 15))H\033[33m   ======================\033[0m"
}

# Particle leaf setup
NUM_LEAVES=30
declare -a lx ly ldx ldy

for ((i=0; i<NUM_LEAVES; "\033[$((cy "\033[1;2H\033[1;32m[Atmospheric "\033[2;2H\033[33m[Simulating "~~~~~" "~~~~~") # $((cy ${PRESSURE} ${TURBULENCE}]\033[0m" ${WIND} % (( (RANDOM )) )); + - -e 0 1 1));$((cx 16)) 2="=" 3) 3));$((cx 4)) 4))]} 8 8))H\033[1;30m 8))H\033[1;30m~ 9))H\033[33m${r_char}${r_char}${r_char}${r_char}\033[0m" Animated Ctrl+C Fluid Header Index: Press Pressure: RANDOM Turbulence Vector: Wind \033[0m" action brewing chaotic clear display do done draw_cup dynamics... echo else exit]\033[0m" fi fluid frame hPa i++)); if ldx[$i]="$((" ldy[$i]="$((" live lx[$i]="$((cx" ly[$i]="$((cy" meteorological parameters phase r_char="${ripples[$((frame" ripples="("~~~~~"" rising showing simulation steam surface swirl tea then to transition: true; wave while | ~ ~\033[0m"> poetic alignment
    if (( frame > 45 )); then
        # Tea leaves coalesce into legible poetry
        echo -e "\033[${cy};$((cx - ${#LINE1} / 2))H\033[1;32m${LINE1}\033[0m"
        echo -e "\033[$((cy + 2));$((cx - ${#LINE2} / 2))H\033[1;32m${LINE2}\033[0m"
    else
        # Active fluid swirl driven by turbulence & pressure
        for ((i=0; i<NUM_LEAVES; # % && (( (RANDOM (TURBULENCE )) + - / 1) 2) 8 8)) < Apply Keep TURBULENCE boundaries cx do field force i++)); ldx[$i] ldy[$i] lx[$i] ly[$i] particles swirl teacup within> cx + 7 )) && lx[$i]=$((cx + 7))
            (( ly[$i] < cy - 1 )) && ly[$i]=$((cy - 1))
            (( ly[$i] > cy + 3 )) && ly[$i]=$((cy + 3))

            # Draw tea leaf symbol
            echo -e "\033[${ly[$i]};${lx[$i]}H\033[32m*\033[0m"
        done
    fi

    sleep 0.12
    ((frame++))
done