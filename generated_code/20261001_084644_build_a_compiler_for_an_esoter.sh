#!/usr/bin/env bash
# Esoteric Barometric-Dependent Compiler & Mandelbrot Generator of Existential Dread

# Attempt to fetch local barometric pressure, defaulting to standard 1013 hPa if offline
PRESSURE=$(curl -s --connect-timeout 1 "[https://wttr.in/?format=%P](https://wttr.in/?format=%P)" 2>/dev/null | grep -oE '[0-9]+' || echo "1013")
[[ -z "$PRESSURE" ]] && PRESSURE=1013

# Dynamic character palette selection based on atmospheric pressure (the dread index)
if (( PRESSURE > 1020 )); then
    PALETTE=" .:-=+*#%@"
    DREAD="High pressure: The crushing weight of absolute certainty."
elif (( PRESSURE < 1000 )); then
    PALETTE=" ░▒▓█⚡💀∅Ψ"
    DREAD="Low pressure: The void whispers directly through the barometer."
else
    PALETTE=" .~*#$@§∞"
    DREAD="Equilibrium: A fleeting, deceptive illusion of stability."
fi

echo "Barometric Pressure: ${PRESSURE} hPa"
echo "Existential State: $DREAD"
echo "Compiling syntax stream..."
sleep 1

# High-performance procedural Mandelbrot renderer in Awk using the dynamic palette
awk -v pal="$PALETTE" '
BEGIN {
    w = 64; h = 32;
    split(pal, chars, "");
    num_chars = length(chars);
    
    for (y = 0; y < h; y++) {
        line = "";
        for (x = 0; x < w; x++) {
            cr = (x / w) * 3.0 - 2.0;
            ci = (y / h) * 2.4 - 1.2;
            zr = 0; zi = 0;
            n = 0;
            max_iter = 45;
            
            while (n < max_iter && (zr*zr + zi*zi) <= 4) {
                tr = zr*zr - zi*zi + cr;
                zi = 2 * zr * zi + ci;
                zr = tr;
                n++;
            }
            
            if (n == max_iter) {
                line = line chars[1];
            } else {
                idx = (n % (num_chars - 1)) + 2;
                line = line chars[idx];
            }
        }
        print line;
    }
}'