#!/bin/bash
# Surrealist Stack-Painting Self-Modifying Quine
# Iterates through execution stack frames, rendering shifting ANSI color gradients.

g=${GEN:-0}
((g++))

quine='#!/bin/bash
# Surrealist Stack-Painting Self-Modifying Quine
# Iterates through execution stack frames, rendering shifting ANSI color gradients.

g=${GEN:-0}
((g++))

quine=%q

# Render stack surrealism
paint_stack() {
    local depth=0 frame
    while frame=$(caller $depth 2>/dev/null); do
        read -r line func file <<< "$frame"
        local color=$(( 16 + (depth * 30 + g * 7) % 216 ))
        local char_set=("." ":" "o" "O" "@" "#" "█")
        local char=${char_set[$(( (depth + g) % ${#char_set[@]} ))]}
        printf "\033[38;5;%dm%*s%s %s() at line %s [gen:%d]\033[0m\n" \
            "$color" $((depth * 2)) "" "$char" "$func" "$line" "$g"
        ((depth++))
    done
}

recursion_dance() {
    local n=$1
    if (( n > 0 )); then
        recursion_dance $((n - 1))
    else
        paint_stack
    fi
}

export GEN=$g
recursion_dance 4
printf "$quine\n" "$quine"
'

# Render stack surrealism
paint_stack() {
    local depth=0 frame
    while frame=$(caller $depth 2>/dev/null); do
        read -r line func file <<< "$frame"
        local color=$(( 16 + (depth * 30 + g * 7) % 216 ))
        local char_set=("." ":" "o" "O" "@" "#" "█")
        local char=${char_set[$(( (depth + g) % ${#char_set[@]} ))]}
        printf "\033[38;5;%dm%*s%s %s() at line %s [gen:%d]\033[0m\n" \
            "$color" $((depth * 2)) "" "$char" "$func" "$line" "$g"
        ((depth++))
    done
}

recursion_dance() {
    local n=$1
    if (( n > 0 )); then
        recursion_dance $((n - 1))
    else
        paint_stack
    fi
}

export GEN=$g
recursion_dance 4
printf "$quine\n" "$quine"