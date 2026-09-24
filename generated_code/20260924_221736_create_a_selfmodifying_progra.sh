#!/usr/bin/env bash
# Self-modifying ambient log-to-audio and dynamic Voronoi wallpaper generator

# Self-modification: append execution hash to evolve internal state
echo "# state: $(date +%s%N | md5sum | head -c 8)" >> "$0"

# Determine log source (syslog or systemd journal stream)
LOG_SRC="/var/log/syslog"
[ -f "$LOG_SRC" ] || LOG_SRC=<(journalctl -f -n 0 --no-pager 2>/dev/null)

# Process live system logs into polyphonic ambient sounds and shifting visuals
tail -fn0 "$LOG_SRC" | while read -r line; do
    # Derive frequency from log line length for procedural soundscape
    len=${#line}
    freq=$(( 110 + (len * 29) % 880 ))
    
    # Generate ambient sine wave tone if SoX is available
    if command -v sox &>/dev/null; then
        play -n synth 0.8 sine "$freq" gain -25 echo 0.8 0.8 150 0.4 trim 0 0.8 &>/dev/null &
    fi

    # Render shifting Voronoi/geometric desktop wallpaper if ImageMagick is available
    if command -v convert &>/dev/null; then
        wall="/tmp/ambient_voronoi.png"
        rand_x=$((RANDOM % 1920))
        rand_y=$((RANDOM % 1080))
        rand_color="rgb($((RANDOM % 256)),$((RANDOM % 200)),$((RANDOM % 256)))"
        
        convert -size 1920x1080 xc:'#0f0f17' \
            -fill "$rand_color" -draw "circle $rand_x,$rand_y $((rand_x + 50)),$rand_y" \
            -blur 0x15 "$wall" 2>/dev/null

        # Apply wallpaper across common desktop environments
        if command -v feh &>/dev/null; then
            feh --bg-scale "$wall" 2>/dev/null
        elif command -v gsettings &>/dev/null; then
            gsettings set org.gnome.desktop.background picture-uri "file://$wall" 2>/dev/null
        fi
    fi
done