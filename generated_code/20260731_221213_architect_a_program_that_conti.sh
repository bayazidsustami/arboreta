#!/usr/bin/env bash
# Computer Brain Synth: Translates live CPU usage into an evolving polyphonic audio patch.
# Dependencies: Linux with ALSA (aplay)

if ! command -v aplay &>/dev/null; then
  echo "Error: 'aplay' (ALSA audio player) is required." >&2
  exit 1
fi

STATE_FILE="/tmp/cpu_synth_$($$).state"
echo "220 330 440 1" > "$STATE_FILE"

# Clean up subprocesses and state file on exit
trap 'rm -f "$STATE_FILE"; kill 0; exit 0' EXIT INT TERM

# Background worker: Continuously monitors /proc/stat and updates synthesizer parameter state
(
  prev_total=0
  prev_idle=0

  while true; do
    read -r cpu user nice sys idle iowait irq softirq steal _ < /proc/stat
    total=$((user + nice + sys + idle + iowait + irq + softirq + steal))
    idle_val=$((idle + iowait))

    diff_total=$((total - prev_total))
    diff_idle=$((idle_val - prev_idle))

    prev_total=$total
    prev_idle=$idle_val

    if [ "$diff_total" -gt 0 ]; then
      usage=$(( 100 * (diff_total - diff_idle) / diff_total ))
    else
      usage=5
    fi

    # Map CPU percentage to harmonic chord frequencies (Pentatonic/Polyphonic distribution)
    # Pitch, harmonic spread, and FM modulation index react dynamically to system load
    f1=$(( 110 + (usage * 3) ))
    f2=$(( 165 + (usage * 5) ))
    f3=$(( 220 + (usage * 7) ))
    mod=$(( (usage / 12) + 1 ))

    echo "$f1 $f2 $f3 $mod" > "$STATE_FILE"
    sleep 0.15
  done
) &

# Real-time Bytebeat audio synthesis engine piping raw 8-bit PCM at 8000 Hz into aplay
(
  t=0
  while true; do
    read -r f1 f2 f3 m < "$STATE_FILE" 2>/dev/null || { f1=220; f2=330; f3=440; m=1; }

    # Polyphonic square/saw wave synthesis with FM modulation driven by live CPU state
    sample=$(( (((t * f1 / 1000) ^ (t * f2 / 1000)) + ((t * f3 / 1000) * m)) & 255 ))

    # Output raw unsigned 8-bit audio byte
    printf "\\$(printf '%03o' "$sample")"
    ((t++))
  done
) | aplay -q -f U8 -r 8000 -c 1