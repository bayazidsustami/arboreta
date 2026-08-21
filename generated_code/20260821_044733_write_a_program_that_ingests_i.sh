#!/usr/bin/env bash
# Animated, self-assembling typographic maze using its own source code
# Continuous real-time pathfinding (BFS) and mutation

# Ensure clean setup and cleanup on exit
trap 'printf "\033[?25h\033[0m\033[2J\033[1;1H"; exit 0' INT TERM EXIT
printf "\033[?25l\033[2J"

# Read source code into a clean character stream (stripping whitespace)
SRC=$(tr -d '[:space:]' < "$0")
SRC_LEN=${#SRC}
[ $SRC_LEN -eq 0 ] && SRC="SELF_REFERENTIAL_TYPOGRAPHIC_MAZE_GENERATOR_DEMO" && SRC_LEN=${#SRC}

# Grid dimensions
COLS=$(tput cols 2>/dev/null || echo 80)
LINES=$(tput lines 2>/dev/null || echo 24)
WIDTH=$(( (COLS - 1) / 2 * 2 - 1 )) # Ensure odd width
HEIGHT=$(( (LINES - 2) / 2 * 2 - 1 )) # Ensure odd height
[ $WIDTH -lt 15 ] && WIDTH=15
[ $HEIGHT -lt 15 ] && HEIGHT=15

declare -A GRID
declare -A CHAR_GRID

# Colors (ANSI)
C_WALL="\033[38;5;238m"
C_PATH="\033[38;5;244m"
C_SOL="\033[1;36m"
C_HEAD="\033[1;33m"
C_START="\033[1;32m"
C_END="\033[1;31m"
C_RESET="\033[0m"

# Initialize empty grid (1 = Wall, 0 = Path)
src_idx=0
for ((y=0; y<HEIGHT; "$curr" "$ex,$ey" "${CHAR_GRID["$mx,$my"]}" "${CHAR_GRID["$nx,$ny"]}" "${CHAR_GRID["$x,$y"]}" "${C_PATH}.%s" "${C_RESET}" "${C_WALL}%s${C_RESET}" "${PATH_NODES[@]}") "${PATH_NODES[@]}"; "${VISITED["$nx,$ny"]}" "-1,0"; "-2,0"; "0,-1" "0,-2" "0,1" "0,2" "1,0" "2,0" "\033[%d;%dH" "\033[%d;%dH${C_END}E${C_RESET}" "\033[%d;%dH${C_HEAD}@${C_RESET}" "\033[%d;%dH${C_PATH}.%s" "\033[%d;%dH${C_SOL}%s${C_RESET}" "\033[%d;%dH${C_START}S${C_RESET}" # $((END_X+1)) $((END_Y+1)) $((HEIGHT-1)) $((RANDOM $((START_X+1)) $((START_Y+1)) $((WIDTH-1)) $((mx+1)) $((my+1)) $((nx+1)) $((ny+1)) $((px+1)) $((py+1)) $((x+1)) $((y+1)) $END_X $END_Y $HEIGHT $START_X $START_Y $WIDTH $curr"]}" $found $mx $my $nx $ny ${#PATH_NODES[@]} ${#neighbors[@]} ${#neighbors[@]}))]} ${#queue[@]} ${#stack[@]} ${GRID["$mx,$my"]} ${GRID["$nx,$ny"]} ${GRID["$x,$y"]} % & && 'stack[${#stack[@]}-1]' ((dx="-1;" ((dy="-1;" ((i="0;" ((src_idx++)) ((x="0;" ((y (HEIGHT (HEIGHT/2)) (RANDOM (Recursive (WIDTH (WIDTH/2)) )) * + - -A -eq -ge -gt -lt -n -z / 0 0)) 0.01 0.03 0.5 1 2 2) 2)) 3)) 4) 4)) Animate BFS Backtracker) Build CHAR_GRID["$x,$y"]="${SRC:src_idx%SRC_LEN:1}" Check Clear Draw END_X="$((WIDTH" END_Y="$((HEIGHT" End Ensure GRID["$END_X,$END_Y"]="0" GRID["$START_X,$START_Y"]="0" GRID["$mx,$my"] GRID["$nx,$ny"]="0" GRID["$x,$y"]="1" GRID["1,1"]="0" Generation If Leave Main Maze Mutate PARENT PARENT["$nx,$ny"]="$cx,$cy" PATH_NODES="("$curr"" Pathfinding Pick Reconstruct Redraw START_X="$((" START_Y="$((" Self-Assembly Shift Small Solve Start Toggle VISITED VISITED["$nx,$ny"]="1" VISITED["$sx,$sy"]="1" [ ] ]; a agent along an and animation are assembling away back base break carve cell continuous curr="${PARENT[" current cx="${curr%,*}" cy="${curr#*,}" declare delay dir direct do done draw_initial draw_initial() during dx="${dir%,*}" dx)) dx++)); dx<="1;" dy="${dir#*,}" dy)) dy++)); dy<="1;" dynamic effect else end ex="$3" ey="$4" fi find_path find_path() for force found="1" generate_maze generate_maze() head i++)); i<${#PATH_NODES[@]}; if in initial into keep labyrinth local locally loop: markers maze mutate_maze mutate_maze() mutated mutation mx="$((rx" my="$((ry" neighbor neighbors neighbors+="("$dx,$dy")" node nx="${node%,*}" ny="${node#*,}" of opening path paths pdx="${picked%,*}" pdx)) pdx/2)) pdy="${picked#*,}" pdy)) pdy/2)) periodically picked="${neighbors[$((RANDOM" points printf px="${node%,*}" py="${node#*,}" queue="("${queue[@]:1}")" queue+="("$nx,$ny")" random remaze rx="$((" ry="$((" section sleep solved solving stack="("${stack[@]}")" stack+="("$nx,$ny")" start start/end state, sx="$1" sy="$2" the then to trail traveling traversal true; units unset unsolvable valid visual wall/path while x++)); x<WIDTH; y++)); y<HEIGHT; { }>