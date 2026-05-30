#!/usr/bin/env bash
# ascii_lsystem_poet.sh – live mic → phoneme → colored L‑system animation
# Dependencies: sox, pocketsphinx_continuous, awk, sed, tput, printf
# Works on Linux with ALSA/PulseAudio; requires a mono 16‑bit mic input.

# ---- Configurable parameters -------------------------------------------------
FPS=15                         # frames per second for animation
FRAMES=$((60/$FPS))           # frames per second divisor for fading
MAX_AGE=$((FRAMES*10))        # how many frames a fractal lives
# Simple L‑system rules per phoneme class
declare -A RULES=(
    [A]="F[+F]F[-F]F"
    [E]="F[+F]F[-F]F"
    [I]="F[+F]F[-F]F"
    [O]="F[+F]F[-F]F"
    [U]="F[+F]F[-F]F"
    [B]="F[+F]F[-F]F"
    [C]="F[+F]F[-F]F"
    [D]="F[+F]F[-F]F"
    [F]="F[+F]F[-F]F"
    [G]="F[+F]F[-F]F"
    [H]="F[+F]F[-F]F"
    [J]="F[+F]F[-F]F"
    [K]="F[+F]F[-F]F"
    [L]="F[+F]F[-F]F"
    [M]="F[+F]F[-F]F"
    [N]="F[+F]F[-F]F"
    [P]="F[+F]F[-F]F"
    [Q]="F[+F]F[-F]F"
    [R]="F[+F]F[-F]F"
    [S]="F[+F]F[-F]F"
    [T]="F[+F]F[-F]F"
    [V]="F[+F]F[-F]F"
    [W]="F[+F]F[-F]F"
    [X]="F[+F]F[-F]F"
    [Y]="F[+F]F[-F]F"
    [Z]="F[+F]F[-F]F"
)
# Colors for each phoneme (ANSI 256‑color palette)
declare -A COLORS=(
    [A]=196 [E]=202 [I]=208 [O]=214 [U]=220
    [B]=46  [C]=47  [D]=48  [F]=49  [G]=50
    [H]=51  [J]=52  [K]=53  [L]=54  [M]=55
    [N]=56  [P]=57  [Q]=58  [R]=59  [S]=60
    [T]=61  [V]=62  [W]=63  [X]=64  [Y]=65 [Z]=66
)

# ---- Data structures ---------------------------------------------------------
# Each fractal: "age|x|y|angle|string|color"
declare -a FRACALS

# ---- Helper functions --------------------------------------------------------
draw_point() {
    local x=$1 y=$2 color=$3 char=$4
    tput cup $y $x
    printf "\e[38;5;%sm%s\e[0m" "$color" "$char"
}

# Simple turtle graphics interpreter for our L‑system strings
render_fractal() {
    local -n f=$1   # pass by reference (array entry)
    local age=${f[0]} x=${f[1]} y=${f[2]} angle=${f[3]} str=${f[4]} color=${f[5]}
    local stack=()
    local len=$(( (MAX_AGE - age) / FRAMES + 1 ))  # length shrinks with age

    for ((i=0; i<${#str}; i++)); do
        case "${str:i:1}" in
            F)
                local rad=$(( angle * 314 / 180 ))   # approx pi/180*1000
                local nx=$(( x + len * $(awk "BEGIN{print cos($rad/1000)}") ))
                local ny=$(( y + len * $(awk "BEGIN{print sin($rad/1000)}") ))
                draw_point "$nx" "$ny" "$color" "*"
                x=$nx; y=$ny
                ;;
            "+")
                angle=$(( (angle + 25) % 360 ))
                ;;
            "-")
                angle=$(( (angle - 25 + 360) % 360 ))
                ;;
            "[")
                stack+=("$x|$y|$angle")
                ;;
            "]")
                IFS='|' read -r x y angle <<< "${stack[-1]}"
                unset 'stack[-1]'
                ;;
        esac
    done
    # advance age and reduce string a bit (mutate)
    f[0]=$((age+1))
    f[4]="${str//F/FF}"   # simple mutation: duplicate Fs
}

clear_screen() { tput clear; }

# ---- Main loop ---------------------------------------------------------------
clear_screen
# background audio capture and real‑time speech‑to‑text
pocketsphinx_continuous -inmic yes -time yes 2>/dev/null |
while read -r line; do
    # pocketsphinx outputs "READY...." then lines like "0000000: hello world"
    # Extract the spoken words part
    spoken=$(echo "$line" | sed -n 's/^[0-9]\+:[[:space:]]*//p')
    [[ -z $spoken ]] && continue

    # Convert words to phonemes (simplified: just first letters)
    phonemes=$(echo "$spoken" | tr '[:lower:]' '[:upper:]' | grep -o . | tr -d '\n')
    for ((i=0; i<${#phonemes}; i++)); do
        ph=${phonemes:i:1}
        rule=${RULES[$ph]:-F}
        color=${COLORS[$ph]:-255}
        # start position random within terminal size
        cols=$(tput cols); rows=$(tput lines)
        x=$((RANDOM % cols)); y=$((RANDOM % rows))
        FRACALS+=("$((0))|$x|$y|$((RANDOM%360))|$rule|$color")
    done

    # render loop for a short burst while new input arrives
    for ((frame=0; frame<FRAMES; frame++)); do
        clear_screen
        newlist=()
        for entry in "${FRACALS[@]}"; do
            IFS='|' read -r age x y angle str color <<< "$entry"
            [[ $age -ge $MAX_AGE ]] && continue
            render_fractal entry
            newlist+=("$age|$x|$y|$angle|$str|$color")
        done
        FRACALS=("${newlist[@]}")
        sleep "$(awk "BEGIN{printf \"%.3f\",1/$FPS}")"
    done
done