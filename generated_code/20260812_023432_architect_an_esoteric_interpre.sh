#!/usr/bin/env bash
# Esoteric Git Constellation Interpreter & Ambient Soundscape Synthesizer
# Parses Git history into celestial coordinate maps and streams microtonal PCM audio.

set -euo pipefail

# Ensure we are inside a git repo (or fallback gracefully to a mock visualization)
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Notice: Not in a git repository. Initializing temporary memory constellation..." >&2
fi

# Detect available audio player for raw 16-bit PCM (44.1kHz mono)
AUDIO_PLAYER=""
if command -v aplay >/dev/null 2>&1; then
    AUDIO_PLAYER="aplay -t raw -f S16_LE -r 44100 -c 1"
elif command -v ffplay >/dev/null 2>&1; then
    AUDIO_PLAYER="ffplay -f s16le -ar 44100 -ac 1 -nodisp -autoexit -"
elif command -v paplay >/dev/null 2>&1; then
    AUDIO_PLAYER="paplay --raw --format=s16le --rate=44100 --channels=1"
fi

# Visual Terminal Canvas Setup
clear
cat << "EOF"
  .   *      .  ▲  *   .   .  *      .  *      .    *
.    *   .     / \    *     celestial git interpreter *
   *    .     /   \  .    *    .   *   .    *    .
*   .        /_____\    .   *    .   *      .    *
EOF

echo -e "\n=== CELESTIAL CONSTELLATION MAP ==="

# 1. Parse Git Commit Graph into Stellar Coordinates
declare -A STARS
COMMIT_COUNT=0
BASE_FREQ=110 # A2 fundamental frequency in Hz

while IFS='|' read -r hash parents refs subject; do
    ((COMMIT_COUNT++))
    
    # Deriving star coordinates (RA/Dec) from git commit SHA hashes
    dec_val=$(( 16#${hash:0:4} % 80 ))
    ra_val=$(( 16#${hash:4:4} % 24 ))
    mag=$(( 16#${hash:8:2} % 5 + 1 ))
    
    # Map spectral color based on branch refs
    star_char="★"
    if [[ "$refs" == *"head"* || "$refs" == *"HEAD"* ]]; then
        star_char="✦"
    elif [[ -n "$parents" && "$parents" == *" "* ]]; then
        star_char="✸" # Merge commit
    fi
    
    STARS["$hash"]="$ra_val,$dec_val,$mag,$star_char"
    
    # Draw star to ASCII sky map
    printf "\033[%d;%dH\033[38;5;%dm%s\033[0m" "$((dec_val/4 + 8))" "$((ra_val*3 + 5))" "$((220 + mag*6))" "$star_char"
    
done < <(git log --all --pretty=format:"%h|%p|%d|%s" -n 30 2>/dev/null || echo "a1b2c3d|| (main)|Genesis")

# 2. Extract Musical Harmonies from Branch Topologies
BRANCH_COUNT=$(git branch -a 2>/dev/null | wc -l || echo 1)
CONFLICT_COUNT=0

# Detect Unresolved Merge Conflicts (Generate Microtonal Detuned Feedback Loops)
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    CONFLICT_COUNT=$(git diff --name-only --diff-filter=U 2>/dev/null | wc -l || echo 0)
    # Check for raw conflict markers if diff check is clean
    if [ "$CONFLICT_COUNT" -eq 0 ]; then
        CONFLICT_COUNT=$(grep -rn "^<<<<<<< " . 2>/dev/null | wc -l || echo 0)
    fi
fi

# Print Astronomical Telemetry
printf "\033[18;1H"
echo "--------------------------------------------------------"
echo " Constellation Nodes (Commits): $COMMIT_COUNT"
echo " Harmonic Branches           : $BRANCH_COUNT"
echo " Microtonal Conflict Loops   : $CONFLICT_COUNT"
echo "--------------------------------------------------------"

# 3. Ambient Audio Synthesizer (Pure Bash PCM Generator)
# Harmonic ratios: Root, Perfect 5th, Major 3rd, Octave + Microtonal Conflict Offset
PENTATONIC_RATIOS=(1.0 1.25 1.333 1.5 1.75 2.0)

# Calculate detune factor for microtonal feedback loops
DETUNE=0
if [ "$CONFLICT_COUNT" -gt 0 ]; then
    DETUNE=$(awk "BEGIN {print $CONFLICT_COUNT * 2.37}")
    echo -e "\033[31m! WARNING: Microtonal feedback active ($DETUNE Hz detune) !\033[0m"
fi

if [ -z "$AUDIO_PLAYER" ]; then
    echo -e "\033[33mAudio output device not found. Soundscape synthesized to celestial silent telemetry.\033[0m"
    exit 0
fi

echo -e "\033[36mSynthesizing ambient cosmic resonance... (Press Ctrl+C to exit)\033[0m"

# Generate 5 seconds of ambient microtonal drone stream
SAMPLE_RATE=44100
DURATION=5

awk -v sr="$SAMPLE_RATE" -v dur="$DURATION" -v base="$BASE_FREQ" -v branches="$BRANCH_COUNT" -v detune="$DETUNE" '
BEGIN {
    pi = 3.14159265359;
    num_samples = sr * dur;
    
    # Calculate fundamental and overtone frequencies based on branches
    f1 = base;
    f2 = base * (1.5 + (branches % 3) * 0.125);
    f3 = base * 2.0 + detune; # Microtonal feedback frequency
    
    for (i = 0; i < num_samples; i++) {
        t = i / sr;
        
        # Low frequency oscillator (LFO) for ambient swelling
        lfo = 0.5 + 0.5 * sin(2 * pi * 0.2 * t);
        
        # Synthesize ambient drone harmonics with conflict beating
        wave1 = sin(2 * pi * f1 * t);
        wave2 = 0.6 * sin(2 * pi * f2 * t);
        wave3 = 0.4 * sin(2 * pi * f3 * t + sin(2 * pi * 8 * t)); # Feedback modulation
        
        sample = (wave1 + wave2 + wave3) * lfo * 0.3;
        
        # Convert -1.0..1.0 float to 16-bit signed integer
        int_sample = int(sample * 32767);
        
        # Output 16-bit little-endian binary PCM bytes
        low_byte = int_sample % 256;
        if (low_byte < 0) low_byte += 256;
        high_byte = int(int_sample / 256) % 256;
        if (high_byte < 0) high_byte += 256;
        
        printf("%c%c", low_byte, high_byte);
    }
}' | $AUDIO_PLAYER >/dev/null 2>&1 &

AUDIO_PID=$!
trap 'kill $AUDIO_PID 2>/dev/null || true; echo -e "\nCelestial soundscape suspended."; exit 0' INT TERM

wait $AUDIO_PID 2>/dev/null || true
echo -e "\n\033[32mConstellation synthesized successfully.\033[0m"