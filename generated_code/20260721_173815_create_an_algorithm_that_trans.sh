#!/usr/bin/env bash
# ==============================================================================
# SEISMIC TAPESTRY: Real-Time Global Earthquake Audio-Visual Harmonizer
# Translates live seismic feeds from USGS into harmonized audio frequencies
# and renders dynamic ANSI geometric wave distortions on the digital canvas.
# ==============================================================================

trap 'tput cnorm; clear; exit 0' INT TERM
tput civis
clear

# Pentatonic harmonized frequency scale (Hz) mapped to seismic magnitude tiers
FREQS=(261 293 329 392 440 523 587 659 783 880 1046 1174)

play_tone() {
    local freq=$1
    local duration=$2
    # Generate PCM audio tone dynamically via aplay or fallback to play/bell
    if command -v aplay &>/dev/null; then
        awk -v f="$freq" -v d="$duration" 'BEGIN {
            rate=8000; samples=rate*d;
            for(i=0; i<samples; i++) {
                v = int(127 + 120 * sin(2 * 3.14159 * f * i / rate) * exp(-3 * i / samples));
                printf("%c", v);
            }
        }' | aplay -q -r 8000 -f U8 2>/dev/null &
    elif command -v play &>/dev/null; then
        play -qn synth "$duration" sin "$freq" fade 0.01 "$duration" 0.1 2>/dev/null &
    else
        printf "\a"
    fi
}

draw_canvas() {
    local mag=$1
    local lat=$2
    local lon=$3
    local title=$4
    local freq=$5
    
    local cols=$(tput cols 2>/dev/null || echo 80)
    local lines=$(tput lines 2>/dev/null || echo 24)
    
    # Compute geometric wave distortion grid based on epicenter coordinates & magnitude
    awk -v m="$mag" -v lat="$lat" -v lon="$lon" -v w="$cols" -v h="$lines" 'BEGIN {
        chars = " .:-=+*#%@"
        n_chars = length(chars)
        
        for(y=0; y<h-3; y++) {
            row = ""
            for(x=0; x<w; x++) {
                nx = (x - w/2) / (w/2)
                ny = (y - h/2) / (h/2)
                
                # Wave propagation geometry distorted by latitude & longitude phase shifts
                dist = sqrt(nx*nx + ny*ny)
                wave = sin(dist * (m * 2 + 1) - atan2(ny, nx) * (lat / 10))
                distort = cos(nx * m + wave * (lon / 30))
                
                val = int(((wave + distort + 2) / 4) * (n_chars - 1))
                if (val < 0) val = 0
                if (val >= n_chars) val = n_chars - 1
                
                color = 31 + int(m * 2) % 6
                ch = substr(chars, val+1, 1)
                row = row sprintf("\033[%dm%s\033[0m", color, ch)
            }
            printf "\033[%d;1H%s", y+1, row
        }
    }'
    
    # Overlay real-time seismic event status HUD
    printf "\033[%d;1H\033[1;33m[ EARTHQUAKE DETECTED ] Mag: %.1f | Loc: %s\033[K\033[0m" "$((lines-1))" "$mag" "$title"
    printf "\033[%d;1H\033[1;36mHarmonized Key Freq: %d Hz | Geo Phase Shift: Lat %.2f / Lon %.2f\033[K\033[0m" "$lines" "$freq" "$lat" "$lon"
}

USGS_URL="[https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson](https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson)"

# Main event loop
while true; do
    data=$(curl -s "$USGS_URL" 2>/dev/null)
    
    if [[ -n "$data" ]]; then
        readarray -t quakes < <(echo "$data" | awk '
            BEGIN { RS="\"type\":\"Feature\"" }
            NR>1 {
                mag = 0; title = "Unknown"; lat = 0; lon = 0
                if (match($0, /"mag":([0-9\.-]+)/, m)) mag = m[1]
                if (match($0, /"title":"([^"]+)"/, t)) title = t[1]
                if (match($0, /"coordinates":\[([0-9\.-]+),([0-9\.-]+)/, c)) { lon = c[1]; lat = c[2] }
                if (mag > 0) print mag "|" lat "|" lon "|" title
            }
        ')
        
        if [ ${#quakes[@]} -gt 0 ]; then
            for q in "${quakes[@]}"; do
                IFS='|' read -r mag lat lon title <<< "$q"
                
                mag_clean=$(echo "$mag" | awk '{print ($1 < 0 ? 0 : $1)}')
                key_idx=$(awk -v m="$mag_clean" -v max="${#FREQS[@]}" 'BEGIN { idx=int(m*2); if(idx>=max) idx=max-1; print idx }')
                freq=${FREQS[$key_idx]}
                
                draw_canvas "$mag_clean" "$lat" "$lon" "$title" "$freq"
                play_tone "$freq" 0.5
                
                sleep 0.8
            done
        fi
    fi
    sleep 2
done