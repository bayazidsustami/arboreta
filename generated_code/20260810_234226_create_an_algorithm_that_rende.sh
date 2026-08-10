#!/usr/bin/env bash

# ==============================================================================
# GIT COMMIT LABYRINTH & CONFLICT PUZZLE ENGINE
#
# Generates a playable procedural maze directly from git commit history or a
# synthetic commit graph if outside a repository.
#
# Features:
#   - Real/Synthetic Git Log Parsing (Parents, Branches, Merges)
#   - Deterministic DFS Procedural Maze Generation seeded by Commit Hashes
#   - Branch Points form multi-way Crossroads (+)
#   - Merge Conflicts spawn Interactive Diff Pathfinding Puzzles (⚔)
#   - Terminal TUI rendering engine with WASD / Arrow Key controls
# ==============================================================================

set -u

# Restore terminal settings on exit
cleanup() {
    tput cnorm 2>/dev/null || true
    stty sane 2>/dev/null || true
    echo -e "\033[0m"
    clear
}
trap cleanup EXIT INT TERM

# Setup raw terminal input & hide cursor
stty -echo -icanon min 1 time 0 2>/dev/null || true
tput civis 2>/dev/null || true

# Game Data Structures
COMMITS=()
IS_MERGE=()
IS_BRANCH=()

# Extract commit history or synthesize one
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        hash=$(echo "$line" | awk '{print $1}')
        parent_count=$(git rev-parse --parents "$hash" 2>/dev/null | wc -w)
        parent_count=$((parent_count - 1))
        
        COMMITS+=("$hash")
        if [ "$parent_count" -gt 1 ]; then
            IS_MERGE+=(1)
            IS_BRANCH+=(0)
        else
            IS_MERGE+=(0)
            # Check if branch junction (multiple children or HEAD/branch ref)
            IS_BRANCH+=($((RANDOM % 3 == 0 ? 1 : 0)))
        fi
    done < <(git log --oneline -n 25 2>/dev/null)
fi

# Fallback synthetic Git graph if not in a git repo
if [ ${#COMMITS[@]} -eq 0 ]; then
    SYNTHETIC=(
        "a1b2c3d:feat: initial commit"
        "b2c3d4e:feat: core engine architecture"
        "c3d4e5f:branch: checkout feature/maze"
        "d4e5f6a:merge: Merge branch 'feature/maze' into main"
        "e5f6a7b:feat: implement procedural generation"
        "f6a7b8c:fix: resolve circular reflog dependency"
        "a7b8c9d:merge: Merge pull request #42 from fix/conflict"
        "b8c9d0e:feat: add ANSI rendering engine"
        "c9d0e1f:refactor: optimize collision logic"
        "d0e1f2a:merge: Merge branch 'release/1.0'"
    )
    for entry in "${SYNTHETIC[@]}"; do
        hash="${entry%%:*}"
        COMMITS+=("$hash")
        if [[ "$entry" == *"merge"* ]]; then
            IS_MERGE+=(1); IS_BRANCH+=(0)
        elif [[ "$entry" == *"branch"* ]]; then
            IS_MERGE+=(0); IS_BRANCH+=(1)
        else
            IS_MERGE+=(0); IS_BRANCH+=(0)
        fi
    done
fi

# Grid Dimensions (Must be odd numbers for maze carving)
MAZE_W=41
MAZE_H=19
declare -A GRID

# Initialize Grid with walls
for ((y=0; y<MAZE_H; "%d" "'${hash:$i:1}") "-2,0") "0,2" "2,0" # % (( ((x="0;" (seed )) )); * + 1)) 31 32768 Backtracking Carver Derive Deterministic GRID["$cx,$cy"]=" " GRID["$x,$y"]="#" Git Hashes Maze Recursive based by bytes carve_maze() char_code="$(printf" char_code) commit commit_ptr="$((commit_ptr" cx="$1" cy="$2" direction dirs="("0,-2"" do done for from hash i i++ i<${#hash}; local on pseudo-random seed seeded shuffle total_commits="${#COMMITS[@]}" x++)); x<MAZE_W; y++)); {>0; i-- )); do
        local j=$(( (seed + i) % (i + 1) ))
        local tmp="${dirs[$i]}"
        dirs[$i]="${dirs[$j]}"
        dirs[$j]="$tmp"
        seed=$(( (seed * 17 + 7) % 32768 ))
    done

    for dir in "${dirs[@]}"; do
        local dx="${dir%%,*}"
        local dy="${dir##*,}"
        local nx=$((cx + dx))
        local ny=$((cy + dy))

        if (( nx > 0 && nx < MAZE_W-1 && ny > 0 && ny < MAZE_H-1 )); then
            if [[ "${GRID["$nx,$ny"]}" == "#" ]]; then
                local mx=$((cx + dx/2))
                local my=$((cy + dy/2))
                GRID["$mx,$my"]=" "
                carve_maze $nx $ny
            fi
        fi
    done
}

carve_maze 1 1

# Gather open corridor coordinates
OPEN_TILES=()
for ((y=1; y<MAZE_H-1; " "${GRID["$x,$y"]}"="=" "${OPEN_TILES[@]}"; # (( ((x="1;" (HEAD) (Root + Commit) GOAL_X="1" GOAL_Y="1" GRID["1,1"]="S" OPEN_TILES+="("$x,$y")" Set Start Target [[ ]]; and do done fi for if in then tile tx ty x++)); x<MAZE_W-1; y++));> GOAL_X + GOAL_Y )); then
        GOAL_X=$tx
        GOAL_Y=$ty
    fi
done
GRID["$GOAL_X,$GOAL_Y"]="G"

# Overlay Git Graph Nodes (Merges, Branch Crossroads, Commits)
num_tiles=${#OPEN_TILES[@]}
TOTAL_CONFLICTS=0
for ((i=0; i<total_commits; i++)); do
    t_idx=$(( (i + 1) * num_tiles / (total_commits + 2) ))
    coords="${OPEN_TILES[$t_idx]}"
    cx="${coords%%,*}"
    cy="${coords##*,}"

    if [[ "$cx,$cy" == "1,1" || "$cx,$cy" == "$GOAL_X,$GOAL_Y" ]]; then
        continue
    fi

    if [[ "${IS_MERGE[$i]}" -eq 1 ]]; then
        GRID["$cx,$cy"]="X"
        TOTAL_CONFLICTS=$((TOTAL_CONFLICTS + 1))
    elif [[ "${IS_BRANCH[$i]}" -eq 1 ]]; then
        GRID["$cx,$cy"]="+"
    else
        GRID["$cx,$cy"]="o"
    fi
done

# Game State
PX=1
PY=1
RESOLVED_CONFLICTS=0

# Palette
C_RESET="\033[0m"
C_WALL="\033[38;5;238m"
C_PLAYER="\033[1;33m"
C_START="\033[1;32m"
C_GOAL="\033[1;35m"
C_CONFLICT="\033[1;31m"
C_CROSSROAD="\033[1;36m"
C_COMMIT="\033[1;34m"

# Render Game UI
draw_screen() {
    tput cup 0 0
    echo -e "${C_CROSSROAD}┌─────────────────────────────────────────┐${C_RESET}"
    echo -e "${C_CROSSROAD}│   GIT COMMIT GRAPH PROCEDURAL MAZE      │${C_RESET}"
    echo -e "${C_CROSSROAD}└─────────────────────────────────────────┘${C_RESET}"
    echo -e "Navigate from HEAD ${C_START}[S]${C_RESET} to Root Commit ${C_GOAL}[G]${C_RESET}\n"

    for ((y=0; y<MAZE_H; ! " "#") "$cell" "${C_CONFLICT}="====================================================${C_RESET}"" "${C_CROSSROAD} "${C_CROSSROAD}<<<<<<< "${C_GOAL}="======${C_RESET}"" ") "+") "Conflicts "G") "Git "S") "X") "\nLegend: "o") # $line" $x,$y"]}" ${C_COMMIT}●${C_RESET} ${C_CONFLICT}⚔${C_RESET} ${C_CROSSROAD}┼${C_RESET} ${C_PLAYER}@${C_RESET} ${C_RESET}" ${C_START}$RESOLVED_CONFLICTS${C_RESET}/${C_CONFLICT}$TOTAL_CONFLICTS${C_RESET}" && (( ((x="0;" (Current )); *) -e ;; Branch Branch)${C_RESET}" CONFLICT Commit Conflict Conflict" ENCOUNTERED HEAD Interactive MERGE Merge PX PY Pathfinding Puzzle Resolve Resolved: You auto-merging case cell="${GRID[" clear commit conflict const do done echo else esac failed fi for goal.pos);" if in line line+="$cell" node. pass:\n" path="findAlternativeBranch(commitGraph);"" then to trigger_merge_puzzle() x="=" x++)); x<MAZE_W; y="=" y++)); { | }>>>>>>> feature/merge-resolution${C_RESET}\n"

    echo -e "Select resolution strategy:"
    echo -e "  [1] Accept HEAD changes"
    echo -e "  [2] Accept incoming branch"
    echo -e "  [3] Synthesize both strategies (git rebase --continue)"

    while true; do
        read -s -n1 choice
        case "$choice" in
            1|2|3)
                echo -e "\n${C_START}✔ Conflict successfully resolved! Path unblocked.${C_RESET}"
                sleep 0.8
                return 0
                ;;
        esac
    done
}

# Game Loop Engine
MSG=""
while true; do
    draw_screen
    if [[ -n "$MSG" ]]; then
        echo -e "\n${C_PLAYER}Status:${C_RESET} $MSG"
        MSG=""
    else
        echo -e "\nUse ${C_PLAYER}[WASD / Arrow Keys]${C_RESET} to move, ${C_PLAYER}[Q]${C_RESET} to quit."
    fi

    read -s -n1 key
    
    # Handle Arrow Keys Escape Sequences
    if [[ "$key" == $'\x1b' ]]; then
        read -s -n2 -t 0.05 rest || true
        key="$rest"
    fi

    NX=$PX
    NY=$PY

    case "$key" in
        w|W|"[A") NY=$((PY - 1)) ;;
        s|S|"[B") NY=$((PY + 1)) ;;
        a|A|"[D") NX=$((PX - 1)) ;;
        d|D|"[C") NX=$((PX + 1)) ;;
        q|Q) clear; echo "Labyrinth session terminated."; exit 0 ;;
        *) continue ;;
    esac

    target="${GRID["$NX,$NY"]}"

    if [[ "$target" == "#" ]]; then
        MSG="Path blocked by hard-reset git wall."
        continue
    elif [[ "$target" == "X" ]]; then
        trigger_merge_puzzle
        GRID["$NX,$NY"]=" "
        RESOLVED_CONFLICTS=$((RESOLVED_CONFLICTS + 1))
        PX=$NX; PY=$NY
        clear
    elif [[ "$target" == "+" ]]; then
        MSG="Crossroads! Reached a major git branch split point."
        PX=$NX; PY=$NY
    elif [[ "$target" == "o" ]]; then
        rand_commit="${COMMITS[$((RANDOM % total_commits))]}"
        MSG="Checked out commit: ${C_COMMIT}${rand_commit}${C_RESET}"
        PX=$NX; PY=$NY
    elif [[ "$target" == "G" ]]; then
        clear
        echo -e "${C_START}======================================================${C_RESET}"
        echo -e "${C_START} 🎉 REPOSITORY FULLY UNTANGLED & MERGED! VICTORY!     ${C_RESET}"
        echo -e "${C_START}======================================================${C_RESET}"
        echo -e "You navigated the commit maze and reached the Initial Commit."
        echo -e "Total Merge Conflicts Resolved: ${C_START}$RESOLVED_CONFLICTS${C_RESET}/${C_CONFLICT}$TOTAL_CONFLICTS${C_RESET}\n"
        exit 0
    else
        PX=$NX; PY=$NY
    fi
done