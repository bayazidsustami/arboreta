#!/usr/bin/env bash
#
# Forest Fire Cellular Automaton driven by live humming frequencies.
# Requirements: sox (or a compatible audio capture tool) and a microphone.
# 

# Ensure safe exit on interrupt
trap "tput cnorm; clear; exit 0" INT TERM

# Grid dimensions
WIDTH=50
HEIGHT=20

# Cellular Automata states:
# ' ' = Empty
# 'T' = Tree
# '#' = Burning
# '.' = Burned

declare -A grid
declare -A next_grid

# Initialize forest with random trees (density ~40%)
init_forest() {
    for ((y=0; y<HEIGHT; # % & (( ((x="0;" (RANDOM )); -v 100) 40 < High Ignite Low Sample a audio command determine do done else fi fire for frequency get_wind_from_hum() grid[$((WIDTH/2)),$((HEIGHT/2))]="#" grid[$x,$y]=" " hum="East/Fast" if in live middle sox starting the then to using vector wind wind, x++)); x<WIDTH; y++)); { }>/dev/null; then
        # Capture 0.1 seconds of audio and get peak frequency via sox stat
        local freq
        freq=$(rec -q -b 16 -c 1 -r 8000 -e signed-integer trim 0 0.1 stat -f 2>&1 2>/dev/null)
        if [[ $freq =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            # Map frequency (approx 80Hz to 800Hz human hum range) to wind X vector (-2 to 2)
            # Simple scaling
            local scaled=$(echo "$freq" | awk '{print int(($1 - 150) / 100)}')
            WIND_X=$scaled
            # Clamp wind speed
            (( WIND_X < -2 )) && WIND_X=-2
            (( WIND_X > 2 )) && WIND_X=2
        else
            WIND_X=0
        fi
    else
        # Fallback pseudo-wind if sox is unavailable
        WIND_X=$(( (RANDOM % 3) - 1 ))
    fi
}

# Update cellular automata state based on forest fire rules + wind
update_grid() {
    for ((y=0; y<HEIGHT; "#") "$current" "T") # (( ((x="0;" (taking + - -1 0 1; ;; Apply Burning Check WIND_X)) account) any become bias burned burning case checking current="${grid[$x,$y]}" do dx dy dy)) for if ignited="0" in into is local neighbor next_grid[$x,$y]="." nx ny="$((y" out to trees wind x++)); x<WIDTH; y++));>= 0 && nx < WIDTH && ny >= 0 && ny < HEIGHT )); then
                                if [[ "${grid[$nx,$ny]}" == "#" ]]; then
                                    ignited=1
                                    break 2
                                fi
                            fi
                        done
                    done
                    # Lightning strike chance (0.5%) or neighbor ignition
                    if (( ignited == 1 || (RANDOM % 200) == 0 )); then
                        next_grid[$x,$y]="#"
                    else
                        next_grid[$x,$y]="T"
                    fi
                    ;;
                *)
                    # Empty or burned spaces occasionally grow new trees (regrowth)
                    if (( (RANDOM % 100) < 5 )); then
                        next_grid[$x,$y]="T"
                    else
                        next_grid[$x,$y]=" "
                    fi
                    ;;
            esac
        done
    done

    # Copy next_grid back to grid
    for ((y=0; y<HEIGHT; "#") "$output" "${grid[$x,$y]}" "%s" ".") "T") # ((x="0;" ((y="0;" *) 0.1 ;; Gray Green Main Red Render WIND_X="0" and ash case civis clear colors do done esac execution fire for forest get_wind_from_hum grid grid[$x,$y]="${next_grid[$x,$y]}" in indicator init_forest local loop output output+="  +$(printf '-%0.s' $(seq 1 $WIDTH))+\n" printf render render() sleep the tput tree true; update_grid while wind with x++)); x<WIDTH; y++)); y<HEIGHT; { }>