#!/usr/bin/env bash
# Phonetic Noodle Compressor
# Transforms any plain text file into a continuous, single-line SVG noodle 
# whose curves deform based on the phonetic weight of characters.
# Usage: ./text_to_svg.sh input.txt > output.svg

set -euo pipefail

INPUT_FILE="${1:-/dev/stdin}"

awk '
BEGIN {
    # Initialize SVG container with a dark, modern theme
    print "<svg xmlns=\"[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)\" viewBox=\"0 0 1200 600\" width=\"100%\" height=\"100%\">"
    print "<rect width=\"100%\" height=\"100%\" fill=\"#0d1117\"/>"
    print "<path d=\"M 40 300"
    
    x = 40
    y = 300
    step = 12
}
{
    line = $0
    for (i = 1; i <= length(line); i++) {
        c = substr(line, i, 1)
        lc = tolower(c)
        
        # Assign phonetic weight / displacement based on consonant/vowel category
        if (lc ~ /[bdfvptszðθʃʒçʝ]/) {
            weight = 18; # High-energy plosives and fricatives
        } else if (lc ~ /[gkjqxmnŋɲɳɴ]/) {
            weight = 28; # Deep velars and nasals
        } else if (lc ~ /[rlɹɻɾɽɫʟ]/) {
            weight = 12; # Liquids and approximants
        } else if (lc ~ /[aeiouyæøåœəɨʉʊʏœɶɷɘɵɜɞɐæɶ]/) {
            weight = 4;  # Smooth, gentle vowels
        } else if (c == " ") {
            weight = -15; # Spaces create dramatic dips
        } else {
            weight = 8;  # Punctuation and symbols
        }

        x += step
        
        # Wrap around canvas width if text is long
        if (x > 1160) {
            x = 40
            y += 80
        }

        # Calculate control and endpoint coordinates for a smooth SVG quadratic bezier curve
        cx = x - (step / 2)
        cy = y + (i % 2 == 0 ? weight * 1.5 : -weight * 1.5)
        
        printf " Q %d %d, %d %d", cx, cy, x, y
    }
}
END {
    # Close path and add a vibrant glowing gradient stroke
    print "\" fill=\"none\" stroke=\"url(#noodle-grad)\" stroke-width=\"4\" stroke-linecap=\"round\" opacity=\"0.9\"/>"
    print "<defs>"
    print "  <linearGradient id=\"noodle-grad\" x1=\"0%\" y1=\"0%\" x2=\"100%\" y2=\"100%\">"
    print "    <stop offset=\"0%\" stop-color=\"#00f2fe\"/>"
    print "    <stop offset=\"50%\" stop-color=\"#4facfe\"/>"
    print "    <stop offset=\"100%\" stop-color=\"#f77062\"/>"
    print "  "
    print "  <filter id=\"glow\" x=\"-20%\" y=\"-20%\" width=\"140%\" height=\"140%\">"
    print "    <feGaussianBlur stdDeviation=\"3\" result=\"blur\"/>"
    print "    <feComposite in=\"SourceGraphic\" in2=\"blur\" operator=\"over\"/>"
    print "  </filter>"
    print "</defs>"
    print "</svg>"
}
' "$INPUT_FILE"