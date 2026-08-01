#!/usr/bin/env bash
# ==============================================================================
# Git Repository to Origami Crease Pattern Generator
#
# Translates git history dynamics into origami crease pattern SVG:
#   - Commit frequency  -> Grid tessellation density
#   - Branch merges     -> Mountain folds (solid red lines)
#   - Deleted lines     -> Valley folds (dashed blue lines)
# ==============================================================================

set -euo pipefail

# 1. Ensure execution within a Git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: Target directory is not a Git repository." >&2
    exit 1
fi

# 2. Extract Git metrics
total_commits=$(git rev-list --count HEAD 2>/dev/null || echo 1)
merge_data=$(git log --merges --format="%h %at" 2>/dev/null || true)
deleted_lines=$(git log --numstat --format="" 2>/dev/null | awk '{s+=$2} END {print s+0}')

# 3. Calculate tessellation density (grid divisions N x N)
density=$(( (total_commits / 8) + 4 ))
if [ "$density" -gt 40 ]; then density=40; fi
if [ "$density" -lt 4 ]; then density=4; fi

# 4. Canvas dimensions setup
size=800
margin=50
canvas_size=$((size + margin * 2))
step=$(( size / density ))

# 5. Begin SVG Output
cat <<EOF <svg height="100%" style="background:#fdfcf7;" viewBox="0 0 ${canvas_size} ${canvas_size}" width="100%" xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)">
  <style>
    .border { stroke: #2c3e50; stroke-width: 3; fill: none; }
    .grid { stroke: #d0d7de; stroke-width: 0.8; stroke-dasharray: 2,2; opacity: 0.7; }
    .mountain { stroke: #e74c3c; stroke-width: 2.2; stroke-linecap: round; }
    .valley { stroke: #2980b9; stroke-width: 1.8; stroke-dasharray: 6,4; stroke-linecap: round; }
    .meta { font-family: monospace; font-size: 12px; fill: #7f8c8d; }
  </style>

  <!-- Outer Sheet Boundary -->
  <rect x="${margin}" y="${margin}" width="${size}" height="${size}" class="border" />
EOF

# 6. Render Tessellation Grid (Commit Frequency)
for (( i=1; i<density; i++ )); do
    pos=$(( margin + i * step ))
    echo "  <line x1=\"${pos}\" y1=\"${margin}\" x2=\"${pos}\" y2=\"$((margin + size))\" class=\"grid\" />"
    echo "  <line x1=\"${margin}\" y1=\"${pos}\" x2=\"$((margin + size))\" y2=\"${pos}\" class=\"grid\" />"
done

# 7. Render Mountain Folds (Branch Merges)
merge_count=0
if [ -n "$merge_data" ]; then
    while read -r hash timestamp; do
        [ -z "$hash" ] && continue
        merge_count=$((merge_count + 1))
        
        # Deterministic cell placement based on commit hash / index
        gx=$(( (merge_count * 7 + 3) % density ))
        gy=$(( (merge_count * 13 + 5) % density ))
        
        x1=$(( margin + gx * step ))
        y1=$(( margin + gy * step ))
        x2=$(( x1 + step ))
        y2=$(( y1 + step ))
        
        # Diagonal mountain cross-folds
        echo "  <line x1=\"${x1}\" y1=\"${y1}\" x2=\"${x2}\" y2=\"${y2}\" class=\"mountain\" />"
        echo "  <line x1=\"${x1}\" y1=\"${y2}\" x2=\"${x2}\" y2=\"${y1}\" class=\"mountain\" />"
    done <<< "$merge_data"
fi

# 8. Render Valley Folds (Line Deletions)
# Scale deletions relative to grid capacity
valley_folds=$(( (deleted_lines / 30) + 1 ))
max_valleys=$(( density * density ))
if [ "$valley_folds" -gt "$max_valleys" ]; then valley_folds=$max_valleys; fi

for (( v=0; v<valley_folds; v++ )); do
    gx=$(( (v * 11 + 2) % density ))
    gy=$(( (v * 17 + 4) % density ))
    
    x1=$(( margin + gx * step ))
    y1=$(( margin + gy * step + step / 2 ))
    x2=$(( x1 + step ))
    y2=$(( y1 ))
    
    echo "  <line x1=\"${x1}\" y1=\"${y1}\" x2=\"${x2}\" y2=\"${y2}\" class=\"valley\" />"
done

# 9. Crease Pattern Metadata Legend
cat <<EOF <text class="meta" x="${margin}" y="$((margin + size + 30))">
    Origami Crease Pattern | Commits: ${total_commits} (Grid: ${density}x${density}) | Merges (Mountain): ${merge_count} | Deletions (Valley): ${deleted_lines}
  </text>
</svg>
EOF