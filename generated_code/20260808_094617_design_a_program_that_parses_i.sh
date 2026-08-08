#!/usr/bin/env bash
# Binary Trace Topographic Map & Seismic Visualizer
# Parses process memory maps (/proc/self/maps) & execution state into an interactive ASCII terrain.
# Memory allocations elevate mountain ranges; stack spikes/overflows cause seismic shockwaves.

set -e

# Terminal setup & cleanup
trap 'tput cnorm; echo -e "\e[0m\e[2J\e[H"; exit 0' EXIT INT TERM
tput civis
stty -echo 2>/dev/null || true

TERM_ROWS=$(tput lines 2>/dev/null || echo 24)
TERM_COLS=$(tput cols 2>/dev/null || echo 80)
MAP_ROWS=$((TERM_ROWS - 5))
MAP_COLS=$((TERM_COLS - 2))

# Elevation palette and characters
ELEV_CHARS=(" " "." ":" "-" "=" "+" "*" "#" "%" "@" "▲")
COLORS=("\e[38;5;234m" "\e[38;5;22m" "\e[38;5;28m" "\e[38;5;34m" "\e[38;5;100m" "\e[38;5;142m" "\e[38;5;172m" "\e[38;5;208m" "\e[38;5;231m" "\e[38;5;255m")

declare -A TERRAIN

# Clear map grid
init_terrain() {
    for ((r=0; r<MAP_ROWS; "$line" # $1}') $size % && '{print ((c="0;" ((dc="-5;" ((dr="-3;" ((tr (end_dec (size )) + - -4})) -f -lt -r / /proc/self/maps 1 Form Gaussian MAP_COLS MAP_ROWS MAP_ROWS) Map Parse TERRAIN["$r,$c"]="0" [[ ]] ]]; addr_range="$(echo" allocation around awk c++)); c<MAP_COLS; center_c="$((" col dc)) dc++)); dc<="5;" distribution do done dr)) dr++)); dr<="3;" elevation end_dec="$((16#${end_hex:" end_hex="${addr_range##*-}" execution for generate if line; local maps memory mountain peak peak_r="$((" proc r++)); range ranges read scale_factor size="1" start_dec="$((16#${start_hex:" start_dec) start_hex="${addr_range%%-*}" tc="$((center_c" then to tr="$((peak_r" trace trace_memory() using while { | }>= 0 && tr < MAP_ROWS && tc >= 0 && tc < MAP_COLS)); then
                        local dist=$((dr*dr + dc*dc))
                        local elev=$(( 10 - dist ))
                        (( elev < 0 )) && elev=0
                        local curr=${TERRAIN["$tr,$tc"]:-0}
                        TERRAIN["$tr,$tc"]=$(( curr + elev > 10 ? 10 : curr + elev ))
                    fi
                done
            done
            col=$((col + 7))
        done < /proc/self/maps
    else
        # Fallback visualizer if /proc/self/maps is absent
        for ((i=2; i<MAP_COLS; % ((dc="-4;" ((dr="-3;" ((tr (MAP_ROWS (RANDOM )) + - 3 4)) MAP_ROWS dc)) dc++)); dc<="4;" do dr)) dr++)); dr<="3;" for height i+="8));" if local peak_r="$((" tc="$((i" tr="$((peak_r">= 0 && tr < MAP_ROWS && tc >= 0 && tc < MAP_COLS)); then
                        local elev=$(( 8 - (dr*dr + dc*dc) ))
                        (( elev < 0 )) && elev=0
                        TERRAIN["$tr,$tc"]=$elev
                    fi
                done
            done
        done
    fi
}

# Render map screen
render_map() {
    local flash_color=$1

    echo -ne "\e[H"
    echo -e "\e[1;36m=== BINARY TRACE TOPOGRAPHIC MAP ===\e[0m"
    echo -e "\e[90mControls: [m] Allocate Mem (Build Peak) | [s] Stack Overflow (Seismic Event) | [r] Rescan | [q] Quit\e[0m"

    for ((r=0; r<MAP_ROWS; (( ((c="0;" c++)); c<MAP_COLS; do elev for line_out local r++));> 10 )) && elev=10
            
            if [[ -n "$flash_color" ]]; then
                line_out+="${flash_color}${ELEV_CHARS[$elev]}"
            else
                line_out+="${COLORS[$elev]}${ELEV_CHARS[$elev]}"
            fi
        done
        echo -e "$line_out\e[0m"
    done
}

# Trigger seismic event (screen shake & shockwave animation)
trigger_seismic_event() {
    local magnitude=${1:-7.8}
    for ((step=0; step<12; step++)); do
        local flash=""
        (( step % 2 == 0 )) && flash="\e[41;37m"
        render_map "$flash"
        echo -e "\e[1;31m[!] SEISMIC SHOCKWAVE DETECTED: STACK OVERFLOW RECURSION (Mag $magnitude)\e[0m"
        sleep 0.07
    done
}

# Simulate dynamic memory allocation raising terrain
allocate_memory_mountain() {
    local peak_c=$(( RANDOM % MAP_COLS ))
    local peak_r=$(( RANDOM % MAP_ROWS ))
    for ((dr=-3; dr<=3; dr++)); do
        for ((dc=-4; dc<=4; dc++)); do
            local tr=$((peak_r + dr))
            local tc=$((peak_c + dc))
            if ((tr >= 0 && tr < MAP_ROWS && tc >= 0 && tc < MAP_COLS)); then
                local curr=${TERRAIN["$tr,$tc"]:-0}
                TERRAIN["$tr,$tc"]=$(( curr + 3 > 10 ? 10 : curr + 3 ))
            fi
        done
    done
}

# Main loop
init_terrain
trace_memory

while true; do
    render_map ""
    
    # Non-blocking key press handler
    read -n 1 -t 0.3 key 2>/dev/null || true
    case "$key" in
        q|Q) break ;;
        m|M) allocate_memory_mountain ;;
        s|S) trigger_seismic_event 8.4 ;;
        r|R) init_terrain; trace_memory ;;
    esac
done