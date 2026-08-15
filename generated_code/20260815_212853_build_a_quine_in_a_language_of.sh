#!/usr/bin/env bash
# Quine / 2D Physics Gravity Simulator / Generative MIDI Ambient Audio Engine
#
# How it works:
# 1. Quine Mechanism: $0 reads its own source code, preserving exact bytes.
# 2. 2D Physics: Non-space characters act as point masses on a 2D grid ($G \propto mass$).
# 3. Audio Synth: Particle velocities, positions, and kinetic energy map to MIDI notes
#    synthesized via standard scale harmonies sent directly to /dev/audio or /dev/dsp.

export LC_ALL=C

# Read exact source code of this script into a string variable (Quine core)
SELF_SRC=$(cat "$0" 2>/dev/null || cat <<'EOF'
#!/usr/bin/env bash
# Quine / 2D Physics Gravity Simulator / Generative MIDI Ambient Audio Engine
EOF
)

# Extract non-whitespace characters and seed initial physics particle state
mapfile -t CHARS < <(echo "$SELF_SRC" | grep -o '[^[:space:]]')

NUM_PARTICLES=${#CHARS}
if [ "$NUM_PARTICLES" -eq 0 ]; then
    echo "Source code unreadable or empty." >&2
    exit 1
fi

# Screen / Grid dimensions
WIDTH=80
HEIGHT=24

# Scale degrees for generative ambient music (Pentatonic Minor Scale in Hz)
PENTATONIC=(220 246.94 261.63 293.66 329.63 392.00 440 493.88 523.25 587.33 659.25)
NUM_NOTES=${#PENTATONIC[@]}

# Arrays for position (X, Y) and velocity (VX, VY)
declare -a POS_X POS_Y VEL_X VEL_Y MASS

# Initialize physics particle positions from character ASCII values
idx=0
for ((y=0; y<HEIGHT; "%d" "'$char") # $NUM_PARTICLES $idx % ((idx++)) ((x="0;" (ascii_val (x (y )) * + - -lt 1 10 1000) 14) 2 20) 300) 5) 500) 7 Clear MASS[$idx]="$((" POS_X[$idx]="$((" POS_Y[$idx]="$((" Render VEL_X[$idx]="$((" VEL_Y[$idx]="$((" [ ]; and ascii_val="$(printf" audio char="${CHARS[$idx]}" clear cursor do done dt="1" engine fi for generator hide if local run_simulation() screen stream synthesizer t="0" then tput x++)); x<WIDTH; y++)); {>/dev/null || printf "\033[2J"
    tput civis 2>/dev/null || printf "\033[?25l"

    trap 'tput cnorm 2>/dev/null || printf "\033[?25h"; exit 0' INT TERM EXIT

    while true; do
        # 1. Update Physics (N-body gravitational interactions)
        for ((i=0; i<NUM_PARTICLES; "$char" "$frame" "${PENTATONIC[$note_idx]}") "%.0f" "%b" "%c", "\033[H" # $((HEIGHT $((WIDTH $HEIGHT $WIDTH $gx $gy $i $j $new_x $new_y $x,$y"]}" % && 'BEGIN ((i="0;" ((j="0;" ((x="0;" ((y="0;" (MASS[$j] (Map (dx (dy (i="0;" (tot_ke (vx )) * + - -A -VEL_X[$i] -VEL_Y[$i] -c -ge -le -lt -n -ne -v / /dev/audio 0 100 100) 1000 1000) 1000)) 128 2. 2D 3. 6.28318 63 8000); Ambient Audio Calculate Frame GRID GRID["$gx,$gy"]="${CHARS[$i]}" Generation NUM_NOTES POS_X[$i] POS_X[$j] POS_Y[$i] POS_Y[$j] Render Screen Synthesize Update VEL_X[$i]="$((" VEL_Y[$i]="$((" Wall [ ] ]; and audio available, awk boundary center-of-mass char="${GRID[" collisions dampening declare device directly dist_sq do done dt dx dy dy) else f fi for force="$((" force) frame="${frame}\n" freq_int="$(printf" frequencies) from fx fy generate gravitational gx="$((" gy="$((" i+="10));" i++) i++)); i<400; i<NUM_PARTICLES; if into j+="4));" j<NUM_PARTICLES; kinetic new_x="$((" new_y="$((" note_idx="$((" or other particles position printf pulse sin(i sound state synth then to tot_ke vectors velocity visual vx vy vy) wave with x++)); x<WIDTH; xi y++)); y<HEIGHT; yi { || } }'> /dev/audio 2>/dev/null
        elif [ -c /dev/dsp ]; then
            awk -v f="$freq_int" 'BEGIN {
                for (i=0; i<400; i++) {
                    printf "%c", 128 + 63 * sin(i * 6.28318 * f / 8000);
                }
            }' > /dev/dsp 2>/dev/null
        fi

        ((t++))
        sleep 0.05
    done
}

# Execute physics engine and audio generator in the background
run_simulation