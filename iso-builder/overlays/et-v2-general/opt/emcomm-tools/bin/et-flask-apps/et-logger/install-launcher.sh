#!/bin/bash
# Install et-logger panel launcher
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing Field Logger panel launcher..."

# Copy desktop file to panel launcher dir
mkdir -p "$HOME/.config/xfce4/panel/launcher-28"
cp "$DIR/launcher-28-et-logger.desktop" "$HOME/.config/xfce4/panel/launcher-28/et-logger.desktop"

# Also install as a system .desktop so it's searchable
sudo cp "$DIR/launcher-28-et-logger.desktop" /usr/share/applications/et-logger.desktop 2>/dev/null || true

# Register plugin-28 as a launcher in xfconf
xfconf-query -c xfce4-panel -p /plugins/plugin-28 -t string -s "launcher" --create 2>/dev/null
xfconf-query -c xfce4-panel -p /plugins/plugin-28/items -a -t string -s "et-logger.desktop" --create 2>/dev/null

# Get current plugin-ids and add 28 if not present
CURRENT=$(xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids 2>/dev/null)
if echo "$CURRENT" | grep -q "^28$"; then
    echo "Plugin 28 already registered."
else
    # Read current IDs into array
    IDS=()
    while IFS= read -r line; do
        line=$(echo "$line" | tr -d '[:space:]')
        if [[ "$line" =~ ^[0-9]+$ ]]; then
            IDS+=("$line")
        fi
    done <<< "$CURRENT"

    # Insert 28 before plugin 6 (separator before systray)
    NEW_ARGS=()
    INSERTED=false
    for id in "${IDS[@]}"; do
        if [[ "$id" == "6" && "$INSERTED" == "false" ]]; then
            NEW_ARGS+=(-t int -s 28)
            INSERTED=true
        fi
        NEW_ARGS+=(-t int -s "$id")
    done
    # If 6 wasn't found, append at end
    if [[ "$INSERTED" == "false" ]]; then
        NEW_ARGS+=(-t int -s 28)
    fi

    xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids -rR 2>/dev/null
    xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids -a "${NEW_ARGS[@]}" --create
    echo "Plugin 28 registered in panel."
fi

# Restart panel
xfce4-panel -r &
echo "Done! Field Logger launcher installed."
