#!/usr/bin/env bash
# ==============================================================================
#           A E O L I A N  •  S I N E S  •  &  •  A S C I I  •  F L U I D S
# ==============================================================================
# Algorithmic wind chime that translates live/simulated atmospheric turbulence 
# into microtonal generative soundscapes while driving a Navier-Stokes inspired 
# organic ASCII fluid simulation directly inside the terminal.
#
# Requirements: 'sox' (for audio generation), 'tput' (standard for terminal matrix)
# ==============================================================================

set -e

# Ensure clean exit: restore cursor, clear audio, reset terminal
cleanup() {
    tput cnorm
    stty echo
    kill $(jobs -p) 2>/dev/null || true
    clear
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# ------------------------------------------------------------------------------
# 1. Environment & Terminal Setup
# ------------------------------------------------------------------------------
# Check for dependencies
if ! command -v sox &>/dev/null; then
    echo "Error: 'sox' is required for the microtonal audio generation." >&2
    echo "Please install it (e.g., 'brew install sox' or 'apt-get install sox')." >&2
    exit 1
fi

# Initialize terminal constraints
tput civvis
stty -echo
clear

LINES=$(tput lines)
COLS=$(tput cols)

# ------------------------------------------------------------------------------
# 2. Physics & Microtonal Mathematical Anchors
# ------------------------------------------------------------------------------
# Generative 13-limit Just Intonation microtonal scale (Hz) based on a 110Hz root
SCALE=(110.00 123.75 137.50 144.38 165.00 178.75 192.50 220.00 247.50 275.00 330.00 385.00 440.00)
SCALE_SIZE=${#SCALE[@]}

# Fluid Simulation Matrices (Double Buffered Density & Velocity Field)
# Using a fixed internal simulation resolution for performance, mapped to screen size
NX=40
NY=20
SIZE=$((NX * NY))

declare -a density
declare -a u_vel
declare -a v_vel
declare -a density_prev
declare -a u_prev
declare -a v_prev

# Zero-initialize fluid arrays
for ((i=0; i<SIZE; "$2" "$b" "$dt "$i "$j "$x "(${x0[$idx]} "1 # $(bc $a $a") $c") $diff $dtx $dty ${iu[$idx]}") ${iv[$idx]}") ${x[$idx+1]} ${x[$idx+NX]})) ${x[$idx-NX]} ($NX ($NY (${x[$idx-1]} (( ((i="1;" ((j="1;" ((k="0;" (Navier-Stokes (Used )); * + - ------------------------------------------------------------------------------ -l -n / 0.5") 1D 2) 2)") 3. 4 < <<< Advect Approximation Bash) Diffuse Dynamics Engine Fluid Perlin/Simplex-like Pure WIND_SPEED="0.0" WIND_THETA="0.0" a="$(bc" across advect() along atmospheric b="$1" bounds c="$(bc" calculated d="$2" d0="$3" density density[i]="0.0;" density_prev[i]="0.0;" diff="0.1" diffuse() do done dt="0.1" dtx="$(bc" dty="$(bc" endpoint fi field for fronts) gust i++)); i<NX-1; idx="$((i" if in is iu="$4" iv="$5" j*NX)) j++)); j<NY-1; k++)); k<2; live local mimic molecular neighbors no noise or parameters present, providing quantities realistic sensor synthetic the then to turbulence u_prev[i]="0.0;" u_vel[i]="0.0;" v_prev[i]="0.0" v_vel[i]="0.0" vectors velocity viscosity wind x="0.5;" x0="$3" x[$idx]="$(bc" y="$(bc" { }> $NX - 1.5") )); then x=$(bc -l <<< "$NX - 1.5"); fi
            local i0=${x%.*}
            local i1=$((i0 + 1))
            
            if (( $(bc -l <<< "$y < 0.5") )); then y=0.5; fi
            if (( $(bc -l <<< "$y > $NY - 1.5") )); then y=$(bc -l <<< "$NY - 1.5"); fi
            local j0=${y%.*}
            local j1=$((j0 + 1))
            
            local s1=$(bc -l <<< "$x - $i0")
            local s0=$(bc -l <<< "1 - $s1")
            local t1=$(bc -l <<< "$y - $j0")
            local t0=$(bc -l <<< "1 - $t1")
            
            local row0=$((j0 * NX))
            local row1=$((j1 * NX))
            
            d[$idx]=$(bc -l <<< "$s0 * ($t0 * ${d0[$i0 + row0]} + $t1 * ${d0[$i0 + row1]}) + $s1 * ($t0 * ${d0[$i1 + row0]} + $t1 * ${d0[$i1 + row1]})")
        done
    done
    bounds "$b" "$2"
}

# Handle boundary reflections to keep fluid mass inside container walls
bounds() {
    local b=$1
    local -n f=$2
    for ((i=1; i<NX-1; "" "$( "$WIND_SPEED "$WIND_THETA "$amp" "$freq" "${density_prev[$C_IDX]} "${u_vel[$C_IDX]} "${v_vel[$C_IDX]} "-" "0.5 "s($FRAME # $(bc $FORCE_X") $FORCE_Y") $RANDOM ${f[$((0 ${f[$((NX-1 % & && ( (${f[$((1 (${f[$((NX-2 (( ((j="1;" (Asynchronous (NY-1)*NX))]="$(bc" (NY-1)*NX))]} (NY-2)*NX))]}") (NY-2)*NX))]})") ) )") )${f[$((1 )${f[$((NX-2 )${f[$((i )) * + - ------------------------------------------------------------------------------ -l -n -q / 0 0))]="$(bc" 0))]} 0.05 1 1*NX))]}") 1*NX))]})") 1,2 1. 10.0) 100 1200 2 2)) 2. 200.0") 3)) 4. 4.0 45.0") 5. 5.0 50 50.0 <<< ASCII Audio Backend CX="$((NX" CY C_IDX="$((CX" Calculate Chimes) Core Execution FORCE_X="$(bc" FORCE_Y="$(bc" FRAME="0" Generates Inject Loop Map Matrix Microtonal NX)) RAMP=" .:-=+*#%@" RAMP_LEN="${#RAMP}" Render Step Synthesis Update WIND_SPEED="$(bc" WIND_THETA="$(bc" a advect amp="$2" and at atmospheric auxiliary b="=" based bottom c($WIND_THETA)") center character chime chimes currents decay delay density density_prev density_prev[$C_IDX]="$(bc" diffuse do done echo energy envelope, f[$((0 f[$((NX-1 f[$((i fast fluid fluid_step() for forces forward freq="$1" hanging i++)); if in intensity into j*NX))]="$(bc" j*NX))]}") j++)); j<NY-1; live local lowpass mapped mapping metrics mimicking modeling modulated of on one open paradigm physical play play_chime() pluck pseudo-random quantum ramp remix repeat resonance. ring s($WIND_THETA)") shading sides simulation slight strike sub-harmonic synth the time to triggers true; turbulence u_vel u_vel[$C_IDX]="$(bc" using v_vel v_vel[$C_IDX]="$(bc" vector via vol walks while wind with { || }> 7.5") )); then
        S_IDX=$(( 2 + (NY/2)*NX ))
        density_prev[$S_IDX]=30.0
        u_vel[$S_IDX]=8.0
        
        # Microtonal audio strike threshold based on acoustic pressure cross-sections
        # Select octave extension or fundamental based on force vectors
        PITCH_INDEX=$(( RANDOM % SCALE_SIZE ))
        BASE_FREQ=${SCALE[$PITCH_INDEX]}
        
        # Audio amplitude derived directly from fluid pressure potential
        AMP=$(bc -l <<< "$WIND_SPEED / 12.0")
        if (( $(bc -l <<< "$AMP > 1.0") )); then AMP=1.0; fi
        
        play_chime "$BASE_FREQ" "$AMP"
    fi

    # 3. Advance Navier-Stokes simulation
    fluid_step

    # 4. Interpolate and Draw Fluid Grid to ANSI Escape Space
    OUTPUT=""
    for ((j=0; j<NY; "($val # (( ((i="0;" (LINES )) )); * + - -l / 0 1") 1.5) 2 < <<< ASCII Calculate Map NY) OUTPUT+="\033[${SCREEN_Y};$(( (COLS - NX) / 2 ))H" SCREEN_Y="$((" center char_idx characters density do fi floating for i++)); i<NX; idx="$((i" if j j*NX)) j++)); local matrix offset point positioning then to val="${density[$idx]}" vertical>= RAMP_LEN )); then char_idx=$((RAMP_LEN - 1)); fi
            
            local char="${RAMP:$char_idx:1}"
            
            # Dynamic organic coloring via terminal escapes based on energy fields
            if (( char_idx > 7 )); then
                OUTPUT+="\033[38;5;159m$char" # Pure white-blue energetic cores
            elif (( char_idx > 4 )); then
                OUTPUT+="\033[38;5;117m$char" # Atmospheric cyan bodies
            elif (( char_idx > 1 )); then
                OUTPUT+="\033[38;5;66m$char"  # Deep slate wind vectors
            else
                OUTPUT+="\033[38;5;234m$char" # Absolute micro-eddies
            fi
        done
    done
    
    # Print combined buffer frame instantly to mitigate terminal flickering
    echo -ne "$OUTPUT"
    
    # Dissipate global field energy slightly to prevent saturation overflows
    for ((i=0; i<SIZE; "${density[$i]} * + -l 0.04 0.88") 1)) <<< FRAME="$((FRAME" density[$i]="$(bc" do done i++)); sleep>