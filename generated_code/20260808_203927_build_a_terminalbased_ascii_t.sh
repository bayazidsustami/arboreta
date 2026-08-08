#!/usr/bin/env bash
# FluidText: Terminal ASCII text editor with dynamic fluid simulation & ink settling
# Typed characters swirl like fluid under heat/kinetic energy and settle when paused.

# Terminal setup & cleanup trap
trap 'printf "\e[?25h\e[0m\e[2J\e[1;1H"; stty "$ORIG_STTY"' EXIT INT TERM
ORIG_STTY=$(stty -g)
stty -echo -icanon min 0 time 0
printf "\e[?25l\e[2J"

# Terminal dimensions
COLS=$(tput cols 2>/dev/null || echo 80)
LINES=$(tput lines 2>/dev/null || echo 24)
(( COLS = COLS > 100 ? 100 : COLS ))
(( LINES = LINES > 30 ? 30 : LINES ))

# Editor state & particle storage (fixed-point math scaled by 100)
declare -a P_CHAR P_X P_Y P_VX P_VY P_TX P_TY
N_PARTICLES=0
CURSOR_X=4
CURSOR_Y=3
IDLE_TICKS=0
HEAT=0

# Helper: Random number between $1 and $2
rand() { echo $(( $1 + RANDOM % ($2 - $1 + 1) )); }

# Draw static UI frame
draw_frame() {
    printf "\e[1;1H\e[1;36m+=--- ASCII Fluid Text Editor --- [Type to write | Esc to exit] ---= \e[0m"
    printf "\e[%d;1H\e[36m+------------------------------------------------------------------+ \e[0m" "$LINES"
}

draw_frame

# Main Loop
while true; do
    # 1. Read Input (Non-blocking)
    IFS= read -rn1 -t 0.02 key
    KEY_PRESSED=0

    if [[ -n "$key" ]]; then
        KEY_PRESSED=1
        IDLE_TICKS=0
        HEAT=$(( HEAT < 1500 ? HEAT + 300 : 1500 ))

        ASCII_VAL=$(printf '%d' "'$key" 2>/dev/null || echo 0)

        if [[ "$ASCII_VAL" -eq 27 ]]; then # Escape key
            break
        elif [[ "$ASCII_VAL" -eq 127 || "$ASCII_VAL" -eq 8 ]]; then # Backspace
            if (( N_PARTICLES > 0 )); then
                (( N_PARTICLES-- ))
                unset "P_CHAR[$N_PARTICLES]" "P_X[$N_PARTICLES]" "P_Y[$N_PARTICLES]"
                unset "P_VX[$N_PARTICLES]" "P_VY[$N_PARTICLES]" "P_TX[$N_PARTICLES]" "P_TY[$N_PARTICLES]"
                (( CURSOR_X = CURSOR_X > 4 ? CURSOR_X - 1 : CURSOR_X ))
            fi
        elif [[ "$key" == "" ]]; then # Enter / Newline
            CURSOR_X=4
            (( CURSOR_Y = CURSOR_Y < LINES - 2 ? CURSOR_Y + 1 : CURSOR_Y ))
        else # Printable Character
            tx=$(( CURSOR_X * 100 ))
            ty=$(( CURSOR_Y * 100 ))

            # Spawn particle slightly offset with initial velocity boost
            P_CHAR[N_PARTICLES]="$key"
            P_X[N_PARTICLES]=$(( tx + $(rand -200 200) ))
            P_Y[N_PARTICLES]=$(( ty + $(rand -200 200) ))
            P_VX[N_PARTICLES]=$(rand -400 400)
            P_VY[N_PARTICLES]=$(rand -400 400)
            P_TX[N_PARTICLES]=$tx
            P_TY[N_PARTICLES]=$ty
            (( N_PARTICLES++ ))

            # Move cursor forward
            (( CURSOR_X++ ))
            if (( CURSOR_X > COLS - 4 )); then
                CURSOR_X=4
                (( CURSOR_Y = CURSOR_Y < LINES - 2 ? CURSOR_Y + 1 : CURSOR_Y ))
            fi
        fi
    else
        (( IDLE_TICKS++ ))
        HEAT=$(( HEAT > 10 ? HEAT * 85 / 100 : 0 ))
    fi

    # 2. Fluid & Thermal Physics Update
    # Clear active screen buffer space
    BUF="\e[2;1H"
    declare -A GRID

    for (( i=0; i<N_PARTICLES; (( )); HEAT do i++ if px="${P_X[i]};" py="${P_Y[i]}" tx="${P_TX[i]};" ty="${P_TY[i]}" vx="${P_VX[i]};" vy="${P_VY[i]}"> 50 )); then
            # Swirling fluid vortex + thermal agitation based on typing heat
            dx=$(( px - CURSOR_X * 100 ))
            dy=$(( py - CURSOR_Y * 100 ))
            
            # Vortex force perpendicular to distance vector
            vortex_x=$(( -dy * HEAT / 4000 ))
            vortex_y=$((  dx * HEAT / 4000 ))

            # Turbulent Brownian noise
            rx=$(rand -$HEAT $HEAT)
            ry=$(rand -$HEAT $HEAT)

            vx=$(( (vx + vortex_x + rx / 10) * 85 / 100 ))
            vy=$(( (vy + vortex_y + ry / 10) * 85 / 100 ))
        else
            # Cooling phase: Spring-damper attraction pulling ink back to target character positions
            ax=$(( (tx - px) * 25 / 100 ))
            ay=$(( (ty - py) * 25 / 100 ))

            vx=$(( (vx + ax) * 60 / 100 ))
            vy=$(( (vy + ay) * 60 / 100 ))
        fi

        # Update position
        px=$(( px + vx ))
        py=$(( py + vy ))

        # Boundary collision dampening
        max_x=$(( (COLS - 2) * 100 )); max_y=$(( (LINES - 2) * 100 ))
        (( px < 200 )) && { px=200; vx=$(( -vx / 2 )); }
        (( px > max_x )) && { px=$max_x; vx=$(( -vx / 2 )); }
        (( py < 200 )) && { py=200; vy=$(( -vy / 2 )); }
        (( py > max_y )) && { py=$max_y; vy=$(( -vy / 2 )); }

        P_X[i]=$px; P_Y[i]=$py
        P_VX[i]=$vx; P_VY[i]=$vy

        # Convert fixed-point back to grid coordinates
        gx=$(( px / 100 ))
        gy=$(( py / 100 ))

        # Determine ink state & ANSI color dynamics (Hot dynamic vs Settled ink)
        speed=$(( (vx < 0 ? -vx : vx) + (vy < 0 ? -vy : vy) ))
        if (( speed > 150 || HEAT > 400 )); then
            color="\e[38;5;$(( 45 + (speed / 30) % 6 ))m" # Glowing energetic cyan/blue
        elif (( speed > 30 )); then
            color="\e[38;5;39m"                          # Swirling ink blue
        else
            color="\e[1;37m"                             # Crisp solid white target text
        fi

        GRID["$gx,$gy"]="${color}${P_CHAR[i]}\e[0m"
    done

    # 3. Render Canvas
    FRAME_STR=""
    for (( y=2; y<LINES; "$FRAME_STR" "$cell" "%b" # $x,$y"]}" % && (( (IDLE_TICKS )); -n / 0 2="=" 5) CURSOR_X CURSOR_Y FRAME_STR+="\e[$y;1H$line" Show Write [[ ]]; blinking cell="${GRID[" cursor do done else fi for frame idle if line line+=" " printf target terminal then to when x="=" x++ x<="COLS;" y="=" y++>