#!/usr/bin/env bash
# Esoteric Musical Interpreter & Soundscape Generator
# Executes music notation (e.g. C4-q, E4-8, G4-dh) to sort a numeric array.
# Pitch intervals drive pointer/memory offsets; rhythmic durations trigger GC cycles.

set -euo pipefail

# --- Sound Synthesis & Output Setup ---
# Use sox (play), paplay, or aplay for audio playback if available; otherwise silent simulation.
AUDIO_CMD=""
if command -v play >/dev/null 2>&1; then
    AUDIO_CMD="play -q -n synth"
elif command -v aplay >/dev/null 2>&1; then
    AUDIO_CMD="aplay -q"
fi

play_note() {
    local freq="$1" dur="$2"
    if [[ -n "$AUDIO_CMD" ]]; then
        # Spawn audio process in background to prevent blocking execution
        play -q -n synth "$dur" synth sine "$freq" fade 0.01 "$dur" 0.05 >/dev/null 2>&1 &
    fi
}

# --- Frequency Mapping (Base MIDI Frequencies) ---
declare -A PITCH_MAP=(
    ["C4"]=261.63 ["D4"]=293.66 ["E4"]=329.63 ["F4"]=349.23
    ["G4"]=392.00 ["A4"]=440.00 ["B4"]=493.88 ["C5"]=523.25
    ["D5"]=587.33 ["E5"]=659.25 ["G5"]=783.99 ["A5"]=880.00
)

# Frequency-to-Note index mapping for pitch interval calculations
PITCH_ORDER=("C4" "D4" "E4" "F4" "G4" "A4" "B4" "C5" "D5" "E5" "G5" "A5")

get_pitch_idx() {
    local note="$1"
    for i in "${!PITCH_ORDER[@]}"; do
        if [[ "${PITCH_ORDER[$i]}" == "$note" ]]; then
            echo "$i"
            return
        fi
    done
    echo 0
}

# --- Rhythmic Durations (Duration to GC threshold mapping) ---
declare -A DUR_MAP=(
    ["w"]=2.0   # Whole note (heavy GC)
    ["h"]=1.0   # Half note
    ["q"]=0.5   # Quarter note
    ["8"]=0.25  # Eighth note (frequent mini-GC)
)

# --- State Initialization ---
# Array of numbers to sort
DATA_ARRAY=(42 12 88 3 65 27 91 14 53 39 8 76)
PTR=0 # Memory pointer
GC_ACCUMULATOR=0
PREV_PITCH_IDX=0

# Score: Note format is NOTE-DURATION (e.g., C4-q, E4-8)
SCORE="C4-q E4-q G4-h D4-8 F4-8 A4-q C5-w E4-q C4-q G4-8 E5-q B4-h A4-q C5-8 G4-q E4-w"

# Garbage Collector Routine
run_garbage_collector() {
    echo -e "\033[33m[GC Cycle Triggered]\033[0m Purging stale heap allocation & compacting memory..."
    sleep 0.1
}

# --- Interpreter Engine ---
echo -e "\033[36m=== Executing Music Notation Code ===\033[0m"
echo "Initial Array State: [${DATA_ARRAY[*]}]"
echo "----------------------------------------"

for note_token in $SCORE; do
    IFS='-' read -r note dur_code <<< "$note_token"

    freq="${PITCH_MAP[$note]:-440.00}"
    dur="${DUR_MAP[$dur_code]:-0.5}"

    # Play note as audio feedback
    play_note "$freq" "$dur"

    # 1. Pitch Interval -> Memory Offset Mapping
    curr_pitch_idx=$(get_pitch_idx "$note")
    interval=$(( curr_pitch_idx - PREV_PITCH_IDX ))
    PREV_PITCH_IDX=$curr_pitch_idx

    # Update memory pointer using pitch interval delta
    array_len=${#DATA_ARRAY[@]}
    PTR=$(( (PTR + interval) % array_len ))
    if (( PTR < 0 )); then
        PTR=$(( PTR + array_len ))
    fi

    # Perform step of insertion/bubble sort operation at PTR
    next_ptr=$(( (PTR + 1) % array_len ))
    if (( DATA_ARRAY[PTR] > DATA_ARRAY[next_ptr] )); then
        # Swap values
        tmp=${DATA_ARRAY[PTR]}
        DATA_ARRAY[PTR]=${DATA_ARRAY[next_ptr]}
        DATA_ARRAY[next_ptr]=$tmp
        echo "Note: $note ($dur_code) -> Interval: $interval -> Pointer: $PTR -> Swapped [${DATA_ARRAY[PTR]}, ${DATA_ARRAY[next_ptr]}]"
    else
        echo "Note: $note ($dur_code) -> Interval: $interval -> Pointer: $PTR -> Evaluated [${DATA_ARRAY[PTR]}]"
    fi

    # 2. Rhythmic Duration -> GC Cycles
    # Durations accumulate weight; exceeding threshold triggers GC
    GC_ACCUMULATOR=$(awk "BEGIN {print $GC_ACCUMULATOR + $dur}")
    if (( $(awk "BEGIN {print ($GC_ACCUMULATOR >= 1.5)}") )); then
        run_garbage_collector
        GC_ACCUMULATOR=0
    fi

    sleep "$dur"
done

# --- Final Output ---
echo "----------------------------------------"
echo -e "\033[32mExecution Complete.\033[0m"
echo "Sorted Array: [${DATA_ARRAY[*]}]"