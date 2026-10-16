#!/usr/bin/env bash
# Textile Cellular Automaton Poetry Weaver in Bash
# Encodes poem stanzas into dynamic textile patterns using vowel phonetic weights.

# Sample Poem input
read -r -d '' POEM << 'EOF'
Soft winds blow across the silent sea,
Whispering ancient secrets of the free.
Threads of gold and silver weave the night,
Dancing softly in the pale moonlight.

To sleep, perchance to dream of starry skies,
Where endless oceans meet and softly rise.
The loom of time spins out a fragile thread,
Remembering the words the poets said.
EOF

# Calculate phonetic weight of vowels in a text block
vowel_weight() {
    local text="$1"
    local a_count=$(grep -o -i 'a' <<< "$text" | wc -l)
    local e_count=$(grep -o -i 'e' <<< "$text" | wc -l)
    local i_count=$(grep -o -i 'i' <<< "$text" | wc -l)
    local o_count=$(grep -o -i 'o' <<< "$text" | wc -l)
    local u_count=$(grep -o -i 'u' <<< "$text" | wc -l)
    
    # Weighted sum based on vocalic aperture/openness
    echo $(( a_count*1 + e_count*2 + i_count*3 + o_count*4 + u_count*5 ))
}

# Process the poem stanza by stanza
current_stanza=""
width=40
chars=("░" "▒" "▓" "█" "x" "~" "/")

while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "$line" ]]; then
        if [[ -n "$current_stanza" ]]; then
            echo "----------------------------------------"
            echo "$current_stanza"
            echo "----------------------------------------"
            
            weight=$(vowel_weight "$current_stanza")
            
            # Initialize CA grid seeded by phonetic weight
            grid=""
            for ((i=0; i<width; i++)); do
                if (( (i * 3 + weight) % 7 == 0 )); then
                    grid+="█"
                else
                    grid+=" "
                fi
            done
            
            # Weave and unravel pattern over 10 generations
            for gen in {1..10}; do
                row=""
                for ((i=0; i<width; i++)); do
                    left=${grid:((i-1+width)%width):1}
                    curr=${grid:i:1}
                    right=${grid:((i+1)%width):1}
                    
                    if [[ "$curr" != " " ]] || [[ "$left" != " " && "$right" != " " ]]; then
                        char_idx=$(( (gen + weight + i) % ${#chars[@]} ))
                        row+="${chars[$char_idx]}"
                    else
                        row+=" "
                    fi
                done
                grid="$row"
                echo "$grid"
                sleep 0.04
            done
            echo ""
            current_stanza=""
        fi
    else
        current_stanza+="$line"$'\n'
    fi
done <<< "$POEM"

# Handle final stanza if no trailing newline
if [[ -n "$current_stanza" ]]; then
    echo "----------------------------------------"
    echo "$current_stanza"
    echo "----------------------------------------"
    weight=$(vowel_weight "$current_stanza")
    grid=""
    for ((i=0; i<width; i++)); do
        if (( (i * 3 + weight) % 7 == 0 )); then
            grid+="█"
        else
            grid+=" "
        fi
    done
    for gen in {1..10}; do
        row=""
        for ((i=0; i<width; i++)); do
            left=${grid:((i-1+width)%width):1}
            curr=${grid:i:1}
            right=${grid:((i+1)%width):1}
            if [[ "$curr" != " " ]] || [[ "$left" != " " && "$right" != " " ]]; then
                char_idx=$(( (gen + weight + i) % ${#chars[@]} ))
                row+="${chars[$char_idx]}"
            else
                row+=" "
            fi
        done
        grid="$row"
        echo "$grid"
        sleep 0.04
    done
fi