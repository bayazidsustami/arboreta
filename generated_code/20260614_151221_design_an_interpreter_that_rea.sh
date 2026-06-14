#!/usr/bin/env bash
# musical_turing.sh – interpreter for a simple “musical Turing language”
# Each line: NOTE DURATION_MS MOVE
# NOTE like C4, D#5, etc.; DURATION_MS integer; MOVE one of > < = (right, left, stay)
# The script plays the notes (using sox) and shows an evolving ASCII Mandelbrot
# fractal whose parameters react to pitch and tape‑head position.

# ---- configuration ---------------------------------------------------------
FRAC_W=80          # width of ASCII fractal
FRAC_H=24          # height of ASCII fractal
MAX_ITER=30        # Mandelbrot iterations
SOUND_CMD="play -n synth"  # sox command, must be in $PATH

# ---- helper functions ------------------------------------------------------
# Convert note name to frequency (Hz). Supports sharp (#) and flat (b).
note2freq() {
    local note=$1
    local octave=${note: -1}
    local name=${note:0:${#note}-1}
    declare -A base=([C]=0 [C#]=1 [Db]=1 [D]=2 [D#]=3 [Eb]=3 [E]=4 [F]=5 [F#]=6 [Gb]=6 [G]=7 [G#]=8 [Ab]=8 [A]=9 [A#]=10 [Bb]=10 [B]=11)
    local n=${base[$name]}
    (( n+= (octave+1)*12 ))            # MIDI number, A4=69
    echo "scale=5; 440 * (2 ^ (( $n - 69) / 12))" | bc -l
}

# Render a small ASCII Mandelbrot; parameter $1 is a “focus” that shifts the
# complex plane based on pitch (0..1) and tape position (–1..1).
draw_fractal() {
    local focus=$1   # 0..1
    local shift=$2   # –1..1
    local rows=$FRAC_H cols=$FRAC_W
    local x_min=-2.0   x_max=1.0
    local y_min=-1.2   y_max=1.2
    # adjust view centre with focus & shift
    local cx=$(echo "$x_min + ($x_max-$x_min)*$focus + $shift*0.5" | bc -l)
    local cy=0
    clear
    for ((i=0;i<rows;i++)); do
        local y=$(echo "$y_min + ($y_max-$y_min)*$i/($rows-1)" | bc -l)
        line=""
        for ((j=0;j<cols;j++)); do
            local x=$(echo "$x_min + ($x_max-$x_min)*$j/($cols-1)" | bc -l)
            local zx=$x zy=$y iter=0
            while (( iter<MAX_ITER )); do
                # z = z^2 + c ; c = (cx,cy)
                local zx2=$(echo "$zx*$zx - $zy*$zy + $cx" | bc -l)
                local zy2=$(echo "2*$zx*$zy + $cy" | bc -l)
                zx=$zx2; zy=$zy2
                local mag=$(echo "$zx*$zx + $zy*$zy" | bc -l)
                (( $(echo "$mag > 4" | bc -l) )) && break
                ((iter++))
            done
            # map iter to char
            case $((iter*8/MAX_ITER)) in
                0) ch=' ';;
                1) ch='.';;
                2) ch=':';;
                3) ch='-';;
                4) ch='=';;
                5) ch+'+';;
                6) ch='*';;
                7) ch='#';;
                *) ch='@';;
            esac
            line+=$ch
        done
        echo "$line"
    done
}

# ---- main interpreter ------------------------------------------------------
if [[ -z $1 ]]; then
    echo "Usage: $0 program.txt"
    exit 1
fi

tape=0       # tape head position (integer)
while IFS= read -r line || [[ -n $line ]]; do
    # skip empty/comments
    [[ -z $line || $line == \#* ]] && continue
    read -r note dur move <<<"$line"
    freq=$(note2freq "$note")
    dur_ms=$((dur))
    # schedule sound (play in background)
    $SOUND_CMD synth "$dur_ms"ms sine "$freq" >/dev/null 2>&1 &
    pid=$!
    # compute visual parameters
    pitch_norm=$(echo "scale=4; ($freq - 200) / (2000 - 200)" | bc -l)   # approx 0..1
    head_norm=$(echo "scale=4; $tape / 10" | bc -l)                     # keep small
    # while sound playing, animate fractal
    while kill -0 $pid 2>/dev/null; do
        draw_fractal "$pitch_norm" "$head_norm"
        sleep 0.05
    done
    # update tape head
    case $move in
        '>') ((tape++));;
        '<') ((tape--));;
        '=') ;;  # stay
    esac
done < "$1"
echo "Program finished."