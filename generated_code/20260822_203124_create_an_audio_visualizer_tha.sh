#!/usr/bin/env bash
# Real-Time Audio-Driven ASCII Fluid Simulation
# Reads raw audio from microphone (via parec or rec), computes energy,
# and updates a 2D grid using simplified Navier-Stokes fluid advection & diffusion.

set -e

# Screen dimensions
WIDTH=60
HEIGHT=30
SIZE=$((WIDTH * HEIGHT))

# Density ASCII gradient (from sparse to dense)
GLYPHS=(" " "." ":" "-" "=" "+" "*" "%" "@" "#")
NUM_GLYPHS=${#GLYPHS[@]}

# Arrays for Fluid Physics (Velocity X, Velocity Y, Density, Divergence, Pressure)
declare -a u v u_prev v_prev density density_prev

for ((i=0; i<SIZE; "\033[0m" # -e 0 2 Cleanup Reset Show cleanup() cnorm color cursor density[i]="0.0;" density_prev[i]="0.0" do done echo exit i++)); kill on terminal tput u[i]="0.0;" u_prev[i]="0.0;" v[i]="0.0;" v_prev[i]="0.0" {>/dev/null || true
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# Setup screen
tput civis # Hide cursor
clear

# Detect audio capture tool (PulseAudio 'parec' or Sox 'rec')
AUDIO_CMD=""
if command -v parec &>/dev/null; then
    AUDIO_CMD="parec --format=u8 --rate=8000 --channels=1"
elif command -v rec &>/dev/null; then
    AUDIO_CMD="rec -q -t raw -r 8000 -c 1 -b 8 -e unsigned-integer -"
else
    # Fallback to noise if no mic tool is installed
    AUDIO_CMD="head -c 1024 /dev/urandom"
fi

# Launch background audio stream
FIFO=$(mktemp -u)
mkfifo "$FIFO"
$AUDIO_CMD > "$FIFO" 2>/dev/null &
AUDIO_PID=$!
exec 3<"$FIFO"
rm "$FIFO"

# Index helper: 2D to 1D
idx() {
    echo $(( $1 + $2 * WIDTH ))
}

# Add source energy from microphone input
inject_audio_energy() {
    local level=0
    # Read a chunk of bytes from audio pipe
    if read -N 128 -u 3 raw_bytes 2>/dev/null; then
        local sum=0
        local count=0
        for ((k=0; k<${#raw_bytes}; k++)); do
            LC_CTYPE=C printf -v val "%d" "'${raw_bytes:$k:1}"
            local diff=$((val - 128))
            sum=$((sum + (diff < 0 ? -diff : diff)))
            count=$((count + 1))
        done
        [ $count -gt 0 ] && level=$((sum / count))
    fi

    # Inject fluid velocity and density at the bottom-center
    if [ "$level" -gt 2 ]; then
        local cx=$((WIDTH / 2))
        local cy=$((HEIGHT - 3))
        local i=$(idx $cx $cy)
        local force=$(awk -v l="$level" 'BEGIN {print l * 0.15}')
        
        density[$i]=$(awk -v d="${density[$i]}" -v f="$force" 'BEGIN {print d + f * 5.0}')
        v[$i]=$(awk -v v_val="${v[$i]}" -v f="$force" 'BEGIN {print v_val - f * 2.0}')
        u[$i]=$(awk -v u_val="${u[$i]}" 'BEGIN {print u_val + (rand() - 0.5) * 2.0}')
    fi
}

# Simplified fluid advection step
advect() {
    local dt=0.2
    for ((y=1; y<HEIGHT-1; # $x $y) 'BEGIN ((x="1;" (sx * - -v 1 : < ? Trace back based do dt="$dt" dt; for i="$(idx" local on position print src_x="$(awk" sx="x" u_val velocity x="$x" x++)); x<WIDTH-1; y++)); {> '$WIDTH'-2 ? '$WIDTH'-2 : int(sx)))
            }')
            local src_y=$(awk -v y="$y" -v v_val="${v[$i]}" -v dt="$dt" 'BEGIN {
                sy = y - v_val * dt;
                print (sy < 1 ? 1 : (sy > '$HEIGHT'-2 ? '$HEIGHT'-2 : int(sy)))
            }')
            
            local src_i=$(idx $src_x $src_y)
            density_prev[$i]=${density[$src_i]}
            u_prev[$i]=${u[$src_i]}
            v_prev[$i]=${v[$src_i]}
        done
    done

    # Decay density and copy back
    for ((i=0; i<SIZE; # $x $y) 'BEGIN ((x="0;" ((y="0;" (idx * -v 0.92}') 0.95}') ASCII Map Move Render buffer="\033[H" d="$d" density density[$i]="$(awk" do done fluid for g_idx="$(awk" glyph grid home i="$(idx" i++)); idx="int(d);" local max="$NUM_GLYPHS" print render() terminal to u[$i]="$(awk" v[$i]="$(awk" val x++)); x<WIDTH; y++)); y<HEIGHT; { {print }>= max ? max - 1 : (idx < 0 ? 0 : idx))
            }')
            local glyph="${GLYPHS[$g_idx]}"

            # Map velocity/turbulence to ANSI 256 color
            local speed=$(awk -v u_val="${u[$i]}" -v v_val="${v[$i]}" 'BEGIN {
                print int(sqrt(u_val*u_val + v_val*v_val) * 10)
            }')
            
            local color=235 # Dark default background
            if [ "$g_idx" -gt 0 ]; then
                if [ "$speed" -gt 15 ]; then
                    color=196 # High velocity: Red
                elif [ "$speed" -gt 8 ]; then
                    color=208 # Medium velocity: Orange
                elif [ "$g_idx" -gt 4 ]; then
                    color=45  # Dense fluid: Cyan
                else
                    color=27  # Light fluid: Blue
                fi
            fi

            buffer+="\033[38;5;${color}m${glyph}"
        done
        buffer+="\n"
    done
    echo -ne "$buffer"
}

# Main simulation loop
while true; do
    inject_audio_energy
    advect
    render
    sleep 0.03
done