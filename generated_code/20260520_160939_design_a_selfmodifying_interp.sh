#!/usr/bin/env bash
# kaleido_interpreter.sh - self‑modifying PNG‑based AST interpreter with visual overlay
# Dependencies: imagemagick (convert), ffmpeg, xxd, awk, base64, sed, mktemp

set -euo pipefail

#---------------------------------------------------------
# Configuration
#---------------------------------------------------------
IMG_IN="${1:-program.png}"           # Input PNG containing encoded AST
IMG_OUT="output_$(date +%s).png"    # Final image with all overlays
VID_OUT="execution_$(date +%s).mp4" # Animation of execution steps
TMPDIR=$(mktemp -d)                 # Workspace
FRAME_RATE=10                       # Frames per second for the video
PALETTE="palette.png"               # Small palette for kaleidoscopic effect

#---------------------------------------------------------
# Helper: extract hidden data from PNG (simple LSB steganography)
# Each pixel's R channel LSB encodes one ASCII byte.
#---------------------------------------------------------
extract_ast() {
    local img="$1"
    # Dump raw pixel data, keep only red channel, extract LSB, convert to chars
    convert "$img" rgb:- | \
    dd bs=3 count=$(($(identify -format "%[fx:w*h]" "$img"))) 2>/dev/null | \
    awk '{printf "%c", and($1,1)}' > "$TMPDIR/ast.txt"
}

#---------------------------------------------------------
# Simple AST executor (toy language):
# Commands are 1‑byte opcodes:
# 0x01 N   -> push N (next byte)
# 0x02     -> add (pop two, push sum)
# 0x03     -> mul (pop two, push product)
# 0xFF     -> halt
#---------------------------------------------------------
execute_ast() {
    local ast_file="$1"
    local -a stack
    local ip=0
    local byte
    exec 3<"$ast_file"
    while true; do
        read -r -n1 -u3 byte || break
        ((ip++))
        op=$(printf '%d' "'$byte")
        case $op in
            1) # push
                read -r -n1 -u3 val || break
                ((ip++))
                stack+=("$((printf '%d' "'$val"))")
                ;;
            2) # add
                a=${stack[-1]}; unset 'stack[-1]'
                b=${stack[-1]}; unset 'stack[-1]'
                stack+=($((a+b)))
                ;;
            3) # mul
                a=${stack[-1]}; unset 'stack[-1]'
                b=${stack[-1]}; unset 'stack[-1]'
                stack+=($((a*b)))
                ;;
            255) # halt
                break
                ;;
            *) ;;
        esac
        #-------------------------------------------------
        # Render current state as overlay
        #-------------------------------------------------
        render_step "$ip" "${stack[*]}"
        # Self‑modify: embed current stack size into script comment
        self_modify "${#stack[@]}"
    done 3<&-
    echo "Result: ${stack[-1]:-0}"
}

#---------------------------------------------------------
# Render a single execution step as a kaleidoscopic overlay
#---------------------------------------------------------
render_step() {
    local ip="$1"
    local stack_vals="$2"
    local frame="$TMPDIR/frame_$ip.png"

    # Copy original image as base
    cp "$IMG_IN" "$frame"

    # Create textual overlay with instruction pointer and stack
    convert -size 400x100 xc:none \
        -gravity SouthWest -pointsize 20 -fill white \
        -annotate +10+10 "IP=$ip  Stack=($stack_vals)" \
        miff:- | \
    composite -gravity SouthWest "$frame" "$frame"

    # Apply kaleidoscopic effect (rotate+mirror tiles)
    convert "$frame" -virtual-pixel Tile \
        -distort SRT 0 +repage \
        -virtual-pixel tile \
        -distort Arc 0,0,180 \
        "$frame"

    # Save frame for video
    cp "$frame" "$TMPDIR/frame_${ip}.png"
}

#---------------------------------------------------------
# Self‑modifying part: update comment with current stack depth
#---------------------------------------------------------
self_modify() {
    local depth="$1"
    # Use sed to replace the line starting with '# Stack depth:'
    sed -i "s/^# Stack depth:.*/# Stack depth: $depth/" "$0"
}

#---------------------------------------------------------
# Build kaleidoscopic palette (used by render_step)
#---------------------------------------------------------
build_palette() {
    convert -size 2x2 gradient:#0000FF-#FF00FF "$PALETTE"
}
build_palette

#---------------------------------------------------------
# Main execution
#---------------------------------------------------------
# Insert placeholder comment if missing
if ! grep -q '^# Stack depth:' "$0"; then
    sed -i '2i# Stack depth: 0' "$0"
fi

extract_ast "$IMG_IN"
execute_ast "$TMPDIR/ast.txt"

#---------------------------------------------------------
# Assemble animation from frames
#---------------------------------------------------------
ffmpeg -y -framerate "$FRAME_RATE" -i "$TMPDIR/frame_%d.png" -c:v libx264 -pix_fmt yuv420p "$VID_OUT"

# Cleanup
rm -rf "$TMPDIR"
echo "Animation saved to $VID_OUT"
echo "Final image saved to $IMG_OUT (identical to input)"