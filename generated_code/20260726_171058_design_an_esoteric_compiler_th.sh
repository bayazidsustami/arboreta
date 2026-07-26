#!/usr/bin/env bash
# Esoteric Compiler: Execution Stack MIDI Synthesizer & Vector Field Flora Processor
# Parses shell stack frames into real-time audio/visual streams, blooming memory leaks, and GC supernovae.

# Terminal setup and cleanup on interrupt
trap 'tput cnorm; stty echo; clear; exit 0' EXIT INT TERM
tput civis
stty -echo
clear

# Terminal dimensions
WIDTH=$(tput cols)
HEIGHT=$(tput lines)

# Execution stack and memory tracking arrays
STACK=()
LEAKS_X=()
LEAKS_Y=()
LEAKS_AGE=()
FLORA_CHAR=("🌱" "🌿" "🌸" "🌺" "🥀" "🍂")
VECTORS=("↑" "↗" "→" "↘" "↓" "↙" "←" "↖")

# Initialize audio backend (synthesizes raw PCM audio for MIDI note frequencies)
audio_pipe="/tmp/esoteric_midi_$$.raw"
mkfifo "$audio_pipe" 2>/dev/null
if command -v aplay >/dev/null 2>&1; then
    aplay -q -f U8 -r 8000 "$audio_pipe" 2>/dev/null &
    AUDIO_PID=$!
    exec 3>"$audio_pipe"
else
    exec 3>/dev/null
fi

# Convert MIDI note number to frequency (Hz)
midi_to_freq() {
    local note=$1
    echo "440 * 2^($note - 69) / 12" | bc -l 2>/dev/null || echo 440
}

# Output synthesized MIDI tone to execution pipe
play_midi_note() {
    local note=$1
    local duration=200 # 200 samples @ 8kHz
    local freq
    freq=$(midi_to_freq "$note")
    
    # Generate PCM square wave matching stack MIDI pitch
    perl -e '
        my ($freq, $samples) = @ARGV;
        for (my $i = 0; $i < $samples; $i++) {
            my $val = (sin($i * $freq * 6.28318 / 8000) > 0) ? 180 : 70;
            print pack("C", $val);
        }
    ' "$freq" "$duration" >&3 2>/dev/null
}

# Garbage Collection visual supernova renderer
trigger_gc_supernova() {
    local cx=$((WIDTH / 2))
    local cy=$((HEIGHT / 2))
    
    # Explosive expanding ring visual supernova
    for radius in $(seq 1 12); do
        for angle in $(seq 0 30 330); do
            local x=$(bc -l <<< "$cx + $radius * 2 * s($angle * 0.0174533)" | awk '{print int($1)}')
            local y=$(bc -l <<< "$cy + $radius * c($angle * 0.0174533)" | awk '{print int($1)}')
            
            if [ "$x" -gt 1 ] && [ "$x" -lt "$WIDTH" ] && [ "$y" -gt 1 ] && [ "$y" -lt "$HEIGHT" ]; then
                printf "\033[%d;%dH\033[1;33m💥\033[0m" "$y" "$x"
            fi
        done
        sleep 0.02
    done
    
    # Flash screen clear
    printf "\033[47m"
    clear
    sleep 0.05
    printf "\033[0m"
    clear
    
    # Purge memory stack and leaks
    STACK=()
    LEAKS_X=()
    LEAKS_Y=()
    LEAKS_AGE=()
}

# Main Execution Loop
cycle=0
while true; do
    cycle=$((cycle + 1))
    
    # Simulate stack frames pushing & popping
    action=$((RANDOM % 10))
    if [ $action -lt 6 ]; then
        # Push frame to stack
        addr=$((60 + RANDOM % 36)) # MIDI notes 60-96
        STACK+=("$addr")
    elif [ ${#STACK[@]} -gt 0 ]; then
        # Pop frame from stack
        unset 'STACK[${#STACK[@]}-1]'
        STACK=("${STACK[@]}")
    fi

    # Trigger memory leak bloom if stack overflows threshold
    if [ ${#STACK[@]} -gt 8 ] && [ $((RANDOM % 3)) -eq 0 ]; then
        LEAKS_X+=($((2 + RANDOM % (WIDTH - 4))))
        LEAKS_Y+=($((2 + RANDOM % (HEIGHT - 4))))
        LEAKS_AGE+=(0)
    fi

    # 1. Render Reactive Vector Field
    printf "\033[H"
    for ((y=1; y<=HEIGHT-2; y+=3)); do
        for ((x=1; x<=WIDTH-2; x+=6)); do
            vec_idx=$(((x * y + cycle + ${#STACK[@]}) % 8))
            color_idx=$((31 + (x + y + cycle) % 6))
            printf "\033[%d;%dH\033[0;%dm%s\033[0m" "$y" "$x" "$color_idx" "${VECTORS[$vec_idx]}"
        done
    done

    # 2. Render Decaying Digital Flora from Memory Leaks
    new_lx=()
    new_ly=()
    new_lage=()
    for i in "${!LEAKS_X[@]}"; do
        lx="${LEAKS_X[$i]}"
        ly="${LEAKS_Y[$i]}"
        age="${LEAKS_AGE[$i]}"
        
        if [ "$age" -lt 5 ]; then
            flora="${FLORA_CHAR[$age]}"
            printf "\033[%d;%dH%s" "$ly" "$lx" "$flora"
            new_lx+=("$lx")
            new_ly+=("$ly")
            new_lage+=($((age + 1)))
        fi
    done
    LEAKS_X=("${new_lx[@]}")
    LEAKS_Y=("${new_ly[@]}")
    LEAKS_AGE=("${new_lage[@]}")

    # 3. Parse Executing Stack Frame into MIDI Audio Stream
    if [ ${#STACK[@]} -gt 0 ]; then
        current_frame="${STACK[-1]}"
        play_midi_note "$current_frame"
    fi

    # Render Stack Overlay
    printf "\033[%d;2H\033[1;36m[STACK DEPTH: %2d] [ACTIVE LEAKS: %2d] MIDI: %s\033[0m" \
        "$HEIGHT" "${#STACK[@]}" "${#LEAKS_X[@]}" "${STACK[*]:-IDLE}"

    # 4. Check for Garbage Collection condition
    if [ ${#LEAKS_X[@]} -ge 12 ] || [ ${#STACK[@]} -ge 15 ]; then
        trigger_gc_supernova
    fi

    sleep 0.08
done