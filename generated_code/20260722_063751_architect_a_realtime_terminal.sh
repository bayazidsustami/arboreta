#!/usr/bin/env bash
# Cosmic Flora: Real-time system metrics rendered as interactive blooming fluid flora
# Reads CPU temperature & memory usage, driving a coupled grid simulation with particle dynamics.
# Controls: Press 'q' or Esc to quit.

export LC_ALL=C
stty -echo -icanon min 0 time 0 2>/dev/null
trap 'printf "\033[?25h\033[0m\033[2J\033[1;1H"; stty echo icanon 2>/dev/null; exit 0' EXIT INT TERM

# Utility to get system stats (CPU Temp & Memory %)
get_stats() {
    # CPU Temp
    local t=""
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        t=$(< /sys/class/thermal/thermal_zone0/temp)
        cpu_temp=$((t / 1000))
    elif command -v sysctl >/dev/null 2>&1; then
        t=$(sysctl -n hw.acpi.thermal.tz0.temperature 2>/dev/null | grep -oE '[0-9.]+' | cut -d. -f1)
        cpu_temp=${t:-45}
    else
        cpu_temp=50
    fi

    # Memory Usage %
    if [[ -f /proc/meminfo ]]; then
        local total free avail
        total=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
        avail=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
        if [[ -n "$total" && -n "$avail" && "$total" -gt 0 ]]; then
            mem_pct=$(( (total - avail) * 100 / total ))
        else
            mem_pct=50
        fi
    else
        mem_pct=50
    fi
}

# Terminal dimensions
LINES=$(tput lines 2>/dev/null || echo 24)
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Colors and characters for flora layers
FLORA_CHARS=(" " "." "·" "✦" "✧" "❋" "❊" "❀" "✿" "❁" "❃" "❄")
PALETTE_LOW=(18 19 20 21 27 33 39 45 51 50)       # Deep space blue -> cyan (Cool CPU)
PALETTE_MID=(28 34 40 46 82 118 154 190 226)    # Lush neon green -> yellow (Balanced)
PALETTE_HIGH=(202 208 214 196 201 207 213 225)   # Fiery magenta -> super nova white (Hot CPU)

# Particle system arrays
NUM_PARTICLES=35
px=() py=() vx=() vy=() age=() max_age=() char_idx=()

for ((i=0; i<NUM_PARTICLES; "\033[?25l\033[2J" # & 'q' (quit -n -r / 1 2 2)) Check ESC) Hide age[i]="100" char_idx[i]="0" clear cursor do done for frame="0" i++)); input key max_age[i]="100" on or printf px[i]="$((COLUMNS" py[i]="$((LINES" read screen true; user vx[i]="0" vy[i]="0" while>/dev/null
    if [[ "$key" == "q" || "$key" == $'\e' ]]; then
        break
    fi

    # Refresh metrics every 5 frames
    if (( frame % 5 == 0 )); then
        get_stats
        LINES=$(tput lines 2>/dev/null || echo 24)
        COLUMNS=$(tput cols 2>/dev/null || echo 80)
    fi

    # Color mapping based on CPU temperature
    if (( cpu_temp < 50 )); then
        palette=("${PALETTE_LOW[@]}")
    elif (( cpu_temp < 75 )); then
        palette=("${PALETTE_MID[@]}")
    else
        palette=("${PALETTE_HIGH[@]}")
    fi
    p_len=${#palette[@]}

    # Build screen buffer
    out="\033[1;1H"

    # Spawn/update seeds (flora petals) based on dynamic fluid force fields
    cx=$((COLUMNS / 2))
    cy=$((LINES / 2))
    
    # Fluid pulsation frequency governed by memory usage
    pulse_freq=$(( (mem_pct / 10) + 1 ))
    bloom_radius=$(( (mem_pct * LINES) / 250 + 4 ))

    for ((i=0; i<NUM_PARTICLES; (( age[i] do i++)); if>= max_age[i] )); then
            px[i]=$cx
            py[i]=$cy
            
            # Angle and speed modulated by frame and index
            angle_deg=$(( (i * 360 / NUM_PARTICLES + frame * pulse_freq) % 360 ))
            # Simple integer trigonometry approximations
            case $(( (angle_deg / 45) % 8 )) in
                0) vx[i]=2;  vy[i]=0 ;;
                1) vx[i]=2;  vy[i]=1 ;;
                2) vx[i]=0;  vy[i]=1 ;;
                3) vx[i]=-2; vy[i]=1 ;;
                4) vx[i]=-2; vy[i]=0 ;;
                5) vx[i]=-2; vy[i]=-1 ;;
                6) vx[i]=0;  vy[i]=-1 ;;
                7) vx[i]=2;  vy[i]=-1 ;;
            esac
            
            age[i]=0
            max_age[i]=$(( bloom_radius + (RANDOM % 5) ))
            char_idx[i]=$(( RANDOM % ${#FLORA_CHARS[@]} ))
        fi

        # Fluid field drift: add swirl vector
        dx=$(( px[i] - cx ))
        dy=$(( py[i] - cy ))
        
        # Apply velocity + rotational force (vortex)
        px[i]=$(( px[i] + vx[i] - (dy / 4) ))
        py[i]=$(( py[i] + vy[i] + (dx / 6) ))
        (( age[i]++ ))
    done

    # Render frame buffer with particle states
    # Buffer grid setup
    declare -A grid_char grid_col

    for ((i=0; i<NUM_PARTICLES; (( do i++)); if x y="${py[i]}"> 1 && x < COLUMNS && y > 1 && y < LINES )); then
            # Color intensity shifts from stem to tip based on age
            col_i=$(( (age[i] * p_len) / (max_age[i] + 1) ))
            (( col_i >= p_len )) && col_i=$(( p_len - 1 ))
            
            grid_char["$x,$y"]="${FLORA_CHARS[char_idx[i]]}"
            grid_col["$x,$y"]="${palette[col_i]}"
        fi
    done

    # Draw cosmic core stem
    grid_char["$cx,$cy"]="❁"
    grid_col["$cx,$cy"]="226"

    # Assemble visual buffer stream
    for ((y=1; y<=LINES-2; y++)); do
        out+="\033[${y};1H\033[K"
        for ((x=1; x<=COLUMNS; x++)); do
            if [[ -n "${grid_char["$x,$y"]}" ]]; then
                c=${grid_char["$x,$y"]}
                col=${grid_col["$x,$y"]}
                out+="\033[38;5;${col}m${c}"
            else
                out+=" "
            fi
        done
    done

    # Render Telemetry Overlay
    status="[ COSMIC FLORA ]  CPU HEAT: ${cpu_temp}°C  |  MEM ALLOC: ${mem_pct}%  (Press 'q' to exit)"
    out+="\033[${LINES};1H\033[0;44;37m ${status} \033[0m"

    # Write frame to terminal
    printf "%b" "$out"

    ((frame++))
    sleep 0.05
done