#!/bin/bash
set -e

MAESTRAL_VENV="/opt/maestral-venv"

# Check if the script is being run during package removal
if [ "$1" = "remove" ] || [ "$1" = "upgrade" ]; then
    echo "Preparing to remove USB automount..."
    
    # Stop Maestral if it's running
    if [ -f "$MAESTRAL_VENV/bin/maestral" ]; then
        echo "Stopping Maestral daemon..."
        "$MAESTRAL_VENV/bin/maestral" stop 2>/dev/null || true
    fi
fi

# Exit successfully
exit 0
