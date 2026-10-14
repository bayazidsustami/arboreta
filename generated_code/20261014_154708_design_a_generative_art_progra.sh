#!/usr/bin/env bash
#
# Origami Wi-Fi Flock - A generative terminal art program that translates
# real-time network packet loss into a migrating flock of ASCII paper cranes.
# Requirements: bash, ping, tput, standard coreutils.
# Run: ./origami_flock.sh (Press Ctrl+C to exit)

# Ensure safe cleanup on exit
trap "tput cnorm; clear; exit 0" SIGINT SIGTERM

# Hide cursor and clear screen
tput civis
clear

# Get terminal dimensions
cols=$(tput cols)
rows=$(tput lines)

# Number of cranes in the flock
NUM_CRANES=8

# Initialize crane arrays (x, y, dx, dy, frame, fold_state)
for ((i=0; i<NUM_CRANES; # % '' 'EOF' (ASCII (Folding) (RANDOM (cols (rows )) + - ---/\--- -1 -W -c -d -r / /\ /__\ /____\ 0: 1 1.1.1.1 10))) 1: 2 2) 2)) 2: 5) : << ? CRANE_0 CRANE_1 CRANE_2 Crane EOF Frame Function Wings \ \/ a against art do done down dx[i]="$((" dy[i]="0" fold[i]="0" frame[i]="0" frames get_packet_loss() i++)); level, local loss measure origami packet percentage ping_output="$(ping" read reliable representation) target to up, x[i]="$((RANDOM" y[i]="$((RANDOM" {>/dev/null)
    if [ $? -ne 0 ]; then
        echo 100
        return
    fi
    local loss
    loss=$(echo "$ping_output" | grep -oE '[0-9]+% packet loss' | grep -oE '[0-9]+')
    if [ -z "$loss" ]; then
        echo 0
    else
        echo "$loss"
    fi
}

packet_loss=0
counter=0

# Main animation loop
while true; do
    # Check packet loss every 20 frames to avoid flooding network
    if (( counter % 20 == 0 )); then
        packet_loss=$(get_packet_loss)
    fi
    ((counter++))

    # Update terminal size dynamically
    cols=$(tput cols)
    rows=$(tput lines)

    # Clear previous frame region or just screen
    tput cup 0 0

    # Draw status bar at the top
    printf "\033[36m[Origami Wi-Fi Migration] | Packet Loss: %3d%% | Press Ctrl+C to Exit\033[0m\n" "$packet_loss"

    # Update and render each crane
    for ((i=0; i<NUM_CRANES; # & (( (erratic Higher do folding) i++)); if introduces loss movement packet packet_loss turbulence vertical> 10 )); then
            if (( RANDOM % 100 < packet_loss )); then
                dy[i]=$(( (RANDOM % 3) - 1 ))
                fold[i]=$((RANDOM % 3)) # Unfold/fold erratically
            fi
        else
            # Calm rhythmic flapping
            fold[i]=$(( (counter + i) % 3 ))
        fi

        # Move crane horizontally
        x[i]=$(( x[i] + dx[i] ))
        y[i]=$(( y[i] + dy[i] ))

        # Screen wrapping for migration effect
        if (( x[i] >= cols - 8 )); then
            x[i]=0
            y[i]=$((RANDOM % (rows - 6) + 3))
        elif (( x[i] < 0 )); then
            x[i]=$((cols - 9))
        fi

        if (( y[i] < 2 )); then
            y[i]=2
            dy[i]=1
        elif (( y[i] >= rows - 4 )); then
            y[i]=$((rows - 5))
            dy[i]=-1
        fi

        # Select frame based on fold state
        case ${fold[i]} in
            0) current_art="$CRANE_0" ;;
            1) current_art="$CRANE_1" ;;
            2) current_art="$CRANE_2" ;;
        esac

        # Render crane at calculated coordinates with color shifting based on packet loss
        if (( packet_loss > 25 )); then
            color="\033[31m" # Red alert turbulence
        elif (( packet_loss > 5 )); then
            color="\033[33m" # Yellow warning
        else
            color="\033[32m" # Green smooth migration
        fi

        # Print crane line by line using ANSI positioning
        line_offset=0
        while IFS= read -r line; do
            target_y=$(( y[i] + line_offset ))
            if (( target_y > 1 && target_y < rows && x[i] > 0 && x[i] < cols - ${#line} )); then
                printf "\033[%d;%dH%s%s\033[0m" "$target_y" "${x[i]}" "$color" "$line"
            fi
            ((line_offset++))
        done <<< "$current_art"
    done

    # Frame pacing (~15 FPS)
    sleep 0.07
done