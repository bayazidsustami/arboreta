# ASCII Fungal Network Quine
# Renders self-source as a growing mycelium network:
# - Variable array allocations trigger hyphae branching
# - Dynamic syntax checks trigger sporulation on deliberate/simulated errors

code='
# Quine logic & state initialization
q=$(cat << '\''EOF'\''
%s
EOF
)
SRC=$(printf "$q" "$code")

# Screen setup and cleanup
trap "tput cnorm; clear; exit" INT TERM EXIT
tput civis; clear

# Visual palette for mycelium and spores
BRANCHES=("│" "┤" "┐" "└" "┴" "┬" "├" "─" "┼" "╯" "╭" "╱" "╲")
SPORES=("·" "°" "•" "o" "O" "◌" "x" "*")
COLORS=("\033[32m" "\033[36m" "\033[90m" "\033[92m" "\033[96m" "\033[37m")
RESET="\033[0m"

# Terminal boundaries
LINES=$(tput lines)
COLS=$(tput cols)

# Mycelium memory allocation tracking (branches grow as memory arrays expand)
declare -A network
nodes=()

# Seed source code into initial hyphae nodes
char_idx=0
len=${#SRC}

# Branching loop driven by memory allocation
for ((step=0; step<len && step<250; step++)); do
    # Allocate memory dynamically (triggers network growth)
    nodes+=("$((RANDOM % LINES)):$((RANDOM % COLS))")
    
    # Pick character from own source
    char="${SRC:$char_idx:1}"
    char_idx=$(( (char_idx + 1) % len ))
    
    # Process active hyphae nodes
    for idx in "${!nodes[@]}"; do
        pos="${nodes[$idx]}"
        r=${pos%%:*}
        c=${pos##*:}
        
        # Grow branch symbol from source character code
        b_char="${BRANCHES[$(( (step + idx + CHAR_ORD) % ${#BRANCHES[@]} ))]}"
        col="${COLORS[$(( (step + idx) % ${#COLORS[@]} ))]}"
        
        tput cup $r $c
        printf "${col}%s${RESET}" "$b_char"
        network["$r:$c"]="$char"
        
        # Test code syntax dynamically to simulate/detect sporulation trigger
        if ! eval "[[ ${#char} -gt 0 ]]" 2>/dev/null || (( RANDOM % 12 == 0 )); then
            # Syntax anomaly / sporulation event
            spore="${SPORES[$(( RANDOM % ${#SPORES[@]} ))]}"
            sr=$(( (r + (RANDOM % 3) - 1 + LINES) % LINES ))
            sc=$(( (c + (RANDOM % 3) - 1 + COLS) % COLS ))
            tput cup $sr $sc
            printf "\033[33m%s${RESET}" "$spore"
        fi
        
        # Branch/extend hyphae (memory allocation expansion)
        nr=$(( (r + (RANDOM % 3) - 1 + LINES) % LINES ))
        nc=$(( (c + (RANDOM % 3) - 1 + COLS) % COLS ))
        nodes[$idx]="$nr:$nc"
    done
    sleep 0.01
done

# Clear and display exact Quine source code output
tput cnorm
clear
printf "%s\n" "$SRC"
'

# Quine bootstrap
q=$(cat << 'EOF'
# ASCII Fungal Network Quine
# Renders self-source as a growing mycelium network:
# - Variable array allocations trigger hyphae branching
# - Dynamic syntax checks trigger sporulation on deliberate/simulated errors

code='%s'

# Quine bootstrap
q=$(cat << 'EOF'
%s
EOF
)
printf "$q" "$code" "$q"
EOF
)
printf "$q" "$code" "$q"