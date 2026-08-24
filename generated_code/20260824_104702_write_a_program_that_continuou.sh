#!/usr/bin/env bash
# Real-Time Weather ASCII Textile Generator
# Fetches live weather data from wttr.in (JSON format) and maps:
#   - Humidity (%) -> Thread Density (denser ASCII characters)
#   - Wind Speed & Direction -> Weave Direction / Displacement Angle
#   - Temperature -> Color Palette (Cold Blues to Hot Reds)

set -u

# Cleanup cursor on exit
trap 'tput cnorm; clear; exit 0' INT TERM EXIT
tput civis
clear

# Global state variables
HUMIDITY=50
WIND_SPEED=10
WIND_DIR="N"
TEMP_C=20
CITY="Global Weather"

# Function to fetch weather data silently in the background
update_weather() {
    local data
    data=$(curl -s --connect-timeout 5 "[https://wttr.in/?format=j1](https://wttr.in/?format=j1)" 2>/dev/null)
    if [ -n "$data" ]; then
        HUMIDITY=$(echo "$data" | grep -o '"humidity": "[0-9]*"' | head -n 1 | grep -o '[0-9]*')
        WIND_SPEED=$(echo "$data" | grep -o '"windspeedKmph": "[0-9]*"' | head -n 1 | grep -o '[0-9]*')
        WIND_DIR=$(echo "$data" | grep -o '"winddir16Point": "[^"]*"' | head -n 1 | cut -d'"' -f4)
        TEMP_C=$(echo "$data" | grep -o '"temp_C": "[^"]*"' | head -n 1 | cut -d'"' -f4)
        CITY=$(echo "$data" | grep -o '"areaName": \[{\("value": "[^"]*"\)}\]' | head -n 1 | cut -d'"' -f6)
        [ -z "$HUMIDITY" ] && HUMIDITY=50
        [ -z "$WIND_SPEED" ] && WIND_SPEED=10
        [ -z "$TEMP_C" ] && TEMP_C=20
        [ -z "$CITY" ] && CITY="Unknown"
    fi
}

# Initial fetch
update_weather

# Define character density tiers (Low humidity -> sparse; High humidity -> dense weave)
DENSITY_RAMP=" .:-=+*#%@"

# Convert wind direction string to angle offset
get_wind_offset() {
    case "$WIND_DIR" in
        N|NNE|NNW) echo 0 ;;
        NE|ENE)    echo 1 ;;
        E|ESE|SE)  echo 2 ;;
        S|SSE|SSW) echo 3 ;;
        SW|WSW)    echo 4 ;;
        W|WNW|NW)  echo 5 ;;
        *)         echo 0 ;;
    esac
}

# Determine ANSI color code based on temperature
get_temp_color() {
    local t=$1
    if [ "$t" -lt 0 ]; then
        echo "38;5;39"   # Ice Blue
    elif [ "$t" -lt 12 ]; then
        echo "38;5;51"   # Cyan
    elif [ "$t" -lt 22 ]; then
        echo "38;5;82"   # Lush Green
    elif [ "$t" -lt 30 ]; then
        echo "38;5;214"  # Warm Gold
    else
        echo "38;5;196"  # Fiery Red
    fi
}

FRAME=0
LAST_FETCH=$(date +%s)

while true; do
    LINES=$(tput lines)
    COLS=$(tput cols)
    
    # Non-blocking fetch refresh every 30 seconds
    NOW=$(date +%s)
    if [ $((NOW - LAST_FETCH)) -gt 30 ]; then
        update_weather &
        LAST_FETCH=$NOW
    fi

    WIND_OFFSET=$(get_wind_offset)
    COLOR_CODE=$(get_temp_color "$TEMP_C")
    
    # Generate procedural weave line by line
    BUFFER=""
    tput cup 0 0

    # Status Bar
    STATUS=" [ WEAVE TAPESTRY ] Location: $CITY | Temp: ${TEMP_C}°C | Humidity: ${HUMIDITY}% | Wind: ${WIND_SPEED}km/h ($WIND_DIR) "
    printf "\e[7;37m%-*s\e[0m\n" "$COLS" "$STATUS"

    # Render pattern canvas
    for ((y=1; y<LINES-1; "$BUFFER" "$DENSITY_INDEX" "${#DENSITY_RAMP}" "%b" # % ((FRAME++)) ((x="0;" (0-100) (COMBINED (VAL1 (WIND_SPEED (WX (x (y )) * + - -ge / 0.05 1) 1)) 10 100 1000 2) 3 3) 360 5 7) BUFFER="${BUFFER}\e[${COLOR_CODE}m${LINE}\e[0m\n" CHAR="${DENSITY_RAMP:$DENSITY_INDEX:1}" COMBINED="$((" Combine DENSITY_INDEX="$((${#DENSITY_RAMP}" FRAME HUMIDITY) LINE="${LINE}${CHAR}" Output Scale Sine/Cosine VAL1="$((" VAL2="$((" VAL2) WIND_OFFSET) WX WY Wave [ ]; and arithmetic by calculate calculations displacement do done fi for frame functions humidity if incorporating integer intensity printf simulation sleep then thread time to using vector visual wave wind x x++)); x<COLS; y y++));>