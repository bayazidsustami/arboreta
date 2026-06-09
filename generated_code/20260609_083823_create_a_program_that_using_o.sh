#!/usr/bin/env bash
# Braille‑Cellular Music – infinite self‑modifying score with live MIDI steering
# Requires aseqdump (part of alsa-utils) for MIDI input.

# ---------- configuration ----------
WIDTH=48                # number of Braille cells per line
DELAY=0.12              # seconds between measures
MIDI_DEV="128:0"        # change to your MIDI source (client:port)

# ---------- initialise cells ----------
# each cell = 8‑bit value: high 5 bits = pitch (0‑31), low 3 bits = CA rule (0‑7)
declare -a cells
for ((i=0;i<WIDTH;i++)); do
    pitch=$((RANDOM%32))
    rule=$((RANDOM%8))
    cells[i]=$(((pitch<<3)|rule))
done

# ---------- MIDI listener (runs in background) ----------
midi_offset=0
{ aseqdump -p "$MIDI_DEV" 2>/dev/null |
  while read -r line; do
      # look for Note On messages (0x90‑0x9F) and extract note number
      [[ $line =~ ^\s*([0-9A-Fa-f]{2})\s+([0-9A-Fa-f]{2})\s+([0-9A-Fa-f]{2}) ]] && {
          status=${BASH_REMATCH[1]}
          note=${BASH_REMATCH[2]}
          (( (0x${status} & 0xF0) == 0x90 )) && {
              # map MIDI note (0‑127) to a small offset [-2,+2]
              (( midi_offset = (0x${note}%5) - 2 ))
          }
      }
  done
} &

# ---------- helper: convert cell byte to Braille Unicode ----------
braille_char() {
    local val=$1
    printf "\u%04x" $((0x2800 + val))
}

# ---------- main loop ----------
while :; do
    # render current measure
    line=""
    for ((i=0;i<WIDTH;i++)); do
        line+=$(braille_char "${cells[i]}")
    done
    printf "\r%s" "$line"

    # evolve cells
    prev=("${cells[@]}")
    for ((i=0;i<WIDTH;i++)); do
        # extract pitch and rule
        ((pitch = (prev[i]>>3) & 31))
        ((rule  = prev[i] & 7))

        # cellular‑automaton: neighbourhood rule bits (3‑bit rule as Wolfram code)
        left=$(((prev[(i-1+WIDTH)%WIDTH] & 7)))
        center=$rule
        right=$(((prev[(i+1)%WIDTH] & 7)))
        pattern=$((( (left<<2) | (center<<1) | right ) ))
        # rule bit = (rule>>pattern)&1  (Wolfram rule 30 as default)
        ((newbit = (30>>pattern) & 1))

        # pitch evolves with MIDI steering
        ((pitch = (pitch + midi_offset + newbit) % 32))
        cells[i]=$(((pitch<<3) | newbit))
    done

    sleep "$DELAY"
done