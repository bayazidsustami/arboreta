#!/usr/bin/env bash

# Non-Euclidean ASCII Text Editor
# Typing text adds mass to the cursor singularity. The surrounding text physically curves,
# orbits, and shifts into fractal constellations calculated via integer spacetime warping.

# Restore terminal settings on exit
cleanup() {
    stty sane
    printf "\033[?25h\033[2J\033[1;1H"
    exit 0
}
trap cleanup EXIT INT TERM

# Screen metrics
COLS=$(tput cols 2>/dev/null || echo 80)
LINES=$(tput lines 2>/dev/null || echo 24)

# Singularity / Gravitational Cursor Position & Mass
sing_x=$((COLS / 2))
sing_y=$((LINES / 2))
mass=8

# Typing position offset
type_x=4
type_y=4

# Buffer arrays for stored characters and physics metadata
chars=()
orig_x=()
orig_y=()
cmplx=()

# Configure raw terminal input and hide cursor
stty -echo -icanon min 0 time 0
printf "\033[?25l"

# Main Event Loop
while true; do
    # Clear terminal screen frame
    printf "\033[2J\033[1;1H"

    # Render Non-Euclidean Header
    printf "\033[1;37;44m [NON-EUCLIDEAN ASCII EDITOR] Spacetime Mass: %-4d | Singularity: (%d,%d) | Arrows: Shift Core | ESC: Exit \033[0m" "$mass" "$sing_x" "$sing_y"

    # Draw Gravitational Core / Event Horizon
    printf "\033[%d;%dH\033[1;35;5m⚛\033[0m" "$sing_y" "$sing_x"

    # Render curved and orbiting text particles
    for ((i=0; i<${#chars[@]}; i++)); do
        c="${chars[i]}"
        ox=${orig_x[i]}
        oy=${orig_y[i]}
        cmp=${cmplx[i]}

        # Distance vector relative to singularity
        dx=$((ox - sing_x))
        dy=$(( (oy - sing_y) * 2 )) # Aspect ratio correction
        r2=$((dx*dx + dy*dy + 1))

        # Gravitational attraction force (inverse-square-like)
        pull=$(( (mass * 50) / (r2 + 4) ))

        # Orbital fractal spin force based on character semantic complexity
        spin=$(( (cmp * mass * 15) / (r2 + 4) ))

        # Calculate warped space coordinates (rx, ry)
        rx=$(( ox - (dx * pull) / 35 - (dy * spin) / 35 ))
        ry=$(( oy - (dy * pull) / 70 + (dx * spin) / 70 ))

        # Clamp boundaries
        (( rx < 1 )) && rx=1
        (( rx > COLS )) && rx=$COLS
        (( ry < 2 )) && ry=2
        (( ry > LINES )) && ry=$LINES

        # Gravitational redshift coloring based on proximity to core
        if (( r2 < 20 )); then
            color="\033[1;31m" # Event Horizon Red
        elif (( r2 < 80 )); then
            color="\033[1;33m" # Accretion Disk Yellow
        elif (( r2 < 200 )); then
            color="\033[1;36m" # Orbital Cyan
        else
            color="\033[0;37m" # Deep Space White
        fi

        # Draw particle at non-Euclidean position
        printf "\033[%d;%dH%b%s\033[0m" "$ry" "$rx" "$color" "$c"
    done

    # Draw active typing reticle
    printf "\033[%d;%dH\033[1;32m_\033[0m" "$type_y" "$type_x"

    # Handle Input (Non-blocking)
    read -rn1 -t 0.03 key
    if [[ "$key" == $'\x1b' ]]; then
        read -rn2 -t 0.01 rest
        if [[ "$rest" == "[A" ]]; then ((sing_y > 2)) && ((sing_y--)); # Up
        elif [[ "$rest" == "[B" ]]; then ((sing_y < LINES)) && ((sing_y++)); # Down
        elif [[ "$rest" == "[D" ]]; then ((sing_x > 1)) && ((sing_x--)); # Left
        elif [[ "$rest" == "[C" ]]; then ((sing_x < COLS)) && ((sing_x++)); # Right
        else break; fi # Bare ESC exits
    elif [[ "$key" == $'\x7f' || "$key" == $'\x08' ]]; then
        # Backspace: Collapse spacetime mass
        if (( ${#chars[@]} > 0 )); then
            idx=$((${#chars[@]} - 1))
            unset 'chars[idx]'
            unset 'orig_x[idx]'
            unset 'orig_y[idx]'
            unset 'cmplx[idx]'
            chars=("${chars[@]}")
            orig_x=("${orig_x[@]}")
            orig_y=("${orig_y[@]}")
            cmplx=("${cmplx[@]}")
            ((type_x > 4)) && ((type_x--))
            ((mass > 5)) && ((mass--))
        fi
    elif [[ -n "$key" ]]; then
        # Calculate semantic complexity from ASCII encoding
        ascii_val=$(LC_ALL=C printf '%d' "'$key")
        complexity=$(( (ascii_val % 9) + 1 ))

        # Append to buffer
        chars+=("$key")
        orig_x+=($type_x)
        orig_y+=($type_y)
        cmplx+=($complexity)

        # Advance typing reticle
        ((type_x++))
        if (( type_x >= COLS - 3 )); then
            type_x=4
            ((type_y++))
            (( type_y >= LINES )) && type_y=2
        fi

        # Increase local gravitational pull with input
        if [[ "$key" == " " ]]; then
            ((mass += 3)) # Words increase mass faster
        else
            ((mass += 1))
        fi
    fi
done