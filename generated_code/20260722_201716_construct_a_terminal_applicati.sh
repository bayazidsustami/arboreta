#!/usr/bin/env bash
# ==============================================================================
# 3D ASCII History Labyrinth
# Parses shell history for typos/commands, renders an endless 3D raycasted
# maze, and adjusts ambient lighting/colors dynamically based on typing speed.
# ==============================================================================

# Restore terminal state upon exit
cleanup() {
    printf "\e[?25h\e[0m\e[2J\e[H"
    stty echo cooked 2>/dev/null
    exit 0
}
trap cleanup EXIT INT TERM

# Hide cursor & enable raw input mode
stty -echo raw 2>/dev/null
printf "\e[?25l\e[2J"

# 1. Parse history for wall texture material (extract typos & frequent tokens)
extract_typos() {
    local hist_file=""
    [[ -f "$HOME/.bash_history" ]] && hist_file="$HOME/.bash_history"
    [[ -f "$HOME/.zsh_history" ]] && hist_file="$HOME/.zsh_history"
    
    local words=""
    if [[ -n "$hist_file" ]]; then
        words=$(grep -oE '\b[a-zA-Z]{3,12}\b' "$hist_file" 2>/dev/null | sort | uniq -c | sort -nr | head -n 40 | awk '{print $2}' | tr '\n' ' ')
    fi
    if [[ -z "$words" ]]; then
        words="sl gerp vmi cd.. pud chmdo cleam soos gti tatus diff"
    fi
    echo "$words"
}

TYPO_WORDS=$(extract_typos)
TYPO_CHARS="${TYPO_WORDS// /}"

# Terminal dimensions
get_termsize() {
    read -r LINES COLUMNS < <(stty size 2>/dev/null || echo "24 80")
    WIDTH=${COLUMNS:-80}
    HEIGHT=${LINES:-24}
    HALF_H=$((HEIGHT / 2))
}
get_termsize

# Precompute fixed-point Trigonometry (scale factor 1000)
FP=1000
eval "$(awk -v fp=$FP 'BEGIN {
    for(i=0; i<360; i++) {
        rad = i * 3.141592653589793 / 180.0;
        printf "SIN[%d]=%d; COS[%d]=%d; ", i, int(sin(rad)*fp), i, int(cos(rad)*fp);
    }
}')"

# Infinite Procedural Labyrinth Wall Evaluator
is_wall() {
    local mx=$1 my=$2
    # Seed hash for dynamic maze structures
    local h=$(( ((mx * 73856093) ^ (my * 19349663)) % 100 ))
    [[ $h -lt 0 ]] && h=$(( -h ))
    local gx=$(( (mx < 0 ? -mx : mx) % 3 ))
    local gy=$(( (my < 0 ? -my : my) % 3 ))
    if (( gx == 0 && gy == 0 )); then
        return 0
    elif (( h < 42 && (gx == 0 || gy == 0) )); then
        return 0
    fi
    return 1
}

# Player Position (scaled x1000) & Orientation
PX=1500
PY=1500
PA=0

# Speed and Ambient Light system variables
LAST_KEY_TIME=$(date +%s%N 2>/dev/null || echo 0)
SPEED_LEVEL=0

# Main Render Engine
render_frame() {
    get_termsize
    local typo_len=${#TYPO_CHARS}
    local fov=60

    # Raycast buffers
    local -a col_dist col_char col_color

    # Determine typing speed / light intensity
    local now
    now=$(date +%s%N 2>/dev/null || echo 0)
    local dt=1000000000
    if [[ $now -ne 0 && $LAST_KEY_TIME -ne 0 ]]; then
        dt=$(( now - LAST_KEY_TIME ))
    fi

    if (( dt < 150000000 )); then
        SPEED_LEVEL=4 # Overdrive: Cyberpunk Cyan/Magenta
    elif (( dt < 350000000 )); then
        SPEED_LEVEL=3 # Fast: Bright Amber
    elif (( dt < 700000000 )); then
        SPEED_LEVEL=2 # Moderate: Emerald Green
    elif (( SPEED_LEVEL > 0 )); then
        (( SPEED_LEVEL-- ))
    fi

    # Raycasting across screen width
    for (( x=0; x<WIDTH; "$map_x" "$map_y"; # $char_idx % & && (( (23 (PA (cos_a (hit_x (max_dist (sin_a (x )) )); * + - -char_idx -lt / 0 1 13 200) 232 360 360) 4)) 7 < ANSI Dynamic FP FP)) PX PY Texture WIDTH WIDTH/2) [[ ]] break char_idx="$((" character col_char[x]="${TYPO_CHARS:$char_idx:1}" col_dist[x]="$dist" color cos_a="${COS[$ray_a]}" curr_x curr_y dist dist) dist)) do done extraction fi fov from hit="=" hit_x="$map_x" hit_y if is_wall lighting local map_x="$((" map_y="$((" mapping max_dist offset_angle ray_a="$((" shade sin_a="${SIN[$ray_a]}" step_dist then typo_len typos while x++> 255 )) && shade=255; (( shade < 232 )) && shade=232

            case $SPEED_LEVEL in
                4) col_color[x]="\e[38;5;51m" ;;  # Neon Cyan
                3) col_color[x]="\e[38;5;214m" ;; # Amber Gold
                2) col_color[x]="\e[38;5;46m" ;;  # Neon Green
                *) col_color[x]="\e[38;5;${shade}m" ;; # Dim Monochromatic Ambient
            esac
        else
            col_char[x]=" "
            col_color[x]="\e[0m"
        fi
    done

    # Draw Frame Buffer
    local frame=""
    for (( y=0; y<HEIGHT; (( (HEIGHT (d )) )); * + / 1) FP) d="${col_dist[x]}" do for line local wall_h x="0;" x++ x<WIDTH; y++> HEIGHT )) && wall_h=$HEIGHT

            local top=$(( (HEIGHT - wall_h) / 2 ))
            local bottom=$(( top + wall_h ))

            if (( y >= top && y <= bottom && d < 7*FP )); then
                line+="${col_color[x]}${col_char[x]}"
            elif (( y > bottom )); then
                # Floor shading
                line+="\e[38;5;235m."
            else
                # Ceiling / Sky
                line+=" "
            fi
        done
        frame+="\e[${y};1H${line}"
    done

    # HUD Status Bar
    local hud=" [3D Labyrinth] Pos: ($((PX/FP)),$((PY/FP))) | Speed Lighting: Lvl ${SPEED_LEVEL} | Typo Walls Active "
    frame+="\e[${HEIGHT};1H\e[47;30m${hud:\x0:WIDTH}\e[0m"

    printf "%b" "$frame"
}

# Input Handling & Navigation Engine
while true; do
    render_frame
    
    # Non-blocking input read
    read -rsn1 -t 0.05 key 2>/dev/null
    if [[ -n "$key" ]]; then
        LAST_KEY_TIME=$(date +%s%N 2>/dev/null || echo 0)
        
        # Handle Arrow keys & WASD
        if [[ "$key" == $'\e' ]]; then
            read -rsn2 -t 0.001 rest 2>/dev/null
            key+="$rest"
        fi

        case "$key" in
            w|W|$'\e[A') # Forward
                nx=$(( PX + (COS[PA] * 300) / FP ))
                ny=$(( PY + (SIN[PA] * 300) / FP ))
                ! is_wall $((nx/FP)) $((ny/FP)) && PX=$nx && PY=$ny
                ;;
            s|S|$'\e[B') # Backward
                nx=$(( PX - (COS[PA] * 300) / FP ))
                ny=$(( PY - (SIN[PA] * 300) / FP ))
                ! is_wall $((nx/FP)) $((ny/FP)) && PX=$nx && PY=$ny
                ;;
            a|A|$'\e[D') # Rotate Left
                PA=$(( (PA - 15 + 360) % 360 ))
                ;;
            d|D|$'\e[C') # Rotate Right
                PA=$(( (PA + 15) % 360 ))
                ;;
            q|Q)
                break
                ;;
        esac
    fi
done