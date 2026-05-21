#!/usr/bin/env bash
# 8‑bit Git commit visualizer & melody
# Dependencies: git, curl, jq, sox (play), nc (netcat), awk, sed, tput
# Usage: ./git8bit.sh <GitHub repo URL>
# Example: ./git8bit.sh https://github.com/tj/git-extras

set -euo pipefail

# ---------- Config ----------
REFRESH_INTERVAL=30      # seconds between repo checks
NOTE_BASE=262            # C4 frequency (Hz)
NOTE_SCALE=(0 2 4 5 7 9 11)  # major scale intervals (semitones)
MAX_VOLUME=0.2           # sox volume (0..1)
# ---------- Helpers ----------
usage(){ echo "Usage: $0 <GitHub repo URL>"; exit 1; }

# ---------- Input ----------
[[ $# -ne 1 ]] && usage
REPO_URL=$1
REPO_NAME=$(basename -s .git "$REPO_URL")
WORKDIR=$(mktemp -d)
cd "$WORKDIR"

# ---------- Clone (or pull) ----------
if [[ -d "$REPO_NAME" ]]; then
    cd "$REPO_NAME"
    git remote set-url origin "$REPO_URL"
    git fetch --quiet
else
    git clone --depth 1 "$REPO_URL" "$REPO_NAME" >/dev/null 2>&1
    cd "$REPO_NAME"
fi

# ---------- Functions ----------
# Convert epoch seconds to hour-of-week (0‑167)
hour_of_week(){ 
    local ts=$1
    # GNU date: %u (1‑7) weekday, %H hour
    local dow=$(date -u -d @"$ts" +%u)   # 1=Mon … 7=Sun
    local hour=$(date -u -d @"$ts" +%H)
    echo $(( (dow-1)*24 + hour ))
}

# Map frequency count to a note (Hz)
note_for_hour(){
    local cnt=$1 max=$2
    # Normalize count → 0..6 (scale degrees)
    local idx=$(( cnt * (${#NOTE_SCALE[@]}-1) / (max+1) ))
    local semi=$(( NOTE_SCALE[idx] ))
    # Frequency = base * 2^(semitones/12)
    echo "$(awk "BEGIN{printf \"%0.2f\", $NOTE_BASE * 2 ^ ($semi/12)}")"
}

# Play a tone for given duration (seconds)
play_tone(){
    local freq=$1 dur=$2
    play -n synth "$dur" sine "$freq" vol $MAX_VOLUME >/dev/null 2>&1 &
}

# Render simple ANSI visualizer
render_vis(){
    local hour=$1 cnt=$2 max=$3
    local width=$(tput cols)
    local height=$(tput lines)
    local bar=$(( (cnt * height) / (max+1) ))
    clear
    for ((i=0;i<height;i++)); do
        if (( i >= height-bar )); then
            # Color varies with hour (0‑167) -> hue
            local hue=$(( (hour*15) % 360 ))
            printf "\e[48;2;%d;%d;%dm %*s\e[0m\n" \
                $(( (hue*255)/360 )) $(( ((hue+120)%360)*255/360 )) $(( ((hue+240)%360)*255/360 )) \
                $width ""
        else
            echo
        fi
    done
    echo "Hour $hour  Commits $cnt"
}

# ---------- Main Loop ----------
while true; do
    # Pull latest commits
    git fetch --quiet
    # Extract commit timestamps (UTC)
    mapfile -t epochs < <(git log --pretty=format:%ct origin/$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo master) 2>/dev/null)

    # Count per hour-of-week
    declare -A hourcnt
    for ts in "${epochs[@]}"; do
        h=$(hour_of_week "$ts")
        ((hourcnt[$h]++))
    done

    # Determine max count for scaling
    maxcnt=0
    for h in "${!hourcnt[@]}"; do
        (( hourcnt[$h] > maxcnt )) && maxcnt=${hourcnt[$h]}
    done

    # Iterate over hours in order, play note & render
    for ((h=0; h<168; h++)); do
        cnt=${hourcnt[$h]:-0}
        freq=$(note_for_hour "$cnt" "$maxcnt")
        play_tone "$freq" 0.3
        render_vis "$h" "$cnt" "$maxcnt"
        sleep 0.4   # animation speed tied to tempo
    done

    # Wait before next fetch
    sleep "$REFRESH_INTERVAL"
done