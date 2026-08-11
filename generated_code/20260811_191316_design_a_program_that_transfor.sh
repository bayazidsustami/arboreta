#!/usr/bin/env bash
# ==============================================================================
# Git Commit History to Polyphonic Music Score Generator
# ==============================================================================
# This script transforms git commit history into a polyphonic music score:
#   1. Code Insertions  --> Melodic Leaps (interval shifts along diatonic scale)
#   2. Code Deletions   --> Microtonal Bends (cents detuning / pitch inflection)
#   3. Branch Merges    --> Harmonic Resolutions (consonant multi-voice triads)
#
# Outputs both an ABC notation file (git_score.abc) and an ASCII stave preview.
# ==============================================================================

set -euo pipefail

REPO="${1:-.}"
OUTPUT_ABC="${2:-git_score.abc}"
MAX_COMMITS="${3:-40}"

# Validate git repository
if ! git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
    printf "Error: Directory '%s' is not a valid git repository.\n" "$REPO" >&2
    exit 1
fi

# Pitch scales (Diatonic C Major across 3 octaves)
NOTE_NAMES=("C3" "D3" "E3" "F3" "G3" "A3" "B3" "C4" "D4" "E4" "F4" "G4" "A4" "B4" "C5" "D5" "E5" "F5" "G5" "A5" "B5")
ABC_PITCHES=("C," "D," "E," "F," "G," "A," "B," "C" "D" "E" "F" "G" "A" "B" "c" "d" "e" "f" "g" "a" "b")
SCALE_SIZE=${#NOTE_NAMES[@]}

# Harmonic resolution chords for branch merges (ABC format)
RESOLUTIONS=("[C,E,G]" "[F,A,C]" "[G,B,D]" "[A,C e]" "[C,E,G c]")
RESOL_NAMES=("C Major" "F Major" "G Major" "A Minor" "C Major Octave")

# Treble Stave lines for ASCII visualization
STAVE_NOTES=("F5" "E5" "D5" "C5" "B4" "A4" "G4" "F4" "E4")

current_pitch_idx=7 # Default starting note: C4

# Write ABC notation score header
cat << 'EOF' > "$OUTPUT_ABC"
X:1
T:Git Commit History Polyphonic Score
C:Git History Transposer
M:4/4
L:1/8
Q:1/4=120
K:C
V:1 name="Melodic Leap (Insertions)" clef=treble
V:2 name="Microtone Bend (Deletions)" clef=treble
V:3 name="Harmonic Resolution (Merges)" clef=bass
EOF

v1_notes=""
v2_notes=""
v3_notes=""

printf "=================================================================================\n"
printf "         GIT COMMIT HISTORY TO POLYPHONIC MUSIC SCORE TRANSFORMATION           \n"
printf "=================================================================================\n\n"
printf "%-9s | %-10s | %-10s | %-14s | %-10s | %-18s\n" "Commit" "Insertions" "Deletions" "Melodic Leap" "Microtone" "Harmonic Res."
printf "---------------------------------------------------------------------------------\n"

# Fetch commit history: Hash, Parents, Author, Subject, followed by diff statistics
raw_log=$(git -C "$REPO" log --reverse --parents --numstat -n "$MAX_COMMITS" --pretty=format:"COMMIT_START|%h|%p|%an|%s")

commit_hash=""
parents=""
insertions=0
deletions=0

# Process each commit into musical transformations
process_commit() {
    [ -z "$commit_hash" ] && return

    # Detect branch merge (more than 1 parent commit)
    local parent_count
    parent_count=$(echo "$parents" | wc -w)

    # 1. Code Insertions -> Melodic Leap (shift pitch along diatonic scale)
    local leap=0
    if [ "$insertions" -gt 0 ]; then
        leap=$(( (insertions % 5) + 1 )) # Leap range: 1 to 5 scale steps
        if [ $((insertions % 2)) -eq 0 ]; then
            current_pitch_idx=$(( (current_pitch_idx + leap) % SCALE_SIZE ))
        else
            current_pitch_idx=$(( (current_pitch_idx - leap + SCALE_SIZE) % SCALE_SIZE ))
        fi
    fi

    local note_name="${NOTE_NAMES[$current_pitch_idx]}"
    local abc_note="${ABC_PITCHES[$current_pitch_idx]}"

    # 2. Code Deletions -> Microtonal Pitch Bend (cents detuning)
    local cents=0
    local micro_abc="$abc_note"
    local bend_label="0c"
    if [ "$deletions" -gt 0 ]; then
        cents=$(( (deletions * 13) % 50 )) # Microtone bend magnitude (0-49 cents)
        if [ $((deletions % 2)) -eq 0 ]; then
            bend_label="+${cents}c"
            micro_abc="^/100${abc_note}"
        else
            bend_label="-${cents}c"
            micro_abc="_/100${abc_note}"
        fi
    fi

    # 3. Branch Merges -> Harmonic Resolution (consonant multi-voice triad)
    local res_chord="z2"
    local res_label="-"
    if [ "$parent_count" -gt 1 ]; then
        local chord_idx=$(( (insertions + deletions) % ${#RESOLUTIONS[@]} ))
        res_chord="${RESOLUTIONS[$chord_idx]}"
        res_label="${RESOL_NAMES[$chord_idx]}"
    fi

    # Display row in commit analysis table
    printf "%-9s | +%-9d | -%-9d | %-5s (%+d)   | %-10s | %-18s\n" \
        "$commit_hash" "$insertions" "$deletions" "$note_name" "$leap" "$bend_label" "$res_label"

    # Append events to polyphonic voices
    v1_notes="${v1_notes}${abc_note}2 "
    v2_notes="${v2_notes}${micro_abc}2 "
    v3_notes="${v3_notes}${res_chord} "

    # Reset metrics for next commit iteration
    commit_hash=""
    parents=""
    insertions=0
    deletions=0
}

# Parse stream line by line
while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^COMMIT_START\| ]]; then
        process_commit
        IFS='|' read -r _ commit_hash parents author subject <<< "$line"
        insertions=0
        deletions=0
    elif [[ "$line" =~ ^([0-9]+)[[:space:]]+([0-9]+) ]]; then
        ins="${BASH_REMATCH[1]}"
        del="${BASH_REMATCH[2]}"
        insertions=$((insertions + ins))
        deletions=$((deletions + del))
    fi
done <<< "$raw_log"

# Process final commit
process_commit

# Append polyphonic voice score content to ABC file
cat << EOF >> "$OUTPUT_ABC"

[V:1] $v1_notes
[V:2] $v2_notes
[V:3] $v3_notes
EOF

printf "---------------------------------------------------------------------------------\n"
printf "Score generation complete!\n"
printf "  └─ ABC Music Notation File : %s\n\n" "$OUTPUT_ABC"

# Render ASCII Polyphonic Treble Stave Preview
printf "ASCII STAVE SCORE PREVIEW (Treble Clef - Melodic Leaps):\n"
printf "─────────────────────────────────────────────────────────────────────────────────\n"

for snote in "${STAVE_NOTES[@]}"; do
    printf "%-3s ║" "$snote"
    for pitch in $v1_notes; do
        clean_pitch=$(echo "$pitch" | tr -d '^/_1234567890,')
        case "$snote" in
            "F5") [[ "$clean_pitch" == "f" ]] && printf "──●──" || printf "─────" ;;
            "E5") [[ "$clean_pitch" == "e" ]] && printf "──●──" || printf "─────" ;;
            "D5") [[ "$clean_pitch" == "d" ]] && printf "──●──" || printf "─────" ;;
            "C5") [[ "$clean_pitch" == "c" ]] && printf "──●──" || printf "─────" ;;
            "B4") [[ "$clean_pitch" == "B" ]] && printf "──●──" || printf "─────" ;;
            "A4") [[ "$clean_pitch" == "A" ]] && printf "──●──" || printf "─────" ;;
            "G4") [[ "$clean_pitch" == "G" ]] && printf "──●──" || printf "─────" ;;
            "F4") [[ "$clean_pitch" == "F" ]] && printf "──●──" || printf "─────" ;;
            "E4") [[ "$clean_pitch" == "E" ]] && printf "──●──" || printf "─────" ;;
        esac
    done
    printf "\n"
done
printf "─────────────────────────────────────────────────────────────────────────────────\n"