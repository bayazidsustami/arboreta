#!/bin/bash

# Atmospheric Pressure Cellular Automaton (Tapestry of Winds)
# Fetches global pressure data via wttr.in, seeds a cellular automaton, and weaves gradients.

# Ensure safe cleanup on exit
trap "tput cnorm; clear; exit" INT TERM EXIT
tput civis
clear

# Get terminal dimensions
COLS=$(tput cols)
ROWS=$(tput lines)

# Fallback dimensions if too small
[[ $COLS -lt 10 ]] && COLS=40
[[ $ROWS -lt 5 ]] && ROWS=20

# Fetch live atmospheric pressure via text format from wttr.in (e.g. "1013 hPa")
WEATHER_RAW=$(curl -s "wttr.in/?format=%P" 2>/dev/null)
PRESSURE=$([[ "$WEATHER_RAW" =~ [0-9]+ ]] && echo "${BASH_REMATCH[0]}" || echo "1013")

# Initialize grid with pseudo-random states influenced by live pressure seed
declare -A grid
declare -A next_grid

seed_val=$((PRESSURE % 100))
for ((r=0; r<ROWS; !="0" "\033[${ROWS};1H\033[33m[Live "\033[H$output\033[0m" # ${PRESSURE} % && (( ((PRESSURE ((c="0;" ((r="0;" (Conway-like (PRESSURE (Press (c (neighbors="=" (r (toroidal )) )); * +="(RANDOM" - -ne 0 0)) 0.1 1 2="=" 3 3) 31 4 5) 6 7="=" ANSI Automaton COLS COLS) Color Compute Copy Count Ctrl+C Draw PRESSURE PRESSURE) Periodic Pressure: ROWS ROWS) Render Tapestry... Vibrant Weaving and at automaton base_color="$((" based block breathing by c c++)); c<COLS; cell cellular color="$((" current="=" dc deviation do done dr drift echo else escape exit)\033[0m" fi for frame generation gradient grid grid[$r,$c]="${next_grid[$r,$c]}" hPa] if in influenced keep live mapping modulo nc="$((" neighbors="=" next next_grid next_grid[$r,$c]="0" nr="$((" on output output+="\n" performance position pressure r++)); r<ROWS; rules rules) screen seed seed_val) sequences simulation sleep spectrum subtle then to top-left transition true; using variant while with wrapping) {-1,0,1}; ||>