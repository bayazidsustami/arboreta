#!/usr/bin/env bash
# Git Chiptune Ecosystem Synthesizer
# Maps git commit histories into microtonal chiptune frequencies and renders a glowing ASCII repository branch tree.

set -u

# Handle terminal restoration on exit
cleanup() {
    printf '\e[?25h\e[0m\e[2J\e[1;1H'
    if [[ -n "${SOX_PID:-}" ]]; then
        kill "$SOX_PID" 2>/dev/null || true
    fi
    exit 0
}
trap cleanup EXIT INT TERM

# Ensure stdout uses a safe fallback if no terminal attached
exec 3>&1

# Colors and graphics setup
printf '\e[?25l\e[2J\e[1;1H'

# Generate microtonal frequencies (24-TET scale base near A4=440Hz)
# F(n) = 440 * 2^((n-24)/24)
freqs=()
for i in {0..47}; do
    freqs+=($(awk -v n="$i" 'BEGIN { printf "%.2f", 440 * (2 ** ((n - 24) / 24)) }'))
done

# Collect git commit history or fallback to simulated commits
commits=()
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r line; do
        commits+=("$line")
    done < <(git log --pretty=format:"%h|%s" -n 30 2>/dev/null)
fi

if [[ ${#commits[@]} -eq 0 ]]; then
    commits=(
        "a1b2c3d|Initial synthesis engine"
        "e4f5g6h|Add microtonal oscillator array"
        "7890abc|Merge branch 'feature/polyphony'"
        "def1234|Fix buffer overflow in ASCII render"
        "5678ghi|Evolve leaf nodes in tree matrix"
        "jkl9012|Optimize DSP audio thread pipeline"
        "3456mno|Refactor git tree parser engine"
        "pqr7890|Release v1.0 glowing ecosystem"
    )
fi

# Audio Synthesis Engine setup
# Generates a background stream of microtonal polyphonic square waves using standard audio generators or pure system tones
audio_fifo=$(mktemp -u)
mkfifo "$audio_fifo" 2>/dev/null || true

if command -v play >/dev/null 2>&1; then
    (
        while true; do
            read -r note1 note2 note3 < "$audio_fifo" || break
            play -q -n synth 0.15 sq "${note1:-440}" sq "${note2:-554.37}" sq "${note3:-659.25}" gain -12 synth 0.15 chorus 0.7 0.9 55 0.4 0.25 2 -t lowpass 2400 2>/dev/null || true
        done
    ) &
    SOX_PID=$!
elif command -v speaker-test >/dev/null 2>&1; then
    (
        while true; do
            read -r note1 note2 note3 < "$audio_fifo" || break
            speaker-test -t sine -f "${note1%.*}" -l 1 >/dev/null 2>&1 || true
        done
    ) &
    SOX_PID=$!
else
    # Fallback visual-only mode indicator
    SOX_PID=""
fi

exec 4>"$audio_fifo"

# Glowing ASCII Ecosystem Symbols & Palette
palette=(196 202 208 214 220 154 46 48 51 39 27 93 129 165 201)
chars=("🍂" "🌿" "🌸" "🌺" "💎" "⚡" "✨" "❄️" "🍄" "🌳")

ascii_art=(
"         /\          "
"        /  \         "
"       / /\ \        "
"      / /  \ \       "
"     / /    \ \      "
"    /_/      \_\     "
)

commit_idx=0
total_commits=${#commits[@]}

# Main Interactive Loop
while true; do
    commit="${commits[$commit_idx]}"
    hash="${commit%%|*}"
    msg="${commit#*|}"

    # Extract hex numeric values from commit hash for microtonal polyphony
    hex1=$((16#${hash:0:2}))
    hex2=$((16#${hash:2:2}))
    hex3=$((16#${hash:4:2}))

    note1="${freqs[$((hex1 % 48))]}"
    note2="${freqs[$((hex2 % 48))]}"
    note3="${freqs[$((hex3 % 48))]}"

    # Send notes to audio pipeline
    if [[ -n "$SOX_PID" ]]; then
        echo "$note1 $note2 $note3" >&4 2>/dev/null || true
    fi

    # Render Living ASCII Ecosystem Header
    printf '\e[1;1H\e[2K'
    color_idx=$(( (hex1 + commit_idx) % ${#palette[@]} ))
    color="${palette[$color_idx]}"
    
    printf "\e[38;5;%sm--- GIT CHIPTUNE ECOSYSTEM --- [Commit %d/%d]\e[0m\n" "$color" "$((commit_idx + 1))" "$total_commits"
    printf "\e[2K\e[1mHash:\e[0m \e[38;5;51m%s\e[0m | \e[1mMessage:\e[0m %s\n" "$hash" "$msg"
    printf "\e[2K\e[1mMicrotonal Triad:\e[0m \e[38;5;208m%s Hz\e[0m | \e[38;5;118m%s Hz\e[0m | \e[38;5;198m%s Hz\e[0m\n\n" "$note1" "$note2" "$note3"

    # Dynamic Tree Ecosystem Rendering
    branch_symbol="${chars[$((hex2 % ${#chars[@]}))]}"
    
    for row in "${ascii_art[@]}"; do
        printf "\e[2K  "
        for (( i=0; i<${#row}; i++ )); do
            ch="${row:$i:1}"
            if [[ "$ch" != " " ]]; then
                node_color=$(( (color + i * 3) % 255 ))
                # Random organism bloom based on commit resonance
                if [[ $((RANDOM % 8)) -eq 0 ]]; then
                    printf "\e[38;5;%sm%s\e[0m" "$node_color" "$branch_symbol"
                else
                    printf "\e[38;5;%sm%s\e[0m" "$node_color" "$ch"
                fi
            else
                printf " "
            fi
        done
        printf "\n"
    done

    # Draw dynamic glowing roots/branches
    printf "\e[2K  "
    for (( b=0; b<30; b++ )); do
        glow_color=$(( (hex3 + b * 7) % 231 + 16 ))
        if [[ $(( (hex1 + b) % 3 )) -eq 0 ]]; then
            printf "\e[38;5;%sm|\e[0m" "$glow_color"
        elif [[ $(( (hex2 + b) % 4 )) -eq 0 ]]; then
            printf "\e[38;5;%sm/\e[0m" "$glow_color"
        elif [[ $(( (hex3 + b) % 5 )) -eq 0 ]]; then
            printf "\e[38;5;%sm\\\e[0m" "$glow_color"
        else
            printf "\e[38;5;%sm~\e[0m" "$glow_color"
        fi
    done
    printf "\n\n"

    # Terminal Audio Spectrum Visualizer
    printf "\e[2K\e[1mAudio Spectrum Waveform:\e[0m\n\e[2K  "
    bars=(" " "▂" "▃" "▄" "▅" "▆" "▇" "█")
    for (( s=0; s<40; s++ )); do
        height=$(( (hex1 * s + commit_idx * 13) % 8 ))
        bar_color=$(( 16 + (s * 5) % 200 ))
        printf "\e[38;5;%sm%s\e[0m" "$bar_color" "${bars[$height]}"
    done
    printf "\n\n"
    printf "\e[2K\e[2mPress Ctrl+C to stop performance.\e[0m"

    commit_idx=$(( (commit_idx + 1) % total_commits ))
    sleep 0.25
done