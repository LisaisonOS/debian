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
            
            if [ -n "$WP_CALLSIGN" ]; then
                GENERATED_WALLPAPER="/tmp/generated-wallpaper.png"
                echo "Generating wallpaper..."
                
                if [ -n "$WP_TAGLINE" ]; then
                    convert "$WALLPAPER_BASE" \
                        -gravity center \
                        -font "DejaVu-Sans-Bold" \
                        -pointsize 72 \
                        -fill "rgba(255,255,255,0.95)" \
                        -annotate +0+0 "$WP_CALLSIGN" \
                        -gravity south \
                        -pointsize 28 \
                        -fill "rgba(200,200,200,0.85)" \
                        -annotate +0+38 "$WP_TAGLINE" \
                        "$GENERATED_WALLPAPER"
                else
                    convert "$WALLPAPER_BASE" \
                        -gravity center \
                        -font "DejaVu-Sans-Bold" \
                        -pointsize 72 \
                        -fill "rgba(255,255,255,0.95)" \
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
echo "║  NOTE: After entering your sudo password, the script will take       ║"
echo "║  1-2 minutes before showing any output. Please be patient!           ║"
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
echo "Creating package list..."
cat > config/package-lists/emcomm.list.chroot << 'EOF'
# Desktop Environment
task-xfce-desktop
lightdm

# Live system (CRITICAL!)
live-boot
live-config
live-config-systemd
user-setup

# Base Tools
git
curl
wget
jq
dialog
nano
sudo
build-essential
cmake
gpg
imagemagick
net-tools
default-jdk
openssh-server
screen
socat
steghide
xsel
tree
autoconf
gettext
pkg-config
meld
vim

# Dev libraries
libfltk1.3-dev
libportaudio2
libsamplerate0-dev
libsndfile1-dev
libudev-dev
portaudio19-dev

# GPS and time sync
gpsd
gpsd-clients
gpsd-tools
chrony
at

# AX.25 Packet Radio
ax25-tools
ax25-apps
expect

# Audio tools
pavucontrol
audacity
ffmpeg
sox

# GIS tools
gpsbabel
gpsbabel-gui
sqlite3
qgis

# Wikipedia offline reader
kiwix
kiwix-tools

# RF analysis
splat

# Node.js for mbtileserver serve
npm

# Build tools for VOACAP
gfortran

# BBS Server dependencies (PostgreSQL, inetd)
postgresql
postgresql-contrib
inetutils-inetd

# Wine
wine
wine64

# winetricks dependencies
cabextract
zenity
unzip
p7zip-full

# Ham Radio
js8call
wsjtx
fldigi
flrig
direwolf
libhamlib-utils
conky-std

# Bluetooth (Kenwood TH-D74/D75, BT serial, GPS, audio)
bluez
bluez-tools

# LinBPQ dependencies
ucspi-tcp
stow

# Map tools (navit and maptool - maptool is separate package!)
navit
navit-gui-gtk
navit-graphics-gtk-drawing-area
navit-gui-internal
libcanberra-gtk3-dev
maptool
espeak
osmium-tool
EOF

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

# Replace et-term with XFCE-compatible version (original uses GNOME Terminal gsettings)
echo "Replacing et-term with XFCE-compatible version..."
cat > config/includes.chroot/opt/emcomm-tools/bin/et-term << 'ETTERM'
#!/bin/bash
#
# et-term - EmComm-Tools Terminal Launcher (XFCE version)
# Replaces GNOME Terminal version for Debian/XFCE compatibility
#

# Default title
TITLE="${1:-EmComm Terminal}"

# Launch xfce4-terminal
# Note: Colors are configured via XFCE Terminal preferences, not command line
exec xfce4-terminal \
    --title="$TITLE" \
    "$@"
ETTERM
chmod +x config/includes.chroot/opt/emcomm-tools/bin/et-term

# Skip et-aircraft (not needed for now)
echo "Removing et-aircraft..."
rm -f config/includes.chroot/opt/emcomm-tools/bin/et-aircraft
rm -f config/includes.chroot/usr/share/applications/et-aircraft.desktop

# Remove et-user-* variants, keep only et-user
echo "Cleaning et-user variants..."
rm -f config/includes.chroot/opt/emcomm-tools/bin/et-user-*

# Copy .wine32 (VARA/VarAC) from selected source
echo "Copying Wine prefix from: $WINE_PREFIX_PATH"
sudo cp -a "$WINE_PREFIX_PATH" config/includes.chroot/etc/skel/.wine32

# ============================================================
# CREATE SCRIPTS DIRECTLY (more reliable than hooks)
# ============================================================
echo "Creating EmComm-Tools scripts..."
mkdir -p config/includes.chroot/opt/emcomm-tools/bin

# Create et-ft8 script
cat > config/includes.chroot/opt/emcomm-tools/bin/et-ft8 << 'ETFT8SCRIPT'
#!/bin/bash
# Author: Sylvain Deguire (VA2OPS) - Based on et-js8call by Gaston Gonzalez
. /opt/emcomm-tools/bin/et-common

usage() { echo "usage: $(basename $0) <command>"; echo "  start - Start WSJT-X"; echo "  update-config - Update config"; }
[ $# -ne 1 ] && usage && exit 1
notify_user() { notify-send -t 5000 --app-name="EmComm Tools" "$1"; }

start() {
  prime_rigctld_conn
  /opt/emcomm-tools/bin/et-kill-all && update-config && /usr/bin/wsjtx &
  [ ! -e /dev/et-gps ] && notify-send -u critical "No GPS. Ensure your time is accurate."
}

update-config() {
  WSJTX_CONF_DIR="${HOME}/.config/WSJT-X"; WSJTX_CONF_FILE="${WSJTX_CONF_DIR}/WSJT-X.ini"
  [ -z "$ET_USER_CONFIG" ] && ET_USER_CONFIG="${HOME}/.config/emcomm-tools/user.json"
  mkdir -p "${WSJTX_CONF_DIR}"
  CALLSIGN=$(cat ${ET_USER_CONFIG} | jq -r .callsign); GRID=$(et-system-info grid)
  [ "${CALLSIGN}" = "N0CALL" ] || [ -z "${CALLSIGN}" ] && notify_user "No callsign. Run: et-user." && exit 1
  [ ! -f "${WSJTX_CONF_FILE}" ] && echo -e "[General]\nMyCall=${CALLSIGN}\nMyGrid=${GRID}" > "${WSJTX_CONF_FILE}"
  grep -q "^MyCall=" "${WSJTX_CONF_FILE}" && sed -i "s|^MyCall=.*|MyCall=${CALLSIGN}|" ${WSJTX_CONF_FILE} || echo "MyCall=${CALLSIGN}" >> ${WSJTX_CONF_FILE}
  grep -q "^MyGrid=" "${WSJTX_CONF_FILE}" && sed -i "s|^MyGrid=.*|MyGrid=${GRID}|" ${WSJTX_CONF_FILE} || echo "MyGrid=${GRID}" >> ${WSJTX_CONF_FILE}
  et-log "Updated WSJT-X: ${CALLSIGN} / ${GRID}"
  if [ -e /dev/et-audio ]; then
    APLAY_OUT=$(arecord -l | grep ET_AUDIO)
    if [ $? -eq 0 ]; then
      WSJTX_AUDIO="sysdefault:CARD=ET_AUDIO"
      grep "^AudioInputDevice" ${WSJTX_CONF_FILE} >/dev/null && sed -i "s|^AudioInputDevice.*|AudioInputDevice=\"${WSJTX_AUDIO}\"|" ${WSJTX_CONF_FILE} || echo "AudioInputDevice=\"${WSJTX_AUDIO}\"" >> ${WSJTX_CONF_FILE}
      grep "^AudioOutputDevice" ${WSJTX_CONF_FILE} >/dev/null && sed -i "s|^AudioOutputDevice.*|AudioOutputDevice=\"${WSJTX_AUDIO}\"|" ${WSJTX_CONF_FILE} || echo "AudioOutputDevice=\"${WSJTX_AUDIO}\"" >> ${WSJTX_CONF_FILE}
      /opt/emcomm-tools/bin/et-audio update-config
    else
      notify_user "No ET_AUDIO detected."; exit 1
    fi
  else
    notify_user "No audio device."; exit 1
  fi
}

case $1 in start) start ;; update-config) update-config ;; *) usage; exit 1 ;; esac
ETFT8SCRIPT
chmod +x config/includes.chroot/opt/emcomm-tools/bin/et-ft8

# Create et-varac script
cat > config/includes.chroot/opt/emcomm-tools/bin/et-varac << 'ETVARACSCRIPT'
#!/bin/bash
# Author: Sylvain Deguire (VA2OPS) - Based on et-js8call by Gaston Gonzalez
. /opt/emcomm-tools/bin/et-common

[ -n "$WINEPREFIX" ] && WINE_PREFIX="$WINEPREFIX" || WINE_PREFIX="${HOME}/.wine32"
export WINEPREFIX="${WINE_PREFIX}"
VARAC_DIR="${WINE_PREFIX}/drive_c/VarAC"; VARAC_INI="${VARAC_DIR}/VarAC.ini"; VARAC_EXE="${VARAC_DIR}/VarAC.exe"
VARA_DIR="${WINE_PREFIX}/drive_c/VARA"; VARA_EXE="${VARA_DIR}/VARA.exe"

usage() { echo "usage: $(basename $0) <command>"; echo "  start - Start VarAC"; echo "  update-config - Update config"; echo "  status - Show status"; }
[ $# -ne 1 ] && usage && exit 1
notify_user() { notify-send -t 5000 --app-name="EmComm Tools" "$1"; }

check_install() {
  if [ ! -f "${VARAC_EXE}" ]; then
    et-log "VarAC not installed"; notify_user "VarAC not installed. Run: et-get-vara"
    [ -x "/opt/emcomm-tools/bin/et-get-vara" ] && read -p "Install now? [Y/n]: " r && [ -z "$r" -o "$r" = "y" -o "$r" = "Y" ] && /opt/emcomm-tools/bin/et-get-vara
    [ -f "${VARAC_EXE}" ] && return 0 || return 1
  fi
  [ ! -f "${VARA_EXE}" ] && notify_user "Warning: VARA modem not installed."
  return 0
}

show_status() {
  echo "=== VarAC/VARA Status ==="; echo "Wine: ${WINE_PREFIX}"
  [ -f "${VARAC_EXE}" ] && echo "VarAC: INSTALLED" || echo "VarAC: NOT INSTALLED"
  [ -f "${VARA_EXE}" ] && echo "VARA HF: INSTALLED" || echo "VARA HF: NOT INSTALLED"
  [ -z "$ET_USER_CONFIG" ] && ET_USER_CONFIG="${HOME}/.config/emcomm-tools/user.json"
  [ -f "${ET_USER_CONFIG}" ] && echo "Callsign: $(jq -r .callsign ${ET_USER_CONFIG} 2>/dev/null)"
}

start() {
  check_install || exit 1
  prime_rigctld_conn
  /opt/emcomm-tools/bin/et-kill-all && update-config && start_apps &
  [ ! -e /dev/et-gps ] && notify-send -u critical "No GPS."
}

start_apps() {
  [ -f "${VARA_EXE}" ] && cd "${VARA_DIR}" && wine "${VARA_EXE}" & sleep 3
  cd "${VARAC_DIR}" && wine "${VARAC_EXE}" &
}

update-config() {
  [ -z "$ET_USER_CONFIG" ] && ET_USER_CONFIG="${HOME}/.config/emcomm-tools/user.json"
  CALLSIGN=$(jq -r .callsign ${ET_USER_CONFIG} 2>/dev/null); GRID=$(et-system-info grid 2>/dev/null || jq -r .grid ${ET_USER_CONFIG} 2>/dev/null)
  [ "${CALLSIGN}" = "N0CALL" ] || [ -z "${CALLSIGN}" ] || [ "${CALLSIGN}" = "null" ] && notify_user "No callsign. Run: et-user." && exit 1
  if [ -f "${VARAC_INI}" ]; then
    cp "${VARAC_INI}" "${VARAC_INI}.bak"
    grep -qi "^Mycall=" "${VARAC_INI}" && sed -i "s|^Mycall=.*|Mycall=${CALLSIGN}|i" ${VARAC_INI} || echo "Mycall=${CALLSIGN}" >> ${VARAC_INI}
    grep -qi "^MyLocator=" "${VARAC_INI}" && sed -i "s|^MyLocator=.*|MyLocator=${GRID}|i" ${VARAC_INI} || echo "MyLocator=${GRID}" >> ${VARAC_INI}
    et-log "Updated VarAC: ${CALLSIGN} / ${GRID}"
  fi
  if [ -e /dev/et-audio ]; then
    arecord -l | grep -q ET_AUDIO && /opt/emcomm-tools/bin/et-audio update-config || { notify_user "No ET_AUDIO."; exit 1; }
  else
    notify_user "No audio device."; exit 1
  fi
}

case $1 in start) start ;; update-config) update-config ;; status) show_status ;; *) usage; exit 1 ;; esac
ETVARACSCRIPT
chmod +x config/includes.chroot/opt/emcomm-tools/bin/et-varac

# Create et-get-vara installer
cat > config/includes.chroot/opt/emcomm-tools/bin/et-get-vara << 'ETGETVARASCRIPT'
#!/bin/bash
# VARA/VarAC Installer for EmComm-Tools
[ -n "$WINEPREFIX" ] && WINE_PREFIX="$WINEPREFIX" || WINE_PREFIX="${HOME}/.wine32"
export WINEPREFIX="${WINE_PREFIX}"; export WINEARCH="win32"
DOWNLOAD_DIR="/tmp/vara-install"

check_wine() { [ ! -d "${WINE_PREFIX}" ] && WINEARCH=win32 wineboot --init && sleep 3; }
show_status() {
  echo "=== Status ==="; echo "Wine: ${WINE_PREFIX}"
  [ -f "${WINE_PREFIX}/drive_c/VARA/VARA.exe" ] && echo "VARA HF: INSTALLED" || echo "VARA HF: NOT INSTALLED"
  [ -f "${WINE_PREFIX}/drive_c/VARA FM/VARAFM.exe" ] && echo "VARA FM: INSTALLED" || echo "VARA FM: NOT INSTALLED"
  [ -f "${WINE_PREFIX}/drive_c/VarAC/VarAC.exe" ] && echo "VarAC: INSTALLED" || echo "VarAC: NOT INSTALLED"
}

install_vara_hf() {
  mkdir -p "${DOWNLOAD_DIR}"; echo ""; echo "Download VARA HF from: https://rosmodem.wordpress.com/"
  echo "Save to: ${DOWNLOAD_DIR}/"; read -p "Press Enter when done (s=skip): " r; [ "$r" = "s" ] && return 1
  local f=$(find "${DOWNLOAD_DIR}" -maxdepth 1 -iname "*VARA*.exe" ! -iname "*FM*" 2>/dev/null | head -1)
  [ -n "$f" ] && wine "$f" && return 0 || return 1
}

install_varac() {
  mkdir -p "${DOWNLOAD_DIR}"; echo ""; echo "Download VarAC from: https://www.varac-hamradio.com/download"
  echo "Save ZIP to: ${DOWNLOAD_DIR}/"; read -p "Press Enter when done (s=skip): " r; [ "$r" = "s" ] && return 1
  local f=$(find "${DOWNLOAD_DIR}" -maxdepth 1 -iname "VarAC*.zip" 2>/dev/null | head -1)
  [ -n "$f" ] && unzip -o "$f" -d "${WINE_PREFIX}/drive_c/" && return 0 || return 1
}

menu() {
  while true; do
    show_status; echo ""; echo "1) Install VARA HF"; echo "2) Install VarAC"; echo "3) Install BOTH"; echo "4) Exit"
    read -p "Choice: " c
    case $c in 1) install_vara_hf ;; 2) install_varac ;; 3) install_vara_hf; install_varac ;; 4|"") exit 0 ;; esac
  done
}

check_wine
case "${1:-}" in status) show_status ;; vara-hf) install_vara_hf ;; varac) install_varac ;; all) install_vara_hf; install_varac ;; *) menu ;; esac
ETGETVARASCRIPT
chmod +x config/includes.chroot/opt/emcomm-tools/bin/et-get-vara

# Create et-maps-setup
cat > config/includes.chroot/opt/emcomm-tools/bin/et-maps-setup << 'ETMAPSSCRIPT'
#!/bin/bash
# EmComm-Tools Map Setup - Sylvain Deguire (VA2OPS)
SCRIPT_VERSION="1.1.0"
ET_RELEASE_URL="https://github.com/thetechprepper/emcomm-tools-os-community/releases/download"
ET_RELEASE_TAG="emcomm-tools-os-community-20251128-r5-final-5.0.0"
GEOFABRIK_URL="http://download.geofabrik.de/north-america/canada"
MOUNT_POINT=""; MBTILES_DIR=""; OSM_DIR=""

check_deps() { for cmd in dialog curl maptool; do command -v $cmd &>/dev/null || { echo "Missing: $cmd"; exit 1; }; done; }

select_drive() {
  local drives=() menu=() i=1
  for d in /media/${USER}/*; do
    [ -d "$d" ] && mountpoint -q "$d" 2>/dev/null && drives+=("$d") && menu+=("$i" "$(basename $d) ($(df -h "$d" | tail -1 | awk '{print $4}'))") && ((i++))
  done
  [ ${#drives[@]} -eq 0 ] && dialog --msgbox "No drives found in /media/${USER}/" 8 40 && clear && return 1
  local c=$(dialog --title "Select Drive" --menu "Choose:" 15 50 ${#drives[@]} "${menu[@]}" 2>&1 >/dev/tty); clear
  [ -z "$c" ] && return 1
  MOUNT_POINT="${drives[$((c-1))]}"; MBTILES_DIR="${MOUNT_POINT}/mbtiles"; OSM_DIR="${MOUNT_POINT}/osm-pbf"
}

setup_dirs() { mkdir -p "${MBTILES_DIR}" "${OSM_DIR}" "${MOUNT_POINT}/wikipedia"; echo "Directories created."; }

download_mbtiles() {
  [ -z "$MOUNT_POINT" ] && dialog --msgbox "Select drive first" 8 40 && clear && return
  for m in "osm-us-zoom0to11-20251120.mbtiles:US Map" "osm-ca-zoom0to10-20251120.mbtiles:Canada Map"; do
    fn="${m%%:*}"; desc="${m#*:}"
    dialog --yesno "Download ${desc}?\n(~2GB)" 8 40 && { clear; echo "Downloading ${desc}..."; curl -L -f --progress-bar -o "${MBTILES_DIR}/${fn}" "${ET_RELEASE_URL}/${ET_RELEASE_TAG}/${fn}"; } || clear
  done
}

download_osm() {
  [ -z "$MOUNT_POINT" ] && dialog --msgbox "Select drive first" 8 40 && clear && return
  local html="/tmp/gf.html"
  curl -s -L -o "$html" "${GEOFABRIK_URL}.html" || { echo "Failed to fetch list"; return; }
  local menu=()
  while IFS= read -r line; do
    local pf=$(echo "$line" | sed -n 's/.*href="\([^"]*-latest\.osm\.pbf\)".*/\1/p')
    [ -n "$pf" ] && [ "$pf" != "canada-latest.osm.pbf" ] && menu+=("${pf%-latest.osm.pbf}" "" off)
  done < <(grep '\.osm\.pbf"' "$html")
  local sel=$(dialog --title "OSM Canada" --checklist "Select provinces:" 20 55 12 "${menu[@]}" 2>&1 >/dev/tty); clear
  [ -z "$sel" ] && return
  for p in $sel; do
    p=$(echo "$p" | tr -d '"'); local df="${p}-latest.osm.pbf"
    echo "Downloading ${df}..."
    curl -L -f --progress-bar -o "${OSM_DIR}/${df}" "${GEOFABRIK_URL}/${df}"
    [ -f "${OSM_DIR}/${df}" ] && { echo "Converting..."; mkdir -p "${HOME}/.navit/maps"; maptool --protobuf -i "${OSM_DIR}/${df}" "${HOME}/.navit/maps/${p}.bin"; }
  done
  rm -f "$html"; read -p "Done. Press Enter..."
}

setup_symlinks() {
  [ -z "$MOUNT_POINT" ] && return
  mkdir -p "${HOME}/.local/share/emcomm-tools/mbtileserver"
  ln -sf "${MBTILES_DIR}" "${HOME}/.local/share/emcomm-tools/mbtileserver/tilesets"
  ln -sf "${MOUNT_POINT}/wikipedia" "${HOME}/wikipedia"
  echo "Symlinks created."
}

main_menu() {
  while true; do
    local ds="${MOUNT_POINT:+$(basename $MOUNT_POINT)}"
    local c=$(dialog --title "Map Setup v${SCRIPT_VERSION}" --menu "Drive: ${ds:-NONE}" 15 50 6 \
      1 "Select Drive" 2 "Setup Directories" 3 "Download MBTiles" 4 "Download OSM" 5 "Setup Symlinks" 6 "Exit" 2>&1 >/dev/tty); clear
    case $c in 1) select_drive ;; 2) [ -n "$MOUNT_POINT" ] && setup_dirs ;; 3) download_mbtiles ;; 4) download_osm ;; 5) [ -n "$MOUNT_POINT" ] && setup_symlinks ;; 6|"") break ;; esac
  done
}

check_deps; main_menu
ETMAPSSCRIPT
chmod +x config/includes.chroot/opt/emcomm-tools/bin/et-maps-setup

# Create et-first-boot wizard script
echo "Creating et-first-boot wizard..."
cat > config/includes.chroot/opt/emcomm-tools/bin/et-first-boot << 'ETFIRSTBOOTSCRIPT'
#!/bin/bash
#
# Author : Sylvain Deguire (VA2OPS)
# Date   : January 2026
# Purpose: EmComm-Tools First Boot Configuration Wizard
#          Runs on first boot to configure user, radio, and maps
#
# This is a temporary CLI solution until a GUI app is developed.
#

FLAG_FILE="${HOME}/.config/emcomm-tools/.first-boot-done"
USER_CONF="${HOME}/.config/emcomm-tools/user.json"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Check if already configured
if [ -f "${FLAG_FILE}" ]; then
    exit 0
fi

# Ensure config directory exists
mkdir -p "$(dirname ${FLAG_FILE})"
mkdir -p "$(dirname ${USER_CONF})"

# Copy default user config if not exists
if [ ! -f "${USER_CONF}" ]; then
    cp /etc/skel/.config/emcomm-tools/user.json "${USER_CONF}" 2>/dev/null || \
    echo '{"language":"en","callsign":"N0CALL","grid":"AA00aa","winlinkPasswd":null}' > "${USER_CONF}"
fi

clear

# =============================================================================
# Welcome Screen
# =============================================================================
echo ""
echo -e "${GREEN}${BOLD}============================================================${NC}"
echo -e "${GREEN}${BOLD}       EmComm-Tools OS - Initial Configuration${NC}"
echo -e "${GREEN}${BOLD}============================================================${NC}"
echo ""
echo "  Welcome! This wizard will help you configure:"
echo ""
echo "    1. User Settings (callsign, grid, Winlink password)"
echo "    2. Radio Configuration (select your transceiver)"
echo "    3. Offline Maps (optional - requires USB drive)"
echo ""
echo -e "${YELLOW}Bienvenue! Cet assistant vous aidera à configurer EmComm-Tools.${NC}"
echo ""
read -p "Press Enter to begin / Appuyez sur Entrée pour commencer... "

# =============================================================================
# Step 1: User Configuration
# =============================================================================
clear
echo ""
echo -e "${GREEN}${BOLD}=== STEP 1/3: User Configuration ===${NC}"
echo -e "${GREEN}${BOLD}=== Configuration utilisateur ===${NC}"
echo ""

if [ -x /opt/emcomm-tools/bin/et-user ]; then
    /opt/emcomm-tools/bin/et-user
else
    echo "Warning: et-user not found, skipping..."
    sleep 2
fi

echo ""
read -p "Press Enter to continue to Radio Configuration... "

# =============================================================================
# Step 2: Radio Configuration
# =============================================================================
clear
echo ""
echo -e "${GREEN}${BOLD}=== STEP 2/3: Radio Configuration ===${NC}"
echo -e "${GREEN}${BOLD}=== Configuration radio ===${NC}"
echo ""

if [ -x /opt/emcomm-tools/bin/et-radio ]; then
    /opt/emcomm-tools/bin/et-radio
else
    echo "Warning: et-radio not found, skipping..."
    sleep 2
fi

echo ""
read -p "Press Enter to continue to Maps Setup... "

# =============================================================================
# Step 3: External Maps Setup
# =============================================================================
clear
echo ""
echo -e "${GREEN}${BOLD}=== STEP 3/3: Offline Maps Setup ===${NC}"
echo -e "${GREEN}${BOLD}=== Configuration des cartes ===${NC}"
echo ""
echo "This step configures offline maps stored on an external USB drive."
echo "Cette étape configure les cartes hors-ligne sur une clé USB externe."
echo ""
echo -e "${YELLOW}Note: You can skip this step and run it later with 'et-maps-setup'${NC}"
echo -e "${YELLOW}Note: Vous pouvez passer cette étape et l'exécuter plus tard${NC}"
echo ""
read -p "Configure maps now? / Configurer les cartes maintenant? (y/n): " maps_choice

if [ "${maps_choice,,}" == "y" ] || [ "${maps_choice,,}" == "o" ]; then
    if [ -x /opt/emcomm-tools/bin/et-maps-setup ]; then
        /opt/emcomm-tools/bin/et-maps-setup
    else
        echo "Warning: et-maps-setup not found, skipping..."
        sleep 2
    fi
fi

# =============================================================================
# Completion Screen
# =============================================================================
clear
echo ""
echo -e "${GREEN}${BOLD}============================================================${NC}"
echo -e "${GREEN}${BOLD}          Configuration Complete! / Terminé!${NC}"
echo -e "${GREEN}${BOLD}============================================================${NC}"
echo ""
echo -e "${YELLOW}To modify your settings later, use these commands:${NC}"
echo -e "${YELLOW}Pour modifier vos paramètres plus tard, utilisez:${NC}"
echo ""
echo -e "  ${CYAN}et-user${NC}        - Change callsign, grid, Winlink password"
echo -e "                   Changer indicatif, grille, mot de passe Winlink"
echo ""
echo -e "  ${CYAN}et-radio${NC}       - Change radio/transceiver selection"
echo -e "                   Changer la sélection de radio"
echo ""
echo -e "  ${CYAN}et-maps-setup${NC}  - Download and configure offline maps"
echo -e "                   Télécharger et configurer les cartes hors-ligne"
echo ""
echo -e "  ${CYAN}et-mode${NC}        - Select operating mode (JS8Call, VarAC, etc.)"
echo -e "                   Sélectionner le mode d'opération"
echo ""
echo "73 de VA2OPS!"
echo ""

# Create flag file to prevent running again
touch "${FLAG_FILE}"

read -p "Press Enter to close this wizard... "
ETFIRSTBOOTSCRIPT
chmod +x config/includes.chroot/opt/emcomm-tools/bin/et-first-boot

# Create autostart entry for first-boot wizard
echo "Creating first-boot autostart entry..."
mkdir -p config/includes.chroot/etc/xdg/autostart
cat > config/includes.chroot/etc/xdg/autostart/et-first-boot.desktop << 'ETFIRSTBOOTDESKTOP'
[Desktop Entry]
Type=Application
Name=EmComm-Tools First Boot Setup
Name[fr]=Configuration initiale EmComm-Tools
Comment=Initial configuration wizard for EmComm-Tools
Comment[fr]=Assistant de configuration initiale pour EmComm-Tools
Exec=xfce4-terminal --title="EmComm-Tools Setup" --geometry=80x30 --command="/opt/emcomm-tools/bin/et-first-boot"
Icon=preferences-system
Terminal=false
Categories=System;Settings;
StartupNotify=false
X-GNOME-Autostart-enabled=true
ETFIRSTBOOTDESKTOP

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

# Hook: et-data group + permissions
cat > config/hooks/live/0050-create-etgroup.hook.chroot << 'EOF'
#!/bin/bash
groupadd -g 1981 et-data || true

# Fix permissions for et-tools config
chown -R root:et-data /opt/emcomm-tools/conf
chmod -R 775 /opt/emcomm-tools/conf

# Fix permissions for et-tools bin scripts
chmod +x /opt/emcomm-tools/bin/*

# Make sure et-maps-setup is executable and in PATH
chmod 755 /opt/emcomm-tools/bin/et-maps-setup 2>/dev/null || true
chmod 755 /opt/emcomm-tools/bin/et-data-symlinks 2>/dev/null || true
chmod 755 /opt/emcomm-tools/bin/et-first-boot 2>/dev/null || true
ln -sf /opt/emcomm-tools/bin/et-maps-setup /usr/local/bin/et-maps-setup
ln -sf /opt/emcomm-tools/bin/et-first-boot /usr/local/bin/et-first-boot

# Copy WSJT-X icon to pixmaps (installed by wsjtx package)
WSJTX_ICON=$(find /usr/share -name "*wsjtx*.png" -o -name "*wsjt*.png" 2>/dev/null | head -1)
if [ -n "$WSJTX_ICON" ]; then
    cp "$WSJTX_ICON" /usr/share/pixmaps/wsjtx_icon.png
    echo "WSJT-X icon copied to pixmaps"
fi

# Copy JS8Call icon if not already in pixmaps
JS8_ICON=$(find /usr/share -name "*js8call*.png" 2>/dev/null | grep -v pixmaps | head -1)
if [ -n "$JS8_ICON" ] && [ ! -f /usr/share/pixmaps/js8call_icon.png ]; then
    cp "$JS8_ICON" /usr/share/pixmaps/js8call_icon.png
    echo "JS8Call icon copied to pixmaps"
fi
EOF
chmod +x config/hooks/live/0050-create-etgroup.hook.chroot

# Hook: Wine 32-bit + winetricks + LinBPQ 32-bit deps
cat > config/hooks/live/0100-enable-i386.hook.chroot << 'EOF'
#!/bin/bash
dpkg --add-architecture i386
apt-get update
apt-get install -y wine32

# LinBPQ 32-bit dependencies
apt-get install -y \
  libpcap0.8-dev:i386 \
  libasound2-dev:i386 \
  zlib1g:i386

curl -o /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
chmod +x /usr/local/bin/winetricks
EOF
chmod +x config/hooks/live/0100-enable-i386.hook.chroot

# Hook: Download and install LinBPQ
cat > config/hooks/live/0150-install-linbpq.hook.chroot << 'EOF'
#!/bin/bash
echo "Installing LinBPQ..."

BBS_HOME="/etc/skel/.local/share/emcomm-tools/bbs-server"
BBS_HOME_FILES="${BBS_HOME}/Files"
INSTALL_DIR="/opt/linbpq-latest"
INSTALL_BIN_DIR="${INSTALL_DIR}/bin"
LINK_PATH="/opt/linbpq"

# Create directories
mkdir -p ${BBS_HOME_FILES}
mkdir -p ${INSTALL_BIN_DIR}

# Download HTML web interface
echo "Downloading LinBPQ web interface..."
cd ${BBS_HOME}
curl -L -o HTMLPages.zip "http://www.cantab.net/users/john.wiseman/Downloads/Beta/HTMLPages.zip"
unzip -o HTMLPages.zip
rm -f HTMLPages.zip

# Download LinBPQ binary
echo "Downloading LinBPQ binary..."
curl -L -o ${INSTALL_BIN_DIR}/linbpq "https://www.cantab.net/users/john.wiseman/Downloads/linbpq"
chmod 755 ${INSTALL_BIN_DIR}/linbpq

# Create symlink
[ -e ${LINK_PATH} ] && rm ${LINK_PATH}
ln -s ${INSTALL_DIR} ${LINK_PATH}

# Stow it to /usr/local
stow -v -d /opt linbpq -t /usr/local

echo "LinBPQ installation complete"
EOF
chmod +x config/hooks/live/0150-install-linbpq.hook.chroot

# Hook: Download and install Pat Winlink
cat > config/hooks/live/0160-install-pat.hook.chroot << 'EOF'
#!/bin/bash
echo "Installing Pat Winlink client..."

PAT_VERSION="0.16.0"
PAT_DEB="pat_${PAT_VERSION}_linux_amd64.deb"
PAT_URL="https://github.com/la5nta/pat/releases/download/v${PAT_VERSION}/${PAT_DEB}"

cd /tmp
curl -L -f -o ${PAT_DEB} ${PAT_URL}
dpkg -i ${PAT_DEB} || apt-get install -f -y
rm -f ${PAT_DEB}

echo "Pat Winlink installation complete"
EOF
chmod +x config/hooks/live/0160-install-pat.hook.chroot

# Hook: Install ARDOP modem
cat > config/hooks/live/0165-install-ardop.hook.chroot << 'EOF'
#!/bin/bash
echo "Installing ARDOP modem..."

VERSION="1.0.4.1.3"
BIN_FILE="ardopcf"
DOWNLOAD_FILE="ardopcf_amd64_Linux_64"
INSTALL_DIR="/opt/ardop-${VERSION}"
INSTALL_BIN_DIR="${INSTALL_DIR}/bin"
LINK_PATH="/opt/ardop"

mkdir -p ${INSTALL_BIN_DIR}

URL="https://github.com/pflarue/ardop/releases/download/${VERSION}/${DOWNLOAD_FILE}"
echo "Downloading ARDOP from ${URL}..."
curl -s -L -o ${INSTALL_BIN_DIR}/${BIN_FILE} --fail ${URL}
chmod 755 ${INSTALL_BIN_DIR}/${BIN_FILE}

[ -e ${LINK_PATH} ] && rm ${LINK_PATH}
ln -s ${INSTALL_DIR} ${LINK_PATH}

stow -v -d /opt ardop -t /usr/local

echo "ARDOP installation complete"
EOF
chmod +x config/hooks/live/0165-install-ardop.hook.chroot

# Hook: Install YAAC (APRS client)
cat > config/hooks/live/0170-install-yaac.hook.chroot << 'EOF'
#!/bin/bash
echo "Installing YAAC..."

VERSION="latest"
ZIP_FILE="YAAC.zip"
INSTALL_DIR="/opt/yaac-${VERSION}"
LINK_PATH="/opt/yaac"

URL="https://www.ka2ddo.org/ka2ddo/${ZIP_FILE}"
echo "Downloading YAAC from ${URL}..."
curl -s -L -o /tmp/${ZIP_FILE} --fail ${URL}

mkdir -p ${INSTALL_DIR}
cd ${INSTALL_DIR}
unzip /tmp/${ZIP_FILE}
rm -f /tmp/${ZIP_FILE}

[ -e ${LINK_PATH} ] && rm ${LINK_PATH}
ln -s ${INSTALL_DIR} ${LINK_PATH}

echo "YAAC installation complete"
EOF
chmod +x config/hooks/live/0170-install-yaac.hook.chroot

# Hook: Install udev rules and disable brltty
cat > config/hooks/live/0175-install-udev.hook.chroot << 'EOF'
#!/bin/bash
echo "Installing udev rules..."

# Reload udev rules (overlay files already copied)
udevadm control --reload || true

echo "Disabling brltty (interferes with serial ports)..."
systemctl mask brltty-udev.service || true
systemctl mask brltty.service || true

echo "udev configuration complete"
EOF
chmod +x config/hooks/live/0175-install-udev.hook.chroot

# Hook: Install VOACAP (HF propagation prediction)
cat > config/hooks/live/0180-install-voacap.hook.chroot << 'EOF'
#!/bin/bash
echo "Installing VOACAP..."

apt-get install -y gfortran

APP="voacapl"
VERSION="0.7.6"
REPO="https://github.com/thetechprepper/voacapl"
SRC_DIR="/opt/src"
REPO_SRC_DIR="${SRC_DIR}/${APP}"
INSTALL_DIR="/opt/${APP}-${VERSION}"
LINK_PATH="/opt/${APP}"

mkdir -p ${SRC_DIR}
cd ${SRC_DIR}

if [ ! -e ${REPO_SRC_DIR} ]; then
    git clone ${REPO}
fi

cd ${REPO_SRC_DIR}
autoreconf -f -i
./configure --prefix=${INSTALL_DIR}
make && make install

# Patch prefix location
sed -i 's|__PREFIX__|/opt/voacapl-0.7.6|' makeitshfbc

# Create itshfbc data
[ -e /root/itshfbc ] && rm -rf /root/itshfbc
./makeitshfbc
mv /root/itshfbc /etc/skel/

[ -e ${LINK_PATH} ] && rm ${LINK_PATH}
ln -s ${INSTALL_DIR} ${LINK_PATH}

stow -v -d /opt ${APP} -t /usr/local

echo "VOACAP installation complete"
EOF
chmod +x config/hooks/live/0180-install-voacap.hook.chroot

# Hook: Install mbtileserver
cat > config/hooks/live/0185-install-mbtileserver.hook.chroot << 'EOF'
#!/bin/bash
echo "Installing mbtileserver..."

APP="mbtileserver"
VERSION="0.11.0"
TARBALL="mbtileserver_${VERSION}_linux_amd64.tar.gz"
INSTALL_DIR="/opt/${APP}-${VERSION}"
INSTALL_BIN_DIR="${INSTALL_DIR}/bin"
LINK_PATH="/opt/${APP}"

URL="https://github.com/consbio/mbtileserver/releases/download/v${VERSION}/${TARBALL}"

mkdir -p ${INSTALL_BIN_DIR}
cd /tmp
curl -s -L -o ${TARBALL} --fail ${URL}
tar -xzf ${TARBALL}
mv mbtileserver ${INSTALL_BIN_DIR}/
rm -f ${TARBALL}

[ -e ${LINK_PATH} ] && rm ${LINK_PATH}
ln -s ${INSTALL_DIR} ${LINK_PATH}

stow -v -d /opt ${APP} -t /usr/local

echo "mbtileserver installation complete"
EOF
chmod +x config/hooks/live/0185-install-mbtileserver.hook.chroot

# Hook: Install QtTermTCP (BBS terminal)
cat > config/hooks/live/0186-install-qttermtcp.hook.chroot << 'EOF'
#!/bin/bash
echo "Installing QtTermTCP..."

VERSION="latest"
BIN_FILE="QtTermTCP"
INSTALL_DIR="/opt/qttermtcp-${VERSION}"
INSTALL_BIN_DIR="${INSTALL_DIR}/bin"
LINK_PATH="/opt/qttermtcp"

# QtTermTCP needs 32-bit Qt libs
apt-get install -y libqt5core5t64 libqt5gui5t64 libqt5widgets5t64 libqt5network5t64 libqt5serialport5

URL="https://www.cantab.net/users/john.wiseman/Downloads/${BIN_FILE}"

mkdir -p ${INSTALL_BIN_DIR}
curl -s -L -o ${INSTALL_BIN_DIR}/${BIN_FILE} --fail ${URL}
chmod 755 ${INSTALL_BIN_DIR}/${BIN_FILE}

[ -e ${LINK_PATH} ] && rm ${LINK_PATH}
ln -s ${INSTALL_DIR} ${LINK_PATH}

stow -v -d /opt qttermtcp -t /usr/local

echo "QtTermTCP installation complete"
EOF
chmod +x config/hooks/live/0186-install-qttermtcp.hook.chroot

# Hook: Install Chattervox
cat > config/hooks/live/0187-install-chattervox.hook.chroot << 'EOF'
#!/bin/bash
echo "Installing Chattervox..."

VERSION="0.5.0"
APP="chattervox"
TARBALL="${APP}-${VERSION}-linux-x64.tar.gz"
INSTALL_DIR="/opt/${APP}-${VERSION}"
LINK_PATH="/opt/${APP}"

URL="https://github.com/brannondorsey/chattervox/releases/download/v${VERSION}/${TARBALL}"

mkdir -p /opt
cd /opt
curl -s -L -o ${TARBALL} --fail ${URL}
tar -xzf ${TARBALL}
mv chattervox-${VERSION}-linux-x64 ${INSTALL_DIR}
rm -f ${TARBALL}

[ -e ${LINK_PATH} ] && rm ${LINK_PATH}
ln -s ${INSTALL_DIR} ${LINK_PATH}

# Create symlink in /usr/local/bin
ln -sf ${INSTALL_DIR}/chattervox /usr/local/bin/chattervox

echo "Chattervox installation complete"
EOF
chmod +x config/hooks/live/0187-install-chattervox.hook.chroot

# Hook: Install Paracon BBS client
cat > config/hooks/live/0188-install-paracon.hook.chroot << 'EOF'
#!/bin/bash
echo "Installing Paracon BBS client..."

VERSION="latest"
APP="paracon"
PYZ_FILE="paracon.pyz"
INSTALL_DIR="/opt/${APP}-${VERSION}"
INSTALL_BIN_DIR="${INSTALL_DIR}/bin"
LINK_PATH="/opt/${APP}"

URL="https://github.com/bpqpkt/paracon/releases/latest/download/${PYZ_FILE}"

mkdir -p ${INSTALL_BIN_DIR}
curl -s -L -o ${INSTALL_BIN_DIR}/${PYZ_FILE} --fail ${URL}
chmod 755 ${INSTALL_BIN_DIR}/${PYZ_FILE}

# Create wrapper script
cat > ${INSTALL_BIN_DIR}/paracon << 'WRAPPER'
#!/bin/bash
python3 /opt/paracon/bin/paracon.pyz "$@"
WRAPPER
chmod 755 ${INSTALL_BIN_DIR}/paracon

[ -e ${LINK_PATH} ] && rm ${LINK_PATH}
ln -s ${INSTALL_DIR} ${LINK_PATH}

stow -v -d /opt paracon -t /usr/local

echo "Paracon installation complete"
EOF
chmod +x config/hooks/live/0188-install-paracon.hook.chroot

# Hook: Install ET-Predict (propagation GUI)
cat > config/hooks/live/0189-install-et-predict.hook.chroot << 'EOF'
#!/bin/bash
echo "Installing ET-Predict..."

VERSION="1.2.0"
APP="et-predict-app"
JAR_FILE="${APP}.jar"
INSTALL_DIR="/opt/${APP}-${VERSION}"
LINK_PATH="/opt/${APP}"

URL="https://github.com/thetechprepper/et-predict-app/releases/download/v${VERSION}/${JAR_FILE}"

mkdir -p ${INSTALL_DIR}
curl -s -L -o ${INSTALL_DIR}/${JAR_FILE} --fail ${URL}

[ -e ${LINK_PATH} ] && rm ${LINK_PATH}
ln -s ${INSTALL_DIR} ${LINK_PATH}

echo "ET-Predict installation complete"
EOF
chmod +x config/hooks/live/0189-install-et-predict.hook.chroot

# Hook: Configure GPS and AX.25 permissions
cat > config/hooks/live/0190-configure-services.hook.chroot << 'EOF'
#!/bin/bash
echo "Configuring services..."

# Disable GPS auto-start (user will enable when needed)
systemctl disable gpsd || true

# Update AX.25 port permissions
if [ -f /etc/ax25/axports ]; then
    chgrp et-data /etc/ax25/axports
    chmod 664 /etc/ax25/axports
fi

# Ensure maptool is in PATH (from navit package)
if [ -f /usr/bin/maptool ]; then
    echo "maptool found at /usr/bin/maptool"
elif [ -f /usr/share/navit/maptool ]; then
    ln -sf /usr/share/navit/maptool /usr/local/bin/maptool
    echo "Created maptool symlink"
fi

# Find maptool wherever it might be
MAPTOOL=$(find /usr -name "maptool" -type f 2>/dev/null | head -1)
if [ -n "$MAPTOOL" ] && [ ! -f /usr/local/bin/maptool ]; then
    ln -sf "$MAPTOOL" /usr/local/bin/maptool
    echo "Created maptool symlink from $MAPTOOL"
fi

echo "Services configured"
EOF
chmod +x config/hooks/live/0190-configure-services.hook.chroot

# Hook: Install QGIS PlaceMarker plugin + npm serve
cat > config/hooks/live/0191-install-qgis-plugin.hook.chroot << 'EOF'
#!/bin/bash
echo "Installing QGIS PlaceMarker plugin..."

PLUGIN_URL="https://plugins.qgis.org/plugins/PlaceMarker/version/1.3.0/download/"
PLUGIN_DIR="/etc/skel/.local/share/QGIS/QGIS3/profiles/default/python/plugins"

mkdir -p "$PLUGIN_DIR"
curl -s -L -o /tmp/PlaceMarker.zip "$PLUGIN_URL"
unzip -o /tmp/PlaceMarker.zip -d "$PLUGIN_DIR"
rm /tmp/PlaceMarker.zip

echo "Installing npm serve for qgis-web-app..."
npm install -g serve || true

echo "QGIS plugin installation complete"
EOF
chmod +x config/hooks/live/0191-install-qgis-plugin.hook.chroot

# Hook: Configure PostgreSQL for BBS server
cat > config/hooks/live/0192-configure-postgres.hook.chroot << 'EOF'
#!/bin/bash
echo "Configuring PostgreSQL for EmComm-Tools..."

# Fix PostgreSQL port to 5432 (default)
sed -i 's/^port = 5433/port = 5432/' /etc/postgresql/*/main/postgresql.conf 2>/dev/null || true

# Enable services
systemctl enable postgresql || true
systemctl enable inetutils-inetd || true

# Create init script for first boot
cat > /opt/emcomm-tools/bin/init-postgres.sh << 'INITPG'
#!/bin/bash
# First-boot PostgreSQL initialization
until sudo -u postgres pg_isready; do
    sleep 1
done
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = 'emcomm'" | grep -q 1 || \
    sudo -u postgres createdb emcomm
echo "PostgreSQL initialized for EmComm-Tools"
INITPG
chmod +x /opt/emcomm-tools/bin/init-postgres.sh

# Create systemd oneshot service for first-boot initialization
cat > /etc/systemd/system/emcomm-postgres-init.service << 'PGSVC'
[Unit]
Description=EmComm-Tools PostgreSQL Initialization
After=postgresql.service
Requires=postgresql.service
ConditionPathExists=!/var/lib/emcomm-tools/.postgres-initialized

[Service]
Type=oneshot
ExecStart=/opt/emcomm-tools/bin/init-postgres.sh
ExecStartPost=/bin/mkdir -p /var/lib/emcomm-tools
ExecStartPost=/bin/touch /var/lib/emcomm-tools/.postgres-initialized
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
PGSVC

systemctl enable emcomm-postgres-init.service || true

echo "PostgreSQL configuration complete"
EOF
chmod +x config/hooks/live/0192-configure-postgres.hook.chroot


# Note: et-ft8, et-varac, et-get-vara, et-maps-setup are created directly in includes.chroot above

# Hook: Install ET-API (callsign lookup)
cat > config/hooks/live/0193-install-et-api.hook.chroot << 'EOF'
#!/bin/bash
echo "Installing ET-API (callsign lookup)..."

APP="et-api"
VERSION="1.1.1"
ET_API_JAR="emcomm-tools-api-${VERSION}.jar"
BASE_URL="https://github.com/thetechprepper/et-api-java/releases/download/${VERSION}"

INSTALL_DIR="/opt/emcomm-tools-api"
BIN_DIR="${INSTALL_DIR}/bin"
DATA_DIR="${INSTALL_DIR}/data"
INDEX_DIR="${INSTALL_DIR}/index"

mkdir -p "${BIN_DIR}" "${DATA_DIR}" "${INDEX_DIR}"

# Download et-api JAR
echo "Downloading ET-API JAR..."
curl -s -L -o "${BIN_DIR}/${APP}" "${BASE_URL}/${ET_API_JAR}"
chmod 755 "${BIN_DIR}/${APP}"

# Download data files
for file in faa.csv license.csv zip2geo.csv zip2geo-elevation.csv; do
    echo "Downloading ${file}..."
    curl -s -L -o "${DATA_DIR}/${file}" "${BASE_URL}/${file}"
done

# Fix permissions
chgrp -R et-data ${DATA_DIR} ${INDEX_DIR}
chmod 775 ${DATA_DIR} ${INDEX_DIR}
chmod 664 ${DATA_DIR}/*.csv

echo "ET-API installation complete"
EOF
chmod +x config/hooks/live/0193-install-et-api.hook.chroot

# Hook: CREATE THE USER (THIS WAS MISSING!)
cat > config/hooks/live/0200-create-user.hook.chroot << 'EOF'
#!/bin/bash
echo "Creating live user account..."

# Create user with all necessary groups
useradd -m -s /bin/bash -G sudo,cdrom,floppy,audio,video,plugdev,users,dialout,netdev,bluetooth,et-data user

# Set password to "live"
echo "user:live" | chpasswd

# Allow sudo without password for live session
echo "user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/user-nopasswd
chmod 440 /etc/sudoers.d/user-nopasswd

echo "User 'user' created with password 'live'"
EOF
chmod +x config/hooks/live/0200-create-user.hook.chroot

# Hook: Configure LightDM autologin
cat > config/hooks/live/0300-configure-autologin.hook.chroot << 'EOF'
#!/bin/bash
echo "Configuring LightDM autologin..."

mkdir -p /etc/lightdm/lightdm.conf.d

cat > /etc/lightdm/lightdm.conf.d/50-autologin.conf << 'LIGHTDM'
[Seat:*]
autologin-user=user
autologin-user-timeout=0
user-session=xfce
autologin-session=xfce
LIGHTDM

echo "LightDM autologin configured for user 'user'"
EOF
chmod +x config/hooks/live/0300-configure-autologin.hook.chroot

# Fix /etc/environment (no variables, no snap)
echo "Fixing /etc/environment..."
cat > config/includes.chroot/etc/environment << 'EOF'
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/emcomm-tools/bin"
ET_HOME="/opt/emcomm-tools"
EOF

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

# Thunar (file manager) launcher
cat > config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-4/thunar.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=File Manager
Comment=Browse the file system
Exec=thunar
Icon=org.xfce.thunar
Terminal=false
Categories=System;FileManager;
EOF

# Terminal launcher - directly call xfce4-terminal, not et-term
cat > config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-5/xfce4-terminal.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Terminal
Comment=Terminal Emulator
Exec=xfce4-terminal
Icon=org.xfce.terminalemulator
Terminal=false
Categories=System;TerminalEmulator;
EOF

# VarAC launcher (uses et-varac script for config injection)
cat > config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-20/varac.desktop << 'EOF'
[Desktop Entry]
Name=VarAC
Comment=VarAC Chat Client
Exec=/opt/emcomm-tools/bin/et-varac start
Icon=/usr/share/pixmaps/varac.png
Terminal=false
Type=Application
Categories=HamRadio;
EOF

# JS8Call launcher (uses et-js8call script, not direct launch!)
cat > config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-21/js8call.desktop << 'EOF'
[Desktop Entry]
Name=JS8Call
Comment=JS8Call Digital Mode
Exec=/opt/emcomm-tools/bin/et-js8call start
Icon=/usr/share/pixmaps/js8call_icon.png
Terminal=false
Type=Application
Categories=HamRadio;
EOF

# fldigi launcher (uses et-fldigi script if available)
cat > config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-22/fldigi.desktop << 'EOF'
[Desktop Entry]
Name=fldigi
Comment=fldigi Digital Modes
Exec=/opt/emcomm-tools/bin/et-fldigi start
Icon=fldigi
Terminal=false
Type=Application
Categories=HamRadio;
EOF

# FT8/WSJT-X launcher (uses et-ft8 script)
cat > config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-23/wsjtx.desktop << 'EOF'
[Desktop Entry]
Name=FT8 (WSJT-X)
Comment=WSJT-X for FT8/FT4 - Check propagation
Exec=/opt/emcomm-tools/bin/et-ft8 start
Icon=/usr/share/pixmaps/wsjtx_icon.png
Terminal=false
Type=Application
Categories=HamRadio;
EOF

# Navit launcher (GPS navigation)
cat > config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-24/navit.desktop << 'EOF'
[Desktop Entry]
Name=Navit
Name[fr]=Navigation GPS
Comment=Offline GPS Navigation
Comment[fr]=Navigation GPS hors-ligne
Exec=navit
Icon=navit
Terminal=false
Type=Application
Categories=Navigation;
EOF

# XFCE panel config to add the launchers
mkdir -p config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml

# XFCE desktop wallpaper config (covers multiple monitor names)
cat > config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/wallpaper.png"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
      <property name="monitorVirtual-1" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/wallpaper.png"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
      <property name="monitoreDP-1" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/wallpaper.png"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
      <property name="monitorDP-1" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/wallpaper.png"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
      <property name="monitorHDMI-1" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/wallpaper.png"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
      <property name="monitorLVDS-1" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/wallpaper.png"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
      <property name="monitorVGA-1" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/wallpaper.png"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
    </property>
  </property>
</channel>
EOF

cat > config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=10;x=512;y=750"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="51"/>
      <property name="nrows" type="uint" value="1"/>
      <property name="length-adjust" type="bool" value="true"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
        <value type="int" value="20"/>
        <value type="int" value="21"/>
        <value type="int" value="23"/>
        <value type="int" value="22"/>
        <value type="int" value="24"/>
        <value type="int" value="6"/>
        <value type="int" value="7"/>
        <value type="int" value="8"/>
        <value type="int" value="9"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="applicationsmenu"/>
    <property name="plugin-2" type="string" value="tasklist"/>
    <property name="plugin-3" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
    </property>
    <property name="plugin-4" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="thunar.desktop"/>
      </property>
    </property>
    <property name="plugin-5" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="xfce4-terminal.desktop"/>
      </property>
    </property>
    <property name="plugin-20" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="varac.desktop"/>
      </property>
    </property>
    <property name="plugin-21" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="js8call.desktop"/>
      </property>
    </property>
    <property name="plugin-23" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="wsjtx.desktop"/>
      </property>
    </property>
    <property name="plugin-22" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="fldigi.desktop"/>
      </property>
    </property>
    <property name="plugin-24" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="navit.desktop"/>
      </property>
    </property>
    <property name="plugin-6" type="string" value="separator"/>
    <property name="plugin-7" type="string" value="systray"/>
    <property name="plugin-8" type="string" value="clock"/>
    <property name="plugin-9" type="string" value="actions"/>
  </property>
</channel>
EOF

# XFCE Display settings (1680x1050 default)
cat > config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/displays.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="displays" version="1.0">
  <property name="Default" type="empty">
    <property name="LVDS-1" type="string" value="LVDS-1">
      <property name="Resolution" type="string" value="1680x1050"/>
      <property name="RefreshRate" type="double" value="60.000000"/>
      <property name="Rotation" type="int" value="0"/>
      <property name="Primary" type="bool" value="true"/>
      <property name="Active" type="bool" value="true"/>
    </property>
  </property>
</channel>
EOF

# Note: Conky uses .conkyrc from overlay (already has proper styling)
# Just ensure gap_y is set to 10 in overlay file before build

# Fuse fix
echo "Adding fuse fix..."
mkdir -p config/packages.chroot
wget -P config/packages.chroot http://ftp.debian.org/debian/pool/main/f/fuse/libfuse2t64_2.9.9-9_amd64.deb

# Download maps if user chose to include them
if [ "$INCLUDE_MAPS" = "yes" ]; then
    echo "Creating map download hook..."
    cat > config/hooks/live/0400-download-maps.hook.chroot << 'EOF'
#!/bin/bash
echo "Downloading offline maps (this will take a while)..."

MAP_DIR="/etc/skel/.local/share/emcomm-tools/mbtileserver/tilesets"
mkdir -p ${MAP_DIR}

ET_RELEASE_URL="https://github.com/thetechprepper/emcomm-tools-os-community/releases/download"
ET_RELEASE_TAG="emcomm-tools-os-community-20251128-r5-final-5.0.0"

cd ${MAP_DIR}

echo "Downloading US map tiles (~2GB)..."
curl -L -f --progress-bar -o osm-us-zoom0to11-20251120.mbtiles \
    "${ET_RELEASE_URL}/${ET_RELEASE_TAG}/osm-us-zoom0to11-20251120.mbtiles"

echo "Downloading Canada map tiles (~500MB)..."
curl -L -f --progress-bar -o osm-ca-zoom0to10-20251120.mbtiles \
    "${ET_RELEASE_URL}/${ET_RELEASE_TAG}/osm-ca-zoom0to10-20251120.mbtiles"

echo "Downloading World map tiles (~200MB)..."
curl -L -f --progress-bar -o osm-world-zoom0to7-20251121.mbtiles \
    "${ET_RELEASE_URL}/${ET_RELEASE_TAG}/osm-world-zoom0to7-20251121.mbtiles"

echo "Map download complete!"
EOF
    chmod +x config/hooks/live/0400-download-maps.hook.chroot
    echo "Map download hook created."
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
echo "║  This will take 15-30 minutes depending on your internet speed.      ║"
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
