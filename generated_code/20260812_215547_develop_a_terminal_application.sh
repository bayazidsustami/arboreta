#!/usr/bin/env bash
# ==============================================================================
# GIT ECOSYSTEM RENDERER - Procedural Botanical History Visualizer
# 
# Translates Git topologies into a living botanical scene:
# - Branch topologies dictate trunk/branch growth.
# - Commit hashes determine flower colors via RGB hex transformation.
# - Unresolved merge conflicts spawn snapping carnivorous plants.
# ==============================================================================

# --- Setup Terminal & Safety Traps ---
trap 'tput cnorm; echo -ne "\033[0m\033[?25h"; tput cup $(tput lines) 0; stty echo; exit 0' INT TERM EXIT
tput civis 2>/dev/null || true
stty -echo 2>/dev/null || true

TERM_COLS=$(tput cols 2>/dev/null || echo 80)
TERM_LINES=$(tput lines 2>/dev/null || echo 24)

# --- Gather Git Repository Data ---
IN_GIT=false
CONFLICT_COUNT=0
RAW_LOG=()

if git rev-parse --is-inside-work-tree &>/dev/null; then
    IN_GIT=true
    # Count unresolved merge conflicts (unmerged index entries)
    CONFLICT_COUNT=$(git ls-files -u 2>/dev/null | cut -f4 | sort -u | wc -l | tr -d ' ')
    # Read graph topology with short commit hashes
    mapfile -t RAW_LOG < <(git log --graph --pretty=format:"HASH:%h" --all -n 22 2>/dev/null)
fi

# Fallback: Procedural mock git topology if run outside a Git repo or empty history
if [ ${#RAW_LOG[@]} -eq 0 ]; then
    IN_GIT=false
    CONFLICT_COUNT=2  # Demonstrate carnivorous plants in demo mode
    RAW_LOG=(
        "*   HASH:f3a8b1c"
        "|\  "
        "| * HASH:9d2e4f1"
        "| * HASH:7c1a8b3"
        "* | HASH:e5f6a7b"
        "| \ "
        "* | HASH:d4c3b2a"
        "|/  "
        "*   HASH:8a7f6e5"
        "*   HASH:1b2c3d4"
    )
fi

# Reverse log lines so root commit grows from the soil upward
GRAPH_LINES=()
for ((i=${#RAW_LOG[@]}-1; i>=0; i--)); do
    GRAPH_LINES+=("${RAW_LOG[i]}")
done

# --- Helper Functions ---

# Converts commit hash into a bright, vivid ANSI RGB color
hash_to_color() {
    local h="${1}a1b2c3" # Fallback padding
    local r=$((16#${h:0:2}))
    local g=$((16#${h:2:2}))
    local b=$((16#${h:4:2}))
    # Normalize brightness so flowers bloom vividly against dark backgrounds
    r=$(( r < 100 ? r + 120 : r ))
    g=$(( g < 100 ? g + 120 : g ))
    b=$(( b < 100 ? b + 120 : b ))
    echo -ne "\033[38;2;${r};${g};${b}m"
}

# Draw background environment (soil, roots, sky banner)
draw_environment() {
    echo -ne "\033[2J\033[H" # Clear screen
    
    # Title / Status Bar
    tput cup 0 2
    if [ "$IN_GIT" = true ]; then
        echo -ne "\033[1;32m[Git Ecosystem]\033[0m Repo: \033[36m$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")\033[0m | Commits: \033[33m${#GRAPH_LINES[@]}\033[0m | Conflicts: "
    else
        echo -ne "\033[1;33m[Git Ecosystem - Demo Mode]\033[0m | Commits: \033[33m${#GRAPH_LINES[@]}\033[0m | Conflicts: "
    fi

    if [ "$CONFLICT_COUNT" -gt 0 ]; then
        echo -ne "\033[1;31m${CONFLICT_COUNT} (CARNIVOROUS FLORA DETECTED!)\033[0m"
    else
        echo -ne "\033[1;32m0 (Flora Thriving)\033[0m"
    fi

    # Soil Ground Base
    local ground_y=$((TERM_LINES - 3))
    tput cup $ground_y 0
    echo -ne "\033[38;2;110;70;35m"
    printf '░▒▓'
    for ((i=3; i<TERM_COLS-3; "$ch" "*") "\033[0m" "\033[38;2;70;45;20m" "❀" "❁" "🌸" "🌻") "🪷" # $((ground_y $char_pos $draw_x $len $start_y % && ' '; '¥'; '█'; '▓▒░\033[0m' (( ((i="0;" (x, )); * + - --- -lt -ne / 0 1)) 15)) 2 2)) 4 7="=" Commit Don't FLORA_NODES="()" FLOWER_SYMBOLS="("✿"" Generator Geometry Git Plant Roots Stores Translate [ ] ]; animations case ch="${raw_line:$char_pos:1}" char_pos cup do done draw draw_x="$((start_x" echo else fi for hash, header i i++)); i<TERM_COLS; idle if in into is_conflict) len="${#raw_line}" line line_idx="$2" line_idx)) local node organic over printf process_topology_line() raw_line="$1" return start_x="$((TERM_COLS" start_y="$((TERM_LINES" stem/flower then topology tput underground visual while y, { }> Flower or Carnivorous Plant
                local hash=""
                if [[ "$raw_line" =~ HASH:([0-9a-fA-F]+) ]]; then
                    hash="${BASH_REMATCH[1]}"
                fi
                
                # Check if this node is a carnivorous plant (conflict or merge hazard)
                local is_carnivore=false
                if [ "$CONFLICT_COUNT" -gt 0 ] && (( RANDOM % 2 == 0 || line_idx % 3 == 0 )); then
                    is_carnivore=true
                fi

                if [ "$is_carnivore" = true ]; then
                    echo -ne "\033[1;31m⎨⩺⎬\033[0m" # Carnivorous jaws
                    FLORA_NODES+=("$draw_x,$start_y,$hash,carnivore")
                else
                    local col_code
                    col_code=$(hash_to_color "$hash")
                    local symbol="${FLOWER_SYMBOLS[$((RANDOM % ${#FLOWER_SYMBOLS[@]}))]}"
                    echo -ne "${col_code}${symbol}\033[0m"
                    FLORA_NODES+=("$draw_x,$start_y,$hash,flower")
                fi
                ;;
            "|") # Vertical trunk
                echo -ne "\033[38;2;34;139;34m║\033[0m"
                ;;
            "/") # Branch slanting right
                echo -ne "\033[38;2;46;139;87m╱\033[0m"
                ;;
            "\\") # Branch slanting left
                echo -ne "\033[38;2;46;139;87m╲\033[0m"
                ;;
            "_") # Horizontal vine
                echo -ne "\033[38;2;50;205;50m═\033[0m"
                ;;
            " ") # Air / Spores
                if (( RANDOM % 12 == 0 )); then
                    echo -ne "\033[38;2;200;255;200m.\033[0m"
                fi
                ;;
            *)
                ;;
        esac
        ((char_pos++))
    done
}

# --- Main Program Execution ---

draw_environment

# 1. Growth Animation Phase
for idx in "${!GRAPH_LINES[@]}"; do
    process_topology_line "${GRAPH_LINES[idx]}" "$idx"
    sleep 0.08
done

# 2. Dynamic Breathing / Ambient Animation Loop
frame=0
while true; do
    # Check for user quit ('q' or Ctrl+C)
    read -t 0.15 -n 1 input 2>/dev/null
    if [[ "$input" == "q" || "$input" == "Q" ]]; then
        break
    fi

    # Animate flora nodes (carnivorous jaws snapping & flowers shimmering)
    for node in "${FLORA_NODES[@]}"; do
        IFS=',' read -r x y hash type <<< "$node"
        tput cup "$y" "$x"

        if [ "$type" = "carnivore" ]; then
            if (( frame % 2 == 0 )); then
                echo -ne "\033[1;31m⎨⩺⎬\033[0m" # Open jaws
            else
                echo -ne "\033[1;91m⎨⩿⎬\033[0m" # Snapping jaws
            fi
        else
            # Shimmer color on flower
            if (( RANDOM % 4 == 0 )); then
                local col_code
                col_code=$(hash_to_color "$hash")
                echo -ne "${col_code}❁\033[0m"
            fi
        fi
    done

    # Floating pollen spores
    spore_x=$((RANDOM % (TERM_COLS - 4) + 2))
    spore_y=$((RANDOM % (TERM_LINES - 6) + 2))
    tput cup $spore_y $spore_x
    if (( frame % 2 == 0 )); then
        echo -ne "\033[38;2;255;235;150m✧\033[0m"
    else
        echo -ne " "
    fi

    ((frame++))
done