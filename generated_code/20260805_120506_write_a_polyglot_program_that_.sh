#!/usr/bin/env bash
# Polyglot Source-Fractal & Self-Portrait Generator
# Renders script source as a self-similar fractal; code mutation alters hash to reveal hidden ASCII portrait.

EXPECTED_SUM=3829104721 # Hardcoded baseline checksum of the script body

# Read self source code excluding the checksum declaration line
SELF=$(cat "$0" 2>/dev/null)
CODE_BODY=$(printf '%s' "$SELF" | grep -v 'EXPECTED_SUM=')
ACTUAL_SUM=$(printf '%s' "$CODE_BODY" | cksum 2>/dev/null | awk '{print $1}')

# Setup terminal screen (clear screen, hide cursor)
printf "\033[2J\033[H\033[?25l"

WIDTH=$(tput cols 2>/dev/null || echo 80)
HEIGHT=$(tput lines 2>/dev/null || echo 24)
LEN=${#SELF}

if [ "$ACTUAL_SUM" = "$EXPECTED_SUM" ]; then
  # Intact source: Render source text as a self-similar bitwise fractal (Sierpinski geometry)
  for ((y=0; y<HEIGHT " "$HEIGHT" "$char" "$line" "${PORTRAIT[@]}"; "\033[%d;%dH\033[%dm%s" "\033[%d;%dH\033[36;1m%s" "\033[0m\033[?25h\033[%d;1H\n" # $((x+1)) $((y+1)) $color $px $py % & && '="=='" '---------' (((x ((py++)) ((x="0;" (WIDTH (o) (x ) )) * + - -lt -z .---------. .---. / 0)); 1 2 21) 3) 4)) 6)) ANSI ASCII Altered LEN)) Mutated PORTRAIT="(" Reset [ \\ ] ^ _ and char=" " checksum color="$((31" cursor disrupts do done else fi for formatting fractal geometry hidden idx="$(((x" if in line printf px="1" py="$((HEIGHT" restore reveal self-portrait source: styles terminal then to x++)); x<64; x<WIDTH y y) y++)); y<32; | ||>