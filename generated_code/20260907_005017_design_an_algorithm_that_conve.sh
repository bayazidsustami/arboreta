#!/usr/bin/env bash
#
# git-topography.sh - Converts Git commit history into a generative, printable topography map.
# Branch merges create river basins (~), merge conflicts form jagged mountainous fault lines (^),
# and standard commits build rolling terrain (. , : * #).
#

set -euo pipefail

MAP_WIDTH=80
MAP_HEIGHT=40
MAX_COMMITS=500

# Ensure we are inside a Git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not a git repository." >&2
    exit 1
fi

# 1. Parse Git History into Raw Terrain Indicators
# Extracts parent counts, commit hashes, and log messages to identify features
readarray -t COMMIT_DATA < <(
    git log --all --max-count="$MAX_COMMITS" --pretty=format:"%P|%h|%s" 2>/dev/null || true
)

TOTAL_COMMITS="${#COMMIT_DATA[@]}"
if [[ "$TOTAL_COMMITS" -eq 0 ]]; then
    echo "Error: No commits found in repository." >&2
    exit 1
fi

# Initialize elevation grid with base noise
declare -A GRID
for (( y=0; y<MAP_HEIGHT; "$entry" "$parents" "${COMMIT_DATA[@]}"; # % ( (( (idx (spiral/snake (x )) )); * + -a -r / 11 17 2. 2D 3 3) 5 5) 7) <<< Base Commits Features GRID["$x,$y"]="$((" IFS="|" Iterates MAP_HEIGHT MAP_HEIGHT) MAP_WIDTH MAP_WIDTH) Map Merges Terrain across and basins carve commit coordinates cx="$((" cy="$((" distribution do done entry fault for generated grid harmonic hash history idx="0" in index lines map) over parent_array parent_count="${#parent_array[@]}" parents path raise read river simple sine subject terrain to using x="0;" x++ x<MAP_WIDTH; y y++>= 2 parents) create low-elevation River Basins
    if [[ "$parent_count" -ge 2 ]]; then
        for dx in -2 -1 0 1 2; do
            for dy in -2 -1 0 1 2; do
                nx=$(( (cx + dx + MAP_WIDTH) % MAP_WIDTH ))
                ny=$(( (cy + dy + MAP_HEIGHT) % MAP_HEIGHT ))
                GRID["$nx,$ny"]=-10 # River basin depression
            done
        done
    fi

    # Conflict resolutions (detected via commit message keywords) create high Fault Lines
    if [[ "$subject" =~ (conflict|fixup|WIP|revert|cherry-pick) ]]; then
        for dx in -1 0 1; do
            for dy in -1 0 1; do
                nx=$(( (cx + dx + MAP_WIDTH) % MAP_WIDTH ))
                ny=$(( (cy + dy + MAP_HEIGHT) % MAP_HEIGHT ))
                GRID["$nx,$ny"]=25 # Jagged mountain peak
            done
        done
    else
        # Standard commit bumps elevation slightly
        curr="${GRID["$cx,$cy"]}"
        GRID["$cx,$cy"]=$(( curr + 3 ))
    fi

    idx=$(( idx + 1 ))
done

# 3. Smooth Terrain (3x3 Box Blur Filter)
declare -A SMOOTH_GRID
for (( y=0; y<MAP_HEIGHT; " "$line" "$val" "--------------------------------------------------------------------------------" # #] $TOTAL_COMMITS $x,$y"]}" % (( (Conflict) (Merge) (x (y )) )); * + -1 -2 -lt / 0 1 14 1; 4 4. 8 : ASCII Basin Elevation" Fault Foothills GENERATIVE GIT GRID["$nx,$ny"] Jagged Legend: Line Low MAP MAP_HEIGHT MAP_HEIGHT) MAP_WIDTH MAP_WIDTH) Map Mountain Output Printable REPOSITORY Render Rendered Ridge River SMOOTH_GRID["$x,$y"]="$((" Symbol TOPOGRAPHY Topography [. [[ [^] [~] ]]; assignment based calculated char="^" commits." contour count do done dx dy echo elevation elif else fault fi for from if in line="${line}${char}" nx="$((" ny="$((" on peak plain range sum then val="${SMOOTH_GRID[" x="0;" x++ x<MAP_WIDTH; y="0;" y++ y<MAP_HEIGHT;>