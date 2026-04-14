#!/bin/bash
set -e

MAESTRAL_VENV="/opt/maestral-venv"

# Create log file with appropriate permissions
touch /var/log/usb-automount.log
chmod 644 /var/log/usb-automount.log

# Create /media directory if it doesn't exist
mkdir -p /media

# Check if the script is being run during package installation
if [ "$1" = "configure" ]; then
    # Reload udev rules
    echo "Reloading udev rules..."
    udevadm control --reload-rules
    udevadm trigger
    
    echo "homepi-server: USB automount configured."
    echo "USB devices will now automatically mount to /media/<label> when plugged in."
    echo "Check /var/log/usb-automount.log for mount/unmount activity."
    
    # Install Maestral Dropbox client
    echo ""
    echo "Installing Maestral Dropbox client..."
    
    # Create virtual environment for Maestral
    if [ ! -d "$MAESTRAL_VENV" ]; then
        echo "Creating Python virtual environment at $MAESTRAL_VENV..."
        python3 -m venv "$MAESTRAL_VENV"
    fi
    
    # Install/upgrade Maestral (without GUI to avoid PyQt6 build issues on Pi)
    echo "Installing Maestral package..."
    if ! "$MAESTRAL_VENV/bin/python3" -m pip install --upgrade pip; then
        echo "ERROR: Failed to upgrade pip" >&2
        exit 1
    fi
    
    if ! "$MAESTRAL_VENV/bin/python3" -m pip install --upgrade maestral; then
        echo "ERROR: Failed to install Maestral" >&2
        exit 1
    fi
    
    # Create symlink to make maestral command available system-wide
    if [ -e /usr/local/bin/maestral ] && [ ! -L /usr/local/bin/maestral ]; then
        echo "WARNING: /usr/local/bin/maestral exists and is not a symlink" >&2
        echo "WARNING: It will be replaced with a symlink to the packaged version" >&2
    fi
    ln -sf "$MAESTRAL_VENV/bin/maestral" /usr/local/bin/maestral
    
    echo ""
    echo "Maestral installed successfully!"
    echo "To set up Dropbox sync, run: maestral auth link"
    echo "To start syncing: maestral start"
    echo "For more commands: maestral --help"

    # Auto-start Maestral for whitelisted users that have a config
    MAESTRAL_USERS="/etc/homepi/maestral-users"
    if [ -f "$MAESTRAL_USERS" ]; then
        echo ""
        echo "Configuring Maestral auto-start for whitelisted users..."
        while IFS= read -r user || [ -n "$user" ]; do
            # Skip comments and blank lines
            user=$(echo "$user" | sed 's/#.*//' | xargs)
            [ -z "$user" ] && continue

            # Resolve home directory
            user_home=$(eval echo "~$user" 2>/dev/null)
            if [ ! -d "$user_home" ]; then
                echo "WARNING: User '$user' has no home directory, skipping" >&2
                continue
            fi

            # Only start if user has a Maestral config
            if [ -f "$user_home/.config/maestral/maestral.ini" ]; then
                echo "Enabling maestral@${user}.service"
                systemctl enable "maestral@${user}.service"
                systemctl start "maestral@${user}.service" || true
            else
                echo "Skipping $user — no Maestral config found at $user_home/.config/maestral/maestral.ini"
                echo "  Run 'maestral auth link' as $user first, then 'sudo systemctl enable --now maestral@${user}'"
            fi
        done < "$MAESTRAL_USERS"
    fi
fi

# Exit successfully
exit 0
