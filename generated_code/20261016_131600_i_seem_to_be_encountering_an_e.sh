#!/usr/bin/env bash

# Error Resilience Assistant
# Solves: "I seem to be encountering an error. Can I try something else for you?"

set -euo pipefail

# Function simulating a primary operation that encounters an error
attempt_primary_task() {
    echo "Executing primary task..."
    # Simulate an unexpected failure
    return 1
}

# Alternative option 1: System diagnostics
run_diagnostics() {
    echo "-> Switching to alternative: System health overview..."
    echo "Uptime: $(uptime)"
    echo "Disk Usage:"
    df -h / | tail -n 1
}

# Alternative option 2: Moment of inspiration
run_inspiration() {
    echo "-> Switching to alternative: Offering words of wisdom..."
    if command -v fortune &> /dev/null; then
        fortune
    else
        echo "\"A smooth sea never made a skilled sailor.\" - English Proverb"
    fi
}

# Alternative option 3: Creative visual showcase
run_visual_showcase() {
    echo "-> Switching to alternative: Terminal color palette display..."
    for i in {31..36}; do
        printf "\e[1;${i}m  ■  Vibrant color theme code: ${i} \e[0m\n"
    done
}

# Main controller handling the graceful error recovery workflow
main() {
    if ! attempt_primary_task; then
        echo ""
        echo "------------------------------------------------------------"
        echo "I seem to be encountering an error. Can I try something else for you?"
        echo "------------------------------------------------------------"
        echo "Available alternatives:"
        echo "  1) Run system diagnostics"
        echo "  2) Share a moment of inspiration"
        echo "  3) Display terminal color showcase"
        echo "  4) Exit gracefully"
        echo ""

        # Handle interactive input or provide a graceful fallback for automation
        if [ -t 0 ]; then
            read -p "Select an option [1-4]: " choice
            echo ""
            case "$choice" in
                1) run_diagnostics ;;
                2) run_inspiration ;;
                3) run_visual_showcase ;;
                *) echo "Operation aborted. Have a wonderful day!" ;;
            esac
        else
            # Non-interactive fallback default
            run_inspiration
        fi
    fi
}

main "$@"