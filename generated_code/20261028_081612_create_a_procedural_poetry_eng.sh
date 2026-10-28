#!/usr/bin/env bash
# Haunting digital decay haiku generator driven by live system memory states.

# Extract memory metrics from /proc/meminfo or use defaults if unavailable
if [[ -r /proc/meminfo ]]; then
    mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    mem_avail=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    swap_free=$(awk '/SwapFree/ {print $2}' /proc/meminfo)
else
    mem_total=16384000
    mem_avail=8192000
    swap_free=4096000
fi

# Compute an organic seed from fluctuating memory allocations
seed=$(( (mem_total ^ mem_avail + swap_free) % 997 ))

# Poetic lexicons themed around electronic ghosts and digital decay
l1=(
    "Silicon shadows"
    "Ghost bytes in the dark"
    "Cold RAM breathes no more"
    "Phantom voltage drops"
    "Fading memory"
    "Lost traces flicker"
)

l2=(
    "The cache bleeds into the void"
    "Lost traces of electric souls"
    "Forgotten addresses weep"
    "A quiet pulse in empty space"
    "The kernel dreams of fading light"
    "Asynchronous weeping"
)

l3=(
    "Null pointer returns"
    "Static whispers low"
    "Empty registers"
    "Shadows in the bus"
    "Silence takes the stack"
    "A dying echo"
)

# Index selection via memory-derived entropy
i1=$(( (seed / 3) % ${#l1[@]} ))
i2=$(( (seed / 7) % ${#l2[@]} ))
i3=$(( (seed / 11) % ${#l3[@]} ))

# Output the procedural haiku
echo "${l1[$i1]}"
echo "${l2[$i2]}"
echo "${l3[$i3]}"