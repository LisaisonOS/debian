#!/bin/bash
#
# Author  : Sylvain Deguire (VA2OPS)
# Date    : January 2026
# Purpose : Install LiaisonOS persistence system
#
# This should be called from your main install.sh or a live-build hook
#

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

et-log "Installing LiaisonOS persistence system..."

# Create symlink for main command
ln -sf /opt/emcomm-tools/bin/et-persistence/et-persistence /usr/local/bin/et-persistence

# Install system-level shutdown save service
if [[ -f "${SCRIPT_DIR}/../../../etc/systemd/system/emcomm-persistence-save.service" ]]; then
    cp -v "${SCRIPT_DIR}/../../../etc/systemd/system/emcomm-persistence-save.service" \
          /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable emcomm-persistence-save.service
    et-log "Enabled shutdown save service"
fi

# Desktop shortcut for manual save
if [[ -f "${SCRIPT_DIR}/../../../usr/share/applications/et-persistence-save.desktop" ]]; then
    cp -v "${SCRIPT_DIR}/../../../usr/share/applications/et-persistence-save.desktop" \
          /usr/share/applications/
    et-log "Installed desktop shortcut"
fi

# User systemd services are in skel, they'll be copied automatically
# But we need to enable them by default

# Create a firstboot hook to enable user services
cat > /etc/skel/.config/autostart/emcomm-persistence-setup.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=LiaisonOS Persistence Setup
Exec=/opt/emcomm-tools/bin/et-persistence/et-persistence-setup-user
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
OnlyShowIn=XFCE;
EOF

et-log "Persistence system installed!"
