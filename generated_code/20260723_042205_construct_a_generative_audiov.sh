#!/usr/bin/env bash
# Generative Audio-Visual Weather Simulator
# Maps real-time CPU thermal activity and memory usage spikes into dynamic terminal weather (pixelated rain, lightning flashes, dynamic wind) and algorithmic PCM audio (synthesized wind & thunder via aplay/perl bytebeat).

# Ensure cleanup of background audio and screen state on exit
trap 'rm -f /tmp/bash_weather_* 2>/dev/null; printf "\e[?25h\e[0m\e[2J\e[1;1H"; kill 0 2>/dev/null; exit 0' INT TERM EXIT

# Hide terminal cursor and clear screen
printf "\e[?25l\e[2J"

# Shared state file for audio synthesis modulation
INTENSITY_FILE="/tmp/bash_weather_intensity_$$"
echo "1" > "$INTENSITY_FILE"

# Generative PCM Audio Synthesizer (runs in background)
# Generates real-time ambient audio stream modulated by system load
(
    while [ -f "$INTENSITY_FILE" ]; do
        INT=$(cat "$INTENSITY_FILE" 2>/dev/null || echo 1)
        # Bytebeat synthesizer: generates low rumble thunder and high pitch wind turbulence
        perl -e '
            $int = $ARGV[0] || 1;
            for ($t = 0; $t < 4000; $t++) {
                $thunder = ($int > 3 && rand() < 0.035) ? (rand(255) & ($t ^ ($t >> 3))) : 0;
                $wind = (($t * ($int + 1) >> 3) & 63) + (rand(8) * $int);
                print chr(($wind + $thunder) & 0xFF);
            }
        ' "$INT"
    done | aplay -q -f u8 -r 8000 2>/dev/null
) &

# Visual Engine & Atmospheric Loop
while true; do
    # Fetch CPU Temperature (°C)
    TEMP=40
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        TEMP=$(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ))
    fi

    # Fetch Memory Allocation Usage (%)
    MEM_PERCENT=50
    if command -v free >/dev/null 2>&1; then
        MEM_PERCENT=$(free | awk '/Mem:/ {if ($2>0) printf "%d", $3/$2*100}')
    fi

    # Compute Atmospheric Parameters
    RAIN_DENSITY=$(( (MEM_PERCENT / 8) + 1 ))
    THROTTLE_FACTOR=$(( TEMP > 60 ? (TEMP - 55) / 2 : 1 ))
    STORM_INTENSITY=$(( THROTTLE_FACTOR + (MEM_PERCENT / 15) ))
    [ $STORM_INTENSITY -lt 1 ] && STORM_INTENSITY=1
    echo "$STORM_INTENSITY" > "$INTENSITY_FILE"

    # Terminal Dimensions
    LINES=$(tput lines 2>/dev/null || echo 24)
    COLS=$(tput cols 2>/dev/null || echo 80)

    # Trigger Algorithmic Lightning Event
    LIGHTNING=0
    if [ "$STORM_INTENSITY" -gt 3 ] && [ $((RANDOM % 7)) -eq 0 ]; then
        LIGHTNING=1
    fi

    # Render ANSI Frame Buffer
    BUFFER="\e[1;1H"
    if [ $LIGHTNING -eq 1 ]; then
        BUFFER+="\e[47m\e[1;30m⚡ THUNDERSTORM DETECTED ⚡ [TEMP: ${TEMP}°C | MEM SPIKE: ${MEM_PERCENT}% | INTENSITY: ${STORM_INTENSITY}]\e[K\e[0m\n"
    else
        BUFFER+="\e[40m\e[1;36m[ ATMOSPHERIC SYSTEM ] CPU Temp: ${TEMP}°C | Mem Load: ${MEM_PERCENT}% | Weather Level: ${STORM_INTENSITY}\e[K\e[0m\n"
    fi

    # Render Cloud Canopy
    CLOUDS=("░" "▒" "▓" "█")
    CLOUD_LINE=""
    for (( c=0; c<COLS; "$BUFFER" "%b" "'" "/" "|" "│" "💧") # $(( $LIGHTNING $RAIN_DENSITY ${#DROP_TYPES[@]} % (( )) )); -eq -lt 0.08 1 20 4 BUFFER+="${LINE_STR}\e[0m\n" CLOUD_LINE+="${CLOUDS[$idx]}" DROP_TYPES="("."" Draw Frame LINE_STR LINE_STR+=" " Matrix Pixelated RANDOM Rain Render Screen [ ]; c="0;" c++ c<COLS; d_idx="$((" do done else fi for idx="$((" if printf r="3;" r++ r<LINES; sleep then to>