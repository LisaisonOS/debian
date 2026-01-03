#!/bin/bash
# =============================================================================
# EmComm-Tools Debian ISO Builder
# https://emcomm-tools.ca
# 
# Author: Sylvain Deguire (VA2OPS)
# Based on EmComm-Tools OS by Gaston Gonzalez ()
#
# Directory structure:
#   ./overlays/          - EmComm-Tools overlay versions (et-r5-final, etc.)
#   ./wine-sources/      - Wine prefixes with VarAC, VARA, FT8, etc.
#   ./backgrounds/       - Wallpaper images (emcomm-base.png for generator)
#   ./motd/              - Custom terminal banners
#   ./build/             - Build output (auto-created)
#
# Usage: ./setup-emcomm-iso.sh
# =============================================================================

set -e

# Get script directory (allows running from anywhere)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Directory structure (relative to script)
OVERLAYS_DIR="$SCRIPT_DIR/overlays"
WINE_SOURCE_DIR="$SCRIPT_DIR/wine-sources"
WALLPAPER_DIR="$SCRIPT_DIR/backgrounds"
MOTD_DIR="$SCRIPT_DIR/motd"
BUILD_DIR="$SCRIPT_DIR/build"
ISO_DIR="$BUILD_DIR/emcomm-debian-iso"

# Check for dialog
if ! command -v dialog &> /dev/null; then
    echo "Installing dialog..."
    sudo apt install -y dialog
fi

echo "=== EmComm-Tools Debian ISO Builder ==="
echo "Script directory: $SCRIPT_DIR"
echo ""

# =============================================================================
# Overlay Selection
# =============================================================================
if [ -d "$OVERLAYS_DIR" ]; then
    # Find all overlay folders
    OVERLAY_FOLDERS=($(find "$OVERLAYS_DIR" -mindepth 1 -maxdepth 1 -type d | sort))
    
    if [ ${#OVERLAY_FOLDERS[@]} -gt 0 ]; then
        MENU_OPTIONS=()
        i=1
        for ov in "${OVERLAY_FOLDERS[@]}"; do
            MENU_OPTIONS+=($i "$(basename "$ov")")
            ((i++))
        done
        
        OV_CHOICE=$(dialog --title "Overlay Selection" \
            --menu "Select the overlay version to use:" 15 60 10 \
            "${MENU_OPTIONS[@]}" \
            3>&1 1>&2 2>&3)
        
        clear
        
        if [ -n "$OV_CHOICE" ]; then
            SELECTED_OVERLAY="${OVERLAY_FOLDERS[$((OV_CHOICE-1))]}"
            OVERLAY_DIR="$SELECTED_OVERLAY/overlay"
            
            # Check if overlay subfolder exists, if not use the folder directly
            if [ ! -d "$OVERLAY_DIR" ]; then
                OVERLAY_DIR="$SELECTED_OVERLAY"
            fi
            
            echo "Selected overlay: $(basename "$SELECTED_OVERLAY")"
        else
            echo "No overlay selected. Exiting."
            exit 1
        fi
    else
        echo "No overlays found in $OVERLAYS_DIR"
        echo "Please add overlay folders (e.g., et-r5-final) to the overlays/ directory."
        exit 1
    fi
else
    echo "Overlays directory not found: $OVERLAYS_DIR"
    echo "Please create the overlays/ directory and add overlay folders."
    exit 1
fi

# Verify overlay exists
if [ ! -d "$OVERLAY_DIR" ]; then
    echo "ERROR: Overlay directory not found: $OVERLAY_DIR"
    exit 1
fi

echo "Using overlay: $OVERLAY_DIR"
echo ""

# =============================================================================
# Maps Configuration
# =============================================================================
INCLUDE_MAPS="no"
MAP_CHOICE=$(dialog --title "EmComm-Tools ISO Builder" \
    --menu "Offline Maps Configuration:\n\nDo you want to include maps in the ISO?" 15 60 3 \
    1 "No - Use external drive (Recommended, ~2.8GB ISO)" \
    2 "Yes - Bake maps into ISO (~5.5GB ISO)" \
    3 "Cancel build" \
    3>&1 1>&2 2>&3)

clear

case $MAP_CHOICE in
    1)
        echo "Maps will NOT be included in ISO."
        echo "Users will setup external drive on first boot."
        INCLUDE_MAPS="no"
        ;;
    2)
        echo "Maps WILL be included in ISO."
        echo "Warning: ISO will be ~5.5GB!"
        INCLUDE_MAPS="yes"
        ;;
    3|"")
        echo "Build cancelled."
        exit 0
        ;;
esac

echo ""
read -p "Press Enter to continue with build..."

# =============================================================================
# Wallpaper Selection
# =============================================================================
WALLPAPER_BASE="$WALLPAPER_DIR/emcomm-base.png"
SELECTED_WALLPAPER=""
GENERATED_WALLPAPER=""

# Check for ImageMagick
if ! command -v convert &> /dev/null; then
    echo "Installing ImageMagick for wallpaper generation..."
    sudo apt install -y imagemagick
fi

# Wallpaper mode selection
WP_MODE=$(dialog --title "Wallpaper Configuration" \
    --menu "How do you want to set the wallpaper?" 15 60 3 \
    1 "Generate custom wallpaper (callsign + tagline)" \
    2 "Select from existing images" \
    3 "Use default from overlay" \
    3>&1 1>&2 2>&3)

clear

case $WP_MODE in
    1)
        # Generate custom wallpaper
        if [ -f "$WALLPAPER_BASE" ]; then
            echo "=== Custom Wallpaper Generator ==="
            echo ""
            read -p "Enter callsign (e.g., VA2OPS): " WP_CALLSIGN
            read -p "Enter tagline (optional, press Enter to skip): " WP_TAGLINE
            echo ""
            echo "Text color options:"
            echo "  1) White (default)"
            echo "  2) Light gray"
            echo "  3) Orange (ham radio style)"
            echo "  4) Light blue"
            read -p "Select color [1]: " WP_COLOR_CHOICE
            
            # Set colors based on choice
            case "${WP_COLOR_CHOICE:-1}" in
                2) WP_CALLSIGN_COLOR="rgba(200,200,200,0.90)"; WP_TAG_COLOR="rgba(170,170,170,0.80)" ;;
                3) WP_CALLSIGN_COLOR="rgba(255,165,0,0.90)"; WP_TAG_COLOR="rgba(255,200,100,0.80)" ;;
                4) WP_CALLSIGN_COLOR="rgba(135,206,250,0.90)"; WP_TAG_COLOR="rgba(173,216,230,0.80)" ;;
                *) WP_CALLSIGN_COLOR="rgba(255,255,255,0.90)"; WP_TAG_COLOR="rgba(200,200,200,0.75)" ;;
            esac
            
            if [ -n "$WP_CALLSIGN" ]; then
                GENERATED_WALLPAPER="/tmp/generated-wallpaper.png"
                echo "Generating wallpaper..."
                
                if [ -n "$WP_TAGLINE" ]; then
                    convert "$WALLPAPER_BASE" \
                        -gravity center \
                        -font "DejaVu-Sans-Bold" \
                        -pointsize 54 \
                        -fill "$WP_CALLSIGN_COLOR" \
                        -annotate +0+0 "$WP_CALLSIGN" \
                        -gravity south \
                        -pointsize 22 \
                        -fill "$WP_TAG_COLOR" \
                        -annotate +0+80 "$WP_TAGLINE" \
                        "$GENERATED_WALLPAPER"
                else
                    convert "$WALLPAPER_BASE" \
                        -gravity center \
                        -font "DejaVu-Sans-Bold" \
                        -pointsize 54 \
                        -fill "$WP_CALLSIGN_COLOR" \
                        -annotate +0+0 "$WP_CALLSIGN" \
                        "$GENERATED_WALLPAPER"
                fi
                
                echo "Wallpaper generated: $WP_CALLSIGN"
            else
                echo "No callsign entered, using default wallpaper."
            fi
        else
            echo "Base image not found: $WALLPAPER_BASE"
            echo "Please copy emcomm-base.png to backgrounds/ directory"
            echo "Using default wallpaper from overlay."
        fi
        ;;
    2)
        # Select from existing images
        if [ -d "$WALLPAPER_DIR" ]; then
            WALLPAPERS=($(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) ! -name "emcomm-base.png" | sort))
            
            if [ ${#WALLPAPERS[@]} -gt 0 ]; then
                MENU_OPTIONS=()
                i=1
                for wp in "${WALLPAPERS[@]}"; do
                    MENU_OPTIONS+=($i "$(basename "$wp")")
                    ((i++))
                done
                
                WP_CHOICE=$(dialog --title "Wallpaper Selection" \
                    --menu "Select wallpaper for the ISO:" 20 60 10 \
                    "${MENU_OPTIONS[@]}" \
                    3>&1 1>&2 2>&3)
                
                clear
                
                if [ -n "$WP_CHOICE" ]; then
                    SELECTED_WALLPAPER="${WALLPAPERS[$((WP_CHOICE-1))]}"
                    echo "Selected wallpaper: $(basename "$SELECTED_WALLPAPER")"
                fi
            else
                echo "No wallpapers found in $WALLPAPER_DIR"
            fi
        else
            echo "Wallpaper directory not found: $WALLPAPER_DIR"
        fi
        ;;
    3|"")
        echo "Using default wallpaper from overlay."
        ;;
esac

# =============================================================================
# MOTD (Banner) Selection
# =============================================================================
SELECTED_MOTD=""

if [ -d "$MOTD_DIR" ]; then
    # Find all MOTD files
    MOTD_FILES=($(find "$MOTD_DIR" -maxdepth 1 -type f | sort))
    
    if [ ${#MOTD_FILES[@]} -gt 0 ]; then
        # Build dialog menu
        MENU_OPTIONS=()
        MENU_OPTIONS+=(0 "Default (from overlay)")
        i=1
        for motd in "${MOTD_FILES[@]}"; do
            MENU_OPTIONS+=($i "$(basename "$motd")")
            ((i++))
        done
        
        MOTD_CHOICE=$(dialog --title "MOTD / Banner Selection" \
            --menu "Select terminal banner for the ISO:" 20 60 10 \
            "${MENU_OPTIONS[@]}" \
            3>&1 1>&2 2>&3)
        
        clear
        
        if [ -n "$MOTD_CHOICE" ] && [ "$MOTD_CHOICE" != "0" ]; then
            SELECTED_MOTD="${MOTD_FILES[$((MOTD_CHOICE-1))]}"
            echo "Selected MOTD: $(basename "$SELECTED_MOTD")"
        else
            echo "Using default MOTD from overlay"
        fi
    else
        echo "No MOTD files found in $MOTD_DIR"
    fi
else
    echo "MOTD directory not found: $MOTD_DIR"
    echo "Create it and add text files to select a custom banner."
fi

# Wine folder selection
echo ""
echo "=== Wine Prefix Selection ==="

# Check if wine-sources exists and has content
if [ ! -d "$WINE_SOURCE_DIR" ] || [ -z "$(ls -A "$WINE_SOURCE_DIR" 2>/dev/null)" ]; then
    echo ""
    echo "Wine-sources directory is empty or missing."
    echo "This contains VARA, VarAC, and other Windows apps for Wine."
    echo ""
    read -p "Download wine-sources from SourceForge? (~860MB) (y/n): " DOWNLOAD_WINE
    
    if [ "${DOWNLOAD_WINE,,}" = "y" ]; then
        mkdir -p "$WINE_SOURCE_DIR"
        echo "Downloading wine-sources-general.tar.gz..."
        wget -O /tmp/wine-sources-general.tar.gz \
            "https://sourceforge.net/projects/emcomm-tools/files/wine-sources-general.tar.gz/download"
        
        if [ $? -eq 0 ]; then
            echo "Extracting..."
            tar -xzf /tmp/wine-sources-general.tar.gz -C "$WINE_SOURCE_DIR/"
            rm /tmp/wine-sources-general.tar.gz
            echo "Wine-sources downloaded and extracted!"
        else
            echo "ERROR: Download failed."
            exit 1
        fi
    else
        echo "Skipping wine-sources download."
        echo "You can manually add Wine prefixes to: $WINE_SOURCE_DIR"
    fi
fi

if [ -d "$WINE_SOURCE_DIR" ]; then
    # Find all folders in wine-sources
    WINE_FOLDERS=()
    while IFS= read -r -d '' folder; do
        WINE_FOLDERS+=("$(basename "$folder")")
    done < <(find "$WINE_SOURCE_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
    
    if [ ${#WINE_FOLDERS[@]} -gt 0 ]; then
        # Build dialog menu
        MENU_OPTIONS=()
        i=1
        for folder in "${WINE_FOLDERS[@]}"; do
            MENU_OPTIONS+=("$i" "$folder")
            ((i++))
        done
        
        WINE_CHOICE=$(dialog --title "Wine Prefix Selection" \
            --menu "Select Wine folder to include in ISO:" 15 60 ${#WINE_FOLDERS[@]} \
            "${MENU_OPTIONS[@]}" \
            3>&1 1>&2 2>&3)
        
        clear
        
        if [ -n "$WINE_CHOICE" ]; then
            SELECTED_WINE="${WINE_FOLDERS[$((WINE_CHOICE-1))]}"
            WINE_PREFIX_PATH="${WINE_SOURCE_DIR}/${SELECTED_WINE}"
            echo "Selected Wine folder: $SELECTED_WINE"
        else
            echo "No Wine folder selected. Build cancelled."
            exit 0
        fi
    else
        echo "No Wine folders found in $WINE_SOURCE_DIR"
        echo "Using fallback: /tmp/.wine32"
        WINE_PREFIX_PATH="/tmp/.wine32"
    fi
else
    echo "wine-sources directory not found: $WINE_SOURCE_DIR"
    echo "Creating it now... Add your .wine32 folders there."
    mkdir -p "$WINE_SOURCE_DIR"
    echo "Using fallback: /tmp/.wine32"
    WINE_PREFIX_PATH="/tmp/.wine32"
fi

# Verify wine folder exists
if [ ! -d "$WINE_PREFIX_PATH" ]; then
    echo "ERROR: Wine folder not found: $WINE_PREFIX_PATH"
    exit 1
fi

echo "Wine prefix to include: $WINE_PREFIX_PATH"
echo ""

# =============================================================================
# BUILD PHASE - Starting now!
# =============================================================================
echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║  Starting build process...                                            ║"
echo "║                                                                       ║"
echo "║  NOTE: After entering your sudo password, the script will take        ║"
echo "║  1-2 minutes before showing any output. Please be patient!            ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

# Save cache if it exists
echo "Checking for existing cache..."
if [ -d "${ISO_DIR}/cache" ]; then
    echo "Saving package cache..."
    sudo mv ${ISO_DIR}/cache /tmp/lb-cache-backup
fi

# Nuke old directory - fresh start!
echo "Cleaning old build..."
cd "$SCRIPT_DIR"
sudo rm -rf ${ISO_DIR}
mkdir -p ${ISO_DIR}
cd ${ISO_DIR}

# Restore cache if we saved it
if [ -d "/tmp/lb-cache-backup" ]; then
    echo "Restoring package cache..."
    sudo mv /tmp/lb-cache-backup ${ISO_DIR}/cache
    echo "Cache restored! Build will be faster."
fi

# Verify we're in right place!
if [ "$PWD" != "$ISO_DIR" ]; then
    echo "ERROR: Not in correct directory! Expected: $ISO_DIR"
    exit 1
fi

# Configure live-build
echo "Configuring live-build..."
lb config \
  --distribution trixie \
  --architectures amd64 \
  --binary-images iso-hybrid \
  --archive-areas "main contrib non-free non-free-firmware" \
  --debian-installer live \
  --debian-installer-gui true

# Package list
echo "Copying package list..."
cp "${SCRIPT_DIR}/scripts/package-lists/emcomm.list.chroot" config/package-lists/

# Copy overlay
echo "Copying overlay..."
mkdir -p config/includes.chroot
cp -a ${OVERLAY_DIR}/* config/includes.chroot/

# Copy selected wallpaper
echo "Setting up wallpaper..."
mkdir -p config/includes.chroot/usr/share/backgrounds
if [ -n "$GENERATED_WALLPAPER" ] && [ -f "$GENERATED_WALLPAPER" ]; then
    echo "Copying generated wallpaper..."
    cp "$GENERATED_WALLPAPER" config/includes.chroot/usr/share/backgrounds/wallpaper.png
elif [ -n "$SELECTED_WALLPAPER" ] && [ -f "$SELECTED_WALLPAPER" ]; then
    echo "Copying selected wallpaper: $(basename "$SELECTED_WALLPAPER")"
    cp "$SELECTED_WALLPAPER" config/includes.chroot/usr/share/backgrounds/wallpaper.png
elif [ -f "${OVERLAY_DIR}/usr/share/backgrounds/va2ops-wallpaper.png" ]; then
    echo "Using default wallpaper from overlay"
    cp "${OVERLAY_DIR}/usr/share/backgrounds/va2ops-wallpaper.png" config/includes.chroot/usr/share/backgrounds/wallpaper.png
else
    echo "Warning: No wallpaper found!"
fi

# Copy selected MOTD
if [ -n "$SELECTED_MOTD" ] && [ -f "$SELECTED_MOTD" ]; then
    echo "Copying selected MOTD: $(basename "$SELECTED_MOTD")"
    cp "$SELECTED_MOTD" config/includes.chroot/etc/motd
fi

# Clean problematic overlay files
echo "Cleaning Ubuntu-specific files..."
rm -f config/includes.chroot/etc/skel/.config/gnome-initial-setup-done
rm -rf config/includes.chroot/etc/skel/.config/systemd/user/default.target.wants
rm -rf config/includes.chroot/usr/share/glib-2.0
rm -f config/includes.chroot/etc/adduser.conf
rm -rf config/includes.chroot/etc/apt

# Explicitly remove GNOME schema override that causes "No such schema" errors
rm -f config/includes.chroot/usr/share/glib-2.0/schemas/90_ubuntu-settings.gschema.override 2>/dev/null || true

# Remove GNOME-specific configs that cause errors on XFCE
rm -rf config/includes.chroot/etc/skel/.config/dconf
rm -f config/includes.chroot/etc/skel/.config/glib-2.0

# et-term is in overlay (XFCE-compatible version)

# Skip et-aircraft (not needed for now)
echo "Removing et-aircraft..."
rm -f config/includes.chroot/opt/emcomm-tools/bin/et-aircraft
rm -f config/includes.chroot/usr/share/applications/et-aircraft.desktop

# Remove et-user-* variants, keep only et-user
echo "Cleaning et-user variants..."
rm -f config/includes.chroot/opt/emcomm-tools/bin/et-user-*

# et-user is in overlay (bilingual version with password security)

# et-fldigi is in overlay (Debian paths: /usr/bin)

# et-winlink is in overlay (with browser auto-launch)

# Copy .wine32 (VARA/VarAC) from selected source
echo "Copying Wine prefix from: $WINE_PREFIX_PATH"
sudo cp -a "$WINE_PREFIX_PATH" config/includes.chroot/etc/skel/.wine32

# ============================================================
# CREATE SCRIPTS DIRECTLY (more reliable than hooks)
# ============================================================
echo "Creating EmComm-Tools scripts..."
mkdir -p config/includes.chroot/opt/emcomm-tools/bin

# et-ft8 is in overlay

# et-varac is in overlay (Wine app - simplified)

# et-get-vara is in overlay

# et-maps-setup is in overlay

# et-first-boot is in overlay

# Create autostart entry for first-boot wizard
echo "Copying first-boot autostart entry..."
mkdir -p config/includes.chroot/etc/xdg/autostart
cp "${SCRIPT_DIR}/scripts/autostart/et-first-boot.desktop" config/includes.chroot/etc/xdg/autostart/

# Create autostart entry for et-dashboard
echo "Copying et-dashboard autostart entry..."
cp "${SCRIPT_DIR}/scripts/autostart/et-dashboard.desktop" config/includes.chroot/etc/xdg/autostart/

# Create symlinks to /usr/local/bin
mkdir -p config/includes.chroot/usr/local/bin
ln -sf /opt/emcomm-tools/bin/et-ft8 config/includes.chroot/usr/local/bin/et-ft8
ln -sf /opt/emcomm-tools/bin/et-varac config/includes.chroot/usr/local/bin/et-varac
ln -sf /opt/emcomm-tools/bin/et-get-vara config/includes.chroot/usr/local/bin/et-get-vara
ln -sf /opt/emcomm-tools/bin/et-maps-setup config/includes.chroot/usr/local/bin/et-maps-setup
ln -sf /opt/emcomm-tools/bin/et-first-boot config/includes.chroot/usr/local/bin/et-first-boot

# Ensure VarAC icon exists
if [ -f "${OVERLAY_DIR}/usr/share/icons/varac.png" ]; then
    echo "VarAC icon found in overlay"
    # Copy to pixmaps too for compatibility
    mkdir -p config/includes.chroot/usr/share/pixmaps
    cp "${OVERLAY_DIR}/usr/share/icons/varac.png" config/includes.chroot/usr/share/pixmaps/
    cp "${OVERLAY_DIR}/usr/share/icons/"*.png config/includes.chroot/usr/share/pixmaps/ 2>/dev/null || true
    echo "Icons copied to pixmaps for Debian compatibility"
else
    echo "WARNING: VarAC icon not found in overlay"
fi

# Create hooks directory
echo "Creating hooks..."
mkdir -p config/hooks/live

# Hook: 0050-create-etgroup
cp "${SCRIPT_DIR}/scripts/hooks/0050-create-etgroup.hook.chroot" config/hooks/live/
chmod +x config/hooks/live/0050-create-etgroup.hook.chroot

# Hook: 0100-enable-i386
cp "${SCRIPT_DIR}/scripts/hooks/0100-enable-i386.hook.chroot" config/hooks/live/
chmod +x config/hooks/live/0100-enable-i386.hook.chroot

# Hook: 0150-install-linbpq
cp "${SCRIPT_DIR}/scripts/hooks/0150-install-linbpq.hook.chroot" config/hooks/live/
chmod +x config/hooks/live/0150-install-linbpq.hook.chroot

# Hook: 0160-install-pat
cp "${SCRIPT_DIR}/scripts/hooks/0160-install-pat.hook.chroot" config/hooks/live/
chmod +x config/hooks/live/0160-install-pat.hook.chroot

# Hook: 0161-install-min-browser
cp "${SCRIPT_DIR}/scripts/hooks/0161-install-min-browser.hook.chroot" config/hooks/live/
chmod +x config/hooks/live/0161-install-min-browser.hook.chroot

# Hook: 0165-install-ardop
cp "${SCRIPT_DIR}/scripts/hooks/0165-install-ardop.hook.chroot" config/hooks/live/
chmod +x config/hooks/live/0165-install-ardop.hook.chroot

# Hook: 0170-install-yaac
cp "${SCRIPT_DIR}/scripts/hooks/0170-install-yaac.hook.chroot" config/hooks/live/
chmod +x config/hooks/live/0170-install-yaac.hook.chroot

# Hook: 0175-install-udev
cp "${SCRIPT_DIR}/scripts/hooks/0175-install-udev.hook.chroot" config/hooks/live/
chmod +x config/hooks/live/0175-install-udev.hook.chroot

# Hook: 0180-install-voacap
cp "${SCRIPT_DIR}/scripts/hooks/0180-install-voacap.hook.chroot" config/hooks/live/
chmod +x config/hooks/live/0180-install-voacap.hook.chroot

# Hook: 0185-install-mbtileserver
cp "${SCRIPT_DIR}/scripts/hooks/0185-install-mbtileserver.hook.chroot" config/hooks/live/
chmod +x config/hooks/live/0185-install-mbtileserver.hook.chroot

# Hook: 0186-install-qttermtcp
cp "${SCRIPT_DIR}/scripts/hooks/0186-install-qttermtcp.hook.chroot" config/hooks/live/
chmod +x config/hooks/live/0186-install-qttermtcp.hook.chroot

# Hook: 0187-install-chattervox
cp "${SCRIPT_DIR}/scripts/hooks/0187-install-chattervox.hook.chroot" config/hooks/live/
chmod +x config/hooks/live/0187-install-chattervox.hook.chroot

# Hook: 0188-install-paracon
cp "${SCRIPT_DIR}/scripts/hooks/0188-install-paracon.hook.chroot" config/hooks/live/
chmod +x config/hooks/live/0188-install-paracon.hook.chroot

# Hook: 0189-install-et-predict
cp "${SCRIPT_DIR}/scripts/hooks/0189-install-et-predict.hook.chroot" config/hooks/live/
chmod +x config/hooks/live/0189-install-et-predict.hook.chroot

# Hook: 0190-configure-services
cp "${SCRIPT_DIR}/scripts/hooks/0190-configure-services.hook.chroot" config/hooks/live/
chmod +x config/hooks/live/0190-configure-services.hook.chroot

# Hook: 0191-install-qgis-plugin
cp "${SCRIPT_DIR}/scripts/hooks/0191-install-qgis-plugin.hook.chroot" config/hooks/live/
chmod +x config/hooks/live/0191-install-qgis-plugin.hook.chroot

# Hook: 0192-configure-postgres
cp "${SCRIPT_DIR}/scripts/hooks/0192-configure-postgres.hook.chroot" config/hooks/live/
chmod +x config/hooks/live/0192-configure-postgres.hook.chroot


# Note: et-ft8, et-varac, et-get-vara, et-maps-setup are created directly in includes.chroot above

# Hook: 0193-install-et-api
cp "${SCRIPT_DIR}/scripts/hooks/0193-install-et-api.hook.chroot" config/hooks/live/
chmod +x config/hooks/live/0193-install-et-api.hook.chroot

# Hook: 0200-create-user
cp "${SCRIPT_DIR}/scripts/hooks/0200-create-user.hook.chroot" config/hooks/live/
chmod +x config/hooks/live/0200-create-user.hook.chroot

# Hook: 0300-configure-autologin
cp "${SCRIPT_DIR}/scripts/hooks/0300-configure-autologin.hook.chroot" config/hooks/live/
chmod +x config/hooks/live/0300-configure-autologin.hook.chroot

# Fix /etc/environment
echo "Copying /etc/environment..."
cp "${SCRIPT_DIR}/scripts/etc/environment" config/includes.chroot/etc/

# XFCE Panel launchers (VarAC, JS8Call, FT8, fldigi)
echo "Adding XFCE panel launchers..."

# Remove any existing panel config from overlay to avoid conflicts
rm -rf config/includes.chroot/etc/skel/.config/xfce4/panel
rm -f config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml

mkdir -p config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-4
mkdir -p config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-5
mkdir -p config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-20
mkdir -p config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-21
mkdir -p config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-22
mkdir -p config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-23
mkdir -p config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-24

# Panel launcher: thunar
cp "${SCRIPT_DIR}/scripts/panel-launchers/launcher-4-thunar.desktop" config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-4/thunar.desktop

# Panel launcher: xfce4-terminal
cp "${SCRIPT_DIR}/scripts/panel-launchers/launcher-5-xfce4-terminal.desktop" config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-5/xfce4-terminal.desktop

# Panel launcher: varac
cp "${SCRIPT_DIR}/scripts/panel-launchers/launcher-20-varac.desktop" config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-20/varac.desktop

# Panel launcher: js8call
cp "${SCRIPT_DIR}/scripts/panel-launchers/launcher-21-js8call.desktop" config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-21/js8call.desktop

# Panel launcher: fldigi
cp "${SCRIPT_DIR}/scripts/panel-launchers/launcher-22-fldigi.desktop" config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-22/fldigi.desktop

# Panel launcher: wsjtx
cp "${SCRIPT_DIR}/scripts/panel-launchers/launcher-23-wsjtx.desktop" config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-23/wsjtx.desktop

# Panel launcher: navit
cp "${SCRIPT_DIR}/scripts/panel-launchers/launcher-24-navit.desktop" config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-24/navit.desktop

# XFCE panel config to add the launchers
mkdir -p config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml

# XFCE config: xfce4-desktop.xml
cp "${SCRIPT_DIR}/scripts/xfce-config/xfce4-desktop.xml" config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/

# XFCE panel config
cp "${SCRIPT_DIR}/scripts/xfce-config/xfce4-panel.xml" config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/

# XFCE config: displays.xml
cp "${SCRIPT_DIR}/scripts/xfce-config/displays.xml" config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/

# Note: Conky uses .conkyrc from overlay (already has proper styling)
# Just ensure gap_y is set to 10 in overlay file before build

# Fuse fix
echo "Adding fuse fix..."
mkdir -p config/packages.chroot
wget -P config/packages.chroot http://ftp.debian.org/debian/pool/main/f/fuse/libfuse2t64_2.9.9-9_amd64.deb

# Download maps if user chose to include them
if [ "$INCLUDE_MAPS" = "yes" ]; then
    echo "Copying map download hook..."
    cp "${SCRIPT_DIR}/scripts/hooks/0400-download-maps.hook.chroot" config/hooks/live/
    chmod +x config/hooks/live/0400-download-maps.hook.chroot
    echo "Map download hook copied."
else
    echo "Skipping map download (external drive mode)."
fi

echo ""
echo "=== Setup complete! ==="
echo ""
echo "User account: user / live (autologin enabled)"
echo "Wine prefix: $WINE_PREFIX_PATH"
if [ "$INCLUDE_MAPS" = "yes" ]; then
    echo "Maps: INCLUDED (ISO will be ~5.5GB)"
else
    echo "Maps: EXTERNAL DRIVE (ISO will be ~2.8GB)"
fi
echo ""

# Stay in the build directory!
cd ${ISO_DIR}

# =============================================================================
# Automatic Build
# =============================================================================
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║  Starting ISO build...                                                ║"
echo "║                                                                       ║"
echo "║  This will take 15-30 minutes depending on your internet speed.       ║"
echo "║  Build log: build.log                                                 ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

sudo lb build 2>&1 | tee build.log
BUILD_STATUS=${PIPESTATUS[0]}

if [ $BUILD_STATUS -eq 0 ]; then
    # Find the ISO file
    ISO_FILE=$(ls -t *.iso 2>/dev/null | head -1)
    
    if [ -n "$ISO_FILE" ]; then
        echo ""
        echo "╔═══════════════════════════════════════════════════════════════════════╗"
        echo "║  BUILD SUCCESSFUL!                                                    ║"
        echo "╚═══════════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "ISO created: ${ISO_DIR}/${ISO_FILE}"
        echo "Size: $(du -h "$ISO_FILE" | cut -f1)"
        echo ""
        
        # Offer to start QEMU
        read -p "Start QEMU to test the ISO? (y/n): " QEMU_CHOICE
        
        if [ "${QEMU_CHOICE,,}" = "y" ]; then
            echo "Starting QEMU..."
            qemu-system-x86_64 \
                -enable-kvm \
                -m 4G \
                -cdrom "$ISO_FILE" \
                -boot d &
            echo "QEMU started in background."
        fi
    else
        echo "Warning: ISO file not found!"
    fi
else
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║  BUILD FAILED!                                                        ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Check build.log for errors."
    echo ""
    echo "If build failed due to mirror sync issues, retry with:"
    echo "  sudo lb clean --binary && sudo lb build 2>&1 | tee build.log"
fi

echo ""
