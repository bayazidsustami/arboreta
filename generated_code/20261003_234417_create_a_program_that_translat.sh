#!/usr/bin/env bash
# Mariana Trench Pressure Fractal Terrarium Generator
# Translates 1,071 atm (108.6 MPa) into a procedural SVG terrarium with physics particles & filters.

OUTPUT_FILE="mariana_terrarium.svg"
PRESSURE=1071 # Atmospheres
PARTICLE_COUNT=150

cat << 'EOF' > "$OUTPUT_FILE"
<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="0 0 800 600" width="100%" height="100%">
  <defs>
    <!-- Deep sea abyss gradient -->
    <linearGradient id="abyss" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#020813" />
      <stop offset="50%" stop-color="#051c2c" />
      <stop offset="100%" stop-color="#010408" />
    </linearGradient>

    <!-- Fractal turbulence filter driven by pressure magnitude -->
    <filter id="fractal-terrarium" x="-20%" y="-20%" width="140%" height="140%">
      <feTurbulence type="fractalNoise" baseFrequency="0.015" numOctaves="5" result="noise" seed="1071">
        <animate attributeName="baseFrequency" values="0.015;0.025;0.015" dur="12s" repeatCount="indefinite" />
      </feTurbulence>
      <feDisplacementMap in="SourceGraphic" in2="noise" scale="35" xChannelSelector="R" yChannelSelector="G" result="displaced" />
      <feColorMatrix type="matrix" values="
        0.2 0 0 0 0.05
        0 0.8 0.4 0 0.1
        0.1 0.3 1 0 0.2
        0 0 0 1 0" in="displaced" result="colored" />
    </filter>

    <!-- Bioluminescent glow filter -->
    <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="6" result="blur" />
      <feMerge>
        <feMergeNode in="blur" />
        <feMergeNode in="SourceGraphic" />
      </feMerge>
    </filter>
  </defs>

  <!-- Background -->
  <rect width="800" height="600" fill="url(#abyss)" />

  <!-- Central Fractal Terrarium Structure -->
  <g filter="url(#fractal-terrarium)" transform="translate(400, 300)">
    <circle cx="0" cy="0" r="180" fill="#0f384c" opacity="0.8" />
    <path d="M-120,-120 Q0,-200 120,-120 T200,0 T120,120 T0,200 T-120,120 T-200,0 Z" fill="none" stroke="#26a69a" stroke-width="3" opacity="0.6" />
  </g>
EOF

# Dynamically inject procedural pressure-driven particles
echo "  <!-- Procedural Hydrothermal Vent Particles (Pressure: ${PRESSURE} atm) -->" >> "$OUTPUT_FILE"
echo '  <g filter="url(#glow)">' >> "$OUTPUT_FILE"

for ((i=1; i<=PARTICLE_COUNT; i++)); do
    # Procedural calculation using index & pressure seed
    cx=$(( (i * 37 + 120) % 700 + 50 ))
    cy=$(( (i * 53 + 80) % 500 + 50 ))
    r=$(( (i % 5) + 2 ))
    opacity=$(awk "BEGIN {print 0.2 + (($i % 8) / 10)}")
    
    # Color shifting between cyan, emerald, and deep blue bioluminescence
    if (( i % 3 == 0 )); then
        color="#00e5ff"
    elif (( i % 3 == 1 )); then
        color="#69f0ae"
    else
        color="#80d8ff"
    fi

    echo "    <circle cx=\"$cx\" cy=\"$cy\" r=\"$r\" fill=\"$color\" opacity=\"$opacity\">" >> "$OUTPUT_FILE"
    echo "      <animate attributeName=\"cy\" values=\"$cy;$((cy-35));$cy\" dur=\"$((4 + (i % 5)))s\" repeatCount=\"indefinite\" />" >> "$OUTPUT_FILE"
    echo "    </circle>" >> "$OUTPUT_FILE"
done

echo "  </g>" >> "$OUTPUT_FILE"
echo "</svg>" >> "$OUTPUT_FILE"

echo "Successfully generated Mariana Trench fractal terrarium: $OUTPUT_FILE"