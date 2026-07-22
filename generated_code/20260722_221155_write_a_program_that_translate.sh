#!/usr/bin/env bash
# System Thread Harmonizer
# Maps active threads to chord progressions, memory to key signature, and deadlocks to dissonance.

# Audio Settings (8kHz sample rate, 8-bit unsigned PCM)
SAMPLE_RATE=8000
DURATION=1

# Scales (Hz): Major vs Minor Pentatonic
MAJOR_SCALE=(261.63 293.66 329.63 392.00 440.00 523.25) # C4 D4 E4 G4 A4 C5
MINOR_SCALE=(261.63 293.66 311.13 392.00 415.30 523.25) # C4 D4 Eb4 G4 Ab4 C5

echo "Starting System Harmonizer... Press [Ctrl+C] to exit."

while true; do
    # 1. Gather System Metrics
    # Total thread count across all processes
    THREADS=$(ps -eo nlwp 2>/dev/null | awk '{s+=$1} END {print s+0}')
    [ "$THREADS" -eq 0 ] && THREADS=10

    # Memory usage percentage
    MEM_PERC=$(free 2>/dev/null | awk '/Mem:/ {printf "%d", $3/$2*100}')
    [ -z "$MEM_PERC" ] && MEM_PERC=30

    # Potential deadlocks (processes in uninterruptible sleep state 'D')
    DEADLOCKS=$(ps -eo state 2>/dev/null | grep -c 'D')

    # 2. Musical Translation
    # High memory (>70%) triggers Minor scale; normal triggers Major
    if [ "$MEM_PERC" -gt 70 ]; then
        KEY_NAME="MINOR"
        scale=("${MINOR_SCALE[@]}")
    else
        KEY_NAME="MAJOR"
        scale=("${MAJOR_SCALE[@]}")
    fi

    # Thread count dictates chord root index and triad structure
    root_idx=$(( THREADS % ${#scale[@]} ))
    f1=${scale[$root_idx]}
    f2=${scale[$(( (root_idx + 2) % ${#scale[@]} ))]}
    f3=${scale[$(( (root_idx + 4) % ${#scale[@]} ))]}

    # Deadlocks shift pitch microtonally (creates sharp beating / dissonance)
    detune=$(awk -v d="$DEADLOCKS" 'BEGIN {print d * 7.35}')
    f1_final=$(awk -v f="$f1" -v d="$detune" 'BEGIN {print f + d}')
    f2_final=$(awk -v f="$f2" -v d="$detune" 'BEGIN {print f - (d * 1.5)}')
    f3_final=$(awk -v f="$f3" -v d="$detune" 'BEGIN {print f + (d * 2.2)}')

    echo "[Metrics] Threads: $THREADS | Memory: ${MEM_PERC}% ($KEY_NAME) | Deadlocks (D-state): $DEADLOCKS"
    echo "  ↳ Playing Triad: ${f1_final}Hz | ${f2_final}Hz | ${f3_final}Hz"

    # 3. Polyphonic Sound Synthesis via AWK piped to standard ALSA audio player (aplay)
    awk -v r="$SAMPLE_RATE" -v dur="$DURATION" -v f1="$f1_final" -v f2="$f2_final" -v f3="$f3_final" '
    BEGIN {
        pi = 3.14159265359;
        samples = r * dur;
        for (i = 0; i < samples; i++) {
            t = i / r;
            # Envelope to avoid audio clicks at start/end
            env = sin(pi * t / dur);
            # Polyphonic sine wave sum
            w = (sin(2 * pi * f1 * t) + sin(2 * pi * f2 * t) + sin(2 * pi * f3 * t)) / 3.0;
            # Convert float [-1.0, 1.0] to unsigned 8-bit PCM [0, 255]
            sample = int(128 + 120 * w * env);
            printf "%c", sample;
        }
    }' | aplay -q -f U8 -r "$SAMPLE_RATE" -c 1 2>/dev/null

    sleep 0.1
done