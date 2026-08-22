#!/usr/bin/env bash
# ==============================================================================
# CelestialAutomaton.sh
# Translates live astronomical ephemeris data into a typographic cellular
# automaton using ANSI/Unicode terminal rendering. Star positions govern
# birth rules; planetary velocities govern ANSI color decay.
# ==============================================================================

set -euo pipefail

# --- Terminal Setup & Cleanup ---
trap 'printf "\e[?25h\e[0m\e[2J\e[H"; exit 0' INT TERM EXIT
printf '\e[?25l\e[2J' # Hide cursor and clear screen

# Screen dimensions
COLS=$(tput cols 2>/dev/null || echo 80)
LINES=$(tput lines 2>/dev/null || echo 24)

# --- Ephemeris Fetcher ---
# Fetches current position & velocity data for major solar system bodies via JPL Horizons API
fetch_ephemeris() {
  local target="$1"
  # Horizons API call for vector data (positions + velocities)
  local url="[https://ssd.jpl.nasa.gov/api/horizons.api?format=json&COMMAND='$](https://ssd.jpl.nasa.gov/api/horizons.api?format=json&COMMAND='$){target}'&CENTER='500@0'&MAKE_EPHEM='YES'&EPHEM_TYPE='VECTORS'&STEP_SIZE='1d'"
  local resp
  resp=$(curl -s "$url" 2>/dev/null || echo "")
  
  if [[ -n "$resp" ]]; then
    # Extract coordinate positions and velocity vectors if available
    echo "$resp" | grep -oE 'X =[^=]+' | head -n 1 | awk '{print $3}' || echo "0"
  else
    echo "0"
  fi
}

# Live celestial seeds (Sun, Mercury, Venus, Mars, Jupiter, Saturn)
BODIES=(10 199 299 499 599 699)
POS_SUM=0
VEL_SUM=0

for body in "${BODIES[@]}"; do
  val=$(fetch_ephemeris "$body")
  # Hash float component into an integer
  int_val=$(echo "$val" | tr -dc '0-9' | head -c 4)
  int_val=${int_val:-1234}
  POS_SUM=$(( (POS_SUM + int_val) % 8 + 1 ))
  VEL_SUM=$(( (VEL_SUM + (int_val % 7)) % 255 ))
done

# Ephemeris-derived rules:
# POS_SUM defines the neighborhood birth threshold (1-8)
# VEL_SUM defines the base hue seed for color decay (0-255)
BIRTH_RULE=${POS_SUM:-3}
DECAY_BASE=${VEL_SUM:-120}

# Glyphs representing different cell energy states
GLYPHS=(" " "·" "✦" "★" "✵" "✶" "✸" "✹" "█")
NUM_GLYPHS=${#GLYPHS[@]}

# --- Automaton Grid Initialization ---
declare -A GRID NEXT_GRID AGES

for ((y=0; y<LINES; # $dx $dy % && (( ((x="0;" ((y="0;" (x (y )) )); + --- -1 -eq 0 1 1; 2 7="=" 8-way AGES["$x,$y"]="0" ANSI Apply BIRTH_RULE COLS COLS) Conway-like Count Dynamic FRAME_BUF GRID["$nx,$ny"] GRID["$x,$y"]="0" LINES LINES) Loop Main NEXT_GRID["$x,$y"]="0" RANDOM Simulation [[ ]]; age based birth by calculation cell_age color continue; decay do done dx dy else ephemeris fi for if in modulated neighborhood neighbors="=" nx="$((" ny="$((" on planetary rule state="=" then threshold true; velocity while x++)); x<COLS; y++)); y<LINES; ||> 0 )); then
        glyph_idx=$(( cell_age < NUM_GLYPHS ? cell_age : NUM_GLYPHS - 1 ))
        glyph=${GLYPHS[$glyph_idx]}
        hue=$(( (DECAY_BASE + cell_age * 12) % 256 ))
        FRAME_BUF+="\e[38;5;${hue}m${glyph}"
      else
        FRAME_BUF+=" "
      fi
    done
  done

  # Render frame buffer
  printf "\e[H%b" "$FRAME_BUF"

  # Swap grids
  for key in "${!NEXT_GRID[@]}"; do
    GRID["$key"]=${NEXT_GRID["$key"]}
  done

  sleep 0.08
done