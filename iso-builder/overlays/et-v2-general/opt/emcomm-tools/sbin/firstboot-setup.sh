#!/bin/bash
# EmComm-Tools First Boot Setup
# Fixes user groups and permissions after Calamares install

echo "Running EmComm-Tools first boot setup..."

# Find the primary user (UID 1000)
PRIMARY_USER=$(getent passwd 1000 | cut -d: -f1)

if [ -n "$PRIMARY_USER" ]; then
    echo "Adding $PRIMARY_USER to required groups..."
    usermod -aG dialout,et-data,plugdev,audio "$PRIMARY_USER"
fi

# Fix radios.d permissions
echo "Fixing radios.d permissions..."
chgrp -R et-data /opt/emcomm-tools/conf/radios.d 2>/dev/null
chmod 775 /opt/emcomm-tools/conf/radios.d 2>/dev/null
chmod 664 /opt/emcomm-tools/conf/radios.d/*.json 2>/dev/null
chmod 775 /opt/emcomm-tools/conf/radios.d/audio 2>/dev/null

echo "First boot setup complete. Reboot for group changes."
