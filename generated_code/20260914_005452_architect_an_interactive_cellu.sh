#!/usr/bin/env bash
# Interactive Cellular Automaton to MIDI Melody Compiler/Player
# Runs Game of Life on a 16-step grid, mapping active cells to pitch scales
# and dead cell transitions to rests/accents, generating playable MIDI files.

set -euo pipefail

WIDTH=16
HEIGHT=8
MIDI_FILE="ca_melody.mid"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Initialize grid (8 octaves/pitches x 16 steps)
# Scale degrees (Pentatonic Minor): C3, Eb3, F3, G3, Bb3, C4, Eb4, F4
PITCHES=(48 51 53 55 58 60 63 65)
declare -A GRID

init_grid() {
    for ((y=0; y<HEIGHT; " "$track_data" "$y" "${!NEXT[@]}"; "%d "Click "Compiling "Space: # $dx $dy $neighbors $state ${GRID[$y,$x]} ${PITCHES[$((HEIGHT % & && ( (( ((x="0;" ((y="0;" (120 (Pitch: (Standard (x (y ) )) + - -1 -A -eq -f -ne 0 0) 0: 1 1; 2 3 4 5 6 7 8 9 A B BPM Binary C CA COMPILER="=="" Clear Compile Construction D Delta-time E Enter F" File Format GRID[$k]="${NEXT[$k]};" GRID[$y,$x] HEIGHT HEIGHT) MELODY MIDI NEXT NEXT[$y,$x]="0" Play Quit" RANDOM Randomize Set Step Tempo WASD WIDTH WIDTH) [[ ]]; c: cells." clear compile_midi() construction declare do done dx dy echo elif else fi for grid if in k local neighbors nx="$((" ny="$((" or p: printf q: r: render_ui() rm sequence..." state="${GRID[$y,$x]}" step_ca() then to toggle toggle_cell() track_data="$TMP_DIR/track.bin" use using x="$2" x++)); x<WIDTH; y="$1" y))]})" y++)); y<HEIGHT; { | || } ·" ■"> 500,000 us/quarter)
    printf '\x00\xFF\x51\x03\x07\xA1\x20' >> "$track_data"
    # Delta-time 0: Program Change (Synth / Square Wave = 80)
    printf '\x00\xC0\x50' >> "$track_data"
    
    local ticks_per_step=120
    
    for ((x=0; x<WIDTH; "$(printf "$p")" "${active_pitches[@]}"; # ${#active_pitches[@]} ${GRID[$y,$x]} '\\x%02x' '\x00\x90%b\x64' ((y="0;" - -eq -gt 0 1 Invert Note On Y [[ ]]; active active_pitches="()" active_pitches+="("${PITCHES[$((HEIGHT" axis cells column do done fi for higher if in local p pitch printf rows="higher" so then x++)); y))]}") y++)); y<HEIGHT;>> "$track_data"
            done
            
            # Duration (ticks_per_step delta-time for Note Off)
            # Delta time 120 in variable length quantity = 0x78
            local first=1
            for p in "${active_pitches[@]}"; do
                if [[ $first -eq 1 ]]; then
                    printf '\x78\x80%b\x00' "$(printf '\\x%02x' "$p")" >> "$track_data"
                    first=0
                else
                    printf '\x00\x80%b\x00' "$(printf '\\x%02x' "$p")" >> "$track_data"
                fi
            done
        else
            # Dead column: Rest (Delta time delay with no events)
            # 120 ticks rest represented as NOP note event off/on with 0 velocity
            printf '\x78\x90\x3C\x00' >> "$track_data"
            printf '\x00\x80\x3C\x00' >> "$track_data"
        fi
    done
    
    # End of Track Event
    printf '\x00\xFF\x2F\x00' >> "$track_data"
    
    local track_size
    track_size=$(wc -c < "$track_data")
    
    # Header Chunk: MThd, length 6, format 0, 1 track, 96 ticks per quarter note
    printf 'MThd\x00\x00\x00\x06\x00\x00\x00\x01\x00\x60' > "$MIDI_FILE"
    # Track Chunk Header: MTrk + length
    printf 'MTrk' >> "$MIDI_FILE"
    printf '%08x' "$track_size" | xxd -r -p >> "$MIDI_FILE"
    cat "$track_data" >> "$MIDI_FILE"
    
    echo "MIDI saved to $MIDI_FILE"
    
    # Play MIDI if audio player is present
    if command -v timidity &>/dev/null; then
        timidity "$MIDI_FILE"
    elif command -v fluidsynth &>/dev/null; then
        fluidsynth -i "$MIDI_FILE"
    elif command -v afplay &>/dev/null; then
        afplay "$MIDI_FILE"
    else
        echo "Install timidity, fluidsynth, or afplay to hear live audio directly."
    fi
}

init_grid

while true; do
    render_ui
    read -r -n 1 key || true
    case "$key" in
        " ") step_ca ;;
        "r") init_grid ;;
        "c") 
            for ((y=0; y<HEIGHT; "p") "q") # $((RANDOM % ((x="0;" *) 0 ;; GRID[$y,$x]="0;" HEIGHT)) Toggle WIDTH)) cell compile_midi do done esac exit for keys on random toggle_cell unassigned x++)); x<WIDTH; y++));>