#!/bin/bash
set -e

# Check if the script is being run during package removal
if [ "$1" = "remove" ] || [ "$1" = "upgrade" ]; then
    echo "Preparing to remove USB automount..."
    # No active services to stop, just informational
fi

# Exit successfully
exit 0
