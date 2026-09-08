#!/usr/bin/env bash
# ==============================================================================
# LUX-Symphonia: An Esoteric Compiler for Light Pollution & Counterpoint
# Translates global light pollution data (SQM) into printable SVG Sheet Music.
# ==============================================================================

set -euo pipefail

# 1. GENERATE SYNTHETIC LIGHT POLLUTION DATASET (SQM: Sky Quality Meter Values)
# Lower SQM (e.g., 16.0) = Urban light pollution; Higher (e.g., 22.0) = Pristine night sky.
generate_light_data() {
    cat << 'EOF'
Year,Location,SQM_Value
1990,Tokyo,16.2
1995,Tokyo,15.8
2000,Tokyo,15.4
2005,Tokyo,15.1
2010,Tokyo,14.8
1990,Atacama,21.9
1995,Atacama,21.8
2000,Atacama,21.7
2005,Atacama,21.6
2010,Atacama,21.5
1990,London,17.1
1995,London,16.8
2000,London,16.5
2005,London,16.2
2010,London,15.9
1990,Galloway,21.2
1995,Galloway,21.0
2000,Galloway,20.8
2005,Galloway,20.5
2010,Galloway,20.3
EOF
}

# Pitch map representing diatonic scale positions (C4=0 to C6=14)
NOTES=("C4" "D4" "E4" "F4" "G4" "A4" "B4" "C5" "D5" "E5" "F5" "G5" "A5" "B5" "C6")

# Map SQM value (14.0 - 22.0) to an index in the NOTES array
sqm_to_cantus() {
    local sqm=$1
    # Awk maps range [14.0, 22.0] into integers [0, 14]
    awk -v val="$sqm" 'BEGIN {
        idx = int((val - 14.0) / (22.0 - 14.0) * 14.0 + 0.5);
        if (idx < 0) idx = 0;
        if (idx > 14) idx = 14;
        print idx;
    }'
}

# Esoteric Counterpoint Engine: Generates a counterpoint note index based on Cantus Firmus
apply_counterpoint() {
    local cantus_idx=$1
    local prev_counter_idx=${2:-7} # Default start around G4/A4

    # Rules:
    # 1. Prefer consonant intervals: 3rds (2 steps), 6ths (5 steps), or Octaves (7 steps)
    # 2. Contrary motion: move in opposite direction relative to Cantus Firmus
    local target
    if (( cantus_idx > 7 )); then
        target=$(( cantus_idx - 3 )) # Contrary down
    else
        target=$(( cantus_idx + 3 )) # Contrary up
    fi

    # Adjust relative to previous note to avoid large leaps
    local diff=$(( target - prev_counter_idx ))
    if (( diff > 4 )); then target=$(( prev_counter_idx + 2 )); fi
    if (( diff < -4 )); then target=$(( prev_counter_idx - 2 )); fi

    # Clamp index within valid range
    if (( target < 0 )); then target=0; fi
    if (( target > 14 )); then target=14; fi

    echo "$target"
}

# SVG Rendering engine: Produces printable vector sheet music
render_svg_score() {
    local cantus_notes=("$@")
    local num_notes=${#cantus_notes[@]}
    
    # SVG Header
    cat << 'EOF'
<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="0 0 1000 600" width="100%" height="100%">
  <style>
    .title { font-family: 'Courier New', monospace; font-size: 24px; font-weight: bold; fill: #111; }
    .subtitle { font-family: 'Courier New', monospace; font-size: 14px; fill: #555; }
    .staff-line { stroke: #333; stroke-width: 1.5; }
    .bar-line { stroke: #333; stroke-width: 2; }
    .note-head { fill: #111; }
    .stem { stroke: #111; stroke-width: 2; }
    .text-label { font-family: sans-serif; font-size: 10px; fill: #666; }
    .counter-note { fill: #d9534f; }
    .counter-stem { stroke: #d9534f; stroke-width: 2; }
  </style>
  <rect width="100%" height="100%" fill="#faf8f5" />
  
  <!-- Title & Metadata -->
  <text x="50" y="50" class="title">LUX-SYMPHONIA: NOCTURNE FOR GLOBAL LIGHTS</text>
  <text x="50" y="75" class="subtitle">Algorithmic Counterpoint Compiled from Historical SQM Light Pollution Fluctuation</text>
  <text x="50" y="95" class="subtitle">Black: Cantus Firmus (Light Data) | Red: Generated Counterpoint</text>
EOF

    # Draw Staves
    # Treble Staff 1 (Cantus Firmus): Y base = 200
    # Treble Staff 2 (Counterpoint): Y base = 380
    local staff1_y=200
    local staff2_y=380

    for (( i=0; i<5; i++ )); do
        local y1=$(( staff1_y + i*15 ))
        local y2=$(( staff2_y + i*15 ))
        echo "  <line x1=\"80\" y1=\"$y1\" x2=\"920\" y2=\"$y1\" class=\"staff-line\" />"
        echo "  <line x1=\"80\" y1=\"$y2\" x2=\"920\" y2=\"$y2\" class=\"staff-line\" />"
    done

    # Draw Bar Lines (Start & End)
    echo "  <line x1=\"80\" y1=\"$staff1_y\" x2=\"80\" y2=\"$((staff1_y+60))\" class=\"bar-line\" />"
    echo "  <line x1=\"920\" y1=\"$staff1_y\" x2=\"920\" y2=\"$((staff1_y+60))\" class=\"bar-line\" />"
    echo "  <line x1=\"80\" y1=\"$staff2_y\" x2=\"80\" y2=\"$((staff2_y+60))\" class=\"bar-line\" />"
    echo "  <line x1=\"920\" y1=\"$staff2_y\" x2=\"920\" y2=\"$((staff2_y+60))\" class=\"bar-line\" />"

    # Clef Representation (Text glyphs for simplicity)
    echo "  <text x=\"50\" y=\"$((staff1_y+45))\" font-family=\"serif\" font-size=\"50\">𝄞</text>"
    echo "  <text x=\"50\" y=\"$((staff2_y+45))\" font-family=\"serif\" font-size=\"50\">𝄞</text>"

    # Render Notes & Counterpoint
    local start_x=120
    local step_x=$(( (920 - 120) / num_notes ))
    local prev_counter=7

    for (( i=0; i<num_notes; i++ )); do
        local c_idx=${cantus_notes[$i]}
        local counter_idx
        counter_idx=$(apply_counterpoint "$c_idx" "$prev_counter")
        prev_counter=$counter_idx

        local x=$(( start_x + i * step_x ))
        
        # Note positions mapping (E4 = bottom line, E4 index is 2)
        # Each index step is half a staff space (7.5px)
        local c_y=$(( staff1_y + 60 - (c_idx * 7.5) ))
        local cp_y=$(( staff2_y + 60 - (counter_idx * 7.5) ))

        # Measure / Beat separators every 4 notes
        if (( i > 0 && i % 4 == 0 )); then
            echo "  <line x1=\"$((x - step_x/2))\" y1=\"$staff1_y\" x2=\"$((x - step_x/2))\" y2=\"$((staff1_y+60))\" class=\"staff-line\" stroke-dasharray=\"2,2\" />"
            echo "  <line x1=\"$((x - step_x/2))\" y1=\"$staff2_y\" x2=\"$((x - step_x/2))\" y2=\"$((staff2_y+60))\" class=\"staff-line\" stroke-dasharray=\"2,2\" />"
        fi

        # Draw Cantus Firmus Note (Black)
        echo "  <ellipse cx=\"$x\" cy=\"$c_y\" rx=\"7\" ry=\"5\" class=\"note-head\" transform=\"rotate(-20 $x $c_y)\" />"
        echo "  <line x1=\"$((x+6))\" y1=\"$c_y\" x2=\"$((x+6))\" y2=\"$((c_y - 30))\" class=\"stem\" />"
        
        # Ledger line for low C4 if needed
        if (( c_idx == 0 )); then
            echo "  <line x1=\"$((x-10))\" y1=\"$((staff1_y+60))\" x2=\"$((x+10))\" y2=\"$((staff1_y+60))\" class=\"staff-line\" />"
        fi

        # Draw Counterpoint Note (Red)
        echo "  <ellipse cx=\"$x\" cy=\"$cp_y\" rx=\"7\" ry=\"5\" class=\"note-head counter-note\" transform=\"rotate(-20 $x $cp_y)\" />"
        echo "  <line x1=\"$((x+6))\" y1=\"$cp_y\" x2=\"$((x+6))\" y2=\"$((cp_y - 30))\" class=\"counter-stem\" />"

        # Ledger line for counterpoint low C4
        if (( counter_idx == 0 )); then
            echo "  <line x1=\"$((x-10))\" y1=\"$((staff2_y+60))\" x2=\"$((x+10))\" y2=\"$((staff2_y+60))\" class=\"staff-line\" />"
        fi
    done

    echo "</svg>"
}

# --- MAIN EXECUTION PIPELINE ---
main() {
    local output_file="light_pollution_score.svg"
    local cantus_sequence=()

    # Parse dataset & extract raw SQM metrics into cantus firmus pitches
    while IFS=',' read -r year location sqm; do
        [[ "$year" == "Year" ]] && continue # Skip header
        local note_idx
        note_idx=$(sqm_to_cantus "$sqm")
        cantus_sequence+=("$note_idx")
    done < <(generate_light_data)

    # Compile data into SVG score sheet
    render_svg_score "${cantus_sequence[@]}" > "$output_file"

    echo "Compilation complete." >&2
    echo "Generative score exported to: $output_file" >&2
}

main "$@"