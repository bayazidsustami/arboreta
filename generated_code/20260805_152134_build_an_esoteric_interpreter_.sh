#!/usr/bin/env bash
# Esoteric Interpreter: OpticScript Refraction Engine
# Source code: PPM image (P3 ASCII format).
# Execution: Simulated light ray navigates optical densities derived from pixel RGB values.
# Gradient vectors refract or reflect the ray, manipulating execution memory state.
# Output: Generates an ASCII/ANSI caustics pattern representing final memory density.

set -euo pipefail

IMAGE_FILE="${1:-source.ppm}"

# Generate default esoteric source image if missing
if [[ ! -f "$IMAGE_FILE" ]]; then
    cat << 'EOF' > "$IMAGE_FILE"
P3
16 16
255
255 0 0   200 50 0   150 100 0  100 150 0  50 200 0   0 255 0   0 200 50  0 150 100
0 100 150 0 50 200  0 0 255    50 0 200   100 0 150  150 0 100 200 0 50 255 0 0
200 50 0  255 255 0 150 100 0  100 150 0  50 200 0   0 255 0   0 200 50  0 150 100
0 100 150 0 50 200  0 0 255    50 0 200   100 0 150  150 0 100 200 0 50 255 255 255
100 0 200 200 50 0  150 100 0  100 150 0  50 200 0   0 255 0   0 200 50  0 150 100
0 100 150 0 50 200  0 0 255    50 0 200   100 0 150  150 0 100 200 0 50 255 0 0
50 200 0  200 50 0  150 100 0  100 150 0  50 200 0   0 255 0   0 200 50  0 150 100
0 100 150 0 50 200  0 0 255    50 0 200   100 0 150  150 0 100 200 0 50 255 100 50
0 255 0   200 50 0  150 100 0  100 150 0  50 200 0   0 255 0   0 200 50  0 150 100
0 100 150 0 50 200  0 0 255    50 0 200   100 0 150  150 0 100 200 0 50 255 0 0
0 200 50  200 50 0  150 100 0  100 150 0  50 200 0   0 255 0   0 200 50  0 150 100
0 100 150 0 50 200  0 0 255    50 0 200   100 0 150  150 0 100 200 0 50 255 0 200
0 150 100 200 50 0  150 100 0  100 150 0  50 200 0   0 255 0   0 200 50  0 150 100
0 100 150 0 50 200  0 0 255    50 0 200   100 0 150  150 0 100 200 0 50 255 0 0
0 100 150 200 50 0  150 100 0  100 150 0  50 200 0   0 255 0   0 200 50  0 150 100
0 100 150 0 50 200  0 0 255    50 0 200   100 0 150  150 0 100 200 0 50 255 255 0
EOF
fi

# Parse PPM Header
exec 3< "$IMAGE_FILE"
read -u 3 MAGIC
if [[ "$MAGIC" != "P3" ]]; then
    echo "Error: Source must be an ASCII PPM image (P3 format)." >&2
    exit 1
fi

read -u 3 LINE
while [[ "$LINE" =~ ^# ]]; do read -u 3 LINE; done
WIDTH=$(echo "$LINE" | awk '{print $1}')
HEIGHT=$(echo "$LINE" | awk '{print $2}')
read -u 3 MAXVAL

# Load pixels into optical density map (n) and initialize caustics memory map
declare -A OPTICAL_DENSITY
declare -A CAUSTICS_MEMORY

raw_rgb=($(cat <&3))
exec 3<&-

idx=0
for ((y=0; y<HEIGHT; # (( ((x="0;" (r (returns )) + / 0 100 3 < CAUSTICS_MEMORY["$x,$y"]="0" Compute OPTICAL_DENSITY["$x,$y"]="$density" Safe ambient b="${raw_rgb[$((idx+2))]}" b) boundary) brightness density do done for g get_density() idx="$((idx+3))" if index local lookup n="100" outside px py="$2" r="${raw_rgb[$idx]}" refractive scaled: vacuum x++)); x<WIDTH; y++)); { ||>= WIDTH || py < 0 || py >= HEIGHT )); then
        echo 100
    else
        echo "${OPTICAL_DENSITY["$px,$py"]}"
    fi
}

# Ray Execution State
rx=0
ry=0
vx=1
vy=1
MAX_PHOTON_STEPS=600

# Ray Refraction Engine Loop
for ((step=0; step<MAX_PHOTON_STEPS; # (( 0 < Boundary check do if ix iy="$ry" step++)); ||>= WIDTH || iy < 0 || iy >= HEIGHT )); then
        break
    fi

    # Record light photon deposition in memory state
    CAUSTICS_MEMORY["$ix,$iy"]=$(( CAUSTICS_MEMORY["$ix,$iy"] + 1 ))

    # Compute spatial refractive gradient (Snell's Law approximation: dn/dx, dn/dy)
    n_right=$(get_density $((ix+1)) $iy)
    n_left=$(get_density $((ix-1)) $iy)
    n_down=$(get_density $ix $((iy+1)))
    n_up=$(get_density $ix $((iy-1)))

    grad_x=$(( n_right - n_left ))
    grad_y=$(( n_down - n_up ))

    # Refract ray towards higher optical density
    if (( grad_x > 15 )); then vx=$((vx + 1)); fi
    if (( grad_x < -15 )); then vx=$((vx - 1)); fi
    if (( grad_y > 15 )); then vy=$((vy + 1)); fi
    if (( grad_y < -15 )); then vy=$((vy - 1)); fi

    # Clamp ray directional momentum
    (( vx > 2 )) && vx=2; (( vx < -2 )) && vx=-2
    (( vy > 2 )) && vy=2; (( vy < -2 )) && vy=-2
    if (( vx == 0 && vy == 0 )); then vx=1; vy=1; fi

    # Step forward
    rx=$((ix + vx))
    ry=$((iy + vy))
done

# Render Memory State as Generative Caustics Pattern
CHARMAP=(" " "." ":" "*" "#" "@")
border_line="+$(printf '%.0s-' $(seq 1 $WIDTH))+"

echo "$border_line"
for ((y=0; y<HEIGHT; $x,$y"]}" ((x="0;" c_idx="$((" do for row="|" val x++)); x<WIDTH; y++));> 5 ? 5 : val ))
        row+="${CHARMAP[$c_idx]}"
    done
    row+="|"
    echo "$row"
done
echo "$border_line"