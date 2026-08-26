#!/usr/bin/env bash
# Audio Visualizer: Parses a recursive function trace to generate a microtonal 
# polyphonic SVG spectrum map (frequencies, microtonal tuning, and time/depth matrix).

OUTPUT_SVG="spectrum_map.svg"

# Base scale configuration: 19-Tone Equal Temperament (19-TET) root frequency (Hz)
ROOT_FREQ=220.00
TET_STEPS=19

# Global arrays to store execution trace data: [time_step, depth, step_cost, frequency_hz]
declare -a TRACE_STEPS
declare -a TRACE_DEPTHS
declare -a TRACE_COSTS
declare -a TRACE_FREQS

STEP_COUNTER=0

# Recursive function: Calculates Fibonacci with trace logging to synthesize audio pitches
trace_recursive_fn() {
    local n=$1
    local depth=$2
    local start_time=$STEP_COUNTER

    ((STEP_COUNTER++))

    # Derive microtonal pitch from recursion properties (depth & value)
    # Pitch step mapping: (depth * 5 + n * 3) % 19-TET steps
    local pitch_step=$(( (depth * 5 + n * 3) % TET_STEPS ))
    # Calculate microtonal frequency using 19-TET ratio: f = f0 * 2^(step / 19)
    local freq
    freq=$(awk -v f0="$ROOT_FREQ" -v step="$pitch_step" -v tet="$TET_STEPS" 'BEGIN { printf "%.2f", f0 * (2 ^ (step / tet)) }')

    if [ "$n" -le 1 ]; then
        local cost=1
        TRACE_STEPS+=("$start_time")
        TRACE_DEPTHS+=("$depth")
        TRACE_COSTS+=("$cost")
        TRACE_FREQS+=("$freq")
        echo "$cost"
        return
    fi

    # Recursive steps (polyphonic branching)
    local left_cost
    left_cost=$(trace_recursive_fn $((n - 1)) $((depth + 1)))
    
    local right_cost
    right_cost=$(trace_recursive_fn $((n - 2)) $((depth + 1)))

    local total_cost=$((left_cost + right_cost + 1))

    TRACE_STEPS+=("$start_time")
    TRACE_DEPTHS+=("$depth")
    TRACE_COSTS+=("$total_cost")
    TRACE_FREQS+=("$freq")

    echo "$total_cost"
}

# Execute recursion trace (depth parameter controls density and duration)
RECURSION_INPUT=7
trace_recursive_fn "$RECURSION_INPUT" 0 > /dev/null

# Render execution trace and microtonal frequencies directly to an SVG Spectrum Map
render_svg_spectrum() {
    local count=${#TRACE_STEPS[@]}
    local width=1000
    local height=600
    local padding=60

    cat <<EOF> "$OUTPUT_SVG"
<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="0 0 $width $height" width="100%" height="100%" style="background-color: #0b0d13; font-family: monospace;">
  <defs>
    <linearGradient id="bg-glow" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#141824"/>
      <stop offset="100%" stop-color="#07080c"/>
    </linearGradient>
    <filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="4" result="blur" />
      <feComposite in="SourceGraphic" in2="blur" operator="over"/>
    </filter>
  </defs>

  <!-- Background -->
  <rect width="100%" height="100%" fill="url(#bg-glow)" />

  <!-- Grid lines -->
  <g stroke="#1e2638" stroke-width="1" stroke-dasharray="4 4">
    <line x1="$padding" y1="100" x2="$((width - padding))" y2="100" />
    <line x1="$padding" y1="200" x2="$((width - padding))" y2="200" />
    <line x1="$padding" y1="300" x2="$((width - padding))" y2="300" />
    <line x1="$padding" y1="400" x2="$((width - padding))" y2="400" />
    <line x1="$padding" y1="500" x2="$((width - padding))" y2="500" />
  </g>

  <!-- Title & Meta Header -->
  <text x="$padding" y="40" fill="#00f3ff" font-size="18" font-weight="bold" letter-spacing="2">RECURSION EXECUTION SPECTRUM MAP [19-TET]</text>
  <text x="$padding" y="58" fill="#607080" font-size="11">Trace Depth: $RECURSION_INPUT | Total Nodes: $count | Microtonal Polyphony Synthesized</text>

  <!-- Spectrum Map Points -->
  <g id="spectrum-nodes">
EOF

    # Calculate scale parameters
    local min_freq=200
    local max_freq=450
    local plot_w=$((width - 2 * padding))
    local plot_h=$((height - 2 * padding - 40))

    for (( i=0; i<count; i++ )); do
        local step=${TRACE_STEPS[$i]}
        local depth=${TRACE_DEPTHS[$i]}
        local cost=${TRACE_COSTS[$i]}
        local freq=${TRACE_FREQS[$i]}

        # Map coordinates
        local cx
        cx=$(awk -v s="$step" -v total="$count" -v pw="$plot_w" -v pad="$padding" 'BEGIN { printf "%.2f", pad + (s / (total - 1)) * pw }')
        
        local cy
        cy=$(awk -v f="$freq" -v min="$min_freq" -v max="$max_freq" -v ph="$plot_h" -v pad="$padding" 'BEGIN { printf "%.2f", (pad + ph) - ((f - min) / (max - min)) * ph }')

        # Map color hue from recursion depth, radius/amplitude from node cost
        local hue=$(( (depth * 45 + 180) % 360 ))
        local r
        r=$(awk -v c="$cost" 'BEGIN { printf "%.2f", 4 + (c * 1.5) }')
        local opacity
        opacity=$(awk -v d="$depth" 'BEGIN { printf "%.2f", 0.9 - (d * 0.1) }')

        # Draw visual polyphonic node + spectral visual line
        cat <<EOF>> "$OUTPUT_SVG"
    <!-- Step $step: Depth $depth, $freq Hz -->
    <line x1="$cx" y1="$((height - padding))" x2="$cx" y2="$cy" stroke="hsl($hue, 80%, 50%)" stroke-opacity="0.25" stroke-width="1.5" />
    <circle cx="$cx" cy="$cy" r="$r" fill="hsl($hue, 90%, 60%)" fill-opacity="$opacity" stroke="#ffffff" stroke-width="0.8" filter="url(#glow)">
      <title>Step: $step | Depth: $depth | Freq: ${freq}Hz | Cost: $cost</title>
    </circle>
EOF
    done

    # X and Y Axis rendering
    cat <<EOF>> "$OUTPUT_SVG"
  </g>

  <!-- Axes -->
  <g stroke="#405068" stroke-width="2">
    <line x1="$padding" y1="$((height - padding))" x2="$((width - padding))" y2="$((height - padding))" />
    <line x1="$padding" y1="80" x2="$padding" y2="$((height - padding))" />
  </g>

  <!-- Labels -->
  <text x="$((width / 2))" y="$((height - 15))" fill="#8090a0" font-size="12" text-anchor="middle">Execution Time Step (Trace Sequence)</text>
  <text x="15" y="$((height / 2))" fill="#8090a0" font-size="12" text-anchor="middle" transform="rotate(-90 15 $((height / 2)))">Synthesized Frequency (Hz / 19-TET)</text>
</svg>
EOF
}

render_svg_spectrum
echo "Successfully generated audio visualizer spectrum: $OUTPUT_SVG"