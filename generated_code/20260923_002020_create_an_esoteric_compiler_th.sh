#!/usr/bin/env bash
# Esoteric Text-to-Automaton Compiler
# Translates raw text into an interactive cellular canvas, blooming fractal flowers
# for infinite loops and shattering into falling obsidian shards for syntax errors.

set -uo pipefail

# Setup terminal dimensions and state
cols=$(tput cols)
rows=$(tput lines)
input="${1:-while(true){loop;} error!}"

# Hide cursor and handle clean exit
tput civis
trap 'tput cnorm; clear; exit 0' INT TERM

# Initialize grid structures
declare -A grid
declare -A next_grid

# Seed the canvas based on text analysis
init_canvas() {
    for ((r=0; r<rows; r++)); do
        for ((c=0; c<cols; c++)); do
            grid[$r,$c]=0
        done
    }

    # Analyze input for esoteric tokens
    local x=$((cols / 2))
    local y=$((rows / 2))
    
    if [[ "$input" =~ (loop|while|for|repeat) ]]; then
        # Fractal flower seed (symmetric cross-bloom)
        for i in {-3..3}; do
            grid[$((y+i)),$x]=1
            grid[$y,$((x+i))]=1
        done
        grid[$((y-1)),$((x-1))]=2
        grid[$((y-1)),$((x+1))]=2
        grid[$((y+1)),$((x-1))]=2
        grid[$((y+1)),$((x+1))]=2
    elif [[ "$input" =~ (error|syntax|fail|!) ]]; then
        # Obsidian shard scatter (sharp jagged fragments)
        for ((i=0; i<cols; i+=3)); do
            local rand_r=$((RANDOM % (rows / 2)))
            grid[$rand_r,$i]=3
        done
    else
        # Standard noise seed from ASCII values
        for ((i=0; i<${#input}; i++)); do
            local char_val=$(( (i * 7) % cols ))
            local char_row=$(( (i * 3) % rows ))
            grid[$char_row,$char_val]=1
        done
    fi
}

# Render the cellular universe
render() {
    local output=""
    for ((r=0; r<rows-1; r++)); do
        for ((c=0; c<cols; c++)); do
            case "${grid[$r,$c]:-0}" in
                1) output+="\033[38;5;213m✿\033[0m" ;; # Fractal flower petal (Pink)
                2) output+="\033[38;5;226m❀\033[0m" ;; # Flower center (Yellow)
                3) output+="\033[38;5;238m█\033[0m" ;; # Obsidian shard (Dark Grey)
                *) output+=" " ;;
            esac
        done
        output+=$'\n'
    done
    printf "%s" "$output"
}

# Run cellular automation rules with esoteric mutations
update_grid() {
    for ((r=0; r<rows-1; r++)); do
        for ((c=0; c<cols; c++)); do
            local current="${grid[$r,$c]:-0}"
            
            # If obsidian shards, make them fall
            if [[ "$current" -eq 3 ]]; then
                if [[ $((r + 1)) -lt $((rows - 1)) ]]; then
                    next_grid[$((r+1)),$c]=3
                    next_grid[$r,$c]=0
                else
                    next_grid[$r,$c]=3
                fi
                continue
            fi

            # Count live neighbors for Conway-like growth / fractal blooming
            local neighbors=0
            for dr in {-1..1}; do
                for dc in {-1..1}; do
                    if [[ "$dr" -ne 0 || "$dc" -ne 0 ]]; then
                        local nr=$((r + dr))
                        local nc=$((c + dc))
                        if [[ "$nr" -ge 0 && "$nr" -lt $((rows-1)) && "$nc" -ge 0 && "$nc" -lt cols ]]; then
                            [[ "${grid[$nr,$nc]:-0}" -gt 0 ]] && ((neighbors++))
                        fi
                    fi
                done
            done

            # Automaton state transition
            if [[ "$current" -gt 0 ]]; then
                if [[ "$neighbors" -eq 2 || "$neighbors" -eq 3 ]]; then
                    next_grid[$r,$c]=$current
                else
                    next_grid[$r,$c]=0
                fi
            else
                if [[ "$neighbors" -eq 3 ]]; then
                    next_grid[$r,$c]=1
                else
                    next_grid[$r,$c]=0
                fi
            fi
        done
    done

    # Copy next_grid back to grid
    for ((r=0; r<rows-1; r++)); do
        for ((c=0; c<cols; c++)); do
            grid[$r,$c]="${next_grid[$r,$c]:-0}"
            unset next_grid[$r,$c]
        done
    done
}

# Main execution loop
init_canvas
while true; do
    tput cup 0 0
    render
    update_grid
    sleep 0.08
done