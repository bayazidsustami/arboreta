#!/usr/bin/env bash
# Poem‑trace animation using combining characters + ANSI colors
# The script prints a short self‑referential poem.
# Each line slowly transforms into the next, while the “execution trace”
# (the source of the line currently being shown) is overprinted using
# Unicode combining diacritics to create a visual “glitch” effect.

# ---- Configuration -------------------------------------------------
# Delay between frames (seconds, can be fractional)
DELAY=0.07
# Number of animation cycles
CYCLES=2

# The poem lines (each line will be animated into the next)
poem=(
    "I write code, and the code writes me."
    "I debug thoughts, while thoughts debug me."
    "My verses echo the interpreter's sigh."
    "Each character a trace, each trace a sigh."
)

# Combine diacritic characters (U+0300–U+036F) to create glitch overlay
diacritics=(̀ ́ ̂ ̃ ̄ ̅ ̆ ̇ ̈ ̉ ̊ ̋ ̌ ̍ ̎ ̏ ̐ ̑ ̒ ̓ ̔ ̕ ̖ ̗ ̘ ̙ ̚ ̛ ̜ ̝ ̞ ̟ ̠ ̡ ̢ ̣ ̤ ̥ ̦ ̧ ̨ ̩ ̪ ̫ ̬ ̭ ̮ ̯ ̰ ̱ ̲ ̳ ̴ ̵ ̶ ̷ ̸ ̹ ̺ ̻ ̼ ̽ ̾ ̀ ́ ͂ ̓ ̈́ ͅ ͆ ͇ ͈ ͉ ͊ ͋ ͌ ͍ ͎ ͏ ͐ ͑ ͒ ͓ ͔ ͕ ͖ ͗ ͘ ͙ ͚ ͛ ͜ ͝ ͞ ͟ ͠ ͡ ͢ ̸ ̹ ̺ ̻ ̼ ̽ ̾ ̿ ̀ ́ ͂ ̓ ̈́ ͅ ͆ ͇ ͈ ͉ ͊ ͋ ͌ ͍ ͎ ͏ ͐ ͑ ͒)

# Helper: print a line with random diacritic overlay
glitch_line() {
    local text="$1"
    local out=""
    local len=${#text}
    for ((i=0; i<len; i++)); do
        char="${text:i:1}"
        # Space characters are left untouched
        if [[ $char == " " ]]; then
            out+="$char"
            continue
        fi
        # Randomly decide whether to add a diacritic (30% chance)
        if (( RANDOM % 10 < 3 )); then
            diac="${diacritics[RANDOM % ${#diacritics[@]}]}"
            out+="${char}${diac}"
        else
            out+="${char}"
        fi
    done
    printf "%b" "$out"
}

# Clear screen and hide cursor
tput civis
clear

# Main animation loop
for ((cycle=1; cycle<=CYCLES; cycle++)); do
    for ((i=0; i<${#poem[@]}; i++)); do
        cur="${poem[i]}"
        nxt="${poem[(i+1)%${#poem[@]}]}"

        # Fade out current line
        for ((f=0; f<8; f++)); do
            tput cup $((i+2)) 0
            printf "\e[2m%s\e[0m" "$(glitch_line "$cur")"
            sleep $DELAY
        done

        # Morph characters one by one towards next line
        maxlen=${#cur}
        (( ${#nxt} > maxlen )) && maxlen=${#nxt}
        for ((step=0; step<=maxlen; step++)); do
            tput cup $((i+2)) 0
            prog=""
            for ((c=0; c<maxlen; c++)); do
                if (( c < step )); then
                    char="${nxt:c:1}"
                else
                    char="${cur:c:1}"
                fi
                [[ -z $char ]] && char=" "
                prog+="$char"
            done
            printf "\e[1;34m%s\e[0m" "$(glitch_line "$prog")"
            sleep $DELAY
        done

        # Hold the finished line a moment
        sleep $DELAY
    done
done

# Restore cursor and exit
tput cnorm
printf "\n"
```