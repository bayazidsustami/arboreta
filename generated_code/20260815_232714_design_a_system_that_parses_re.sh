#!/usr/bin/env bash
#
# Seismic Audio Synthesizer & Interactive Musical Sheet Renderer
# Parses real-time simulated seismic sensor data (Magnitude & Fault Friction)
# to drive dynamic MIDI harmonic progressions and dynamic orchestral timbres.
# Renders an evolving, interactive ASCII/ANSI score directly in the terminal.

set -euo pipefail

# --- Audio Initialization (Timidity / Standard MIDI Setup) ---
MIDI_FIFO="/tmp/seismic_midi_$$.fifo"
rm -f "$MIDI_FIFO"
mkfifo "$MIDI_FIFO"

# Spawn background MIDI synthesizer using timidity or a fallback silent sink
if command -v timidity &>/dev/null; then
    timidity -iA "$MIDI_FIFO" &>/dev/null &
    SYNTH_PID=$!
else
    SYNTH_PID=""
fi

cleanup() {
    [[ -n "$SYNTH_PID" ]] && kill "$SYNTH_PID" 2>/dev/null || true
    rm -f "$MIDI_FIFO"
    tput cnorm 2>/dev/null || true
    clear
}
trap cleanup EXIT

# --- Musical & Geological Constants ---
SCALE_NOTES=(60 62 64 65 67 69 71 72 74 76 77 79 81) # C Major Scale MIDI Pitch
NOTE_NAMES=("C4" "D4" "E4" "F4" "G4" "A4" "B4" "C5" "D5" "E5" "F5" "G5" "A5")
INSTRUMENTS=(0 40 73 19 48 71) # Piano, Violin, Flute, Church Organ, Strings, Clarinet
STAFF_LINES=("E5" "D5" "C5" "B4" "A4" "G4" "F4" "E4" "D4" "C4")

# Terminal UI Setup
tput civis 2>/dev/null || true
clear

draw_header() {
    tput cup 0 0
    echo -e "\033[1;36m========================================================================\033[0m"
    echo -e "\033[1;35m   REAL-TIME SEISMIC HARMONIC GENERATOR & EVOLVING MUSIC SHEET   \033[0m"
    echo -e "\033[1;36m========================================================================\033[0m"
    echo -e "\033[0;33m Sensor Mode: \033[1;32mACTIVE\033[0;33m | Controls: [Q] Quit | P: Pitch Shift | F: Friction Burst \033[0m"
    echo -e "\033[1;36m------------------------------------------------------------------------\033[0m"
}

# Render Sheet Music Frame
draw_sheet_music() {
    local note_idx=$1
    local friction=$2
    local mag=$3
    local note_name="${NOTE_NAMES[$note_idx]}"
    
    tput cup 6 0
    echo -e "\033[1;37m[Evolving Harmonic Score]\033[0m"
    
    for line in "${STAFF_LINES[@]}"; do
        if [[ "$line" == "$note_name" ]]; then
            # Draw note head depending on magnitude
            if (( $(echo "$mag > 3.0" | bc -l) )); then
                echo -e " $line |--- \033[1;31m(  ♫  )\033[0m -------------------------------------------------"
            else
                echo -e " $line |--- \033[1;33m( ♩ )\033[0m ---------------------------------------------------"
            fi
        else
            if [[ "$line" == "C5" || "$line" == "A4" || "$line" == "F4" || "$line" == "D4" ]]; then
                echo -e " $line |------------------------------------------------------------------"
            else
                echo -e " $line |                                                                  "
            fi
        fi
    done

    # Timbre & Friction Dynamics Display
    tput cup 18 0
    echo -e "\033[1;36m------------------------------------------------------------------------\033[0m"
    printf "\033[1;32mSeismic Magnitude:\033[0m %-5.2f Richter | \033[1;35mFault Friction:\033[0m %-5.2f kPa\n" "$mag" "$friction"
    
    local bar_len=$(awk "BEGIN {print int($friction / 2)}")
    local bar=""
    for ((i=0; i<bar_len; i++)); do bar+="#"; done
    printf "\033[1;33mTimbre/Dynamic Texture:\033[0m [\033[1;31m%-50s\033[0m]\n" "$bar"
    echo -e "\033[1;36m========================================================================\033[0m"
}

# Main Real-Time Audio Engine & Sensor Loop
main() {
    draw_header
    local tick=0

    while true; do
        # Simulate real-time seismic telemetry: Magnitude (0.0 to 5.0), Friction (10.0 to 100.0)
        local raw_mag=$(awk -v seed="$RANDOM" 'BEGIN {srand(seed); print (rand()*4.5 + 0.5)}')
        local raw_friction=$(awk -v seed="$RANDOM" 'BEGIN {srand(seed); print (rand()*90.0 + 10.0)}')

        # Allow keyboard override if input is available
        read -t 0.1 -N 1 key 2>/dev/null || key=""
        if [[ "$key" == "q" || "$key" == "Q" ]]; then
            break
        elif [[ "$key" == "p" || "$key" == "P" ]]; then
            raw_mag=4.8
        elif [[ "$key" == "f" || "$key" == "F" ]]; then
            raw_friction=95.0
        fi

        # Convert seismic magnitude to harmonic pitch index
        local note_idx=$(awk "BEGIN {print int(($raw_mag / 5.0) * 12)}")
        (( note_idx > 12 )) && note_idx=12
        (( note_idx < 0 )) && note_idx=0

        local pitch="${SCALE_NOTES[$note_idx]}"
        
        # Fault friction dictates dynamic timbre (instrument selection + velocity)
        local inst_idx=$(awk "BEGIN {print int(($raw_friction / 100.0) * 5)}")
        local inst="${INSTRUMENTS[$inst_idx]}"
        local velocity=$(awk "BEGIN {print int(($raw_friction / 100.0) * 60 + 67)}")

        # Render updating visual music score
        draw_sheet_music "$note_idx" "$raw_friction" "$raw_mag"

        # Output MIDI event stream to FIFO buffer (Channel 1)
        if [[ -p "$MIDI_FIFO" ]]; then
            printf "PROGRAM 1 %d\nNOTE ON 1 %d %d\n" "$inst" "$pitch" "$velocity" > "$MIDI_FIFO" 2>/dev/null || true
        fi

        sleep 0.25

        # Note off event
        if [[ -p "$MIDI_FIFO" ]]; then
            printf "NOTE OFF 1 %d 0\n" "$pitch" > "$MIDI_FIFO" 2>/dev/null || true
        fi

        ((tick++))
    done
}

main