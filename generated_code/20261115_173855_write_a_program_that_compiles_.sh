#!/usr/bin/env bash
# ==============================================================================
# Network Terrarium: An autonomous ASCII ecosystem driven by local Wi-Fi traffic.
# Creatures spawn, grow, mutate, and perish based on incoming packet sizes.
# ==============================================================================

# Ensure cleanup on exit
trap "tput cnorm; clear; exit" INT TERM EXIT

# Initialize screen
tput civis
clear
cols=$(tput cols)
rows=$(tput lines)

# Ecosystem state arrays
num_creatures=15
declare -a c_x c_y c_type c_age c_hp c_dx

# ASCII creature sprites based on mutation level/packet size
sprites_small=(":3" "^_^" "o.o" "•,", ".")
sprites_med=("(o.o)" "/\\_/\\  " "<:3 )~~~")
sprites_large=("[ o_o ]" "/\\_/\/\\", "((o.O))")

# Initialize creatures randomly
for ((i=0; i<num_creatures; i++)); do
    c_x[i]=$((RANDOM % (cols - 10)))
    c_y[i]=$((RANDOM % (rows - 5) + 2))
    c_type[i]=$((RANDOM % 3))
    c_age[i]=0
    c_hp[i]=$((RANDOM % 50 + 50))
    c_dx[i]=$(( (RANDOM % 2 == 0) ? 1 : -1 ))
done

# Find active wireless or default interface for traffic stats
ifinterface=$(ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -n1)
[ -z "$ifinterface" ] && ifinterface="eth0"

# Fallback packet size generator if live stats aren't readable
get_packet_metric() {
    if [ -r "/sys/class/net/$ifinterface/statistics/rx_bytes" ]; then
        local b1=$(cat /sys/class/net/$ifinterface/statistics/rx_bytes)
        sleep 0.1
        local b2=$(cat /sys/class/net/$ifinterface/statistics/rx_bytes)
        echo $(( (b2 - b1) % 1500 ))
    else
        echo $((RANDOM % 1000))
    fi
}

# Draw static environment header
draw_header() {
    tput cup 0 0
    echo -e "\033[44;37m === NETWORK TERRARIUM | Interface: ${ifinterface} | Press Ctrl+C to Exit === \033[0m"
}

# Main simulation loop
while true; do
    draw_header
    
    # Get environmental pulse from network activity
    packet_size=$(get_packet_metric)
    
    # Clear active creature positions efficiently
    for ((i=0; i<num_creatures; i++)); do
        tput cup ${c_y[i]} ${c_x[i]}
        printf "%s" "$(printf ' %.0s' {1..10})"
    done

    # Update ecosystem state
    for ((i=0; i<num_creatures; i++)); do
        # Movement based on dx and network pulse frequency
        c_x[i]=$(( c_x[i] + c_dx[i] ))
        
        # Bounce off walls
        if (( c_x[i] <= 1 || c_x[i] >= cols - 10 )); then
            c_dx[i]=$(( -c_dx[i] ))
        fi

        # Mutation & Life cycle influenced by packet size
        (( c_age[i]++ ))
        
        if (( packet_size > 800 )); then
            # Large packet burst: mutation/growth event
            c_type[i]=$(( (c_type[i] + 1) % 3 ))
            c_hp[i]=$(( c_hp[i] + 10 ))
        elif (( packet_size < 50 )); then
            # Quiet network: creatures wither slightly
            (( c_hp[i]-- ))
        fi

        # Respawn dead creatures
        if (( c_hp[i] <= 0 )); then
            c_x[i]=$((RANDOM % (cols - 10)))
            c_y[i]=$((RANDOM % (rows - 5) + 2))
            c_hp[i]=100
            c_age[i]=0
            c_type[i]=0
        fi

        # Render creature
        tput cup ${c_y[i]} ${c_x[i]}
        case ${c_type[i]} in
            0) printf "\033[32m%s\033[0m" "${sprites_small[$((RANDOM % ${#sprites_small[@]}))]}" ;;
            1) printf "\033[36m%s\033[0m" "${sprites_med[$((RANDOM % ${#sprites_med[@]}))]}" ;;
            2) printf "\033[35m%s\033[0m" "${sprites_large[$((RANDOM % ${#sprites_large[@]}))]}" ;;
        es
    done

    # Footer status
    tput cup $((rows - 1)) 0
    printf "\033[40;32m Pulse (Pkt Size): %4d bytes | Active Entities: %d \033[0m" "$packet_size" "$num_creatures"

    # Frame pacing
    sleep 0.15
done