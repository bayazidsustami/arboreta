#!/usr/bin/env bash
# Live MIDI → Cellular Automaton + Poetic Markov generator
# Dependencies: aseqdump (ALSA), awk, sed, tr, fold, head, tput

# ------- Configuration -------
WIDTH=80          # grid width
HEIGHT=24         # grid height (terminal rows)
CA_RULE=90        # Wolfram Rule number (binary 01011010)
MARKOV_ORDER=2   # order of Markov chain
POEM_LINES=5      # lines of poetry per frame
# ---------------------------------------------------------

# Initialize CA grid (random)
grid=()
for ((i=0;i<HEIGHT;i++)); do
    row=$(awk -v w=$WIDTH 'BEGIN{s=""; for(i=0;i<w;i++) s+=(int(rand()*2))} END{print s}')
    grid+=("$row")
done

# Simple Markov model (starts empty)
declare -A markov   # key: "w1 w2", value: list of possible next chars

# Convert rule number to binary string
rule_bin=$(printf "%08d" "$(bc <<< "obase=2;$CA_RULE")")
# Map 3‑bit neighbourhood to result (0‑7)
declare -A rule_map
for i in {0..7}; do
    idx=$((7-i))
    rule_map[$i]=${rule_bin:$idx:1}
done

# Function: apply CA rule to a row
next_row() {
    local row=$1
    local len=${#row}
    local new=""
    for ((i=0;i<len;i++)); do
        left=${row:((i-1+len)%len):1}
        center=${row:i:1}
        right=${row:((i+1)%len):1}
        idx=$(( (left<<2) + (center<<1) + right ))
        new+="${rule_map[$idx]}"
    done
    echo "$new"
}

# Function: update Markov model with current grid rows
update_markov() {
    local text=$1
    local len=${#text}
    for ((i=0;i<=len-MARKOV_ORDER-1;i++)); do
        key=${text:i:MARKOV_ORDER}
        next=${text:i+MARKOV_ORDER:1}
        markov["$key"]+="${next}"
    done
}

# Function: generate a poem line from current grid
generate_line() {
    # start with a random key from the model or a random binary fragment
    if (( ${#markov[@]} )); then
        keys=(${!markov[@]})
        key=${keys[RANDOM % ${#keys[@]}]}
    else
        key=$(head -c $MARKOV_ORDER < /dev/urandom | tr -dc '01')
    fi
    line=$key
    while (( ${#line} < WIDTH )); do
        choices=${markov["$key"]}
        if [[ -z $choices ]]; then
            # fall back to random binary
            line+=${RANDOM:0:1}
            key=${line: -MARKOV_ORDER}
            continue
        fi
        # pick random continuation
        next=${choices:RANDOM%${#choices}:1}
        line+=$next
        key=${line: -MARKOV_ORDER}
    done
    # translate binary to letters (simple mapping)
    echo "$line" | tr '01' 'aeiou'
}

# Function: render grid and poetry
render() {
    tput civis               # hide cursor
    printf "\e[H"            # move cursor home
    for row in "${grid[@]}"; do
        # map 0/1 to spaces / blocks
        printf "%s\n" "$(echo "$row" | tr '01' ' █')"
    done
    echo
    for ((i=0;i<POEM_LINES;i++)); do
        generate_line
    done
    echo -e "\e[0m"
}

# Capture MIDI events (note on/off) with aseqdump
# We'll derive a simple "tempo" proxy from event rate
tempo=120
key=0
( aseqdump -p "$(aseqdump -l | head -n1 | awk '{print $2}')" 2>/dev/null | \
  while read -r line; do
        # Extract MIDI note number (if present)
        if [[ $line =~ ^\s*\[[0-9]+\]\s+([0-9]+):\s+([0-9a-fA-F]+) ]]; then
            status=${BASH_REMATCH[2]}
            case $status in
                90*) note=$((0x${status:2:2})); key=$(( (note/12)%12 ));; # Note on
                80*) ;; # Note off – ignore
            esac
        fi
        # Simple tempo adaptation: count events per second
        ((event_cnt++))
        current_time=$(date +%s)
        if (( current_time != last_time )); then
            tempo=$(( (event_cnt*60)/1 ))   # events per minute as proxy
            event_cnt=0
            last_time=$current_time
        fi
        # feed grid update
        # shift rows down, insert new top row derived from note/key
        new_top=$(printf "%0${WIDTH}d" $(( (key*13 + tempo) % 2**WIDTH )) | tail -c $WIDTH)
        grid=("$new_top" "${grid[@]::HEIGHT-1}")
        # update Markov with concatenated rows
        update_markov "$(printf "%s" "${grid[@]}" | tr -d '\n')"
        render
        sleep 0.05
  done ) &
wait # keep script alive until aseqdump ends (Ctrl‑C)