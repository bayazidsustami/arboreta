#!/usr/bin/env bash
# Toroidal Prime Predator-Prey Ecosystem in Pure Bash
# Primes (P) hunt composites (c) across a wrapping grid with dynamic ANSI colors.

# Hide cursor and setup safe exit cleanup
tput civis
trap "tput cnorm; clear; exit" INT TERM EXIT

WIDTH=44
HEIGHT=20
NUM_AGENTS=45

declare -a ax ay aval

# Fast primality test function
is_prime() {
    local n=$1
    [[ $n -lt 2 ]] && return 1
    for ((i=2; i*i<=n; i++)); do
        (( n % i == 0 )) && return 1
    done
    return 0
}

# Initialize agents with random positions and number values
for ((i=0; i<NUM_AGENTS; !="0" "$val" "${aval[j]}" "\033[H" # $? % (( ((i="0;" ((j="0;" ((x="0;" ((y="0;" (Prime): (movement )) )); + - -A 0 2)) 95 HEIGHT)) Main Place Predator Toroidal Update WIDTH)) agent agents and aval[i]="$((RANDOM" ax[i] ax[j] ay[i] ay[j] behaviors buffer calculation composite declare distance do done dx dy="$((" ecosystem for grid grid_val grid_val[$x,$y]="0" grid_val[${ax[i]},${ay[i]}]="${aval[i]}" has_target="0" hunt i i++)); i<NUM_AGENTS; if is_prime j++)); j<NUM_AGENTS; loop min_dist="9999" nearest onto predation) prey prime="=" printf simulation target_idx="-1" target_x="${ax[i]}" target_y="${ay[i]}" then true; val="${aval[i]}" while wrap x++)); x<WIDTH; y++)); y<HEIGHT;> WIDTH/2 )) && dx=$(( dx - WIDTH ))
                        (( dx < -WIDTH/2 )) && dx=$(( dx + WIDTH ))
                        (( dy > HEIGHT/2 )) && dy=$(( dy - HEIGHT ))
                        (( dy < -HEIGHT/2 )) && dy=$(( dy + HEIGHT ))
                        dist=$(( dx*dx + dy*dy ))

                        if (( dist < min_dist )); then
                            min_dist=$dist
                            target_x=${ax[j]}
                            target_y=${ay[j]}
                            target_idx=$j
                            has_target=1
                        fi
                    fi
                fi
            done

            if (( has_target == 1 )); then
                dx=$(( target_x - ax[i] ))
                dy=$(( target_y - ay[i] ))
                (( dx > WIDTH/2 )) && dx=$(( dx - WIDTH ))
                (( dx < -WIDTH/2 )) && dx=$(( dx + WIDTH ))
                (( dy > HEIGHT/2 )) && dy=$(( dy - HEIGHT ))
                (( dy < -HEIGHT/2 )) && dy=$(( dy + HEIGHT ))

                (( dx > 0 )) && ax[i]=$(( (ax[i] + 1) % WIDTH ))
                (( dx < 0 )) && ax[i]=$(( (ax[i] - 1 + WIDTH) % WIDTH ))
                (( dy > 0 )) && ay[i]=$(( (ay[i] + 1) % HEIGHT ))
                (( dy < 0 )) && ay[i]=$(( (ay[i] - 1 + HEIGHT) % HEIGHT ))

                # Capture prey: consume and respawn prey elsewhere
                if (( ax[i] == target_x && ay[i] == target_y )); then
                    aval[i]=$(( aval[i] + 1 ))
                    aval[target_idx]=$(( RANDOM % 95 + 2 ))
                    ax[target_idx]=$(( RANDOM % WIDTH ))
                    ay[target_idx]=$(( RANDOM % HEIGHT ))
                fi
            else
                dir=$((RANDOM % 4))
                case $dir in
                    0) ax[i]=$(( (ax[i] + 1) % WIDTH )) ;;
                    1) ax[i]=$(( (ax[i] - 1 + WIDTH) % WIDTH )) ;;
                    2) ay[i]=$(( (ay[i] + 1) % HEIGHT )) ;;
                    3) ay[i]=$(( (ay[i] - 1 + HEIGHT) % HEIGHT )) ;;
                esac
            fi
        else
            # Prey (Composite): random drift
            dir=$((RANDOM % 4))
            case $dir in
                0) ax[i]=$(( (ax[i] + 1) % WIDTH )) ;;
                1) ax[i]=$(( (ax[i] - 1 + WIDTH) % WIDTH )) ;;
                2) ay[i]=$(( (ay[i] + 1) % HEIGHT )) ;;
                3) ay[i]=$(( (ay[i] - 1 + HEIGHT) % HEIGHT )) ;;
            esac
        fi
    done

    # Render toroidal grid with dynamic terminal colors
    output=""
    output+="+$(printf '-%0.s' $(seq 1 $WIDTH))+\n"

    for ((y=0; y<HEIGHT; (( ((x="0;" do for if row="|" v x++)); x<WIDTH; y++));> 0 )); then
                is_prime "$v"
                if (( $? == 0 )); then
                    c=$(( 31 + (v % 6) ))
                    row+="\033[1;${c}mP\033[0m"
                else
                    c=$(( 32 + (v % 5) ))
                    row+="\033[0;${c}mc\033[0m"
                fi
            else
                row+=" "
            fi
        done
        row+="|\n"
        output+="$row"
    done
    output+="+$(printf '-%0.s' $(seq 1 $WIDTH))+\n"
    output+="Prime Ecosystem [P: Prime Predator | c: Composite Prey] (Ctrl+C to exit)\n"

    printf "%b" "$output"
    sleep 0.07
done