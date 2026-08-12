#!/usr/bin/env bash
# ==============================================================================
# Gothic Echoes: Interactive Kernel-Driven Stained Glass & Pipe Organ Visualizer
# 
# Parses live kernel log events to dynamically render an evolving medieval 
# gothic rosette glass window in ANSI terminal graphics while synthesizing 
# microtonal pipe organ harmonics based on memory allocation metrics.
# ==============================================================================

# Ensure cleanup on exit
trap 'printf "\e[?25h\e[0m\e[2J\e[H"; kill 0 2>/dev/null; exit' EXIT INT TERM

# Initialize terminal interface
printf "\e[?25l\e[2J\e[H"
COLS=$(tput cols 2>/dev/null || echo 80)
LINES=$(tput lines 2>/dev/null || echo 24)
CX=$((COLS / 2))
CY=$((LINES / 2))
RAD=$(( LINES < COLS/2 ? LINES/2 - 2 : COLS/4 - 2 ))
[[ $RAD -lt 4 ]] && RAD=6

# Audio Pipe Setup (generates microtonal organ PCM syntheses via background worker)
AUDIO_FIFO="/tmp/organ_pipe_$$.fifo"
mkfifo "$AUDIO_FIFO" 2>/dev/null
(
  # Audio player fallback check (aplay, paplay, or silence)
  if command -v aplay >/dev/null 2>&1; then
    aplay -q -f U8 -r 8000 -c 1 "$AUDIO_FIFO" 2>/dev/null
  elif command -v paplay >/dev/null 2>&1; then
    paplay --raw --channels=1 --rate=8000 "$AUDIO_FIFO" 2>/dev/null
  else
    cat "$AUDIO_FIFO" > /dev/null
  fi
) &

# Background Pipe Organ Synthesizer in AWK
# Synthesizes additive microtonal organ pipe sounds (Fundamental + Harmonics)
exec 3>"$AUDIO_FIFO"
play_chord() {
  local f1=$1 f2=$2 f3=$3 duration=$4
  awk -v f1="$f1" -v f2="$f2" -v f3="$f3" -v dur="$duration" '
  BEGIN {
    sr = 8000;
    samples = int(sr * dur);
    for (i = 0; i < samples; i++) {
      t = i / sr;
      # Microtonal pipe organ timbre: fundamental + octave + 5th + octave upper
      wave = sin(2 * 3.14159 * f1 * t) * 0.4 + \
             sin(2 * 3.14159 * f2 * t) * 0.3 + \
             sin(2 * 3.14159 * f3 * t) * 0.2 + \
             sin(2 * 3.14159 * (f1 * 2) * t) * 0.1;
      # Envelope (smooth decay)
      env = 1.0 - (i / samples);
      val = int(128 + 120 * wave * env);
      if (val < 0) val = 0; if (val > 255) val = 255;
      printf "%c", val;
    }
  }' >&3 2>/dev/null &
}

# Medieval Stained Glass Color Palettes (24-bit RGB)
COLORS_RUBY=( "180;20;30" "220;40;50" "140;10;20" "255;70;80" )
COLORS_COBALT=( "20;50;180" "40;80;220" "10;30;140" "70;120;255" )
COLORS_AMBER=( "220;150;30" "250;180;50" "180;110;10" "255;210;90" )
COLORS_EMERALD=( "20;140;60" "40;180;90" "10;90;30" "70;220;120" )
COLORS_AMETHYST=( "120;30;160" "160;50;200" "80;10;120" "200;90;240" )

ALL_PALETTES=( COLORS_RUBY COLORS_COBALT COLORS_AMBER COLORS_EMERALD COLORS_AMETHYST )

# Calculate stained glass traceries and geometry
render_glass_window() {
  local energy=$1
  local mem_spike=$2
  local log_hash=$3

  # Gothic Arch & Rosette Drawing Buffer
  for ((y=1; y<=LINES; y++)); do
    for ((x=1; x<=COLS; x+=2)); do
      # Distance relative to center
      dx=$(( (x - CX) / 2 ))
      dy=$(( y - CY ))
      dist_sq=$(( dx*dx + dy*dy ))
      dist=$(awk "BEGIN {print sqrt($dist_sq)}")

      # Angle for radial petal geometry
      angle=$(awk "BEGIN {print atan2($dy, $dx)}")

      # Frame boundaries & tracery lines
      is_lead_frame=0
      
      # Outer Gothic Arch / Rosette border
      if awk "BEGIN {exit !($dist >= $RAD - 0.6 && $dist <= $RAD + 0.6)}"; then
        is_lead_frame=1
      # Concentric ring tracery
      elif awk "BEGIN {exit !($dist >= $RAD*0.5 - 0.4 && $dist <= $RAD*0.5 + 0.4)}"; then
        is_lead_frame=1
      fi

      # 8-fold radial spoke tracery
      spoke=$(awk -v a="$angle" 'BEGIN {val = sin(8 * a); print (val > -0.15 && val < 0.15) ? 1 : 0}')
      if [[ $spoke -eq 1 && $(awk "BEGIN {print ($dist <= $RAD)?1:0}") -eq 1 ]]; then
        is_lead_frame=1
      fi

      # Render Lead Frame (Dark Iron) or Colored Glass Panes
      if [[ $is_lead_frame -eq 1 ]]; then
        printf "\e[%d;%dH\e[48;2;30;30;35m\e[38;2;10;10;12m╬╬" "$y" "$x"
      elif awk "BEGIN {exit !($dist < $RAD)}"; then
        # Determine glass sector ID
        sector=$(awk -v a="$angle" -v d="$dist" -v r="$RAD" 'BEGIN {
          sec = int((a + 3.14159) / (2 * 3.14159) * 8);
          ring = (d > r*0.5) ? 1 : 0;
          print sec + (ring * 8);
        }')

        # Map log hash and memory activity to color selections
        pal_idx=$(( (log_hash + sector + mem_spike) % 5 ))
        color_arr_name="${ALL_PALETTES[$pal_idx]}[$(( (sector + energy) % 4 ))]"
        eval rgb=\${$color_arr_name}

        # Light pulsing effect based on kernel log activity
        if [[ $energy -gt 0 && $(( RANDOM % 3 )) -eq 0 ]]; then
          rgb="255;255;240" # Flash lumen
        fi

        printf "\e[%d;%dH\e[48;2;%sm  " "$y" "$x" "$rgb"
      else
        # Dark stone background outer wall
        printf "\e[%d;%dH\e[48;2;12;10;15m\e[38;2;25;20;30m░░" "$y" "$x"
      fi
    done
  done
}

# Live Kernel Log Parsing Engine
read_kernel_stream() {
  if command -v dmesg >/dev/null 2>&1; then
    dmesg -w 2>/dev/null || dmesg 2>/dev/null | tail -f -n 20
  elif [[ -r /var/log/syslog ]]; then
    tail -f -n 20 /var/log/syslog
  else
    # Fallback simulated kernel log generator if restricted environment
    while true; do
      echo "[$(date +%s.%N)] kmalloc allocation spike: pages=$((RANDOM % 4096)) flags=0x$(printf '%x' $RANDOM)"
      sleep 0.2
    done
  fi
}

# Main Event Processing Loop
printf "\e[1;1H\e[38;2;255;215;0m-- GOTHIC ECHOES: KERNEL LOG STAINED GLASS ORGAN --\e[0m"

read_kernel_stream | while read -r log_line; do
  # Extract numeric features and memory allocation signatures from log line
  log_len=${#log_line}
  log_hash=0
  for (( i=0; i<log_len; i++ )); do
    char_code=$(printf '%d' "'${log_line:$i:1}")
    log_hash=$(( (log_hash * 31 + char_code) % 65536 ))
  done

  # Detect memory spikes / allocation signatures in kernel messages
  mem_spike=0
  if [[ "$log_line" =~ (alloc|page|kmalloc|mem|slab|dma|buffer|vma) ]]; then
    mem_spike=1
  fi

  # Compute Microtonal Pipe Organ Frequencies (Just Intonation & 19-TET Ratios)
  # Base octave: ~110Hz - 220Hz (A2 - A3 organ fundamental)
  base_freq=$(awk -v h="$log_hash" 'BEGIN {print 110 + (h % 110)}')
  
  # Microtonal intervals (e.g., 19-TET pitch steps: 2^(n/19))
  ratio1=$(awk -v s="$((log_hash % 19))" 'BEGIN {print 2 ^ (s / 19.0)}')
  ratio2=$(awk -v s="$(((log_hash + 7) % 19))" 'BEGIN {print 2 ^ (s / 19.0)}')

  f1=$(awk "BEGIN {print $base_freq * $ratio1}")
  f2=$(awk "BEGIN {print $base_freq * $ratio2}")
  f3=$(awk "BEGIN {print $base_freq * 1.5}") # Just fifth overlay

  # Trigger microtonal chord synthesis upon memory allocation event
  if [[ $mem_spike -eq 1 ]]; then
    play_chord "$f1" "$f2" "$f3" 0.35
    energy=2
  else
    play_chord "$f1" "$f2" "$f3" 0.15
    energy=0
  fi

  # Evolve terminal stained glass rendering
  render_glass_window "$energy" "$mem_spike" "$log_hash"

  # Render Live Kernel Log Overlay at bottom
  trimmed_log="${log_line:0:$((COLS - 4))}"
  printf "\e[%d;2H\e[48;2;0;0;0m\e[38;2;200;180;100m %-*s \e[0m" "$((LINES - 1))" "$((COLS - 4))" "$trimmed_log"
done