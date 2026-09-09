#!/usr/bin/env bash
# ==============================================================================
# Git Soundscape & ASCII Health Starfield
#
# Synthesizes polyphonic ambient audio via SoX using real-time Git commit metrics
# (insertions, deletions, churn rate, author entropy) while rendering a dynamic
# ASCII starfield.
# ==============================================================================

set -euo pipefail

# Ensure we are inside a Git repository
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Error: Must be run inside a valid Git repository." >&2
    exit 1
fi

# Restore terminal screen and kill background audio on exit
cleanup() {
    printf "\e[?25h\e[0m\e[2J\e[H"
    jobs -p | xargs -r kill &>/dev/null || true
}
trap cleanup EXIT
printf "\e[?25l\e[2J"

# Term dimensions
LINES=$(tput lines || echo 24)
COLS=$(tput cols || echo 80)

# Pentatonic minor pitch array (MIDI/Hz mapping approximation)
NOTES=(130.81 146.83 164.81 196.00 220.00 261.63 293.66 329.63 392.00 440.00 523.25 587.33)
STAR_CHARS=("." "." "·" "*" "+" "✦" "✧" "⚛")

# Global repository metric state
TOTAL_COMMITS=$(git rev-list --count HEAD 2>/dev/null || echo 10)
INS=10
DEL=5
ENTROPY=3
HEALTH=100

# Background thread: dynamically generates polyphonic audio using SoX
audio_engine() {
    if ! command -v play &>/dev/null; then
        return
    fi

    while true; do
        # Map metrics to musical parameters
        local idx1=$(( (INS + TOTAL_COMMITS) % ${#NOTES[@]} ))
        local idx2=$(( (DEL + ENTROPY) % ${#NOTES[@]} ))
        local f1="${NOTES[$idx1]}"
        local f2="${NOTES[$idx2]}"
        
        # Determine synth waveform and modulation speed based on health
        local wave="sine"
        [ "$HEALTH" -lt 60 ] && wave="triangle"
        [ "$HEALTH" -lt 30 ] && wave="sawtooth"
        
        local mod_speed=$(awk -v h="$HEALTH" 'BEGIN { print 0.1 + ((100 - h) / 20.0) }')

        # Synthesize 2-second dual-voice pad with tremolo/chorus effects
        play -q -n synth 2.0 \
            $wave "$f1" \
            $wave "$f2" \
            combine mix \
            tremolo "$mod_speed" 40 \
            reverb 50 50 100 \
            gain -12 &>/dev/null || true
    done
}

# Start audio thread in background
audio_engine &

# Main visualization loop
FRAME=0
while true; do
    FRAME=$((FRAME + 1))

    # Fetch recent commit statistics every 10 iterations to balance performance
    if [ $((FRAME % 10)) -eq 1 ]; then
        LOG_STATS=$(git log -1 --stat --oneline 2>/dev/null || true)
        INS=$(echo "$LOG_STATS" | grep -oE '[0-9]+ insertion' | awk '{print $1}' || echo 1)
        DEL=$(echo "$LOG_STATS" | grep -oE '[0-9]+ deletion' | awk '{print $1}' || echo 1)
        ENTROPY=$(git log -10 --format="%an" 2>/dev/null | sort -u | wc -l || echo 1)
        
        [ -z "$INS" ] && INS=1
        [ -z "$DEL" ] && DEL=1
        
        # Calculate health score based on ratio of insertions vs deletions and author diversity
        TOTAL=$((INS + DEL))
        HEALTH=$(( 100 - (DEL * 80 / (TOTAL > 0 ? TOTAL : 1)) + (ENTROPY * 5) ))
        [ "$HEALTH" -gt 100 ] && HEALTH=100
        [ "$HEALTH" -lt 5 ] && HEALTH=5
    fi

    # Buffer string for screen rendering
    BUFFER=""

    # Render dynamic ASCII Starfield
    for ((y=1; y<LINES-4; " "$BUFFER" "$COLS") "$DEL" "$ENTROPY") "$FILLED" "$HEALTH" "$H_BAR" "$INS" "$RAND" "$TOTAL_COMMITS" "$i" "\e[H%b" # $((HEALTH $(seq ${#STAR_CHARS[@]} % %3d%% %d %d" ((i="0;" ((x="1;" (Healthy) (High (Moderate) (RAND (x )) * + +%d - -%d -gt -lt / 0.1 1 100 17 3 30)) 31 35 70 8)) ; AUTHORS: BAR_WIDTH BUFFER="${BUFFER}\e[35m Synth Pad: ${NOTES[$(( (INS + TOTAL_COMMITS) % ${#NOTES[@]} ))]}Hz / ${NOTES[$(( (DEL + ENTROPY) % ${#NOTES[@]} ))]}Hz | Mod: Frame ${FRAME}\e[0m" CHAR="${STAR_CHARS[$CHAR_IDX]}" CHAR_IDX="$((" COMMITS: Churn/Crit) Color DEL: Draw FILLED="$((" FRAME FRAME) Green HEALTH HEALTH: H_BAR="${H_BAR}░" Health INS) INS: LINE="${LINE} " Pseudo-random RAND="$((" Red Repository STATS_LINE="$(printf" Telemetry Yellow [ [%s] \ ]; and based by commit dashboard do done elif else fi for frame grading health i++)); i<BAR_WIDTH; if modulated on placement printf section sleep star terminal then ticks to x++)); x<="COLS;" y y++)); |>