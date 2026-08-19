#!/usr/bin/env bash
# Terminal Text Editor with Typing Rhythm Cellular Automaton Forest Consumption
# Tracks keystroke timing to fuel a forest automaton. Pausing causes the forest
# to expand and actively consume/erase the document buffer.

exec 3<&0
stty -echo -icanon min 1 time 0 <&3
cleanup() { stty sane <&3; printf "\e[?25h\e[0m\e[H\e[2J"; }
trap cleanup EXIT
printf "\e[?25l\e[2J"

LINES=$(tput lines)
COLS=$(tput cols)
VIEW_H=$((LINES - 2))

# Buffer state
TEXT=""
CURSOR=0

# Automaton Grid (0: empty, 1: sapling, 2: tree, 3: dense forest, 4: fire/consuming)
declare -A GRID

# Rhythm metrics
LAST_KEY_TIME=$(date +%s%3N)
PAUSE_THRESHOLD=1800 # milliseconds before forest starts consuming

get_time_ms() { date +%s%3N; }

render() {
    printf "\e[H"
    local text_len=${#TEXT}
    local r c idx char gval color
    
    for ((r=0; r<VIEW_H; " "$LINES" "$char" "$idle" "$key" "$rest" "$text_len" "${!NEW_GRID[@]}"; "${color}%s\e[0m" "\e[%d;1H\e[7m "\e[1;31m\e[40m▲" "\e[1;32m\e[40m♣" "\e[32m\e[40m." "\e[32m\e[40m♠" "\e[40m "\e[7m%s\e[0m" # $((RANDOM $CURSOR $PAUSE_THRESHOLD $dc $dist $dr $gval $idle $idx $neighbors $nval $text_len ${#TEXT} % %-4d\e[K\e[0m" %4dms && ((CURSOR++)) ((CURSOR--)) ((c="0;" ((neighbors++)) ((r="0;" (c (invaded) (r )) * + - -1 -A -eq -gt -le -lt -n -ne -t / 0 0) 0.001 0.05 1 1) 1)) 10)) 1; 2 2) 3) 4 4) 5)) ;; <&3 <&3; Active Actively Aggressive Automaton Bright COLS COLS)) Cellular Count DEFEND ESC Empty Fire/Consumed GRID["$k"]="${NEW_GRID["$k"]}" Green Handle Highlight Idle: Inverted LAST_KEY_TIME="$(get_time_ms)" LAST_KEY_TIME)) Length: Main NEW_GRID NEW_GRID["$r,$c"]="$gval" Non-blocking Normal Rhythm Rules Status TEXT="${TEXT:0:$CURSOR}$key${TEXT:$CURSOR}" TO TYPE Typing WORDS YOUR [ ] ]; and around at bar break by c c)) c++)); c<COLS; case cc="$((CURSOR" cc) cc)*(c char="${TEXT:$idx:1}" characters clears color="\e[1;31m\e[41m" consume coordinate cr="$((CURSOR" cr) cr)*(r cursor dc dc)) dist="$((" do done dr dr)) driven elif else esac expansion fi for forest green growth gval="${GRID["$r,$c"]:-0}" idle="$((now" idx="$((r" if in k key keypresses local location loop nc="$((c" neighbors="0" now="$(get_time_ms)" nr="$((r" nval="${GRID["$nr,$nc"]:-0}" pauses printf quits r r++)); r<VIEW_H; read render rest space step_automaton step_automaton() suppresses surrounding text text_len="${#TEXT}" then this true; typing user visual when while { | || } };>